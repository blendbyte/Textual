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

/* Settings › History: the message archive (how long, its size, delete,
 import), what the chat shows after a restart, and text logs */

struct HistorySettings: View
{
	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel

	/* Days, as TPCMessageArchiveKeepPeriod; 0 is forever, -1 off */
	private static let keepPeriods = [14, 30, 90, 180, 365, 730, 0]

	private static let archiveOff = -1
	private static let archiveDefault = 365

	private static let savedLines = [1000, 5000, 10000, 15000, 25000, 50000]

	@State private var messageCount = 0
	@State private var fileSize = ""
	@State private var busy = false
	@State private var importStatus = ""

	/* Where the slider is: a position in keepPeriods */
	@State private var keepIndex = 4.0
	@State private var sliding = false

	private func keepIndex(of keepPeriod: Int) -> Double
	{
		Double(Self.keepPeriods.firstIndex(of: keepPeriod) ?? 4)
	}

	private func updateArchiveSize()
	{
		TDCSettingsBridge.messageArchiveSize { (count, size) in
			messageCount = count
			fileSize = size
		}
	}

	private func changeKeepPeriod(to keepPeriod: Int)
	{
		guard let window = model.window, busy == false, keepPeriod != TDCSettingsBridge.messageArchiveKeepPeriod else {
			return
		}

		busy = true

		TDCSettingsBridge.changeMessageArchiveKeepPeriod(keepPeriod, messageCount: messageCount, in: window) {
			busy = false

			store.objectWillChange.send()

			/* Back where it was when it wasn't changed */
			if (TDCSettingsBridge.messageArchiveKeepPeriod != Self.archiveOff) {
				keepIndex = self.keepIndex(of: TDCSettingsBridge.messageArchiveKeepPeriod)
			}

			updateArchiveSize()
		}
	}

