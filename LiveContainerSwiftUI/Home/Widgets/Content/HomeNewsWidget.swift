//
//  HomeNewsWidget.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// News' Today widget: today's top stories, as HomeNewsStories fetches them,
/// each with where it's from and its headline, and tapping one opens it. The
/// small widget shows the top story in white on dark, as iOS's draws its
/// story over a photo; the medium one shows Top Stories; the large one adds
/// Trending under a line. Until there are stories, it's as iOS draws it with
/// none: News' mark and No Stories.
struct HomeNewsWidget: View {
    let size: HomeWidgetSize
    /// The widget's size on screen.
    let frameSize: CGSize

    var body: some View {
        let stories = HomeNewsStories.shared.stories

        // Checked every five minutes, so stories more than half an hour old
        // are fetched again while the widget shows.
        TimelineView(.periodic(from: .now, by: 300)) { context in
            Group {
                switch size {
                case .small:
                    small(stories.first)
                case .medium, .large:
                    lists(stories)
                }
            }
            .onChange(of: context.date) {
                HomeNewsStories.shared.refreshIfNeeded()
            }
        }
        .onAppear {
            HomeNewsStories.shared.refreshIfNeeded()
        }
    }

    // MARK: Small

    /// The top story in white over the dark gradient, or No Stories: dark
    /// whatever the theme, as iOS's is.
    private func small(_ story: HomeNewsStories.Story?) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(red: 0.24, green: 0.24, blue: 0.25), Color(red: 0.13, green: 0.13, blue: 0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
            HomeNewsMark()
                .fill(.white)
                .frame(width: 13, height: 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(16)
            if let story {
                VStack(alignment: .leading, spacing: 3) {
                    Text(story.source)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Text(story.headline)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
            } else {
                Text("zc.widget.news.noStories".loc)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.56))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: Medium and large

    /// Top Stories and, on a large widget, Trending under a line.
    private func lists(_ stories: [HomeNewsStories.Story]) -> some View {
        let isLarge = size == .large
        let top = Array(stories.prefix(2))
        let trending = Array(stories.dropFirst(2).prefix(2))

        return VStack(alignment: .leading, spacing: 0) {
            heading("zc.widget.news.topStories".loc, color: .pink, showsMark: true)
            if top.isEmpty {
                if isLarge {
                    placeholderStory
                        .padding(.top, 4.5)
                    placeholderStory
                        .padding(.top, 11.7)
                }
            } else {
                VStack(alignment: .leading, spacing: isLarge ? 11.7 : 9) {
                    ForEach(top) { story in
                        storyRow(story, lines: isLarge ? 3 : 2, height: isLarge ? 69.3 : nil)
                    }
                }
                .padding(.top, isLarge ? 4.5 : 6)
            }
            if isLarge {
                Rectangle()
                    .fill(HomeWidgetDesign.divider)
                    .frame(height: 1 / 2)
                    .padding(.top, 14.4)
                heading("zc.widget.news.trending".loc, color: .orange, showsMark: false)
                    .padding(.top, 11.7)
                if !trending.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(trending) { story in
                            storyRow(story, lines: 2, height: nil)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
            if top.isEmpty || (isLarge && trending.isEmpty) {
                Text("zc.widget.news.noStories".loc)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(15.3)
        .padding(.bottom, 1.8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { HomeWidgetBackground() }
    }

    /// A list's name, and on the first, News' mark at the right.
    private func heading(_ title: String, color: Color, showsMark: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 15.3, weight: .bold))
                .foregroundStyle(color)
            Spacer()
            if showsMark {
                HomeNewsMark()
                    .fill(.pink)
                    .frame(width: 11.7, height: 11.7)
            }
        }
    }

    /// A story: where it's from in small capitals, then its headline.
    private func storyRow(_ story: HomeNewsStories.Story, lines: Int, height: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(story.source)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)
            Text(story.headline)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(lines)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: height.map { CGFloat($0) }, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    /// Gray bars where a story's source and headline go, and a square where
    /// its picture goes, as iOS draws them with no stories.
    private var placeholderStory: some View {
        HStack(alignment: .top, spacing: 7.2) {
            VStack(alignment: .leading, spacing: 6.1) {
                RoundedRectangle(cornerRadius: 1.8)
                    .fill(HomeWidgetDesign.placeholder)
                    .frame(width: 45, height: 8.1)
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1.8)
                        .fill(HomeWidgetDesign.placeholder)
                        .frame(height: 9)
                }
            }
            .padding(.top, 3.6)
            RoundedRectangle(cornerRadius: 6.8, style: .continuous)
                .fill(HomeWidgetDesign.placeholder)
                .frame(width: 69.3, height: 69.3)
        }
    }
}

/// News' mark: the N its icon draws, of two pieces either side of a gap
/// running down from the top left.
struct HomeNewsMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        // The left piece: the N's left stroke and the lower half of its
        // diagonal.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.2))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.8, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        // The right piece: the upper half of the diagonal and the right stroke.
        path.move(to: CGPoint(x: rect.minX + w * 0.2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.8))
        path.closeSubpath()
        return path
    }
}
