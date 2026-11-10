//
//  HomeMapsWidget.swift
//  LiveContainerSwiftUI
//

import CoreLocation
import MapKit
import SwiftUI

/// Maps' widget, as iOS draws it: a map of where you are, with the blue dot
/// of your location in its middle, once zContainer may know where you are,
/// which the widget asks when it first shows; until then, a map of the
/// country the device is set to. It follows you while it's on screen. When
/// zContainer may only know roughly where you are, it shows more of the map
/// around you, with the area you're in shaded, as Maps does, rather than a
/// dot that may be in the wrong place. Light or dark as the theme is. MapKit
/// draws each map once, and it's kept in Caches.
struct HomeMapsWidget: View {
    /// The widget's size, as it's laid out.
    let frameSize: CGSize

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let location = HomeMapLocation.shared
        let key = HomeMapSnapshots.Key(
            width: Int(frameSize.width.rounded()),
            height: Int(frameSize.height.rounded()),
            isDark: colorScheme == .dark,
            place: location.coordinate.map(HomeMapSnapshots.Place.init),
            isApproximate: location.isApproximate
        )
        // A map of somewhere else isn't shown while this one is drawn: only
        // the last one of the same place.
        let image = HomeMapSnapshots.shared.image(key) ?? HomeMapSnapshots.shared.nearbyImage(for: key)

        ZStack {
            HomeWidgetDesign.mapPlaceholder
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
            if location.coordinate != nil {
                if location.isApproximate {
                    HomeMapApproximateArea(diameter: frameSize.height * HomeWidgetDesign.approximateAreaShare)
                } else {
                    HomeMapLocationDot()
                }
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .clipped()
        .animation(.easeOut(duration: 0.3), value: image)
        .task(id: key) {
            await HomeMapSnapshots.shared.load(key)
        }
        .onAppear {
            HomeMapLocation.shared.widgetAppeared()
        }
        .onDisappear {
            HomeMapLocation.shared.widgetDisappeared()
        }
    }
}

/// Your location on the Maps widget: a blue dot in a white ring, with a soft
/// shadow under it, as Maps draws it.
private struct HomeMapLocationDot: View {
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: HomeWidgetDesign.locationRing, height: HomeWidgetDesign.locationRing)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 0.5)
            .overlay {
                Circle()
                    .fill(Color(uiColor: .systemBlue))
                    .frame(width: HomeWidgetDesign.locationDot, height: HomeWidgetDesign.locationDot)
            }
            .accessibilityHidden(true)
    }
}

/// Where you are, roughly, as iOS shows Maps when it may only know roughly:
/// the area you're in, shaded blue, with a ring around it.
private struct HomeMapApproximateArea: View {
    let diameter: Double

    var body: some View {
        Circle()
            .fill(Color(uiColor: .systemBlue).opacity(0.18))
            .overlay {
                Circle()
                    .strokeBorder(Color(uiColor: .systemBlue).opacity(0.5), lineWidth: 1)
            }
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}

/// Where you are, for the Maps widget, once zContainer may know: followed
/// while a Maps widget is on screen, as you move.
@MainActor
@Observable
final class HomeMapLocation: NSObject, CLLocationManagerDelegate {
    static let shared = HomeMapLocation()

    /// Where you are, or nil until it's known, or while zContainer may not
    /// know.
    private(set) var coordinate: CLLocationCoordinate2D?
    /// Whether zContainer may only know roughly where you are, which iOS
    /// allows unless Precise Location is on for it.
    private(set) var isApproximate = false
    @ObservationIgnored private let manager = CLLocationManager()
    /// How many Maps widgets are on screen.
    @ObservationIgnored private var showing = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // A new place a few hundred meters on is worth a new map.
        manager.distanceFilter = 250
        isApproximate = manager.accuracyAuthorization == .reducedAccuracy
    }

    /// Follows where you are while a Maps widget is on screen.
    func widgetAppeared() {
        showing += 1
        update()
    }

    func widgetDisappeared() {
        showing = max(showing - 1, 0)
        update()
    }

    private func update() {
        if showing > 0, isAllowed {
            manager.startUpdatingLocation()
        } else {
            manager.stopUpdatingLocation()
        }
    }

    /// Whether zContainer may ask where you are, which it hasn't yet.
    var canAsk: Bool {
        manager.authorizationStatus == .notDetermined
    }

    private var isAllowed: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// Asks to know where you are while zContainer is open, as the Maps
    /// widget needs.
    func requestAccess() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            isApproximate = manager.accuracyAuthorization == .reducedAccuracy
            if !isAllowed {
                coordinate = nil
            }
            update()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        MainActor.assumeIsolated {
            coordinate = location.coordinate
            isApproximate = manager.accuracyAuthorization == .reducedAccuracy
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
}

/// The maps the Maps widgets show, by size, look and place. Each is drawn
/// once, off the main thread, and kept in Caches.
@MainActor
@Observable
final class HomeMapSnapshots {
    static let shared = HomeMapSnapshots()

