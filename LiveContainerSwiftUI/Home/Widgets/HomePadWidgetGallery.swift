//
//  HomePadWidgetGallery.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The widget gallery on iPad, as iPadOS 26.5 shows it: a sheet nearly as
/// wide as the screen, rising from the bottom to a little under the top,
/// with a panel down its left listing the apps with widgets, under a search
/// field, and beside it the app's widget at each size it comes in, at the
/// size it will be, to swipe between, with its name above and Add Widget,
/// in the app's color, below. Tapping above it, or pulling it down, closes
/// it. Measured on an iPad Air 11-inch.
struct HomePadWidgetGallery: View {
    @Environment(HomeScreenModel.self) private var model
    @State private var query = ""
    @State private var selection = HomeWidgetKind.calendar
    @State private var pull = 0.0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - Design.sideInset * 2
            let height = geometry.size.height - Design.top

            ZStack(alignment: .top) {
                Color.black
                    .opacity(Design.dimming)
                    .contentShape(.rect)
                    .onTapGesture(perform: close)
                    .accessibilityLabel(Text("lc.common.close".loc))
                    .accessibilityAddTraits(.isButton)
                HStack(alignment: .top, spacing: 0) {
                    sidebar
                        .frame(width: Design.sidebarWidth, height: height - Design.sidebarInset * 2)
                        .padding(Design.sidebarInset)
                    HomePadWidgetSizes(kind: selection, height: height)
                        .id(selection)
                        .frame(maxWidth: .infinity)
                }
                .frame(width: width, height: height, alignment: .topLeading)
                .background(Design.sheet, in: .rect(topLeadingRadius: Design.cornerRadius, topTrailingRadius: Design.cornerRadius, style: .continuous))
                .offset(y: Design.top + max(pull, 0))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            pull = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > Design.pullToClose {
                                close()
                            } else {
                                withAnimation(.spring) {
                                    pull = 0
                                }
                            }
                        }
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .ignoresSafeArea()
        .tint(AppAccent.color)
    }

    // MARK: Sidebar

    /// The search field and the apps with widgets, the one showing selected.
    private var sidebar: some View {
        VStack(spacing: Design.rowSpacing) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("zc.widget.gallery.search".loc, text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .font(.system(size: 17))
            .padding(.horizontal, 12)
            .frame(height: Design.searchHeight)
            .background(Design.searchField, in: .capsule)
            .padding(.top, Design.searchTop)
            .padding(.bottom, Design.searchBottom)
            ScrollView {
                VStack(spacing: Design.rowSpacing) {
                    ForEach(kinds) { kind in
                        row(kind)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(Design.sidebarPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Design.sidebar, in: .rect(cornerRadius: Design.sidebarCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Design.sidebarCornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        }
    }

    /// An app with widgets: its icon and its name, highlighted when it's the
    /// one showing.
    private func row(_ kind: HomeWidgetKind) -> some View {
        let isSelected = kind == selection

        return Button {
            selection = kind
        } label: {
            HStack(spacing: Design.iconSpacing) {
                HomeWidgetAppIcon(app: .init(kind))
                    .frame(width: Design.iconSize, height: Design.iconSize)
                Text(kind.title)
                    .font(.system(size: 17))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Design.rowPadding)
            .frame(height: Design.rowHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Design.rowCornerRadius, style: .continuous)
                        .fill(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The apps whose name, or their widget's, holds what's typed.
    private var kinds: [HomeWidgetKind] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            return HomeWidgetKind.allCases
        }
        return HomeWidgetKind.allCases.filter { kind in
            kind.title.localizedStandardContains(query) || kind.widgetTitle.localizedStandardContains(query)
        }
    }

    private func close() {
        model.isAddingWidget = false
    }

    /// iPadOS's measurements, in points.
    enum Design {
        /// The sheet's distance from the top and from the sides, and its
        /// corners.
        static let top = 114.0
        static let sideInset = 8.0
        static let cornerRadius = 38.0
        /// The panel: its width, its distance from the sheet's edges, the
        /// space inside it, and its corners.
        static let sidebarWidth = 204.5
        static let sidebarInset = 10.0
        static let sidebarPadding = 12.0
        static let sidebarCornerRadius = 26.0
        /// The search field's height and the space under it.
        static let searchHeight = 36.0
        static let searchTop = 13.0
        static let searchBottom = 30.0
        /// An app's row: its height, the space at its sides, its corners,
        /// its icon and the space after it, and the space between rows.
        static let rowHeight = 55.5
        static let rowPadding = 13.0
        static let rowCornerRadius = 14.0
        static let iconSize = 30.0
        static let iconSpacing = 14.5
        static let rowSpacing = 0.0
        /// How far the sheet has to be pulled down to close.
        static let pullToClose = 140.0
        /// How much the Home Screen darkens behind the sheet.
        static let dimming = 0.4

        /// The sheet, the panel and the search field, light or dark.
        static let sheet = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 35 / 255, alpha: 1) : UIColor(white: 0.97, alpha: 1)
        })
        static let sidebar = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 25 / 255, alpha: 1) : UIColor(white: 1, alpha: 1)
        })
        static let searchField = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 30 / 255, alpha: 1) : UIColor(white: 0.93, alpha: 1)
        })
    }
}

