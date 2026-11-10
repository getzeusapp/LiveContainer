//
//  HomeNewsStories.swift
//  LiveContainerSwiftUI
//

import Foundation
import SwiftUI

/// The stories the News widget shows: today's top stories for the country
/// the device is set to, in its language where the country has an edition in
/// it and otherwise in the country's own, from Google News' top stories feed,
/// as Apple News isn't something zContainer can read. Each has its headline,
/// where it's from and when it was published. They're fetched when a News
/// widget shows and the ones it has are more than half an hour old, and kept
/// in Caches, so the widget shows the last ones straight away.
@MainActor
@Observable
final class HomeNewsStories {
    static let shared = HomeNewsStories()

    /// A story: its headline, its publisher, when it was published, and the
    /// page it opens.
    struct Story: Codable, Identifiable, Equatable, Sendable {
        var id: URL {
            link
        }
        let headline: String
        let source: String
        let published: Date?
        let link: URL
    }

    /// The stories, top first. Empty until they've been fetched once, or
    /// while there's no connection and none were kept.
    private(set) var stories: [Story] = []
    @ObservationIgnored private var fetchedAt: Date?
    @ObservationIgnored private var isFetching = false

    /// How long stories are kept before they're fetched again.
    private static let refreshInterval: TimeInterval = 30 * 60

    init() {
        if let saved = try? Data(contentsOf: Self.cacheURL),
           let cache = try? JSONDecoder().decode(Cache.self, from: saved) {
            stories = cache.stories
            fetchedAt = cache.fetchedAt
        }
    }

    /// Fetches the stories when they're older than half an hour, or there
    /// are none.
    func refreshIfNeeded() {
        guard !isFetching else {
            return
        }
        if let fetchedAt, Date.now.timeIntervalSince(fetchedAt) < Self.refreshInterval, !stories.isEmpty {
            return
        }
        isFetching = true
        Task {
            await fetch()
            isFetching = false
        }
    }

    private func fetch() async {
        for edition in Self.editions() {
            guard let url = edition.url,
                  let (data, response) = try? await URLSession.shared.data(for: Self.request(url)),
                  (response as? HTTPURLResponse)?.statusCode == 200 else {
                continue
            }
            let found = await Task.detached(priority: .utility) {
                HomeNewsFeedParser.stories(in: data)
            }.value
            guard !found.isEmpty else {
                continue
            }
            stories = found
            fetchedAt = .now
            Self.rememberEdition(edition)
            if let saved = try? JSONEncoder().encode(Cache(stories: found, fetchedAt: .now)) {
                try? FileManager.default.createDirectory(at: Self.cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? saved.write(to: Self.cacheURL, options: .atomic)
            }
            return
        }
    }

    private static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/rss+xml, application/xml", forHTTPHeaderField: "Accept")
        return request
    }

    // MARK: Editions

    /// A Google News edition: its language and country.
    struct Edition: Equatable, Sendable {
        let language: String
        let country: String

        var url: URL? {
            var components = URLComponents(string: "https://news.google.com/rss")
            components?.queryItems = [
                URLQueryItem(name: "hl", value: language),
                URLQueryItem(name: "gl", value: country),
                URLQueryItem(name: "ceid", value: "\(country):\(language)"),
            ]
            return components?.url
        }
    }

    /// The editions to try, best first: the one that worked last time for
    /// this language and country, the device's language in its country, the
    /// country's own language, then the United States' in English.
    private static func editions() -> [Edition] {
        let locale = Locale.current
        let country = locale.region?.identifier ?? "US"
        let language = googleLanguage(locale.language.languageCode?.identifier ?? "en")
        var candidates: [Edition] = []
        if let remembered = rememberedEdition() {
            candidates.append(remembered)
        }
        candidates.append(Edition(language: "\(language)-\(country)", country: country))
        candidates.append(Edition(language: language, country: country))
        let maximal = Locale.Language(identifier: "und-\(country)").maximalIdentifier
        if let own = Locale.Language(identifier: maximal).languageCode?.identifier {
            let own = googleLanguage(own)
            candidates.append(Edition(language: "\(own)-\(country)", country: country))
            candidates.append(Edition(language: own, country: country))
        }
        candidates.append(Edition(language: "en-US", country: "US"))
        var unique: [Edition] = []
        for candidate in candidates where !unique.contains(candidate) {
            unique.append(candidate)
        }
        return unique
    }

    /// The language code Google News uses for a language: Norwegian is "no",
    /// and Hebrew is "iw".
    private static func googleLanguage(_ code: String) -> String {
        switch code {
        case "nb", "nn":
            "no"
        case "he":
            "iw"
        default:
            code
        }
    }

    private static var editionKey: String {
        "ZCNewsEdition-\(Locale.current.identifier)"
    }

    private static func rememberEdition(_ edition: Edition) {
        UserDefaults.standard.set([edition.language, edition.country], forKey: editionKey)
    }

    private static func rememberedEdition() -> Edition? {
        guard let saved = UserDefaults.standard.stringArray(forKey: editionKey), saved.count == 2 else {
            return nil
        }
        return Edition(language: saved[0], country: saved[1])
    }

    // MARK: Cache

    private struct Cache: Codable {
        let stories: [Story]
        let fetchedAt: Date
    }

    private static var cacheURL: URL {
        URL.cachesDirectory
            .appending(path: "HomeScreen", directoryHint: .isDirectory)
            .appending(path: "NewsStories.json")
    }
}

/// Reads stories out of an RSS feed: each item's title, link, publication
/// date and source, the headline without the " - Source" the feed adds.
private final class HomeNewsFeedParser: NSObject, XMLParserDelegate {
    private var stories: [HomeNewsStories.Story] = []
    private var element = ""
    private var title = ""
    private var link = ""
    private var date = ""
    private var source = ""
    private var isInItem = false

    static func stories(in data: Data) -> [HomeNewsStories.Story] {
        let parser = XMLParser(data: data)
        let reader = HomeNewsFeedParser()
        parser.delegate = reader
        parser.parse()
        return reader.stories
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        element = elementName
        if elementName == "item" {
            isInItem = true
            title = ""
            link = ""
            date = ""
            source = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else {
            return
        }
        switch element {
        case "title":
            title += string
        case "link":
            link += string
        case "pubDate":
            date += string
        case "source":
            source += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer {
            element = ""
        }
        guard elementName == "item" else {
            return
        }
        isInItem = false
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        var headline = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty, headline.hasSuffix(" - \(source)") {
            headline = String(headline.dropLast(source.count + 3))
        }
        guard !headline.isEmpty, let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        stories.append(HomeNewsStories.Story(
            headline: headline,
            source: source,
            published: Self.dateFormatter.date(from: date.trimmingCharacters(in: .whitespacesAndNewlines)),
            link: url
        ))
    }
}