	var body: some View
	{
		let keepPeriod = TDCSettingsBridge.messageArchiveKeepPeriod
		let archiveOn = (keepPeriod != Self.archiveOff)

		let shownPeriod = Self.keepPeriods[max(0, min((Self.keepPeriods.count - 1), Int(keepIndex)))]

		let logs = store.bool("LogTranscript")

		Form {
			Section {
				SettingsPageHeader(section: .history)
			}

			Section {
				SettingToggle(title: SettingsText("set-his-a"), help: SettingsText("set-his-ah"),
							  isOn: Binding(get: { archiveOn },
											set: { changeKeepPeriod(to: ($0 ? Self.archiveDefault : Self.archiveOff)) }))

				VStack(alignment: .leading, spacing: 6) {
					LabeledContent {
						Text(TDCSettingsBridge.title(forMessageArchiveKeepPeriod: shownPeriod))
							.foregroundStyle(archiveOn ? Color.accentColor : Color.secondary)
							.fontWeight(.semibold)
					} label: {
						SettingLabel(title: SettingsText("set-his-k"), help: SettingsText("set-his-kh"))
					}

					Slider(value: $keepIndex, in: 0...Double(Self.keepPeriods.count - 1), step: 1) {
						Text(SettingsText("set-his-k"))
					} onEditingChanged: { (editing) in
						sliding = editing

						if (editing == false) {
							changeKeepPeriod(to: Self.keepPeriods[Int(keepIndex)])
						}
					}
					.labelsHidden()
					.onChange(of: keepIndex) { _, _ in
						/* The keyboard moves it without editing */
						if (sliding == false) {
							changeKeepPeriod(to: Self.keepPeriods[Int(keepIndex)])
						}
					}

					HistoryKeepPeriodTicks(periods: Self.keepPeriods, selection: Int(keepIndex)) { (index) in
						keepIndex = Double(index)
					}
				}
				.disabled(archiveOn == false || busy)

				LabeledContent {
					Text(fileSize)
						.foregroundStyle(.secondary)
				} label: {
					SettingLabel(title: ((archiveOn == false && messageCount == 0) ? SettingsText("set-his-s0") :
										 ((messageCount == 1) ? SettingsText("set-his-s1") : SettingsText("set-his-sn", messageCount.formatted()))),
								 help: SettingsText("set-his-sh"))
				}

				LabeledContent {
					Button(SettingsText("set-his-d"), role: .destructive) {
						guard let window = model.window else {
							return
						}

						busy = true

						importStatus = ""

						TDCSettingsBridge.deleteMessageArchive(withMessageCount: messageCount, in: window) {
							busy = false

							updateArchiveSize()
						}
					}
					.disabled(busy || messageCount == 0)
				} label: {
					SettingLabel(title: SettingsText("set-his-dt"), help: SettingsText("set-his-dh"))
				}

				LabeledContent {
					HStack {
						if (importStatus.isEmpty == false) {
							Text(importStatus)
								.foregroundStyle(.secondary)
						}

						Button(SettingsText("set-his-i")) {
							guard let window = model.window else {
								return
							}

							busy = true

							TDCSettingsBridge.importTextLogs(in: window) { (status) in
								importStatus = status
							} completionHandler: { (status) in
								busy = false

								importStatus = status

								updateArchiveSize()
							}
						}
						.disabled(busy || archiveOn == false)
					}
				} label: {
					SettingLabel(title: SettingsText("set-his-it"), help: SettingsText("set-his-ih"))
				}
			}

			Section(SettingsText("set-his-h2")) {
				SettingToggle(title: SettingsText("set-his-r"), help: SettingsText("set-his-rh"),
							  isOn: store.bool("ReloadScrollbackOnLaunch"))

				SettingToggle(title: SettingsText("set-his-q"), help: SettingsText("set-his-qh"),
							  isOn: store.bool("ServerListRetainsQueriesBetweenRestarts"))

				SettingValuePicker(title: SettingsText("set-his-l"), help: SettingsText("set-his-lh"),
								   selection: store.integer("ScrollbackMaximumSavedLineCount"), values: Self.savedLines) { (value) in
					SettingsText("set-his-ln", value.formatted())
				}
			}

			Section(SettingsText("set-his-h3")) {
				SettingToggle(title: SettingsText("set-his-t"), help: SettingsText("set-his-th"),
							  isOn: Binding(get: { logs.wrappedValue }, set: { (isOn) in
					/* Text logs need a folder: ask for one first */
					if (isOn && TDCSettingsBridge.transcriptFolderURL == nil) {
						if let window = model.window {
							TDCSettingsBridge.chooseTranscriptFolder(in: window) { (chosen) in
								if (chosen) {
									logs.wrappedValue = true
								}
							}
						}

						return
					}

					logs.wrappedValue = isOn
				}))

				LabeledContent {
					Menu {
						Button(SettingsText("set-his-fc")) {
							if let window = model.window {
								TDCSettingsBridge.chooseTranscriptFolder(in: window) { _ in store.objectWillChange.send() }
							}
						}

						if let url = TDCSettingsBridge.transcriptFolderURL {
							Button(SettingsText("set-his-fs")) {
								NSWorkspace.shared.activateFileViewerSelecting([url])
							}
						}
					} label: {
						if let url = TDCSettingsBridge.transcriptFolderURL {
							Label(url.lastPathComponent, systemImage: "folder")
						} else {
							Text(SettingsText("set-his-fn"))
						}
					}
					.fixedSize()
				} label: {
					SettingLabel(title: SettingsText("set-his-f"))
				}
				.disabled(logs.wrappedValue == false)
			}
		}
		.onAppear {
			if (TDCSettingsBridge.messageArchiveKeepPeriod != Self.archiveOff) {
				keepIndex = keepIndex(of: TDCSettingsBridge.messageArchiveKeepPeriod)
			}

			updateArchiveSize()
		}
	}
}

/// The keep periods under the slider, each under its stop; a click goes there
struct HistoryKeepPeriodTicks: View
{
	let periods: [Int]
	let selection: Int
	let choose: (Int) -> Void

	/* Where the slider's first and last stops are from its ends */
	private let inset: CGFloat = 10

	private func shortTitle(_ period: Int) -> String
	{
		switch period {
			case 0: return SettingsText("set-his-t0")
			case 365: return SettingsText("set-his-ty1")
			case 730: return SettingsText("set-his-ty2")
			default: return SettingsText("set-his-td", period)
		}
	}

	var body: some View
	{
		GeometryReader { (geometry) in
			let step = ((geometry.size.width - (inset * 2)) / CGFloat(max(1, (periods.count - 1))))

			ForEach(Array(periods.enumerated()), id: \.offset) { (index, period) in
				Button {
					choose(index)
				} label: {
					Text(shortTitle(period))
						.font(.caption)
						.foregroundStyle((index == selection) ? Color.primary : Color.secondary)
						.fixedSize()
				}
				.buttonStyle(.plain)
				.position(x: (inset + (step * CGFloat(index))), y: 7)
			}
		}
		.frame(height: 14)
	}
}
