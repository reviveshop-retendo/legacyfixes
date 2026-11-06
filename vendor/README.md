# Vendored third-party components

These directories contain upstream projects that LegacyFixes builds and ships
from its own repository. They keep their original licenses and are **not**
covered by the root MIT license.

## TubeReplacer

- Upstream: https://github.com/Preloading/TubeReplacer
- Commit: `ac273fb4f9ce90ca4871454555883f3b62e0e016` (v2.0.2, 2026-10-30)
- License: GPL-3.0 (see `TubeReplacer/LICENSE`)
- Package: `dev.preloading.tubereplacer`

TubeReplacer replaces the dead backend of the classic App Store YouTube app
(versions 1.0.0–2.0.0) on iOS 5–10 with a local Innertube bridge. It is the
component that actually restores search, playback and sign-in; the
`com.legacyfixes.youtube` package depends on it.

Provenance / local changes:

- Vendored source is unmodified apart from removing `.git`, `.gitmodules`,
  CI/editor metadata and build output.
- `lib/zip` is a git submodule upstream. Its contents at submodule commit
  `b7c63224ed78596cef8567fe7bfeef045961b8a0` are vendored directly because the
  CI checkout does not initialise submodules.
- Builds use protoc **35.1**, which emits Objective-C protobuf code version
  `40311` matching the vendored `lib/protobuf` runtime. Other protoc versions
  fail the runtime version check.
- No source-level behaviour changes. Upstream's optional first-launch
  analytics/crash reporting code is therefore still present; see
  `googleapp/general.x` and `googleapp/crashreporter.x`. Do not install it if
  that is a concern.
