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

/* Settings › Highlights: words that get your attention, as tags; a tag opens
 the sheet with where it counts, from whom and its sound */

struct HighlightsSettings: View
{
	@ObservedObject private var store = SettingsStore.shared
	@EnvironmentObject private var model: SettingsModel

	/* "5 or more names"; 0 is off */
	private static let massLimits = [0, 3, 4, 5, 6, 8, 10, 15, 20]

	private static let regularExpression = 2

	var body: some View
	{
		let matchType = store.integer("NicknameHighlightMatchingType")
		let isRegularExpression = (matchType.wrappedValue == Self.regularExpression)

		let keywords = TDCSettingsBridge.highlightKeywordEntriesExcluded(false)
		let excluded = TDCSettingsBridge.highlightKeywordEntriesExcluded(true)

		let nickname = store.bool("TrackNicknameHighlightsOfLocalUser")

		let spam = store.bool("AutomaticallyDetectHighlightSpam")
		let threshold = store.integer("Highlights -> Mass Highlight Threshold")

		let massLimit = Binding<Int>(get: {
			(spam.wrappedValue ? max(2, threshold.wrappedValue) : 0)
		}, set: { (value) in
			if (value > 0) {
				threshold.wrappedValue = value
			}

			spam.wrappedValue = (value > 0)
		})

		let invalid = TDCSettingsBridge.invalidRegularExpressionKeywords

		Form {
			Section {
				SettingsPageHeader(section: .highlights)
			}

			Section {
				HighlightsSample(nickname: ((nickname.wrappedValue && isRegularExpression == false) ? TDCSettingsBridge.highlightSampleNickname : nil),
								 keyword: (keywords.first?["string"] as? String))
			}

			Section {
				VStack(alignment: .leading, spacing: 8) {
					SettingLabel(title: SettingsText("set-hil-w"), help: SettingsText("set-hil-wh"))

					HighlightKeywordTags(entries: keywords, excluded: false)
				}
				.padding(.vertical, 4)

				VStack(alignment: .leading, spacing: 8) {
					SettingLabel(title: SettingsText("set-hil-x"), help: SettingsText("set-hil-xh"))

					HighlightKeywordTags(entries: excluded, excluded: true)
				}
				.padding(.vertical, 4)
			}

			Section {
				Picker(selection: matchType) {
					Text(SettingsText("set-hil-m1")).tag(1)
					Text(SettingsText("set-hil-m0")).tag(0)
					Text(SettingsText("set-hil-m2")).tag(2)
				} label: {
					SettingLabel(title: SettingsText("set-hil-m"), help: SettingsText("set-hil-mh\(matchType.wrappedValue)"))
				}

				if (invalid.isEmpty == false) {
					Label(SettingsText("set-hil-mi", invalid.joined(separator: ", ")), systemImage: "exclamationmark.triangle")
						.foregroundStyle(.orange)
				}

				SettingToggle(title: SettingsText("set-hil-n"),
							  help: SettingsText(isRegularExpression ? "set-hil-nhr" : "set-hil-nh"),
							  isOn: Binding(get: { nickname.wrappedValue && isRegularExpression == false },
											set: { nickname.wrappedValue = $0 }))
					.disabled(isRegularExpression)

				SettingValuePicker(title: SettingsText("set-hil-s"), help: SettingsText("set-hil-sh"),
								   selection: massLimit, values: Self.massLimits) { (value) in
					((value == 0) ? SettingsText("set-hil-s0") : SettingsText("set-hil-sn", value))
				}
			}
		}
	}
}

/// A list of words as tags, with an Add tag at the end
struct HighlightKeywordTags: View
{
	let entries: [[String: Any]]
	let excluded: Bool

	@EnvironmentObject private var model: SettingsModel

	private func edit(_ index: Int)
	{
		if let window = model.window {
			TDCSettingsBridge.editHighlightKeyword(at: index, excluded: excluded, in: window)
		}
	}

