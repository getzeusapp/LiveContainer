//
//  HomeAddAppSheet.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The apps the multitask dock's plus offers, in a sheet over everything:
/// those that can run with multitasking and aren't running yet, in the Home
/// Screen's order. Picking one opens it with multitasking, and it joins the
/// dock. Dark, as the Home Screen and the dock are, which its white icon
/// names are drawn for.
struct HomeAddAppSheet: View {
    @Environment(HomeScreenModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let apps = model.multitaskAddCandidates

        NavigationStack {
            Group {
                if apps.isEmpty {
                    ContentUnavailableView {
                        Label("zc.multitask.addApp".loc, systemImage: "square.stack")
                    } description: {
                        Text("zc.multitask.addApp.noApps".loc)
                    }
                } else {
                    ScrollView {
                        HomeAppPickerGrid(apps: apps, metrics: model.padMetrics ?? model.metrics ?? .reference, onPick: model.addToMultitasking)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 16)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("zc.multitask.addApp".loc)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button(role: .close) {
                            dismiss()
                        }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("lc.common.cancel".loc)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}