    /// A place a map is centered on, to about a hundred meters, so moving a
    /// little doesn't draw a new map.
    struct Place: Hashable, Sendable {
        let latitude: Int
        let longitude: Int

        init(_ coordinate: CLLocationCoordinate2D) {
            latitude = Int((coordinate.latitude * 1000).rounded())
            longitude = Int((coordinate.longitude * 1000).rounded())
        }

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: Double(latitude) / 1000, longitude: Double(longitude) / 1000)
        }
    }

    struct Key: Hashable, Sendable {
        let width: Int
        let height: Int
        let isDark: Bool
        /// Where the map is centered, or nil for the country's map.
        let place: Place?
        /// Whether the place is only roughly known, which shows more of the
        /// map around it.
        let isApproximate: Bool
    }

    private var images: [Key: UIImage] = [:]
    @ObservationIgnored private var requested: Set<Key> = []
    /// The region shown without a location: the country the device is set to.
    @ObservationIgnored private var region: MKCoordinateRegion?

    /// How much of the map a widget shows around you, top to bottom, in
    /// meters, for each point of its height, as Maps' widget zooms in.
    private static let metersPerPoint = 32.0
    /// How much more of the map shows when your location is only roughly
    /// known.
    private static let approximateZoomOut = 4.0

    func image(_ key: Key) -> UIImage? {
        images[key]
    }

    /// A map drawn at the same size and look of a place within a kilometer
    /// of `key`'s, to show while `key`'s is drawn, so moving a little doesn't
    /// flash the map away. A map of anywhere further isn't one.
    func nearbyImage(for key: Key) -> UIImage? {
        guard let place = key.place else {
            return nil
        }
        return images.first { candidate in
            guard candidate.key.width == key.width, candidate.key.height == key.height,
                  candidate.key.isDark == key.isDark, candidate.key.isApproximate == key.isApproximate,
                  let other = candidate.key.place else {
                return false
            }
            return abs(other.latitude - place.latitude) <= 9 && abs(other.longitude - place.longitude) <= 18
        }?.value
    }

    /// Draws the map of `key`, unless it's drawn or being drawn.
    func load(_ key: Key) async {
        guard !requested.contains(key), key.width > 0, key.height > 0 else {
            return
        }
        requested.insert(key)
        let file = Self.cacheURL(key)
        if let saved = UIImage(contentsOfFile: file.path(percentEncoded: false)) {
            images[key] = saved
            return
        }
        let mapRegion: MKCoordinateRegion
        if let place = key.place {
            let height = Double(key.height) * Self.metersPerPoint * (key.isApproximate ? Self.approximateZoomOut : 1)
            mapRegion = MKCoordinateRegion(center: place.coordinate, latitudinalMeters: height, longitudinalMeters: height * Double(key.width) / Double(key.height))
        } else if let country = await countryRegion() {
            mapRegion = country
        } else {
            requested.remove(key)
            return
        }
        let options = MKMapSnapshotter.Options()
        options.region = mapRegion
        options.size = CGSize(width: key.width, height: key.height)
        options.mapType = .standard
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: key.isDark ? .dark : .light)
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else {
            requested.remove(key)
            return
        }
        let image = snapshot.image
        images[key] = image
        if let png = image.pngData() {
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? png.write(to: file, options: .atomic)
        }
    }

    /// The country the device is set to, as Maps shows it without your
    /// location, found once by name.
    private func countryRegion() async -> MKCoordinateRegion? {
        if let region {
            return region
        }
        let code = Locale.current.region?.identifier ?? "US"
        guard let name = Locale(identifier: "en_US").localizedString(forRegionCode: code) else {
            return nil
        }
        guard let placemark = try? await CLGeocoder().geocodeAddressString(name).first,
              let location = placemark.location else {
            return nil
        }
        let radius = (placemark.region as? CLCircularRegion)?.radius ?? 500_000
        let found = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: radius * 1.3, longitudinalMeters: radius * 1.3)
        region = found
        return found
    }

    /// Where a map is kept: one for each place or country, size and look.
    private static func cacheURL(_ key: Key) -> URL {
        let place = key.place.map { "\($0.latitude)_\($0.longitude)" } ?? (Locale.current.region?.identifier ?? "US")
        return URL.cachesDirectory
            .appending(path: "HomeScreen", directoryHint: .isDirectory)
            .appending(path: "Maps-4-\(place)\(key.isApproximate ? "-approximate" : "")-\(key.width)x\(key.height)-\(key.isDark ? "dark" : "light").png")
    }
}
