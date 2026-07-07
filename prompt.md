# Full Test Suite Implementation — Prompt

## Objective

Implement and maintain a **complete three-layer test strategy** for HOSSPI HMS frontend: **unit/widget**, **integration**, and **end-to-end (Patrol)**. Every layer must pass reliably, cover all modules, and produce actionable diagnostics on failure.

**Outcome:** `flutter test`, `flutter test integration_test`, and `patrol test` all green against a seeded non-production backend — with no silent gaps, skipped suites without reason, or untested workspace routes.

---

## Test Pyramid

| Layer | Location | Runner | Backend | Purpose |
| ----- | -------- | ------ | ------- | ------- |
| **Unit & widget** | `frontend/test/` | `flutter test` | Mocked / overrides | Controllers, DTOs, entities, validators, shared components, page shells |
| **Integration** | `frontend/integration_test/` | `flutter test integration_test` | Mocked / overrides | Startup, routing, auth guards, session shell, platform-critical navigation |
| **E2E (Patrol)** | `frontend/patrol_test/` | `patrol test` | **Live seeded API** | Real login, module workflows, cross-role journeys, failure diagnostics |

Unit and integration tests **must not** call production or require secrets. Patrol E2E **must** use seeded demo credentials (below) against a running backend with demo data.

---

## Current State (read before changing code)

| Layer | Location | Status |
| ----- | -------- | ------ |
| Unit & widget | `frontend/test/` (~181 files) | Broad coverage; gaps in some modules (see matrix) |
| Integration | `frontend/integration_test/` (1 file) | Smoke only — needs expansion |
| E2E (Patrol) | `frontend/patrol_test/` (~12 files) | Bootstrapped; needs real-login flows + remaining modules |
| Harness (unit) | `frontend/test/helpers/test_harness.dart` | `pumpHosspiHmsApp`, `testReadyAppOverrides` |
| Harness (E2E) | `frontend/patrol_test/helpers/` | `patrol_harness.dart`, `failure_reporter.dart` |
| Run scripts | `frontend/tool/run_patrol_tests.ps1`, `.sh` | Smoke + optional full suite |
| Rules | `frontend/.cursor/testing.mdc` | Defines all three layers |
| Quality gates | `frontend/docs/release/build-ci-release.md` | All three runners in PR checklist |

**Prerequisite for E2E:** backend running with seeded demo data (`npm run db:seed` from `backend/`). Verify with `npm run db:verify:demo`.

---

## Seeded Demo Credentials (E2E / Patrol only)

Patrol auth and module flows must perform **real login** against the live API — not `testReadyAppOverrides` or mocked sessions.

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

Store in `patrol_test/helpers/demo_credentials.dart` (or `--dart-define`). Source of truth: `backend/scripts/seeders/seed-catalog.js`, `backend/scripts/README.md`.

Each role-specific Patrol suite logs in as the correct account, then logs out (or resets app state) before the next conflicting session.

---

## Module Coverage Matrix

Every row must reach **Complete** before the suite is considered fully implemented.

| Module | Unit: controller | Unit: DTOs/entities | Widget: page/dialog | Integration | E2E (Patrol) |
| ------ | ---------------- | ------------------- | ------------------- | ----------- | ------------ |
| auth | required | required | login, register pages | route guards, login shell | real login/logout |
| home | required | required | dashboard widgets | nav from home | dashboard + sidebar |
| patients | required | required | registry page | route + shell | registry + detail |
| opd | ✓ | required | walk-in dialog | shell load | queue + encounter |
| clinical | ✓ | ✓ | workspace page | shell load | note/action flow |
| ipd | ✓ | required | admission dialog | shell load | admission shell |
| nursing | ✓ | required | — | shell load | task shell |
| lab | ✓ | required | result entry | shell load | catalog/result |
| radiology | ✓ | required | — | shell load | order shell |
| pharmacy | required | ✓ | catalog dialog | shell load | order/dispense |
| billing | ✓ | required | payment dialog | shell load | invoice shell |
| claims | ✓ | required | — | shell load | claim shell |
| hr | ✓ | required | onboarding dialogs | shell load | staff detail |
| biomedical | ✓ | required | — | shell load | work order |
| housekeeping | required | required | — | shell load | task queue |
| operations | ✓ | required | — | shell load | primary action |
| emergency | required | required | — | shell load | dispatch (ambulance) |
| icu | ✓ | required | — | shell load | stay shell |
| theater | ✓ | required | — | shell load | case shell |
| discharge | ✓ | required | — | shell load | plan shell |
| physiotherapy | ✓ | required | — | shell load | session shell |
| mortuary | ✓ | required | — | shell load | case shell |
| communications | ✓ | required | — | shell load | inbox shell |
| reports | ✓ | required | — | shell load | report shell |
| subscriptions | ✓ | required | — | shell load | plan shell |
| access_admin | ✓ | required | — | shell load | role shell |
| settings | ✓ | required | settings page | shell load | profile section |
| tenant_facility | ✓ | required | setup page | setup redirect | setup shell |
| rooms_beds | ✓ | required | — | shell load | bed map shell |
| integrations | required | required | — | shell load | connector shell |
| profile | required | required | profile page | — | — |

