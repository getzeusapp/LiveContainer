//
//  LCAboutView.swift
//  LiveContainerSwiftUI
//
//  Settings > About zContainer: who made LiveContainer, which zContainer is
//  built on, where zContainer's source is, the notices the AGPL asks a
//  modified version to show, and the license texts that come with the app.
//

import SwiftUI

struct LCAboutView: View {
    var body: some View {
        Form {
            Section {
                LCAboutHeader()
            }
            .listRowBackground(Color.clear)

            Section {
                LCAboutLinkRow(title: "LiveContainer", detail: LCAboutLinks.display(LCAboutLinks.liveContainer),
                               url: LCAboutLinks.liveContainer)
                LCAboutLinkRow(title: "Duy Tran (khanhduytran0)", detail: "lc.about.creator".loc,
                               url: LCAboutLinks.khanhduytran0)
                LCAboutLinkRow(title: "Huge_Black", detail: "lc.about.swiftUI".loc, url: LCAboutLinks.hugeBlack)
                LCAboutLinkRow(title: "lc.about.contributors".loc, detail: nil,
                               url: LCAboutLinks.liveContainerContributors)
            } header: {
                Text("lc.about.basedOn".loc)
                .settingsSectionHeader()
            } footer: {
                Text("lc.about.modifiedNotice".loc)
            }

            Section {
                LCAboutLinkRow(title: "lc.about.sourceCode".loc, detail: LCAboutLinks.display(LCAboutLinks.source),
                               url: LCAboutLinks.source)
                NavigationLink {
                    LCLicenseView(license: .zContainer)
                } label: {
                    LCAboutRowLabel(title: LCLicense.zContainer.licenseName, detail: "lc.about.licenseDetail".loc)
                }
                NavigationLink {
                    LCLicensesView()
                } label: {
                    LCAboutRowLabel(title: "lc.about.licenses".loc, detail: "lc.about.licensesDetail".loc)
                }
            } header: {
                Text("lc.about.legal".loc)
                .settingsSectionHeader()
            } footer: {
                Text("lc.about.licenseNotice".loc)
            }

            Section {
                ForEach(LCAcknowledgement.all) { item in
                    LCAboutLinkRow(title: item.name, detail: item.detail, url: item.url)
                }
            } header: {
                Text("lc.about.acknowledgements".loc)
                .settingsSectionHeader()
            }
        }
        .navigationTitle("lc.about.title".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
