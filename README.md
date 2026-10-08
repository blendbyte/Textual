> [!WARNING]
> **This branch is a work in progress toward Textual 8.**
>
> `main` is under heavy development and is being substantially refactored. Until Textual 8 is released, it may contain serious bugs, incomplete features, and breaking changes, and it may not build at all. Do not use builds from this branch with settings or logs you care about.
>
> Looking for the current release? Get it from [www.textualapp.com](https://www.textualapp.com). The Textual 7 source lives on the [`v7`](https://github.com/blendbyte/Textual/tree/v7) branch.

> [!IMPORTANT]
> **Textual is under new maintainership.** For most of its life, Textual had a single full-time maintainer, who has since moved on to other ventures. We've now taken over maintainership, and active development continues here.
>
> Development picks up from [Textwerk](https://github.com/bashgeek/Textwerk), a community fork of Textual that has now been retired. Many of the features and fixes made in Textwerk will carry over to Textual 8.
>
> To everyone who has contributed to Textual in any form, whether a suggestion, bug report, pull request, financial support, or something else: thank you. Textual exists because of you, and we're glad to keep it going.

<img src="App/Resources/Assets.xcassets/Application/applicationIcon.appiconset/icon_128x128@2x.png" alt="Textual icon" width="128" height="128">

# Textual

Textual is a highly customizable app for Internet Relay Chat (IRC) on macOS. It can be customized with styles written in CSS, HTML, and JavaScript, plugins written in Objective-C and Swift, and scripts written in AppleScript and many other languages.

Get Textual at [www.textualapp.com](https://www.textualapp.com).

## Resources

- Website: [www.textualapp.com](https://www.textualapp.com)
- Documentation: [www.textualapp.com/docs](https://www.textualapp.com/docs)
- Questions and ideas: [GitHub Discussions](https://github.com/blendbyte/Textual/discussions)
- Bug reports: [GitHub Issues](https://github.com/blendbyte/Textual/issues)
- Security issues: see [SECURITY.md](SECURITY.md)
- Chat: `#textual` on `irc.libera.chat`

## Contributing

Pull requests are welcome. Because `main` is being refactored heavily ahead of Textual 8, large changes are likely to conflict with work in progress, so please open a discussion first for anything beyond a small fix. Fixes for Textual 7 should target the `v7` branch.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. It explains how to build and test Textual, the contributor license grant and the project conventions.

## License

Textual is distributed under the BSD 3-Clause License. See [LICENSE](LICENSE) for the full text.

Textual began as a fork of [LimeChat](https://github.com/psychs/limechat) in 2010.

**LimeChat** (BSD 2-Clause)
Copyright (c) 2008-2010 Satoshi Nakagawa

**Textual** (BSD 3-Clause)
Copyright (c) 2010-2020 Codeux Software, LLC & respective contributors
Copyright (c) 2026 Blendbyte GmbH & respective contributors

Both licenses require preserving copyright notices in source and binary distributions. The names of the copyright holders may not be used to promote products derived from this software without prior written permission. Additional attributions are listed in [Acknowledgements.pdf](Acknowledgements.pdf).

### Third-party software

Textual bundles or links against the following third-party components:

| Component | License | Copyright |
|---|---|---|
| [GRMustache](https://github.com/groue/GRMustache) | MIT | (c) 2014 Gwendal Roué |
| [Google Toolbox for Mac](https://github.com/google/google-toolbox-for-mac) (`GTMNSString+HTML`) | Apache 2.0 | (c) 2006-2008 Google Inc. |
| [Reachability](https://github.com/tonymillion/Reachability) | BSD | (c) 2011 Tony Million |
| [AutoHyperlinks Framework](https://github.com/Codeux-Software/AutoHyperlinks) | BSD 3-Clause | (c) 2005-2011 The Adium Team, (c) 2011 Codeux Software, LLC |
| [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) (`GCDAsyncSocket`) | Public Domain | Originally by Robbie Hanson; maintained by Deusty LLC |
| [Colloquy](https://github.com/Colloquy/colloquy) (Chat Core) | BSD-style | (c) 2000-2012 the Colloquy IRC Client |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | MIT | (c) 2006-2017 Andy Matuschak and contributors |

The "Cocoa Extensions" internal framework also carries a small number of third-party snippets from Apple, Dave Dribin, Satoshi Nakagawa, and the Chromium developers; see the framework's `ACKNOWLEDGEMENT.txt`. Bundled styles include their own copyright and license files. The application icon was created by Brandon Rodriguez, and parts of the image assets are (c) 2015 Reda Lemeden.

---

## Maintained by Blendbyte

<br>

<p align="center">
  <a href="https://www.blendbyte.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://www.blendbyte.com/logo_horizontal_light.png">
      <img src="https://www.blendbyte.com/logo_horizontal.png" alt="Blendbyte" width="360">
    </picture>
  </a>
</p>

<p align="center">
  <strong><a href="https://www.blendbyte.com">Blendbyte</a></strong> builds cloud infrastructure, web apps, and developer tools.<br>
  We've been shipping software to production for 20+ years.
</p>

<p align="center">
  We took over Textual to keep a great IRC client alive on the Mac.<br>
  Issues and PRs get read. Good ones get merged.
</p>

<br>

<p align="center">
  <a href="https://www.blendbyte.com">blendbyte.com</a> · <a href="mailto:hello@blendbyte.com">hello@blendbyte.com</a>
</p>
