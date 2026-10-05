> [!IMPORTANT]
> **Textual is under new maintainership.** For most of its life, Textual had a single full-time maintainer, who has since moved on to other ventures. We've now taken over maintainership, and active development continues here.
>
> Development picks up from [Textwerk](https://github.com/bashgeek/Textwerk), a community fork of Textual that has now been retired. Some of the features and fixes made in Textwerk will carry over to a new Textual release.
>
> To everyone who has contributed to Textual in any form, whether a suggestion, bug report, pull request, financial support, or something else: thank you. Textual exists because of you, and we're glad to keep it going.

# Textual [![GitHub release](https://img.shields.io/github/tag/Codeux-Software/Textual.svg)](https://github.com/Codeux-Software/Textual/blob/master) [![Platform](https://img.shields.io/badge/platform-OS%20X-lightgrey.svg)](http://www.textualapp.com/mac-app-store)

Textual is a highly customizable app for interacting with Internet Relay Chat (IRC) chatrooms on macOS.

Textual can be customized with styles written in CSS, HTML, and JavaScript; [plugins](https://help.codeux.com/textual/Writing-Plugins.kb) written in Objective-C & Swift, and [scripts](https://help.codeux.com/textual/Writing-Scripts.kb) written in AppleScript (plus many other languages)

Precompiled versions of Textual can be purchased in the [directly from codeux.com](https://www.textualapp.com/).

## Screenshots

[![Light Screenshot](https://www.codeux.com/textual/private/images/v600media/YosemiteLightThumbnail.png)](https://www.codeux.com/textual/private/images/v600media/YosemiteLightFullscreen.png) 
[![Dark Screenshot](https://www.codeux.com/textual/private/images/v600media/YosemiteDarkThumbnail.png)](https://www.codeux.com/textual/private/images/v600media/YosemiteDarkFullscreen.png)

## Resources

- [Homepage](https://codeux.com/textual)
- [Frequently Asked Questions](https://help.codeux.com/textual/Frequently-Asked-Questions.kb)
- [Support](https://help.codeux.com/textual/Support.kb)
- \#textual on irc.libera.chat
- Guides: [Writing Plugins](https://help.codeux.com/textual/Writing-Plugins.kb), [Writing Scripts](https://help.codeux.com/textual/Writing-Scripts.kb)

## Note Regarding Downloading Source Code

Textual is dependent on several other projects to build. This repository is automatically linked against these other projects using what are known as "submodules" — Clicking the "Download ZIP" button to build a copy of Textual will not download a copy of these projects. The source code must be cloned using [Github for Mac](https://mac.github.com/) or by using the following commands in Terminal:

```
git clone https://github.com/Codeux-Software/Textual.git Textual
cd Textual
git submodule update --init --recursive
```

## Note Regarding Code Signing

**DO NOT change the Code Signing Identity setting through Xcode.** Textual uses a configuration file to specify the code signing identity. This allows it to be used across all projects associated with Textual without having to modify each.

**DO** edit the file located at _[Configurations ➜ Build ➜ Code Signing Identity.xcconfig](https://github.com/Codeux-Software/Textual/blob/master/Configurations/Build/Code%20Signing%20Identity.xcconfig)_

**It is HIGHLY DISCOURAGED to turn off code signing.** Certain features rely on the fact that Textual is properly signed and is within a sandboxed environment.

**TEXTUAL DOES NOT REQUIRE A CERTIFICATE ISSUED BY APPLE TO BUILD** which means there is absolutely no reason to turn code signing off.

## Note Regarding Trial Mode

The code which is responsible for licensing paid copies of Textual is in the source code that you download from here.

If you do not have a license key, then set the ``TEXTUAL_BUILT_WITH_LICENSE_MANAGER`` flag to `0` in the `Standard Release` configuration file to disable the inclusion of this code at build time.

## Building Textual

The latest version of Textual requires two things to be built. One is a valid (does not need to be issued by Apple) code signing certificate. The second is an installation of Xcode 10.0 or newer on macOS High Sierra. **Building on anything earlier is not supported because of Swift 4.2 code.**

**DO NOT change the Code Signing Identity setting through Xcode.** Modify the file located at _[Configurations ➜ Build ➜ Code Signing Identity.xcconfig](https://github.com/Codeux-Software/Textual/blob/master/Configurations/Build/Code%20Signing%20Identity.xcconfig)_ instead.

Build Textual using the "Standard Release" build scheme.

## Original Limechat License

Textual began as a fork of [LimeChat](https://github.com/psychs/limechat) in 2010

LimeChat's original license is presented below.

<pre>
The New BSD License

Copyright (c) 2008 - 2010 Satoshi Nakagawa < psychs AT limechat DOT net >
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.
</pre>

## License for content originating from Textual

Unless stated otherwise by Textual's [Acknowledgements.pdf](Acknowledgements.pdf) document, the license presented below shall govern the distribution of and modifications to; the work hosted by this repository.

<pre>
Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
      Please see Acknowledgements.pdf for additional information.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

   * Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
   * Neither the name of Textual, "Codeux Software, LLC", nor the
     names of its contributors may be used to endorse or promote products
     derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.
</pre>
