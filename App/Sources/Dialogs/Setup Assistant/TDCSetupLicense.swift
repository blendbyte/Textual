/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2026 Blendbyte GmbH & respective contributors.
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

import SwiftUI

/* The trial, a key, or the upgrade a Textual 7 license earns, inside the setup
 window instead of a window popping up after it. All of it is the license
 window's own model and actions: only where it shows differs. */

struct SetupLicenseStep: View
{
	@ObservedObject var license: LicenseWindowModel

	let importModel: ImportModel?

	var body: some View
	{
		if (license.registered) {
			SetupHeader(title: SetupText("sa-li-ok-t"), lead: SetupText("sa-li-ok-d")) {
				SetupSymbol(symbol: "checkmark.seal.fill", color: .green)
			}
		} else if (license.busy != .none) {
			VStack(spacing: 12) {
				SetupHeader(title: SetupText("sa-li-busy-t"), lead: SetupText("sa-li-busy-d")) {
					SetupSymbol(symbol: "key.fill", color: .yellow)
				}

				ProgressView()
					.controlSize(.small)
			}
		} else if let title = license.offerTitle {
			offer(title)
		} else {
			trial
		}
	}

	private func offer(_ title: String) -> some View
	{
		VStack(spacing: 12) {
			SetupHeader(title: title, lead: (license.offerMessage ?? "")) {
				SetupSymbol(symbol: "key.fill", color: .yellow)
			}

			if let key = license.offerLicenseKey {
				SetupGroup {
					Text(verbatim: key)
						.font(.system(.body, design: .monospaced))
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(10)
				}
				.frame(maxWidth: 460)
			}

			problem(license.upgradeError)
		}
	}

	private var trial: some View
	{
		VStack(spacing: 12) {
			SetupHeader(title: SetupText("sa-li-title"), lead: SetupText("sa-li-lead")) {
				SetupSymbol(symbol: "key.fill", color: .yellow)
			}

			SetupGroup {
				if let importModel = importModel, importModel.offersLicenseFile {
					SetupControlRow(divider: false, title: SetupText("sa-li-file-t"), text: SetupText("sa-li-file-d")) {
						Button(SetupText("sa-li-file-b")) {
							importModel.requestLicenseAccess()
						}
					}
				}

				keyRow
			}
			.frame(maxWidth: 520)

			problem(license.keyError)

			problem(license.upgradeError)

			if (importModel?.licenseImportFailed == true) {
				problem(ImportText("3jr-s5"))
			}

			if (license.seats.isEmpty == false) {
				VStack(alignment: .leading, spacing: 10) {
					LicenseSeatsSection(model: license)
				}
				.frame(maxWidth: 520)
			}
		}
	}

	private var keyRow: some View
	{
		VStack(alignment: .leading, spacing: 8) {
			VStack(alignment: .leading, spacing: 2) {
				Text(SetupText("sa-li-key-t"))

				Text(SetupText("sa-li-key-d"))
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}

			HStack(spacing: 8) {
				TextField(SetupText("sa-li-key-p"), text: $license.keyText)
					.textFieldStyle(.roundedBorder)

				Button(SetupText("sa-li-key-b")) {
					license.activate?(license.keyText)
				}
				.disabled(keyIsValid == false)
			}
		}
		.padding(10)
	}

	private var keyIsValid: Bool
	{
		(license.isValidKey?(license.keyText) ?? false)
	}

	@ViewBuilder
	private func problem(_ text: String?) -> some View
	{
		if let text = text {
			Text(verbatim: text)
				.font(.callout)
				.foregroundStyle(.red)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
	}
}

/// Going on without a license, or what an offer asks for
struct SetupLicenseButtons: View
{
	let setup: SetupModel

	@ObservedObject var license: LicenseWindowModel

	var body: some View
	{
		if (license.registered == false && license.offerTitle != nil) {
			if let secondary = license.offerSecondaryTitle {
				Button(secondary) {
					license.offerSecondary?()

					/* Support opens elsewhere; anything else means carrying on */
					if (secondary != LocalizedKey("TLOLicenseManager[vgp-j6]")) {
						setup.goForward()
					}
				}
				.disabled(license.busy != .none)
			}

			if let primary = license.offerPrimaryTitle {
				Button(primary) {
					license.offerPrimary?()
				}
				.keyboardShortcut(.defaultAction)
				.disabled(license.busy != .none)
			}
		} else {
			Button(license.registered ? SetupText("sa-b-continue") : SetupText("sa-li-start")) {
				setup.goForward()
			}
			.keyboardShortcut((license.seats.isEmpty) ? .defaultAction : nil)
			.disabled(license.busy != .none || license.seats.isEmpty == false)
		}
	}
}
