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
| Testing rules | `frontend/.cursor/testing.mdc` | No production services or secrets in tests |
| Quality gates | `frontend/docs/release/build-ci-release.md` | `flutter test`, `flutter test integration_test` |
| App package | `frontend/pubspec.yaml` (`hosspi_hms`) | Android `com.example.flutter_template`; web dev on port 5201 |

Patrol is **not** installed. `integration_test` alone cannot drive native dialogs, permissions, or multi-app flows — Patrol fills that gap.

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
- Tests that call production APIs or require real credentials.
- Golden-image baselines (optional later).

---

## Implementation Standards

| Area | Requirement |
| ---- | ----------- |
| Isolation | Use provider overrides, mock repositories, or seeded test fixtures — same rule as `testing.mdc`. |
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
- [ ] Add `patrol_test/smoke_test.dart` — launch app with `testReadyAppOverrides`, assert home loads (parity with existing integration smoke).
- [ ] Confirm: `patrol test -t patrol_test/smoke_test.dart`.

### Phase 2 — Shared test kit

- [ ] `patrol_test/helpers/patrol_harness.dart` — wrap `pumpHosspiHmsApp`, authenticated session presets, common navigation (`goToModule`, `openFirstRow`).
- [ ] `patrol_test/helpers/failure_reporter.dart` — hook `patrolTest` / `addTearDown` to capture screenshot + JSON diagnostic on failure.
- [ ] Document report output location and how to open the latest failure bundle.

### Phase 3 — Module flow suites

Add one Patrol file per domain (mirror `frontend/lib/features/`):

| Suite file | Minimum flows |
| ---------- | ------------- |
| `auth_flow_test.dart` | login, logout, unauthenticated redirect |
| `home_navigation_test.dart` | dashboard load, sidebar/route navigation |
| `patients_flow_test.dart` | registry list, open patient detail |
| `opd_flow_test.dart` | queue load, start/open encounter dialog |
| `clinical_flow_test.dart` | workspace shell, primary clinical action |
| `billing_flow_test.dart` | workspace load, invoice/payment shell |
| *(extend for remaining modules)* | workspace entry + one representative mutation dialog |

Prioritize modules in `prompts/` order where backend gaps are closed. Mark skipped flows with `skip:` and a linked issue — do not leave silent failures.

### Phase 4 — CI & reporting

- [ ] Add `frontend/tool/run_patrol_tests.ps1` (and `.sh` if needed) for local/CI execution.
- [ ] CI job: run Patrol smoke on Linux (`xvfb` / web target) and document Android emulator requirements for full suite.
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
- [ ] `patrol test` runs smoke + all module suites without production secrets.
- [ ] `flutter test` (existing suite) still passes unchanged.
- [ ] A deliberate failure generates a complete diagnostic bundle.
- [ ] README documents: install, run all, run one suite, read failure reports, CI limitations.
- [ ] Every module workspace has at least one passing Patrol test or an explicit `skip` with reason.

---

## References

- Patrol: https://patrol.leancode.co/documentation
- Existing harness: `frontend/test/helpers/test_harness.dart`
- Testing rules: `frontend/.cursor/testing.mdc`
- Module prompts: `prompts/*.md` (workflow definitions per domain)
- Product scope: `.cursor/app-write-up.mdc`
