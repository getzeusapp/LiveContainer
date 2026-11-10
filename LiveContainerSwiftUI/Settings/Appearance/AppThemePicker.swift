//
//  AppThemePicker.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// zContainer's app theme in Settings > Appearance, picked as the Settings
/// app's Display & Brightness picks Light or Dark: a small picture of the Home
/// Screen in each, with its name and a check under the one showing, then
/// Automatic, which follows iOS. Picking Light or Dark turns Automatic off;
/// turning Automatic off keeps the theme showing.
struct AppThemePicker: View {
    @Binding var appearance: AppAppearance

    @Environment(SystemAppearance.self) private var system
    /// Automatic as its switch shows it. The switch moves when it's tapped,
    /// and the theme follows once the switch has settled: a theme change
    /// redraws the whole screen, the switch too, and one under a switch still
    /// taking a tap undoes the tap.
    @State private var isAutomatic = false
    /// The theme change waiting for the switch to settle.
    @State private var pendingChange: Task<Void, Never>?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            AppThemeChoice(isDark: false, isSelected: !system.isDark) {
                appearance = .light
            }
            AppThemeChoice(isDark: true, isSelected: system.isDark) {
                appearance = .dark
            }
        }
        .padding(.vertical, SettingsDesign.themeChoicesPadding)
        // The line under the pictures runs from the card's edge, as the
        // Settings app's does, not from the names under them.
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading]
        }
        .sensoryFeedback(.selection, trigger: system.isDark)

        Toggle(AppAppearance.automatic.title, isOn: $isAutomatic)
            .onChange(of: appearance, initial: true) {
                isAutomatic = appearance == .automatic
            }
            .onChange(of: isAutomatic) {
                followSwitch()
            }
    }

    /// Has the theme follow iOS once Automatic's switch has settled, or keep
    /// the theme showing when it's turned off.
    private func followSwitch() {
        pendingChange?.cancel()
        guard isAutomatic != (appearance == .automatic) else {
            return
        }
        let isAutomatic = isAutomatic
        pendingChange = Task {
            try? await Task.sleep(for: SettingsDesign.themeSwitchSettling)
            guard !Task.isCancelled else {
                return
            }
            if isAutomatic {
                appearance = .automatic
            } else {
                appearance = system.isDark ? .dark : .light
            }
        }
    }
}

/// Light or Dark: the Home Screen in it, its name, and a check when it's the
/// theme showing.
private struct AppThemeChoice: View {
    let isDark: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let title = (isDark ? AppAppearance.dark : AppAppearance.light).title

