# Prebuilt frameworks

Third-party frameworks Textual ships as prebuilt binaries, unmodified. Everything else is built from source in this repository.

| Framework | Version | Source | Licence |
|---|---|---|---|
| `Sparkle.framework` | 2.10.0 (2064) | [Sparkle 2.10.0 release](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0), `Sparkle-2.10.0.tar.xz` | `LICENSE.txt` (Acknowledgements) |

SHA-256 of the release archive: `c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c` (as published on GitHub).
SHA-256 of `Sparkle.framework/Versions/B/Sparkle`: `a4b35bf38c12044686d0910dcb680560f1ff000061fbe19541c0b5e41c6c6008`

When updating, use an official release archive, check it against the checksum GitHub publishes, and record the version and both checksums here. `Scripts/PostprocessSparkle.sh` removes the downloader service and re-signs the helpers with Textual's identity.

Sparkle is used only by the direct-download build. The App Store build neither links nor embeds it.
