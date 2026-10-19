/* *********************************************************************
*                  _____         _               _
*                 |_   _|____  _| |_ _   _  __ _| |
*                   | |/ _ \ \/ / __| | | |/ _` | |
*                   | |  __/>  <| |_| |_| | (_| | |
*                   |_|\___/_/\_\\__|\__,_|\__,_|_|
*
* Copyright (c) 2018 - 2020 Codeux Software, LLC & respective contributors.
*       Please see Acknowledgements.pdf for additional information.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions
* are met:
*
*  * Redistributions of source code must retain the above copyright
*    notice, this list of conditions and the following disclaimer.
*  * Redistributions in binary form must reproduce the above copyright
*    notice, this list of conditions and the following disclaimer in the
*    documentation and/or other materials provided with the distribution.
*  * Neither the name of Textual, "Codeux Software, LLC", nor the
*    names of its contributors may be used to endorse or promote products
*    derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
* ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
* OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
* HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
* LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
* OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
* SUCH DAMAGE.
*
*********************************************************************** */

import AppKit
import SwiftUI

/* Settings › Previews: pictures, videos and cards for links people post,
 which sites' links are previewed, and the services with a look of their own */

struct PreviewsSettings: View
{
	@ObservedObject private var store = SettingsStore.shared

	/* "InlineMediaMaximumFilesize" stores the position in this list, from 1 */
	private static let fileSizes = [1, 2, 3, 4, 5, 10, 15, 20, 50, 100]

	private static let widths = [200, 300, 400, 500, 600, 800, 1000]

	/* 0 is any height */
	private static let heights = [0, 300, 400, 600, 800, 1000, 1500]

	private static let onlyListedSites = 1

	@State private var newSite = ""
	@State private var newSiteInvalid = false

	private func addSite()
	{
		guard newSite.isEmpty == false else {
			return
		}

		store.objectWillChange.send()

		if (TDCSettingsBridge.addPreviewSite(newSite)) {
			newSite = ""

			newSiteInvalid = false
		} else {
			newSiteInvalid = true
		}
	}

