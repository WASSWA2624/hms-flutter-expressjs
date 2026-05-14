# Build, CI, and Release Readiness

Rule sources:

- [`app-rules/ci_cd_quality_gates.md`](../../app-planner/app-rules/ci_cd_quality_gates.md)
- [`app-rules/platform_guidelines.md`](../../app-planner/app-rules/platform_guidelines.md)
- [`app-rules/security.md`](../../app-planner/app-rules/security.md)
- [`app-rules/dependencies.md`](../../app-planner/app-rules/dependencies.md)
- [`app-rules/testing.md`](../../app-planner/app-rules/testing.md)

This template keeps build inputs public and non-secret. Pass runtime values with
Flutter define files through `--dart-define-from-file`; do not commit API keys,
passwords, tokens, private certificates, signing files, or production
credentials.

## Local Quality Gates

Run these commands before opening a pull request or preparing a release:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code -- .
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
```

Use `git diff --exit-code -- .` after generation to fail fast when committed
generated files are stale. Use `flutter test integration_test -d <deviceId>` if
more than one Flutter device is connected; CI runs the integration smoke test on
Linux under `xvfb` for deterministic desktop coverage. Use
`flutter test --coverage` when coverage output is needed for a release review.

## CI Workflow

The workflow at `.github/workflows/ci.yml` runs the same quality gates on pull
requests, pushes to `main`, and manual dispatches. It also runs release smoke
builds for Web, Android APK, Linux, Windows, macOS, and unsigned iOS.

CI uses the production-safe placeholder values in `env/production.json.example`:

```sh
flutter build web --release --dart-define-from-file=env/production.json.example
```

Replace the placeholder URL by providing a secure CI define file or CI-only
`--dart-define=API_BASE_URL=...` overrides. Keep credentials and signing
material out of the repository and out of logs.

## Platform Build Commands

Run platform builds only on hosts with the required SDKs installed.

### Web

```sh
flutter build web --release --dart-define-from-file=env/production.json.example
```

Artifact path: `build/web/`.

### Android

```sh
flutter build apk --release --dart-define-from-file=env/production.json.example
```

```sh
flutter build appbundle --release --dart-define-from-file=env/production.json.example
```

Artifact paths: `build/app/outputs/flutter-apk/` and
`build/app/outputs/bundle/release/`.

Before a store release, replace the template Android application ID and configure
release signing outside source control. The starter currently uses debug signing
for local release smoke builds only.

### iOS

```sh
flutter build ios --release --no-codesign \
  --dart-define-from-file=env/production.json.example
```

Use `flutter build ipa --release` with app-specific signing and export options
when distribution credentials are available on a secure macOS build host.

### Windows

```sh
flutter build windows --release --dart-define-from-file=env/production.json.example
```

Artifact path: `build/windows/x64/runner/Release/`.

Windows builds require Developer Mode for plugin symlink support and Visual
Studio with the Desktop development with C++ workload.

### macOS

```sh
flutter config --enable-macos-desktop
flutter build macos --release \
  --dart-define-from-file=env/production.json.example
```

Artifact path: `build/macos/Build/Products/Release/`.

macOS builds require a macOS host with Xcode. Configure signing, entitlements,
notarization, and packaging outside source control before distribution.

### Linux

```sh
flutter config --enable-linux-desktop
flutter build linux --release \
  --dart-define-from-file=env/production.json.example
```

Install Flutter Linux desktop dependencies first, including GTK, CMake, Ninja,
pkg-config, and package-specific native dependencies such as libsecret.

## Versioning Rules

- Keep `pubspec.yaml` as the source of truth for template versioning.
- Use semantic versioning for the build name: `major.minor.patch`.
- Increase the build number after every release candidate: `version: 0.1.0+1`.
- Prefer `--build-name` and `--build-number` in CI only when a release pipeline
  needs to stamp an already-reviewed version.
- Keep platform store metadata aligned with the Dart package version when a
  product-specific app enables store deployment.

## Production Safety Checks

`AppConfig` rejects production values that use plain HTTP, enable developer
tools, or set `LOG_LEVEL=debug`. Keep these checks in place for every release
build.

Before release, scan for debug-only behavior and accidental secrets:

```sh
rg -n "kDebugMode|debugPrint|print\(|localhost|127\.0\.0\.1|apiKey|secret|token" lib android ios linux web
```

Test fixtures may contain fake tokens or passwords, but source code, assets,
workflow files, and docs must not contain real secrets.

## Release Checklist

- `pubspec.yaml` has the intended `version`.
- Dependencies are reviewed and `pubspec.lock` is committed.
- Code generation is current and produces no diff.
- Formatting, analyzer, unit/widget tests, and integration smoke tests pass.
- Web, Android, iOS, Windows, macOS, and Linux release builds complete on
  supported hosts.
- Production `API_BASE_URL` uses HTTPS and contains no credentials.
- Production `LOG_LEVEL` is `info`, `warn`, or `error`.
- `FEATURE_DEVELOPER_TOOLS_ENABLED` is false for production.
- No `print`, `debugPrint`, local endpoint, or debug-only diagnostics are
  shipped in production code.
- Signing credentials, keystores, provisioning profiles, and export options are
  stored in secure CI facilities, not in the repository.
