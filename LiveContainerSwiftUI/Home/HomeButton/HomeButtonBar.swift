//
//  HomeButtonBar.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Home button centered along the bottom of a screen opened over the Home
/// Screen, or along a side or the top of an iPad's screen, beside its Home
/// button as it's turned (`isVertical` for a side). It steps aside while the
/// keyboard is up, so it doesn't ride on top of the keyboard while something
/// is typed. On iPad only an on-screen keyboard counts: with a hardware
/// keyboard nothing covers the bottom, and the button stays. Along a side the
/// bar keeps its width meanwhile, so the screen beside it doesn't move.
struct HomeButtonBar: View {
    /// What pressing the button does.
    let action: () -> Void
    /// Whether the bar runs down a side of the screen rather than across it.
    var isVertical = false

    @State private var isKeyboardShowing = false

    var body: some View {
        ZStack {
            if !isKeyboardShowing {
                HomeButton(action: action)
                    .padding(isVertical ? .horizontal : .vertical, HomeDesign.homeButtonBarPadding)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: isVertical ? nil : .infinity, maxHeight: isVertical ? .infinity : nil)
        .frame(width: isVertical ? HomeDesign.homeButtonSize + HomeDesign.homeButtonBarPadding * 2 : nil)
        .animation(HomeDesign.modeChange, value: isKeyboardShowing)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification), perform: keyboardWillShow)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification), perform: keyboardWillHide)
        .onReceive(OnScreenKeyboard.changes, perform: keyboardChanged)
    }

    /// On iPhone, any keyboard showing hides the button.
    private func keyboardWillShow(_ notification: Notification) {
        guard SharedModel.isPhone else {
            return
        }
        isKeyboardShowing = true
    }

    private func keyboardWillHide(_ notification: Notification) {
        isKeyboardShowing = false
    }

    /// On iPad, only an on-screen keyboard hides the button, not the
    /// shortcuts bar a hardware keyboard brings.
    private func keyboardChanged(_ notification: Notification) {
        guard !SharedModel.isPhone else {
            return
        }
        isKeyboardShowing = OnScreenKeyboard.isUp(after: notification)
    }
}
