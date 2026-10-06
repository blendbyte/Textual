# Static libraries for Textual

### How this works

`source/buildLibraries.sh` automates the building of libressl, libgpg-error, libgcrypt, and libotr for the Textual IRC Client.
By default, the build is done in `/tmp/static-library-build-results`. 

Other libraries and frameworks are obtained prebuilt or built manually.

Prebuilt:
- [AppCenter.framework 4.2.0](https://github.com/microsoft/appcenter-sdk-apple) 
- [AppCenterCrashes.framework 4.2.0](https://github.com/microsoft/appcenter-sdk-apple)
- [Sparkle.framework 1.26.0](https://github.com/sparkle-project/Sparkle/)

Built manually:
- [asn1c 0.9.28](https://github.com/vlm/asn1c) (used by Apple Receipt Loader, built using `Libraries/Source/Apple Receipt ASN1c/asn1c.xcodeproj`)
- [GRMustache af9d138f6fc1d985a2c4089ad19b791a02827908](https://github.com/groue/GRMustache) (templating engine, built using `Libraries/Source/GRMustache/GRMustache.xcodeproj`)

## Main Libraries

### How to build

This repository contains prebuilt binaries; however, if you need to rebuild them, instructions follow.
This assumes the arches being built are the default (x86_64 and arm64).

The ARCHES can be changed in the `buildLibraries.sh` script, in case other architectures are needed in the future.

1. `cd source`
2. `./buildLibraries.sh`
3. Ensure that `/tmp/static-library-build-results/lib-static/universal` contains the following files:
   - libcrypto.a
   - libgcrypt.a
   - libgpg-error.a
   - libotr.a
   - libssl.a
   - libtls.a
4. Copy the above `.a` files into the `Libraries` directory in this repository, overwriting any existing libraries.


## How to update library versions
Modify `source/buildLibraries.sh` to have the desired library version numbers. Note that this might break build and might require additional patches.

After building the libraries, the following additional steps must be taken:
1. Verify that there are no critical differences between the headers for the different arches:
   
   `diff -Nruw /tmp/static-library-build-results/includes/x86_64 /tmp/static-library-build-results/includes/arm64`
   
   A slight difference in the comment header in `gpgrt.h` is expected.
2. Delete the `Headers/libotr` and the `Headers/openssl` directories in this repository.
3. Copy everything inside `/tmp/static-library-build-results/includes/arm64/` into `Headers` in this repository.
4. When completed, `Headers` should contain the following files:
   - gcrypt.h
   - gpg-error.h
   - gpgrt.h
   - tls.h

   And the following directories:
   - libasn1c
   - libmustache
   - libotr
   - openssl
5. Delete the following directories within `Documentation` in this repository:
   - libgcrypt
   - libgpg-error
   - libotr
   - libssl
6. Copy everything inside `/tmp/static-library-build-results/licenses/arm64/` to `Documentation`.
5. Build the Encryption Kit Xcode project and make corrections for any API changes in the libraries.


## Other Libraries

For the prebuilt libraries, just download the latest releases and copy the frameworks into `Libraries`.

For the libraries built manually, instructions follow.

### libasn1: 

1. Build `Source/Apple Receipt ASN1c/asn1c.xcodeproj`.
2. Copy the `libasn1c.a`  build product into `Libraries`.

Updating this library is somewhat complicated -- files need to be copied from the source package and the Xcode project needs to be modified appropriately.

### GRMustache:

1. Check out the source code from GitHub.
2. Open `src/GRMustache.xcodeproj`, set the project to "GRMustache7-MacOS", and set build to "Any Mac".
3. Go to Project Info and set the Deployment Target to macOS 10.12.
4. Close the Xcode project.
5. Open Terminal, cd to the directory for GRMustache, and run `make lib/libGRMustache7-MacOS.a`.
6. Copy `lib/libGRMustache7-MacOS.a` to `Source/GRMustache/Libraries/libmustache.a` in this repo.
7. If you are building a different version of GRMustache, you will need to copy over the headers to `Source/GRMustache/Headers` and ensure that there have been no substantial changes.
8. Open `Sources/GRMustache/GRMustache.xcodeproj` in this repo.
9. Build the GRMustache wrapper.
10. Copy the `GRMustache.framework` build product to the `Libraries` directory in this repo.

## Licensing

See the `Documentation` directory.
