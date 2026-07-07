# Pharmacist Role — Module Access & Navigation Fix

## Objective

Restore correct **Pharmacist** access in HOSSPI HMS so pharmacy staff can reach their operational modules from the app shell — not only the role dashboard and Settings.

## Problem (observed)

When logging in as the demo pharmacist (`pharmacy@hosspi.com`, **Harper Demo**, role **Pharmacist**), the sidebar shows only:

- **Overview → Dashboard** (Pharmacy workload)
- **Administration → Settings**

Missing from navigation: **Pharmacy**, **Reports**, and **Patient Registry** — even though the pharmacist dashboard profile, quick actions, and shortcuts are already defined for this role.

**Evidence:** Pharmacist session on `127.0.0.1:5201` — Pharmacy workload dashboard renders, but shell navigation is restricted to Dashboard and Settings.

## Expected behavior

After login, a Pharmacist with an active tenant subscription should have shell access aligned with peer diagnostic roles (Lab, Radiology):

| Module | Access level | Purpose |
| ------ | ------------ | ------- |
| **Pharmacy** (`/pharmacy`) | Full workbench | Dispense, stock, orders, returns — per [pharmacy-flow.mdc](.cursor/flows/pharmacy-flow.mdc) |
| **Reports** (`/reports`) | Read-only, pharmacy-relevant | Dispensing throughput, stock pressure, order metrics |
| **Patient Registry** (`/patients`) | Read-only, pharmacy-scoped | Search patients; view demographics plus **pharmacy-related context only** (active/past orders, prescriptions, dispense history, allergies relevant to dispensing) |
| **Dashboard** | Unchanged | Pharmacy workload summary cards and quick actions |
| **Settings** | Unchanged | Profile, password, personal preferences |

### Out of scope (must remain blocked)

- OPD / IPD stage control, clinical documentation, nursing MAR, billing reconciliation, HR, access admin, tenant/facility setup, and other non-pharmacy modules.

## Likely root causes (investigate in this order)

1. **RBAC gap** — `PHARMACIST` lacks permissions granted to similar roles:
   - `backend/src/config/permissions.js` — no `PATIENT_READ` or `REPORTS_READ` (compare `RADIOLOGY_TECH`, `BILLING`)
   - `frontend/lib/core/permissions/access_policy.dart` — mirror the same permission set
2. **Route role gate** — Pharmacist excluded from patient registry:
   - `frontend/lib/app/router/app_routes.dart` → `patientRegistryRoles`
3. **Module entitlement alignment** — shell routes require subscription modules:
   - Pharmacy → `pharmacy-dispensing`
   - Reports → `reporting-analytics`
   - Patients → `patient-registry` + `patient:read`
   - Verify demo tenant entitlements in `backend/src/lib/subscriptions/tenant-entitlements.js` and auth payload (`module_entitlements` on login)
4. **Home action module slug mismatch** — home quick actions use `pharmacy` / `reports` while routes use `pharmacy-dispensing` / `reporting-analytics`:
   - `frontend/lib/features/home/presentation/pages/home_page.dart`
   - `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart` (pharmacist `shortcutIds`: `pharmacy`, `reports`)
5. **Patient registry UI scope** — registry may need a pharmacy-limited detail panel (pattern: department-scoped read, not full clinical record).

## Implementation requirements

1. **Align RBAC** — Add `patient:read` and `reports:read` to `PHARMACIST` in backend permissions and frontend `AppAccessPolicy`; keep write access limited to pharmacy scope.
2. **Open shell routes** — Ensure `AppRoutes.pharmacy`, `AppRoutes.reports`, and `AppRoutes.patients` pass `AccessRequirement.isAllowed` for Pharmacist when tenant modules are active.
3. **Add Pharmacist to patient registry roles** — Include `AppRole.pharmacist` in `patientRegistryRoles`; enforce read-only via permissions and UI gates.
4. **Pharmacy-scoped patient view** — In patient registry detail, show pharmacy context (orders, dispense status, formulary/allergy flags); hide unrelated clinical tabs/actions.
5. **Backend authorization** — Mirror frontend access on pharmacy, reports, and patient read APIs; backend must enforce, not rely on UI hiding alone.
6. **Demo seed** — Confirm `pharmacy@hosspi.com` demo user inherits updated role permissions after re-seed or migration.
7. **Preserve module boundaries** — Pharmacist dispenses only; no OPD/IPD stage mutations per [opd-flow.mdc](.cursor/flows/opd-flow.mdc) §5 and [pharmacy-flow.mdc](.cursor/flows/pharmacy-flow.mdc) §5.

## Source of truth

1. [pharmacy-flow.mdc](.cursor/flows/pharmacy-flow.mdc)
2. [opd-flow.mdc](.cursor/flows/opd-flow.mdc) — Pharmacy role: workspace only
3. [app-write-up.mdc](.cursor/app-write-up.mdc) — Pharmacy module boundaries
4. [prompts/18-pharmacy-module-prompt.md](prompts/18-pharmacy-module-prompt.md)
5. [prompts/08-patients-module-prompt.md](prompts/08-patients-module-prompt.md)
6. [prompts/04-access-admin-module-prompt.md](prompts/04-access-admin-module-prompt.md)

## Acceptance criteria

- [ ] Login as `pharmacy@hosspi.com` → sidebar shows **Pharmacy**, **Reports**, and **Patients** (plus Dashboard, Settings).
- [ ] `/pharmacy` loads the pharmacy workbench; dispense queue and stock panels are usable.
- [ ] `/reports` loads; pharmacist sees pharmacy-appropriate reports only.
- [ ] `/patients` loads; pharmacist can search/view patients but cannot edit demographics or launch non-pharmacy workflows.
- [ ] Patient detail shows pharmacy-related information; unrelated clinical sections are hidden or read-blocked.
- [ ] Dashboard quick actions (`dispense_medication`, `run_report`) and shortcuts (`pharmacy`, `reports`) are visible and navigable.
- [ ] Direct URL access to blocked modules (e.g. `/opd`, `/clinical`, `/billing`) is denied with consistent access messaging.
- [ ] Backend APIs reject unauthorized pharmacist mutations outside pharmacy scope.

## Quality gate

- `frontend/`: `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` (include `route_guards_test.dart`, pharmacy/home tests)
- `backend/`: targeted `npm test` for permissions, auth session, module-entitlement middleware, pharmacy-workspace
- Manual smoke: pharmacist login on web (`127.0.0.1:5201`) — verify nav, routes, and patient pharmacy panel
