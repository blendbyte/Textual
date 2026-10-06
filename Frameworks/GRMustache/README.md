# GRMustache

Vendored copy of [GRMustache](https://github.com/groue/GRMustache) by Gwendal Roué, MIT licensed (`LICENSE.txt`), built as `GRMustache.framework` for Textual's styles and the inline content loader.

- Source: `src/classes` of upstream commit `af9d138f` (2016-06-30, v7.3.2 plus 19 commits; upstream is archived).
- Built from source as a dependency of the app; install name `@rpath/GRMustache.framework/Versions/A/GRMustache`, unchanged from the prebuilt framework Textual shipped before.
- Manual reference counting: the target builds with `CLANG_ENABLE_OBJC_ARC = NO`.

Local changes to the upstream sources:

- The 15 public headers import each other as `<GRMustache/…>`.
- `GRMustache.h` does not import `NSValueTransformer+GRMustache.h` and `NSFormatter+GRMustache.h`, so the public headers are the same 15 that Textual's plugin API exposed before.
