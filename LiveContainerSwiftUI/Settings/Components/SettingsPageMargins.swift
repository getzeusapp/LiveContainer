//
//  SettingsPageMargins.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UIKit

/// The space around the cards of a page of Settings whose counterpart in the
/// Settings app is drawn with UIKit, such as General, Developer and each
/// app's page: UIKit's margins at the sides, which differ from SwiftUI's
/// (wider on larger iPhones, narrower in the iPad's detail column), and its
/// smaller gap above the first card. The Settings app's own list and its
/// newer pages, such as Apps, keep SwiftUI's.
struct SettingsPageMargins: ViewModifier {
    /// Whether the page takes UIKit's margins on iPad too, as it does in
    /// Settings' detail column.
    let isOnPad: Bool

    /// How wide the page is, which UIKit's margins depend on.
    @State private var width = 0.0

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *), isOnPad || SharedModel.isPhone {
            let margins = UIKitListMargins.margins(width: width)
            content
                .contentMargins(.leading, margins.map { CGFloat($0.leading) }, for: .scrollContent)
                .contentMargins(.trailing, margins.map { CGFloat($0.trailing) }, for: .scrollContent)
                .contentMargins(.top, SettingsDesign.uiKitPageTopMargin, for: .scrollContent)
                .onGeometryChange(for: Double.self) { proxy in
                    proxy.size.width
                } action: { width in
                    self.width = width
                }
                .environment(\.isSettingsPageSpacedAsUIKit, true)
        } else {
            content
        }
    }
}

extension View {
    /// Spaces a page's cards as the Settings app's UIKit pages are spaced, on
    /// iPhone and, unless `isOnPad` is false, on iPad.
    func settingsPageMargins(isOnPad: Bool = true) -> some View {
        modifier(SettingsPageMargins(isOnPad: isOnPad))
    }

    /// Places a section's header as the Settings app's UIKit pages do, on a
    /// page spaced as they are: a little lower under the card above, and
    /// closer over its own card than SwiftUI puts it. Elsewhere it leaves
    /// the header as it is.
    func settingsSectionHeader() -> some View {
        modifier(SettingsSectionHeader())
    }
}

/// A section's header placed as UIKit places it, where its page is spaced
/// as UIKit spaces it.
private struct SettingsSectionHeader: ViewModifier {
    @Environment(\.isSettingsPageSpacedAsUIKit) private var isSpacedAsUIKit

    func body(content: Content) -> some View {
        if isSpacedAsUIKit {
            content
                .padding(.top, SettingsDesign.uiKitHeaderLowering)
                .padding(.bottom, -SettingsDesign.uiKitHeaderCardRaise)
        } else {
            content
        }
    }
}

extension EnvironmentValues {
    /// Whether the page is spaced as the Settings app's UIKit pages are, so
    /// its section headers are placed as theirs are.
    @Entry var isSettingsPageSpacedAsUIKit = false
}

/// The margins at the sides of UIKit's inset grouped lists, which the
/// Settings app's UIKit pages inset their cards by. UIKit only says once it
/// has a list to lay out, so one as wide as the page is laid out unseen in
/// the window, once for each width.
@MainActor
private enum UIKitListMargins {
    private static var sides: [Double: Double] = [:]

    /// The margins for a page `width` points wide, from the sides of its
    /// list's scroll view, or nil, for SwiftUI's own, until the page has been
    /// measured.
    static func margins(width: Double) -> (leading: Double, trailing: Double)? {
        guard width > 0, let window = keyWindow else {
            return nil
        }
        let side = side(width: width, in: window)
        return (side + underSidebar(width: width, in: window), side)
    }

    /// How far the list of a page `width` points wide scrolls under the
    /// sidebar beside it. From iOS 26, the iPad's sidebar floats over the
    /// detail column, whose list reaches under it, and SwiftUI measures a
    /// content margin from there; the sidebar takes the part of the window
    /// the page doesn't. Settings' pages fill the window otherwise.
    private static func underSidebar(width: Double, in window: UIWindow) -> Double {
        guard #available(iOS 26.0, *), !SharedModel.isPhone else {
            return 0
        }
        return max(Double(window.bounds.width) - width, 0)
    }

    private static func side(width: Double, in window: UIWindow) -> Double {
        if let side = sides[width] {
            return side
        }
        let list = UITableView(frame: CGRect(x: 0, y: 0, width: width, height: window.bounds.height), style: .insetGrouped)
        list.isHidden = true
        window.addSubview(list)
        list.layoutIfNeeded()
        let side = max(Double(list.layoutMargins.left - window.safeAreaInsets.left), 0)
        list.removeFromSuperview()
        sides[width] = side
        return side
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .lazy
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first
    }
}
