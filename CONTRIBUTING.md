# Contributing to Textual

Thanks for your interest in improving Textual. This document explains the terms under which contributions are accepted and the conventions the project follows.

> [!WARNING]
> `main` is a work in progress toward Textual 8 and is being substantially refactored. Large changes are likely to conflict with work in progress. Please open a [discussion](https://github.com/blendbyte/Textual/discussions) before starting on anything beyond a small fix.

## Contributor license grant

**By submitting a pull request or any other contribution to this repository, you agree to the following terms.**

1. **You keep your copyright.** You remain the copyright holder of your contribution.
2. **Your contribution is licensed under the project license.** You license your contribution to everyone under the BSD 3-Clause License found in [LICENSE](LICENSE).
3. **You grant Blendbyte GmbH an additional license.** You grant Blendbyte GmbH a perpetual, worldwide, non-exclusive, royalty-free, irrevocable license to use, reproduce, modify, prepare derivative works of, publicly display, distribute, and sublicense your contribution, and to license it under other terms, including in commercial releases of Textual.
4. **You have the right to contribute it.** The contribution is your original work, or you otherwise have the right to submit it under these terms. If you are contributing on behalf of an employer, you represent that you are authorized to grant these rights on its behalf.

Contributions that cannot be licensed under these terms, for example code copied from projects under incompatible licenses, cannot be accepted. If your contribution includes third-party code, say so in the pull request and include its license.

The pull request template contains a checkbox confirming that you agree to these terms. It must be ticked before a pull request can be merged.

## Branches

| Branch | Purpose |
|---|---|
| `main` | Textual 8 development. Unstable, may not build. |
| `v7` | Textual 7 maintenance. Bug and security fixes only. |

Open pull requests against `main` unless you are fixing a bug that only affects Textual 7, in which case target `v7`.

## How to contribute

1. **Discuss first.** For anything beyond a typo or an obvious bug fix, open a discussion or an issue so we can agree on the approach before you write code.
2. **Fork, branch, and open a pull request** against the appropriate branch.
3. **Keep pull requests focused.** One behavior change per pull request. Unrelated fixes, refactors, and formatting changes belong in separate pull requests.
4. **Fill out the pull request template**, including how you tested the change.

## Running a development build

Debug builds are **Textual Dev**: they have their own bundle identifier (`com.textualapp.app.dev`) and app group, so they never share settings, logs or scrollback with an installed copy of Textual. They show "Textual Dev" in the menu bar and a DEV ribbon on the Dock icon.

`Development/dev` builds and runs Textual Dev and provides servers to test against, all on 127.0.0.1:

```sh
Development/dev run                  # build and start Textual Dev
Development/dev server start         # local Ergo server (6667, TLS 6697; NickServ, SASL)
Development/dev connect              # connect Textual Dev to it
Development/dev scripted --list      # scripted servers for edge cases (floods, spoofed NickServ, …)
Development/dev input /brag          # run a command as if typed in the newest server
Development/dev config nickServHost=services.textual.test   # change the newest server's settings
Development/dev reset                # delete Textual Dev's data
```

In Textual Dev, `irc://` links to 127.0.0.1, localhost or ::1 connect right away and accept the test servers' self-signed certificates; other links only add the server, as in release builds. `input`, `config` and `reset` use `textual://dev-…` links that only Debug builds understand. Use a test nickname rather than your own on public networks, and don't import the settings of your installed Textual: both copies would then use the same Keychain items.

## Conventions

- **Match the surrounding code.** Follow the existing naming, formatting, and comment style of the file you are editing. Most of the app is Objective-C and uses tabs for indentation.
- **Build the whole workspace.** Before submitting, build all targets, including plugins and services, not just the main app. Code that looks unused may still be called from another target.
- **User-visible strings go in `.strings` files**, never inline in code.
- **Style templates and the JavaScript API are a public contract.** Third-party styles ship their own templates and call into `Textual.*`. Anything removed there must keep working, for example as a no-op shim.
- **Preference changes must state their migration behavior.** If a pull request adds or changes a preference, say explicitly whether existing users are migrated or left alone.
- **No new dependencies without discussion.**

## Reporting bugs and requesting features

- **Bugs:** use the [bug report form](https://github.com/blendbyte/Textual/issues/new/choose). Include your Textual version, macOS version, and steps to reproduce.
- **Feature requests:** use the feature request form for concrete proposals, or [Discussions](https://github.com/blendbyte/Textual/discussions/categories/ideas) for open-ended ideas.
- **Security vulnerabilities:** do not open a public issue. Follow the [security policy](SECURITY.md).

## Questions

Ask in [GitHub Discussions](https://github.com/blendbyte/Textual/discussions), join `#textual` on `irc.libera.chat`, or email hello@blendbyte.com.
