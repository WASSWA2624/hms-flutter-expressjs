# Patrol E2E Tests

Patrol complements `flutter test` and `integration_test` by driving full-app
flows on web and native targets with richer failure diagnostics.

E2E suites perform **real login** against a seeded non-production backend — not
mocked sessions or `testReadyAppOverrides`.

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

## Backend prerequisite

From `backend/`:

```sh
npm run prisma:migrate:deploy
npm run db:reset:demo
npm run db:verify:demo
npm run dev
```

API base URL: `http://localhost:3000` (see `env/development.json.example`).

Demo credentials live in `patrol_test/helpers/demo_credentials.dart`. Password for
all seeded accounts: `Hosspi@2624.`

## Run locally

From `frontend/`:

```powershell
.\tool\run_patrol_tests.ps1
```

Run a single suite:

```sh
patrol test -t patrol_test/smoke_test.dart -d chrome --dart-define-from-file=env/development.json.example
```

Full suite (local, backend required):

```powershell
.\tool\run_patrol_tests.ps1 -FullSuite
```

### Platforms

| Platform | Command | Notes |
| -------- | ------- | ----- |
| Web (CI default) | `patrol test -d chrome` | Headless via `--web-headless=true` in the script |
| Android | `patrol test -d <deviceId>` | Requires emulator/device, `ANDROID_HOME`, and `PatrolJUnitRunner` setup |
| iOS | `patrol test -d "iPhone 16"` | Requires macOS + Runner UI test target (see Patrol docs) |

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

## Suite layout

| File | Login as | Coverage |
| ---- | -------- | -------- |
| `smoke_test.dart` | `tenant.admin@hosspi.com` | Boot, real login, home (mobile + desktop) |
| `auth_flow_test.dart` | `reception@hosspi.com` | Shell redirect, real login/logout |
| `home_navigation_test.dart` | tenant admin / billing / doctor | Dashboard + sidebar navigation |
| `patients_flow_test.dart` | `reception@hosspi.com` | Registry list + detail |
| `opd_flow_test.dart` | `doctor@hosspi.com` | OPD queue shell |
| `clinical_flow_test.dart` | `doctor@hosspi.com` | Clinical workspace shell |
| `lab_flow_test.dart` | `lab@hosspi.com` | Laboratory shell |
| `pharmacy_flow_test.dart` | `pharmacy@hosspi.com` | Pharmacy shell |
| `billing_flow_test.dart` | `billing@hosspi.com` | Billing shell |
| `hr_flow_test.dart` | `hr@hosspi.com` | HR staff list |
| `biomedical_flow_test.dart` | `biomed@hosspi.com` | Biomedical shell |
| `housekeeping_flow_test.dart` | `housekeeping@hosspi.com` | Task queue shell |
| `operations_flow_test.dart` | `operations@hosspi.com` | Operations shell |
| `ambulance_flow_test.dart` | `ambulance@hosspi.com` | Emergency dispatch shell |
| `module_workspaces_flow_test.dart` | role-appropriate per route | Remaining workspace shells |
| `helpers/demo_credentials.dart` | — | Seeded account emails + password |
| `helpers/patrol_harness.dart` | — | `loginAs`, `logoutPatrol`, `goToModule` |
| `helpers/failure_reporter.dart` | — | Diagnostic bundle on failure |

## CI limitations

- Linux CI runs Patrol smoke on Chrome (headless) when a seeded backend is available.
- Full native suite (Android emulator, iOS Simulator) is documented but not required on every PR.
- Web shards can be enabled with `--web-shard` when the suite grows.

## Related docs

- [`integration_test/README.md`](../integration_test/README.md) — Flutter integration tests (mocked)
- [`docs/release/build-ci-release.md`](../docs/release/build-ci-release.md) — quality gates