/// An app's widget at each size it comes in, at the size it will be, to swipe
/// between, under its name and what it shows, with dots for the sizes and
/// Add Widget in the app's color at the bottom, where iPadOS puts them.
private struct HomePadWidgetSizes: View {
    let kind: HomeWidgetKind
    /// The sheet's height.
    let height: Double

    @Environment(HomeScreenModel.self) private var model
    @State private var size: HomeWidgetSize? = .small

    var body: some View {
        let metrics = model.padMetrics ?? model.metrics ?? .reference

        ZStack(alignment: .top) {
            VStack(spacing: 4) {
                Text(kind.widgetTitle)
                    .font(.title2.bold())
                Text(kind.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, Design.titleTop)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(kind.sizes, id: \.self) { size in
                        HomeWidgetPreview(widget: HomeWidget(size: size, kinds: [kind]), width: HomeWidgetPreview.size(of: size, metrics: metrics).width)
                            .containerRelativeFrame(.horizontal)
                            .id(size)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $size)
            .frame(height: Design.previewHeight)
            .offset(y: height * Design.previewCenter - Design.previewHeight / 2)

            HStack(spacing: Design.dotSpacing) {
                ForEach(kind.sizes, id: \.self) { dot in
                    Circle()
                        .fill(dot == (size ?? .small) ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .frame(width: Design.dotSize, height: Design.dotSize)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, Design.buttonBottom + Design.buttonHeight + Design.dotsAboveButton)
            .accessibilityHidden(true)

            Button(action: add) {
                Label("zc.widget.gallery.add".loc, systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: Design.buttonWidth, height: Design.buttonHeight)
                    .background(kind.galleryTint, in: .capsule)
            }
            .buttonStyle(.plain)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, Design.buttonBottom)
        }
        .frame(height: height)
    }

    private func add() {
        model.addWidget(HomeWidget(size: size ?? .small, kinds: [kind]))
    }

    private enum Design {
        /// The space above the widget's name.
        static let titleTop = 30.0
        /// Where the widget's middle is, as a share of the sheet's height,
        /// and the room the sizes swipe in.
        static let previewCenter = 0.44
        static let previewHeight = 340.0
        /// The dots: their size, the space between them, and above Add
        /// Widget.
        static let dotSize = 7.5
        static let dotSpacing = 10.4
        static let dotsAboveButton = 59.5
        /// Add Widget: its size, and its space from the bottom.
        static let buttonWidth = 459.5
        static let buttonHeight = 49.5
        static let buttonBottom = 75.5
    }
}

/// An app's icon in the widget gallery, as the Home Screen shows it, drawn
/// by the system from the app on the device.
struct HomeWidgetAppIcon: View {
    let app: HomeWidgetAppIcons.App

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            Group {
                if let icon = HomeWidgetAppIcons.shared.image(app, isDark: colorScheme == .dark) {
                    Image(uiImage: icon)
                        .resizable()
                } else {
                    HomeWidgetDesign.placeholder
                }
            }
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: side * HomeDesign.iconCornerFraction, style: .continuous))
        }
        .onAppear {
            HomeWidgetAppIcons.shared.load(app)
        }
        .accessibilityHidden(true)
    }
}

extension HomeWidgetKind {
    /// The color of Add Widget in the gallery: the app's own, as iOS tints it.
    var galleryTint: Color {
        switch self {
        case .calendar:
            Color(red: 239 / 255, green: 82 / 255, blue: 74 / 255)
        case .news:
            Color(red: 250 / 255, green: 45 / 255, blue: 85 / 255)
        case .maps, .photos, .reminders:
            Color(uiColor: .systemBlue)
        }
    }
}

/// Opens the widget gallery: as a sheet on iPhone, and on iPad as iPadOS's
/// own, over the Home Screen.
struct HomeWidgetGalleryPresentation: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        if SharedModel.isPhone {
            content.sheet(isPresented: $isPresented) {
                HomeWidgetGallery()
            }
        } else {
            content.fullScreenCover(isPresented: $isPresented) {
                HomePadWidgetGallery()
                    .presentationBackground(.clear)
                    .statusBarHidden()
            }
        }
    }
}
