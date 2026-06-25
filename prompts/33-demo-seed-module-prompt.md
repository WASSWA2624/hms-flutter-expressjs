# Demo and Seed Data Module — Implementation Prompt

## Objective

Document and maintain **Demo and Seed Data** for HOSSPI HMS: safe, repeatable seeding for development, testing, onboarding, and product demonstrations — covering tenant, facility, users, roles, subscriptions, modules, patients, and sample clinical/operational records per [app-write-up.mdc](../.cursor/app-write-up.mdc) Demo and Seed Data Expectations.

**Scope:** Backend seed scripts, idempotent demo markers, environment guards (never accidental production seed), and alignment with OPD/IPD demo flows.

**Central rule:** all seed data must be **clearly marked as demo**, safe to clear/recreate, and **disabled in production** unless explicitly overridden with strong safeguards.

---

## Global Implementation Standards

Mandatory platform rules for all work in this module.

| Area | Requirement |
| ---- | ----------- |
| Product scope | [app-write-up.mdc](../.cursor/app-write-up.mdc) — respect module boundaries; do not duplicate workflows owned elsewhere. |
| Patient flows | Align with [`.cursor/flows/`](../.cursor/flows/). Use [opd-flow.mdc](../.cursor/flows/opd-flow.mdc) and [ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) for journey touchpoints; read the module-specific flow file when one exists (lab, nursing, pharmacy, radiology, discharge, emergency, icu, theater). |
| Encounters | One active OPD encounter per outpatient visit; IPD admission as inpatient hub; overlays (ICU, Theater) and executing departments attach — never parallel admission records. |
| UI/UX | Modern, clean, minimal on-screen text; hospital workflow language (not enum names or UUIDs). Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`, `platform_guidelines.mdc`. Reuse `frontend/lib/shared/*` before creating new widgets. Responsive on Android, iOS, web, Windows, macOS, Linux. |
| Theming and i18n | Full theme support (light/dark/system). All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Modal-first workflows | **All create/edit/approve/complete/handoff actions** use **in-page dialogs, bottom sheets, or nested modals**. Do **not** navigate to new routes for within-module workflows. Shell entry routes (`/opd`, `/ipd`, etc.) and deep-link **pre-selection** of a patient/record are allowed; selecting a row opens the workspace detail panel — not a separate workflow page. |
| Realtime sync | Subscribe to relevant `RealtimeEventGroups` in workspace controllers. After mutations, refresh affected rows, detail panels, summary cards, and nav badges. Keep UI, frontend state, backend services, and database consistent. |
| Architecture | UI/controllers → repository → API (`frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`). Enforce RBAC + ABAC + tenant/facility scope + module entitlements (frontend `AccessGate` + backend authorization). |
| Database | Apply migrations for schema changes per backend standards; keep API contracts and schema aligned. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched modules. |

---


## Flow Integration Requirements

### Main Setup Flow (app-write-up)

Seed must support steps 1–7:

1. Default tenant and facility
2. Facility structure (departments, wards, beds, service units)
3. Default admins and department demo users (doctor, nurse, receptionist, cashier, pharmacist, lab, radiology, HR, operations, housekeeping, mortuary, etc.)
4. Roles, permissions, module entitlements
5. Subscription plan, active subscription, module subscriptions, license
6. Sample patients and visits through **OPD → triage → clinical → lab/pharmacy → billing**
7. Sample **IPD admissions**, nursing, discharge, and operational records (operations, biomedical, mortuary)

### OPD flow

- Sample OPD encounters in various backend stages (`WAITING_VITALS`, `WAITING_DOCTOR_REVIEW`, `LAB_REQUESTED`, `DISCHARGED`, `ADMITTED`) per [opd-flow.mdc](../.cursor/flows/opd-flow.mdc).
- At least one patient ready for OPD-to-IPD handoff testing.

### IPD flow

- Admissions in `ADMITTED_PENDING_BED`, `ADMITTED_IN_BED`, `DISCHARGE_PLANNED`, `DISCHARGED` per [ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc).
- Bed statuses including `Available`, `Occupied`, `Cleaning` for housekeeping/IPD integration.

### Department and overlay flows

Seed samples that exercise end-to-end paths documented in:

- [nursing-flow.mdc](../.cursor/flows/nursing-flow.mdc), [lab-flow.mdc](../.cursor/flows/lab-flow.mdc), [radiology-flow.mdc](../.cursor/flows/radiology-flow.mdc), [pharmacy-flow.mdc](../.cursor/flows/pharmacy-flow.mdc)
- [emergency-flow.mdc](../.cursor/flows/emergency-flow.mdc), [icu-flow.mdc](../.cursor/flows/icu-flow.mdc), [theater-flow.mdc](../.cursor/flows/theater-flow.mdc)
- [discharge-flow.mdc](../.cursor/flows/discharge-flow.mdc)

---

## Current State (read before changing code)

| Area | Location | Notes |
|------|----------|-------|
| Seed scripts | `backend/scripts/seeders/` | Tenant, users, clinical catalogs, Uganda diagnosis catalog, etc. |
| Env guards | `backend/.cursor/`, `constants-env` | Confirm production blocks |
| Frontend | No dedicated feature — devs run backend seed CLI | |
| Tests | Some modules use demo fixtures in tests | |

### Known gaps

- Single documented “run demo seed” entry point for new developers
- Not all app-write-up demo accounts may exist in one seeder run
- OPD/IPD end-to-end demo path may require manual steps after seed
- Dental demo data not seeded (module not built)
- Clear/recreate script documentation

---

## Scope — Core Capabilities

1. **Idempotent seed command** — document primary npm/script command and flags.
2. **Demo user matrix** — table of accounts, passwords (non-prod), roles, modules.
3. **Clinical path samples** — OPD visit + IPD admission linked to same patient.
4. **Operational samples** — open maintenance request, housekeeping task, mortuary case (read-only if mutations disabled).
5. **Safety** — `NODE_ENV`/explicit flag checks; warn on production hostnames.

---

## UI / UX Requirements

This is **admin seeding/reset tooling**, **not** a clinical workspace. The primary entry point is the backend seed CLI; any UI is a restricted admin panel — there is no patient worklist, no summary-card board, and no row-level clinical actions.

- **Layout:** if/where surfaced in the app, render an admin **Demo Data** panel (super-admin/operations only) using `AppWorkspace`/`app_content_panel` with three guarded actions — **Run seed**, **Clear demo data**, **Recreate (clear + run)** — plus a status area showing last run time, outcome, and seeded counts.
- **Safeguards:** every destructive/seed action requires a confirmation modal (`AppDialog`) that names the target environment/tenant and blocks when `NODE_ENV=production` (or a production hostname) unless an explicit dangerous override flag is provided; show a prominent warning banner in non-trivial environments.
- **Demo marking:** clearly label all seeded entities as **demo data** in the UI (badge/banner) and reflect the idempotent demo marker; make clear which data is safe to clear/recreate.
- **Progress & errors:** show run progress and surface backend errors verbatim; never silently partially-seed without reporting.
- Theming (light/dark/system), full localization via `app_en.arb`, and responsive layout across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Peer with admin/maintenance tooling panels (guarded, confirmation-driven actions) — not clinical worklists.

---


## Architecture and Conventions

| Rule | Requirement |
| ---- | ----------- |
| Layering | Widgets → Riverpod controllers → repository interface → impl → API client. No API calls from widgets. |
| State | `AsyncNotifier` + `Result<T>` / `AppFailure` for errors. |
| Permissions | `AccessGate` / `AppAccessActionGate`; backend auth mandatory even when UI hides actions. |
| File size | Extract reusable widgets to `presentation/widgets/`; shared components to `frontend/lib/shared/`. |
| Realtime | `frontend/.cursor/realtime_sync.mdc` — partial refresh after modal success when supported. |

---


## Acceptance Criteria

- [ ] New developer can seed demo tenant and login as doctor, nurse, receptionist, cashier.
- [ ] OPD worklist has actionable demo rows per opd-flow stages.
- [ ] IPD worklist has demo admissions per ipd-flow stages.
- [ ] Seed does not run on production without explicit dangerous flag.
- [ ] Demo data labeled in DB or metadata where supported.

---

## Quality Gate

From `frontend/` when touching Flutter:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="<module>"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
.cursor/app-write-up.mdc (Demo and Seed Data Expectations)
backend/scripts/seeders/
backend/env.template.txt

Related prompts: prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/01-auth-module-prompt.md, prompts/02-subscriptions-module-prompt.md
```