        Button(action: action) {
            VStack(spacing: SettingsDesign.themeChoiceSpacing) {
                AppThemePreview(isDark: isDark)

                Text(title)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.tertiary), isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// The Home Screen's first page and dock, small, in Light or Dark: the
/// wallpaper, dimmed as Dark dims a photo, and the icons in their light or
/// dark versions, where the Home Screen puts them, inside a phone's or
/// iPad's outline.
private struct AppThemePreview: View {
    let isDark: Bool

    @Environment(WallpaperStore.self) private var wallpaper
    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        let metrics = metrics
        let height = SettingsDesign.themePreviewHeight
        let scale = height / metrics.size.height
        let width = metrics.size.width * scale
        let screen = RoundedRectangle(cornerRadius: height * SettingsDesign.themePreviewCornerFraction, style: .continuous)

        ZStack(alignment: .topLeading) {
            wallpaperLayer
            page(metrics: metrics, scale: scale)
            dock(metrics: metrics, scale: scale)
        }
        .frame(width: width, height: height)
        .clipShape(screen)
        .overlay {
            screen.strokeBorder(.black, lineWidth: SettingsDesign.themePreviewBezel)
        }
        .overlay {
            screen.strokeBorder(.separator, lineWidth: 0.5)
        }
        .environment(\.colorScheme, isDark ? .dark : .light)
        .environment(\.prefersDarkAppIcons, isDark)
        .accessibilityHidden(true)
    }

    /// The wallpaper, with a photo dimmed in Dark when Dark dims it.
    private var wallpaperLayer: some View {
        Color.black
            .overlay {
                if let image = wallpaper.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay {
                Color.black
                    .opacity(isDark && wallpaper.isCustom && wallpaper.dimsInDarkMode ? HomeDesign.wallpaperDimming : 0)
            }
            .clipped()
    }

    /// The first page's icons and widgets, where the Home Screen puts them.
    private func page(metrics: HomeMetrics, scale: Double) -> some View {
        let layout = model.layout
        let grid = layout.grid(forPage: 0, on: metrics)
        let pageMetrics = layout.metrics(forPage: 0, on: metrics)
        let items = Array((layout.pages.first ?? []).enumerated()).filter { index, _ in
            index < grid.origins.count && grid.origins[index] != nil
        }

        return ForEach(items, id: \.element) { index, item in
            if let widget = model.widget(for: item), let frame = layout.widgetFrame(ofPage: 0, index: index, on: metrics) {
                previewWidget(widget, frame: frame, metrics: metrics, scale: scale)
            } else {
                let center = pageMetrics.iconCenter(at: grid.origins[index] ?? index)
                icon(item, size: metrics.iconSize * scale)
                    .position(x: center.x * scale, y: center.y * scale)
            }
        }
    }

    /// A widget, drawn at its size on the Home Screen and made small.
    private func previewWidget(_ widget: HomeWidget, frame: CGRect, metrics: HomeMetrics, scale: Double) -> some View {
        HomeWidgetContent(kind: widget.kinds.first ?? .calendar, size: widget.size, frameSize: frame.size)
            .frame(width: frame.width, height: frame.height)
            .clipShape(.rect(cornerRadius: metrics.widgetCornerRadius, style: .continuous))
            .scaleEffect(scale)
            .frame(width: frame.width * scale, height: frame.height * scale)
            .position(x: frame.midX * scale, y: frame.midY * scale)
    }

    /// The dock's glass and its icons, and on an iPad the divider and the
    /// recent apps after them.
    private func dock(metrics: HomeMetrics, scale: Double) -> some View {
        let items = model.layout.dock
        let recents = model.dockRecents
        let contents = HomeDockContents(icons: items.count, recents: recents.count)
        let frame = metrics.dockGlass(contents)
        let size = metrics.dockIconSize(contents) * scale
        let padDock = metrics.padDock(contents)

        return ZStack(alignment: .topLeading) {
            Group {
                if metrics.isDockFlush {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: metrics.dockCornerRadius(contents) * scale, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .frame(width: frame.width * scale, height: frame.height * scale)
            .position(x: frame.midX * scale, y: frame.midY * scale)

            if let padDock, padDock.showsDivider {
                Rectangle()
                    .fill(.white.opacity(HomeDesign.padDockDividerOpacity))
                    .frame(width: max(padDock.divider.width * scale, 0.5), height: padDock.divider.height * scale)
                    .position(x: padDock.divider.midX * scale, y: padDock.divider.midY * scale)
            }

            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                let center = metrics.dockIconCenter(at: index, in: contents)
                icon(item, size: size)
                    .position(x: center.x * scale, y: center.y * scale)
            }

            ForEach(Array(recents.enumerated()), id: \.element) { index, item in
                let center = metrics.dockRecentCenter(at: index, in: contents)
                icon(item, size: size)
                    .position(x: center.x * scale, y: center.y * scale)
            }
        }
    }

    /// An app's icon, Settings', or a folder with its first icons in it.
    @ViewBuilder
    private func icon(_ item: HomeItem, size: Double) -> some View {
        let corner = size * HomeDesign.iconCornerFraction

        switch item {
        case .app(let key):
            Group {
                if let app = model.apps[key] {
                    HomeAppIconImage(app: app, isDark: isDark)
                } else {
                    HomeDesign.iconPlaceholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: corner, style: .continuous))
        case .settings:
            HomeSettingsArtwork(size: size, cornerRadius: corner)
        case .folder(let id):
            folder(model.layout.folders[id]?.items ?? [], size: size, corner: corner)
        case .widget:
            EmptyView()
        }
    }

    /// A folder's glass, with its first nine apps' icons in three rows.
    private func folder(_ items: [HomeItem], size: Double, corner: Double) -> some View {
        let mini = size * SettingsDesign.themePreviewFolderIconRatio
        let gap = size * SettingsDesign.themePreviewFolderGapRatio
        let apps = items.prefix(HomeFolder.iconsPerPage).compactMap { item -> LCAppModel? in
            if case .app(let key) = item {
                model.apps[key]
            } else {
                nil
            }
        }

        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .frame(width: size, height: size)
            .overlay {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(mini), spacing: gap), count: 3), spacing: gap) {
                    ForEach(apps, id: \.self) { app in
                        HomeAppIconImage(app: app, isDark: isDark)
                            .frame(width: mini, height: mini)
                            .clipShape(.rect(cornerRadius: mini * HomeDesign.iconCornerFraction, style: .continuous))
                    }
                }
                .frame(width: mini * 3 + gap * 2, height: mini * 3 + gap * 2, alignment: .top)
            }
    }

    /// Where the Home Screen puts its icons. On iPhone, the Home Screen's own
    /// layout. On iPad, the window's, as Settings measured it.
    private var metrics: HomeMetrics {
        if SharedModel.isPhone {
            model.metrics ?? .reference
        } else {
            model.padMetrics ?? model.metrics ?? .reference
        }
    }
}
