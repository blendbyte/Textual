# Build configurations

Every project in this repository (the app, the bundled plugins and the
frameworks) has three build configurations: **Debug**, **Release** and
**App Store**. Their settings live in these files rather than in the
projects.

| File | Set on | Contents |
| --- | --- | --- |
| `Base.xcconfig` | (included) | Settings shared by every project and configuration |
| `Warnings.xcconfig` | (included) | Compiler warnings |
| `Signing.xcconfig` | (included) | Signing identity and team |
| `Debug.xcconfig` | projects, Debug | Debug overrides; the Textual Dev identifiers; feature flags |
| `Release.xcconfig` | projects, Release | Identifiers and feature flags of the direct download |
| `AppStore.xcconfig` | projects, App Store | Identifiers and feature flags of the App Store build |
| `App.xcconfig` | app and test targets | The app; App Store entitlements and no Sparkle under `[config=App Store]` |
| `Version.xcconfig` | (included by `App`) | `MARKETING_VERSION` (the version users see) and `CURRENT_PROJECT_VERSION` (the build number, raised by one for every release) |
| `Plugin.xcconfig` | plugin targets | The bundled plugins |
| `Framework.xcconfig` | framework targets | Auto Hyperlinks, Cocoa Extensions, GRMustache |

Xcode applies a target's file on top of its project's, so the per-kind
files override the per-configuration ones. Settings that differ for one
target only stay in that target's build settings in the project.

## Feature flags

The `TEXTUAL_BUILT_*` settings in the per-configuration files are written
to `FeatureFlags.h` by `Scripts/UpdateFeatureFlags.sh`. They include or
leave out code; they don't add the resources a feature may need. To add a
flag, add it to that script as well.

## Building without Blendbyte's certificates

Create `Configurations/Signing.local.xcconfig` (ignored by git):

    CODE_SIGN_IDENTITY = -
    DEVELOPMENT_TEAM =

## Sandbox

`Sandbox/Inherited.entitlements` is used to sign the plugins, which
inherit the app's sandbox.
