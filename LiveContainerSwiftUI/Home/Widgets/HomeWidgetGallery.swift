//
//  HomeWidgetGallery.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The widget gallery, from edit mode's Edit menu, as iOS's Add Widget sheet:
/// a search field, then each app's widget as a small one shows it, with the
/// app's name. Choosing one shows it at each size it comes in, to swipe
/// between, with Add Widget under it, which puts it at the top of the page
/// showing.
struct HomeWidgetGallery: View {
    @Environment(HomeScreenModel.self) private var model
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 22) {
                    ForEach(kinds) { kind in
                        NavigationLink(value: kind) {
                            HomeWidgetGalleryTile(kind: kind)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "zc.widget.gallery.search".loc)
            .navigationDestination(for: HomeWidgetKind.self) { kind in
                HomeWidgetSizes(kind: kind)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("lc.common.cancel".loc, systemImage: "xmark") {
                        model.isAddingWidget = false
                    }
                }
            }
        }
        .tint(AppAccent.color)
    }

    /// The widgets whose app or widget name holds what's typed.
    private var kinds: [HomeWidgetKind] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            return HomeWidgetKind.allCases
        }
        return HomeWidgetKind.allCases.filter { kind in
            kind.title.localizedStandardContains(query) || kind.widgetTitle.localizedStandardContains(query)
        }
    }
}

/// A widget in the gallery's grid: its small size as it shows, with the
/// app's name under it.
private struct HomeWidgetGalleryTile: View {
    let kind: HomeWidgetKind

    var body: some View {
        VStack(spacing: 8) {
            HomeWidgetPreview(widget: HomeWidget(size: .small, kinds: [kind]), width: 150)
            Text(kind.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(kind.title))
        .accessibilityAddTraits(.isButton)
    }
}

/// A widget's sizes, to swipe between, with its name and what it shows above
/// and Add Widget below, as iOS's gallery shows an app's widget.
private struct HomeWidgetSizes: View {
    let kind: HomeWidgetKind

    @Environment(HomeScreenModel.self) private var model
    @State private var size = HomeWidgetSize.small

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(kind.widgetTitle)
                    .font(.title2.bold())
                Text(kind.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            TabView(selection: $size) {
                ForEach(kind.sizes, id: \.self) { size in
                    HomeWidgetPreview(widget: HomeWidget(size: size, kinds: [kind]), width: previewWidth(for: size))
                        .tag(size)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: add) {
                Label("zc.widget.gallery.add".loc, systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .navigationTitle(kind.title)
    }

    /// How wide a size shows: as a widget of that size is on an iPhone, so
    /// they keep their proportions.
    private func previewWidth(for size: HomeWidgetSize) -> Double {
        size == .small ? 170 : 340
    }

    private func add() {
        model.addWidget(HomeWidget(size: size, kinds: [kind]))
    }
}

/// A widget drawn at the size it has on the Home Screen, made `width` wide,
/// for the gallery.
struct HomeWidgetPreview: View {
    let widget: HomeWidget
    let width: Double

    @Environment(HomeScreenModel.self) private var model
    @State private var shownKind: HomeWidgetKind?

    var body: some View {
        let metrics = model.metrics ?? .reference
        let size = Self.size(of: widget.size, metrics: metrics)
        let scale = width / size.width

        HomeWidgetView(widget: widget, size: size, cornerRadius: metrics.widgetCornerRadius, shownKind: $shownKind, contentScale: metrics.widgetContentScale)
            .scaleEffect(scale)
            .frame(width: size.width * scale, height: size.height * scale)
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .allowsHitTesting(false)
    }

    /// A widget's size on the Home Screen: its block of places, from the top
    /// left of a page.
    static func size(of size: HomeWidgetSize, metrics: HomeMetrics) -> CGSize {
        let pageMetrics = metrics.forWidgetPage
        return pageMetrics.widgetFrame(origin: 0, span: size.span).size
    }
}
