# Patrol E2E Testing Integration — Implementation Prompt

## Objective

Integrate [Patrol](https://patrol.leancode.co/) into HOSSPI HMS so end-to-end flows can be exercised on real devices and browsers, failures are diagnosable from artifacts alone, and the full suite is runnable locally and in CI.

**Outcome:** a maintainable Patrol test suite that complements existing unit/widget tests, covers every major module workflow, and produces actionable reports whenever a test fails.

---

## Current State (read before changing code)

| Area | Location | Notes |
| ---- | -------- | ----- |
| Unit & widget tests | `frontend/test/` (~180 files) | `flutter_test`, `mocktail`, provider overrides |
| Test harness | `frontend/test/helpers/test_harness.dart` | `pumpHosspiHmsApp`, `testReadyAppOverrides`, viewport helpers |
| Integration smoke | `frontend/integration_test/startup_navigation_smoke_test.dart` | Single startup/navigation test via `integration_test` |
| Testing rules | `frontend/.cursor/testing.mdc` | Unit/widget tests avoid production; Patrol E2E uses seeded demo accounts only |
| Quality gates | `frontend/docs/release/build-ci-release.md` | `flutter test`, `flutter test integration_test` |
| App package | `frontend/pubspec.yaml` (`hosspi_hms`) | Android `com.example.flutter_template`; web dev on port 5201 |

Patrol is **not** installed. `integration_test` alone cannot drive native dialogs, permissions, or multi-app flows — Patrol fills that gap.

**Prerequisite:** backend running with seeded demo data (`npm run db:seed` or `node scripts/setup-default-accounts.js`). Verify with `npm run db:verify:demo` from `backend/`.

---

## Seeded Demo Credentials (required for Patrol login)

Patrol auth and module flows must perform **real login** against the live API — not `testReadyAppOverrides` or mocked sessions. Use only these seeded accounts:

| Email | Typical use in Patrol suites |
| ----- | ---------------------------- |
| `super.admin@hosspi.com` | Platform-wide access, cross-tenant smoke |
| `tenant.admin@hosspi.com` | Tenant setup, access admin, subscriptions |
| `facility.admin@hosspi.com` | Facility config, settings, access admin |
| `doctor@hosspi.com` | OPD, clinical, IPD, theater |
| `nurse@hosspi.com` | Nursing, triage, ward workflows |
| `lab@hosspi.com` | Lab workspace |
| `pharmacy@hosspi.com` | Pharmacy workspace |
| `reception@hosspi.com` | Patient registry, front desk, OPD intake |
| `billing@hosspi.com` | Billing, claims |
| `operations@hosspi.com` | Operations workspace |
| `hr@hosspi.com` | HR workspace |
| `biomed@hosspi.com` | Biomedical workspace |
| `housekeeping@hosspi.com` | Housekeeping workspace |
| `ambulance@hosspi.com` | Emergency / ambulance flows |
| `patient.portal@hosspi.com` | Patient portal (if exposed in app) |

**Password (all accounts):** `Hosspi@2624.`

Store credentials in `patrol_test/helpers/demo_credentials.dart` (or env via `--dart-define`) — never commit alternate passwords. Source of truth: `backend/scripts/seeders/seed-catalog.js`, `backend/scripts/README.md`.

Each module suite must log in as the role with correct permissions for that workflow, then log out (or use a fresh app instance) before the next role-specific test when sessions would conflict.

---

## Scope

### In scope

1. **Tooling setup** — `patrol_cli`, `patrol` dev dependency, `patrol` block in `pubspec.yaml`, native config for Android, iOS, and web.
2. **Test infrastructure** — `patrol_test/` directory, shared helpers (reuse patterns from `test_harness.dart`), stable `Key`/`Semantics`/`finders` conventions for Patrol selectors.
3. **Flow coverage** — E2E tests for every module workspace and critical cross-module journey (auth → home → module shell → primary create/view/complete action).
4. **Failure diagnostics** — on any failure, emit a report bundle (screenshot, widget tree / Patrol logs, test name, route, timestamp, platform) under a predictable path (e.g. `frontend/build/patrol_reports/<run-id>/`).
5. **CI & docs** — scripts to run the suite headlessly; update `integration_test/README.md` (or add `patrol_test/README.md`) with run/fix instructions.

### Out of scope

- Replacing existing unit/widget tests in `frontend/test/`.
- Tests against production environments or non-seeded databases.
- Golden-image baselines (optional later).

---

## Implementation Standards

| Area | Requirement |
| ---- | ----------- |
| Authentication | Real login UI + API using seeded demo credentials above; backend must be reachable (local dev or CI test stack). |
| Isolation | Unit/widget tests keep provider overrides; Patrol E2E uses real auth and API against seeded data only — never production. |
| Selectors | Prefer `Key`, `Semantics(label: ...)`, or stable l10n strings from `app_en.arb`; avoid brittle text tied to demo data IDs. |
| Responsiveness | Smoke at least mobile and desktop viewport widths for shared shell layouts. |
| Modules | Cover all workspace routes under `frontend/lib/features/*/presentation/pages/*_workspace_page.dart` plus auth, tenant setup, and home. |
| Version lock | Keep `patrol` and `patrol_cli` on compatible versions; document the pair in README. |
| Quality gate | From `frontend/`: existing gates **plus** `patrol test` (or documented subset for CI). |

---

## Phased Deliverables

### Phase 1 — Bootstrap

- [ ] Install and verify: `dart pub global activate patrol_cli`, `patrol doctor`.
- [ ] Add `patrol` to `dev_dependencies`; configure `patrol` section (`app_name`, `test_directory`, Android package, iOS bundle ID).
- [ ] Complete native setup per [Patrol docs](https://patrol.leancode.co/documentation) (Android `PatrolJUnitRunner`, iOS UI test target, web/Playwright if used).
- [ ] Add `patrol_test/smoke_test.dart` — launch app, log in as `tenant.admin@hosspi.com` / `Hosspi@2624.`, assert home loads.
- [ ] Confirm: `patrol test -t patrol_test/smoke_test.dart` (with backend + seed data running).

### Phase 2 — Shared test kit

- [ ] `patrol_test/helpers/demo_credentials.dart` — centralized emails and shared password constant.
- [ ] `patrol_test/helpers/patrol_harness.dart` — `loginAs(email)`, `logout`, `goToModule`, `openFirstRow`; real auth only, no session overrides.
- [ ] `patrol_test/helpers/failure_reporter.dart` — hook `patrolTest` / `addTearDown` to capture screenshot + JSON diagnostic on failure.
- [ ] Document report output location and how to open the latest failure bundle.

### Phase 3 — Module flow suites

Add one Patrol file per domain (mirror `frontend/lib/features/`):

| Suite file | Login as | Minimum flows |
| ---------- | -------- | ------------- |
| `auth_flow_test.dart` | `reception@hosspi.com` | login, logout, unauthenticated redirect |
| `home_navigation_test.dart` | `tenant.admin@hosspi.com` | dashboard load, sidebar/route navigation |
| `patients_flow_test.dart` | `reception@hosspi.com` | registry list, open patient detail |
| `opd_flow_test.dart` | `doctor@hosspi.com` | queue load, start/open encounter dialog |
| `clinical_flow_test.dart` | `doctor@hosspi.com` | workspace shell, primary clinical action |
| `lab_flow_test.dart` | `lab@hosspi.com` | workspace entry, result/catalog action |
| `pharmacy_flow_test.dart` | `pharmacy@hosspi.com` | workspace entry, order/dispense shell |
| `billing_flow_test.dart` | `billing@hosspi.com` | workspace load, invoice/payment shell |
| `hr_flow_test.dart` | `hr@hosspi.com` | staff list, open staff detail |
| `biomedical_flow_test.dart` | `biomed@hosspi.com` | asset list, open work order |
| `housekeeping_flow_test.dart` | `housekeeping@hosspi.com` | task queue, complete task shell |
| `operations_flow_test.dart` | `operations@hosspi.com` | workspace entry, primary action |
| `ambulance_flow_test.dart` | `ambulance@hosspi.com` | emergency dispatch shell |
| *(extend for remaining modules)* | role-appropriate account | workspace entry + one representative mutation dialog |

Prioritize modules in `prompts/` order where backend gaps are closed. Mark skipped flows with `skip:` and a linked issue — do not leave silent failures.

### Phase 4 — CI & reporting

- [ ] Add `frontend/tool/run_patrol_tests.ps1` (and `.sh` if needed) for local/CI execution.
- [ ] CI job: start seeded backend (or test container), then run Patrol smoke on Linux (`xvfb` / web target); document Android emulator requirements for full suite.
- [ ] Export JUnit/XML or Patrol-native artifacts for CI upload; failed runs must attach the diagnostic bundle.

---

## Failure Diagnostics (required behavior)

Every failing Patrol test must produce:

1. **Human-readable summary** — test name, assertion message, platform, viewport.
2. **Screenshot** — full screen at failure time.
3. **Structured JSON** — route, visible semantics tree or finder chain, stack trace, git SHA (if available).
4. **Repro command** — exact `patrol test -t <file> --platform <platform>` one-liner.

Store under `frontend/build/patrol_reports/<timestamp>_<test-name>/`. Never overwrite prior runs in the same session without archiving.

---

## Acceptance Criteria

- [ ] `patrol doctor` passes on a clean dev machine.
- [ ] `patrol test` runs smoke + all module suites using seeded demo credentials against a non-production backend.
- [ ] `flutter test` (existing suite) still passes unchanged.
- [ ] A deliberate failure generates a complete diagnostic bundle.
- [ ] README documents: install, run all, run one suite, read failure reports, CI limitations.
- [ ] Every module workspace has at least one passing Patrol test or an explicit `skip` with reason.

---

## References

- Patrol: https://patrol.leancode.co/documentation
- Seeded accounts: `backend/scripts/seeders/seed-catalog.js`, `backend/scripts/README.md`
- Existing widget harness (unit tests only): `frontend/test/helpers/test_harness.dart`
- Testing rules: `frontend/.cursor/testing.mdc`
- Module prompts: `prompts/*.md` (workflow definitions per domain)
- Product scope: `.cursor/app-write-up.mdc`