	var body: some View
	{
		let show = store.bool("DisplayEventInLogView -> Inline Media")
		let cards = store.bool("InlineMediaWebPageCards")
		let width = store.integer("InlineMediaScalingWidth")

		let fileSizeIndex = store.integer("InlineMediaMaximumFilesize")

		let fileSize = Binding<Int>(get: {
			Self.fileSizes[max(0, min((Self.fileSizes.count - 1), (fileSizeIndex.wrappedValue - 1)))]
		}, set: { (value) in
			fileSizeIndex.wrappedValue = ((Self.fileSizes.firstIndex(of: value) ?? 1) + 1)
		})

		let services = TDCSettingsBridge.previewServiceNames
		let servicesOff = services.filter { TDCSettingsBridge.previewServiceIsEnabled($0) == false }

		let siteMode = store.integer("InlineMediaDomainRuleMode")
		let sites = TDCSettingsBridge.previewSites

		Form {
			Section {
				SettingsPageHeader(section: .previews)
			}

			Section {
				PreviewsSample(previews: show.wrappedValue, cards: cards.wrappedValue, imageWidth: width.wrappedValue)
			}

			Section {
				SettingToggle(title: SettingsText("set-pre-s"), help: SettingsText("set-pre-sh"), isOn: show)
			}

			Section {
				SettingValuePicker(title: SettingsText("set-pre-w"), help: SettingsText("set-pre-wh"),
								   selection: width, values: Self.widths) { (value) in
					SettingsText("set-pre-px", value)
				}

				SettingValuePicker(title: SettingsText("set-pre-t"), help: SettingsText("set-pre-th"),
								   selection: store.integer("InlineMediaMaximumHeight"), values: Self.heights) { (value) in
					((value == 0) ? SettingsText("set-pre-t0") : SettingsText("set-pre-px", value))
				}

				SettingValuePicker(title: SettingsText("set-pre-f"), help: SettingsText("set-pre-fh"),
								   selection: fileSize, values: Self.fileSizes) { (value) in
					SettingsText("set-pre-mb", value)
				}
			}
			.disabled(show.wrappedValue == false)

			Section {
				SettingToggle(title: SettingsText("set-pre-c"), help: SettingsText("set-pre-ch"), isOn: cards)

				SettingToggle(title: SettingsText("set-pre-a"), isOn: store.bool("InlineMediaAudio"))

				NavigationLink(value: SettingsSubpage.previewServices) {
					SettingLabel(title: SettingsText("set-pre-v"),
								 help: (servicesOff.isEmpty ? SettingsText("set-pre-va") :
										SettingsText("set-pre-vo", ListFormatter.localizedString(byJoining: servicesOff))))
				}
			}
			.disabled(show.wrappedValue == false)

			Section(SettingsText("set-pre-h2")) {
				Picker(selection: siteMode) {
					Text(SettingsText("set-pre-r0")).tag(0)
					Text(SettingsText("set-pre-r1")).tag(1)
				} label: {
					SettingLabel(title: SettingsText("set-pre-r"),
								 help: ((siteMode.wrappedValue == Self.onlyListedSites && sites.isEmpty) ? SettingsText("set-pre-rn") : SettingsText("set-pre-rh")))
				}

				ForEach(sites, id: \.self) { (site) in
					HStack {
						SettingLabel(title: site)

						Spacer()

						Button {
							store.objectWillChange.send()

							TDCSettingsBridge.removePreviewSite(site)
						} label: {
							Image(systemName: "minus.circle.fill")
								.foregroundStyle(.secondary)
						}
						.buttonStyle(.borderless)
						.help(SettingsText("set-pre-rr"))
						.accessibilityLabel(SettingsText("set-pre-rr"))
					}
				}

				VStack(alignment: .leading, spacing: 4) {
					HStack {
						TextField(SettingsText("set-pre-ra"), text: $newSite, prompt: Text(verbatim: "example.com"))
							.labelsHidden()
							.onSubmit(addSite)
							.onChange(of: newSite) { _, _ in
								newSiteInvalid = false
							}

						Button(SettingsText("set-pre-rb"), action: addSite)
							.disabled(newSite.isEmpty)
					}

					if (newSiteInvalid) {
						Text(SettingsText("set-pre-ri"))
							.font(.callout)
							.foregroundStyle(.orange)
					}
				}
			}
			.disabled(show.wrappedValue == false)

			Section {
				Text(SettingsText("set-pre-n"))
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}
}

// MARK: - Services

/// Sites whose links have a preview of their own: a player, a post, a picture
struct PreviewServicesPage: View
{
	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel

	var body: some View
	{
		Form {
			Section {
				ForEach(TDCSettingsBridge.previewServiceNames, id: \.self) { (name) in
					Toggle(name, isOn: store.value(get: { TDCSettingsBridge.previewServiceIsEnabled(name) },
												   set: { TDCSettingsBridge.setPreviewService(name, enabled: $0) }))
				}
			} header: {
				VStack(alignment: .leading, spacing: 3) {
					Text(SettingsText("set-pre-v"))
						.font(.title2.weight(.semibold))
						.foregroundStyle(.primary)
						.settingsPageTitle(model: model)

					Text(SettingsText("set-pre-vl"))
						.foregroundStyle(.secondary)
				}
				.padding(.bottom, 6)
			}
		}
		.formStyle(.grouped)
		.navigationTitle(SettingsText("set-pre-v"))
	}
}

// MARK: - Sample

/// Two lines of a channel with what their links turn into
struct PreviewsSample: View
{
	let previews: Bool
	let cards: Bool
	let imageWidth: Int

	@Environment(\.colorScheme) private var colorScheme

	private func line(_ time: String, _ nickname: String, _ color: NSColor, _ text: String, _ link: String) -> some View
	{
		(Text(time + " ").foregroundStyle(.secondary) +
		 Text("<\(nickname)> ").foregroundStyle(Color(nsColor: color)) +
		 Text(text + " ") +
		 Text(link).foregroundStyle(Color(nsColor: .linkColor)).underline())
			.lineLimit(1)
	}

	var body: some View
	{
		VStack(alignment: .leading, spacing: 6) {
			line("14:03", "alice", .systemPurple, SettingsText("set-pre-x1"), "https://textualapp.com")

			if (previews && cards) {
				HStack(spacing: 10) {
					Image(nsImage: NSApp.applicationIconImage)
						.resizable()
						.frame(width: 40, height: 40)

					VStack(alignment: .leading, spacing: 2) {
						Text(SettingsText("set-pre-x2"))
							.bold()

						Text(verbatim: "textualapp.com · " + SettingsText("set-pre-x3"))
							.foregroundStyle(.secondary)
					}
					.lineLimit(1)
				}
				.padding(8)
				.frame(maxWidth: 360, alignment: .leading)
				.background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
				.padding(.leading, 40)
			}

			line("14:04", "bob", .systemGreen, SettingsText("set-pre-x4"), "https://example.com/sunset.jpg")
				.padding(.top, 2)

			if (previews) {
				/* As wide as chosen, at a third of the size */
				RoundedRectangle(cornerRadius: 4, style: .continuous)
					.fill(LinearGradient(colors: [Color(nsColor: .systemOrange), Color(nsColor: .systemPink), Color(nsColor: .systemPurple)],
										 startPoint: .top, endPoint: .bottom))
					.overlay(alignment: .bottom) {
						Circle()
							.fill(Color.yellow.opacity(0.9))
							.frame(width: 18, height: 18)
							.offset(y: -10)
					}
					.frame(width: (CGFloat(imageWidth) / 3), height: (CGFloat(imageWidth) / 3 * 0.6))
					.padding(.leading, 40)
			}
		}
		.font(.system(size: 12))
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background((colorScheme == .dark) ? Color(white: 0.11) : Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
		}
		.animation(.default, value: imageWidth)
		.accessibilityElement(children: .combine)
	}
}