Mark incomplete cells with `skip:` only when backend or UI is genuinely unavailable — document the reason inline.

---

## Layer Requirements

### 1. Unit & widget tests (`frontend/test/`)

**Mandatory per feature module:**

- `*_workspace_controller_test.dart` (or equivalent controller) — load, filter, mutation, error states
- `*_dtos_test.dart` — JSON round-trip, null handling, enum mapping
- `*_entities_test.dart` — value objects, query models, copy/equality
- Widget tests for primary pages, dialogs, and shared components used by the module
- Repository impl tests where custom mapping or offline logic exists

**Mandatory shared/core:**

- `frontend/lib/shared/components/*` — widget test per component
- `frontend/lib/core/*` — permissions, session, realtime, formatters, validators
- Responsive layout tests for `app_workspace`, `responsive_shell_scaffold`, breakpoints

**Standards:**

- Use `mocktail` or provider overrides; never hit real API
- Mirror `lib/` structure under `test/`
- Mobile + desktop viewport for layout-critical widgets

### 2. Integration tests (`frontend/integration_test/`)

**Mandatory suites:**

| File | Coverage |
| ---- | -------- |
| `startup_navigation_smoke_test.dart` | App boot, home load, 404 route (existing) |
| `auth_shell_test.dart` | Unauthenticated redirect, login page render, session restore shell |
| `routing_guards_test.dart` | Protected routes reject unauthenticated users |
| `responsive_shell_test.dart` | Shell renders at mobile + desktop viewports |
| `module_navigation_test.dart` | Deep-link to each workspace route with mocked session + entitlements |

**Standards:**

- `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`
- Reuse `test/helpers/test_harness.dart` — provider overrides only, no live backend
- No production services or secrets

### 3. End-to-end tests (`frontend/patrol_test/`)

**Mandatory infrastructure:**

- `patrol` + `patrol_cli` (version-locked; see `patrol_test/README.md`)
- `helpers/demo_credentials.dart`, `patrol_harness.dart` (`loginAs`, `logout`, `goToModule`)
- `helpers/failure_reporter.dart` — diagnostic bundle on every failure

**Mandatory suites:**

| File | Login as | Minimum flows |
| ---- | -------- | ------------- |
| `smoke_test.dart` | `tenant.admin@hosspi.com` | Boot, real login, home (mobile + desktop) |
| `auth_flow_test.dart` | `reception@hosspi.com` | Real login, logout, unauthenticated redirect |
| `home_navigation_test.dart` | `tenant.admin@hosspi.com` | Dashboard, sidebar/route navigation |
| `patients_flow_test.dart` | `reception@hosspi.com` | Registry list, open patient detail |
| `opd_flow_test.dart` | `doctor@hosspi.com` | Queue load, encounter dialog |
| `clinical_flow_test.dart` | `doctor@hosspi.com` | Workspace shell, primary clinical action |
| `lab_flow_test.dart` | `lab@hosspi.com` | Workspace entry, catalog/result action |
| `pharmacy_flow_test.dart` | `pharmacy@hosspi.com` | Order/dispense shell |
| `billing_flow_test.dart` | `billing@hosspi.com` | Invoice/payment shell |
| `hr_flow_test.dart` | `hr@hosspi.com` | Staff list, open detail |
| `biomedical_flow_test.dart` | `biomed@hosspi.com` | Asset list, work order |
| `housekeeping_flow_test.dart` | `housekeeping@hosspi.com` | Task queue shell |
| `operations_flow_test.dart` | `operations@hosspi.com` | Primary workspace action |
| `ambulance_flow_test.dart` | `ambulance@hosspi.com` | Emergency dispatch shell |
| `module_workspaces_flow_test.dart` | role-appropriate per route | All remaining workspace shells |

