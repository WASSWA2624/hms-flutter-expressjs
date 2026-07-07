# Patrol E2E Tests

Patrol complements `flutter test` and `integration_test` by driving full-app
flows on web and native targets with richer failure diagnostics.

## Version lock

Keep these versions aligned (see [Patrol compatibility](https://patrol.leancode.co/documentation)):

| Tool | Version |
| ---- | ------- |
| `patrol` (pubspec dev dependency) | ^4.6.1 |
| `patrol_cli` (global) | 4.4.0 |

Install CLI:

```sh
dart pub global activate patrol_cli
```

Ensure `$HOME/.pub-cache/bin` (or `%LOCALAPPDATA%\Pub\Cache\bin` on Windows) is on `PATH`, then verify:

```sh
patrol doctor
```

## Run locally

From `frontend/`:

```powershell
.\tool\run_patrol_tests.ps1
```

Run a single suite:

```sh
patrol test -t patrol_test/smoke_test.dart -d chrome
```

Run the full module workspace sweep:

```sh
patrol test -t patrol_test/module_workspaces_flow_test.dart -d chrome
```

### Platforms

| Platform | Command | Notes |
| -------- | ------- | ----- |
| Web (CI default) | `patrol test -d chrome` | Headless via `--web-headless=true` in the script |
| Android | `patrol test -d <deviceId>` | Requires emulator/device, `ANDROID_HOME`, and `PatrolJUnitRunner` setup |
| iOS | `patrol test -d "iPhone 16"` | Requires macOS + Runner UI test target (see Patrol docs) |

Tests use provider overrides and seeded sessions — no production credentials.

## Failure reports

On failure, bundles are written to:

```text
frontend/build/patrol_reports/<timestamp>_<test-name>/
  summary.txt
  diagnostics.json
  screenshot.png (or screenshot.txt when capture is unavailable)
```

Open the latest bundle:

```sh
cat build/patrol_reports/latest.txt
```

Verify the reporter manually (intentional failure):

```sh
patrol test -t patrol_test/diagnostics_verification_test.dart -d chrome
```

Remove `skip: true` in that file first.

Each JSON bundle includes a one-line repro command, for example:

```sh
patrol test -t patrol_test/smoke_test.dart --platform chrome
```

## Suite layout

| File | Coverage |
| ---- | -------- |
| `smoke_test.dart` | App boot + home (mobile + desktop) |
| `auth_flow_test.dart` | Login shell, redirect, logout |
| `home_navigation_test.dart` | Dashboard + sidebar/route navigation |
| `patients_flow_test.dart` | Patient registry shell |
| `opd_flow_test.dart` | OPD queue + encounter action |
| `clinical_flow_test.dart` | Clinical workspace shell + note action |
| `billing_flow_test.dart` | Billing shell |
| `module_workspaces_flow_test.dart` | Remaining workspace routes |
| `helpers/patrol_harness.dart` | Session presets, navigation, viewport |
| `helpers/failure_reporter.dart` | Diagnostic bundle on failure |

## CI limitations

- Linux CI runs Patrol smoke on Chrome (headless) only.
- Full native suite (Android emulator, iOS Simulator) is documented but not required on every PR.
- Web shards can be enabled with `--web-shard` when the suite grows.

## Related docs

- [`integration_test/README.md`](../integration_test/README.md) — Flutter integration smoke tests
- [`docs/release/build-ci-release.md`](../docs/release/build-ci-release.md) — quality gates
