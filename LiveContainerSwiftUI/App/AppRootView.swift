//
//  AppRootView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The main window's root: the Home Screen, with onboarding over it while it
/// shows. Onboarding sits in the same view tree rather than being presented,
/// so the questions and errors installs raise from the Home Screen still show
/// over it. When onboarding finishes it fades away while the Home Screen
/// fades in and its icons settle from a little closer, as after unlocking.
struct AppRootView: View {
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(HomeScreenModel.self) private var home
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var sceneDelegate: SceneDelegate

    var body: some View {
        ZStack {
            HomeScreenView()
                .scaleEffect(onboarding.isPresented && !reduceMotion ? OnboardingDesign.homeArrivalScale : 1)
                .opacity(onboarding.isPresented ? 0 : 1)
                // Hidden under onboarding for touches and VoiceOver alike.
                .allowsHitTesting(!onboarding.isPresented)
                .accessibilityHidden(onboarding.isPresented)

            if onboarding.isPresented {
                OnboardingView(startsAtConnect: onboarding.startsAtConnect)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onChange(of: onboarding.isPresented, onboardingChanged)
        // Where the Home button goes, on the Home Screen and every screen
        // over it: beside an iPad's Home button, as the iPad is turned.
        .environment(\.homeButtonEdge, HomeButtonEdge(sceneDelegate.interfaceOrientation))
        .appIconAppearance()
        // Zeus's pink, for switches too, as Zeus tints its own, in place of
        // iOS's green.
        .tint(AppAccent.color)
    }

    /// Closes what's open over the Home Screen, like Settings, when
    /// onboarding opens from it, since onboarding shows under presented
    /// screens.
    private func onboardingChanged() {
        if onboarding.isPresented {
            home.showHomeScreen()
        }
    }
}