**Failure diagnostics (every failing Patrol test):**

1. Human-readable `summary.txt` — test name, assertion, platform, viewport
2. `screenshot.png` (or fallback note when unavailable)
3. `diagnostics.json` — route, semantics/finder chain, stack trace, repro command
4. Store under `frontend/build/patrol_reports/<timestamp>_<test-name>/`

---

## Phased Deliverables

### Phase 1 — Close unit & widget gaps

- [ ] Audit module matrix; add missing controller, DTO, entity, and widget tests
- [ ] Ensure every `*_workspace_controller.dart` has a matching test file
- [ ] Ensure every `*_workspace_page.dart` has at least a shell widget test
- [ ] `flutter test` passes with zero failures

### Phase 2 — Expand integration suite

- [ ] Add `auth_shell_test.dart`, `routing_guards_test.dart`, `responsive_shell_test.dart`
- [ ] Add `module_navigation_test.dart` covering all 26 workspace routes
- [ ] Update `integration_test/README.md` with per-file descriptions and run commands
- [ ] `flutter test integration_test` passes on CI device target

### Phase 3 — Complete Patrol E2E

- [ ] `demo_credentials.dart` + `loginAs()` using real API (replace session overrides in auth/module flows)
- [ ] Implement all suite files in the E2E table above
- [ ] `module_workspaces_flow_test.dart` covers every workspace route with correct role
- [ ] `diagnostics_verification_test.dart` confirms failure bundles
- [ ] `patrol test` full suite passes with backend + seed data running

### Phase 4 — CI, docs, and maintenance

- [ ] `frontend/tool/run_patrol_tests.ps1` / `.sh` — smoke (CI) + full suite (local)
- [ ] CI: `flutter test` → `flutter test integration_test` → Patrol smoke (headless Chrome)
- [ ] CI E2E stage: seeded backend container + Patrol module subset
- [ ] Keep `patrol_test/README.md`, `integration_test/README.md`, and `build-ci-release.md` in sync
- [ ] New features ship with all three layers updated in the same PR

---

## Quality Gate (run from `frontend/`)

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
patrol test -t patrol_test/smoke_test.dart -d chrome --web-headless=true
```

Full E2E (local, requires backend):

```sh
.\tool\run_patrol_tests.ps1 -FullSuite
```

---

## Acceptance Criteria

### Unit & widget

- [ ] `flutter test` passes with no failures
- [ ] Every feature module row in the matrix has controller + DTO/entity tests
- [ ] Every workspace page has a widget or integration shell test
- [ ] Shared components and core utilities have tests

### Integration

- [ ] `flutter test integration_test` passes
- [ ] Auth guards, startup, routing, and all workspace deep-links covered
- [ ] Tests use harness overrides only — no live backend

### E2E (Patrol)

- [ ] `patrol doctor` passes on a clean dev machine
- [ ] Full `patrol test` suite passes with seeded demo credentials
- [ ] Every workspace route has a passing Patrol test or documented `skip`
- [ ] Deliberate failure produces a complete diagnostic bundle
- [ ] README documents install, run, failure reports, and CI limitations

### Overall

- [ ] All three layers green in CI
- [ ] No module ships without corresponding tests at every applicable layer
- [ ] Test additions follow `frontend/.cursor/testing.mdc`

---

## References

- Testing rules: `frontend/.cursor/testing.mdc`
- Unit harness: `frontend/test/helpers/test_harness.dart`
- Patrol docs: https://patrol.leancode.co/documentation
- Patrol README: `frontend/patrol_test/README.md`
- Integration README: `frontend/integration_test/README.md`
- Seeded accounts: `backend/scripts/seeders/seed-catalog.js`, `backend/scripts/README.md`
- CI gates: `frontend/docs/release/build-ci-release.md`
- Module workflows: `prompts/*.md`
- Product scope: `.cursor/app-write-up.mdc`