	var body: some View
	{
		SettingsFlowLayout(spacing: 6) {
			ForEach(Array(entries.enumerated()), id: \.offset) { (index, entry) in
				HStack(spacing: 4) {
					Button {
						edit(index)
					} label: {
						HStack(spacing: 4) {
							Text((entry["string"] as? String) ?? "")

							if let summary = TDCSettingsBridge.summary(ofHighlightKeywordEntry: entry) {
								Text(summary)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
						}
					}
					.buttonStyle(.plain)
					.help(SettingsText("set-hil-e"))

					Button {
						TDCSettingsBridge.removeHighlightKeyword(at: index, excluded: excluded)
					} label: {
						Image(systemName: "xmark.circle.fill")
							.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
					.help(SettingsText("set-hil-r"))
				}
				.padding(.leading, 9)
				.padding(.trailing, 5)
				.padding(.vertical, 4)
				.background(Color.primary.opacity(0.08), in: Capsule())
				.contextMenu {
					Button(SettingsText("set-hil-e")) {
						edit(index)
					}

					Button(SettingsText("set-hil-r")) {
						TDCSettingsBridge.removeHighlightKeyword(at: index, excluded: excluded)
					}
				}
			}

			Button {
				edit(-1)
			} label: {
				Label(SettingsText("set-hil-a"), systemImage: "plus")
					.padding(.horizontal, 9)
					.padding(.vertical, 4)
					.overlay {
						Capsule().strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
					}
			}
			.buttonStyle(.plain)
		}
	}
}

/// Lines with your nickname and your first word highlighted
struct HighlightsSample: View
{
	let nickname: String?
	let keyword: String?

	@Environment(\.colorScheme) private var colorScheme

	private func highlighted(_ text: String, _ isHighlighted: Bool) -> Text
	{
		if (isHighlighted) {
			return Text(text).bold().foregroundStyle(Color(nsColor: .systemOrange))
		}

		return Text(text)
	}

	var body: some View
	{
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 0) {
				Rectangle().fill((nickname != nil) ? Color(nsColor: .systemOrange) : Color.clear).frame(width: 3)

				(Text("14:03 ").foregroundStyle(.secondary) +
				 Text("<alice> ").foregroundStyle(Color(nsColor: .systemPurple)) +
				 Text(SettingsText("set-hil-x1")) +
				 highlighted((nickname ?? SettingsText("set-hil-x0")), (nickname != nil)) +
				 Text(SettingsText("set-hil-x2")))
					.padding(.leading, 6)
			}

			HStack(spacing: 0) {
				Rectangle().fill((keyword != nil) ? Color(nsColor: .systemOrange) : Color.clear).frame(width: 3)

				(Text("14:04 ").foregroundStyle(.secondary) +
				 Text("<bob> ").foregroundStyle(Color(nsColor: .systemGreen)) +
				 Text(SettingsText("set-hil-x3")) +
				 highlighted((keyword ?? SettingsText("set-hil-x5")), (keyword != nil)) +
				 Text(SettingsText("set-hil-x4")))
					.padding(.leading, 6)
			}
		}
		.font(.system(size: 12))
		.lineLimit(1)
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background((colorScheme == .dark) ? Color(white: 0.11) : Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
		.overlay {
			RoundedRectangle(cornerRadius: 8, style: .continuous)
				.strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
		}
		.accessibilityElement(children: .combine)
	}
}

/// Views side by side, wrapping onto the next line when there's no room
struct SettingsFlowLayout: Layout
{
	var spacing: CGFloat = 6

	private func rows(_ proposal: ProposedViewSize, _ subviews: Subviews) -> [[(Int, CGSize)]]
	{
		let width = (proposal.width ?? .infinity)

		var rows: [[(Int, CGSize)]] = [[]]
		var rowWidth: CGFloat = 0

		for (index, subview) in subviews.enumerated() {
			let size = subview.sizeThatFits(.unspecified)

			if (rows[rows.count - 1].isEmpty == false && (rowWidth + spacing + size.width) > width) {
				rows.append([])
				rowWidth = 0
			}

			rowWidth += ((rows[rows.count - 1].isEmpty ? 0 : spacing) + size.width)

			rows[rows.count - 1].append((index, size))
		}

		return rows
	}

	func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize
	{
		let rows = rows(proposal, subviews)

		let height = rows.reduce(0) { $0 + ($1.map { $0.1.height }.max() ?? 0) } + (spacing * CGFloat(max(0, rows.count - 1)))
		let width = rows.map { row in row.reduce(0) { $0 + $1.1.width } + (spacing * CGFloat(max(0, row.count - 1))) }.max() ?? 0

		return CGSize(width: (proposal.width ?? width), height: height)
	}

	func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ())
	{
		var y = bounds.minY

		for row in rows(proposal, subviews) {
			var x = bounds.minX

			let height = (row.map { $0.1.height }.max() ?? 0)

			for (index, size) in row {
				subviews[index].place(at: CGPoint(x: x, y: (y + ((height - size.height) / 2))), proposal: ProposedViewSize(size))

				x += (size.width + spacing)
			}

			y += (height + spacing)
		}
	}
}
