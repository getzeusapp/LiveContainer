//
//  SettingsRow.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A row of the Settings page itself: a colored icon, the name of the page it
/// opens and, on the trailing side, a summary of what that page holds.
struct SettingsRow<Value: View>: View {
    /// The row's name, already localized.
    let title: String
    /// The SF Symbol on the row's icon.
    let systemImage: String
    /// The color of the row's icon.
    let color: Color
    /// The Settings app's icon for the row, where it has one: an IconServices
    /// graphic icon type, which shows in place of the symbol.
    var graphicIcon: String?
    /// What shows on the trailing side, such as the current choice.
    @ViewBuilder let value: Value

    var body: some View {
        LabeledContent {
            value
        } label: {
            Label {
                Text(title)
            } icon: {
                SettingsIcon(systemImage: systemImage, color: color, graphicIcon: graphicIcon)
            }
        }
    }
}

extension SettingsRow where Value == EmptyView {
    /// A row with nothing on its trailing side.
    init(title: String, systemImage: String, color: Color, graphicIcon: String? = nil) {
        self.init(title: title, systemImage: systemImage, color: color, graphicIcon: graphicIcon) {
            EmptyView()
        }
    }
}
