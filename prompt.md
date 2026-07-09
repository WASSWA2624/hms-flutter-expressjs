# Standardize Role-Based Dashboard & Sidebar Access

## Objective

Refactor the HOSSPI HMS home dashboard and sidebar navigation so every staff role sees a **consistent layout** with **role-scoped content**. Users must only see menu items and dashboard widgets they are entitled to — no clutter from unrelated modules.

**Primary files:** `frontend/lib/features/home/`, `frontend/lib/app/router/app_routes.dart`, `frontend/lib/app/router/app_router.dart`, `frontend/lib/core/permissions/access_policy.dart`, `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`

**Standards:** Follow `frontend/.cursor/design-system.mdc`, `layouts.mdc`, `ui-workspace.mdc`. All labels via `app_en.arb`. Responsive on mobile, tablet, and desktop.

---

## Dashboard Layout (all roles)

Use one shared dashboard scaffold. **Do not** render a page title or a refresh button on the dashboard.

Sections, top to bottom:

| # | Section | Purpose | Constraints |
|---|---------|---------|-------------|
| 1 | **Summary badges** | Role-specific KPI/metric cards (e.g. waiting patients, pending labs, critical alerts) | Cap at 3–4 cards per role; hide zero-value cards |
| 2 | **Quick actions** | Primary workflow buttons (register patient, start consultation, dispatch ambulance, etc.) | Reuse shared `QuickAction` component; identical styling across all dashboards |
| 3 | **Critical shortcuts** | Tiles linking to urgent/pending work (critical patients, pending labs, overdue tasks) | Role-relevant only; deep-link into target workspace with pre-selection where applicable |
| 4 | **Charts** | Trend or distribution visuals (line, pie, donut) | **Maximum 4** charts; show only when data exists; enable `showCharts` in `home_dashboard_layout.dart` |

Drill-downs from dashboard widgets use **modals** or workspace deep-links — never intermediate workflow routes.

---

## Sidebar Menu Access

Filter sidebar items so each role sees **only** entitled routes. Admins see the full menu. Map requirements to existing `AppRoutes` names and enforce via `AccessRequirement` / `_canAccessShellRoute()`.

### Full access (all shell menu items)

| Role | Email |
|------|-------|
| Super Admin | `super.admin@hosspi.com` |
| Tenant Admin | `tenant.admin@hosspi.com` |
| Facility Admin | `facility.admin@hosspi.com` |

### Scoped access

| Role | Email | Allowed menu items |
|------|-------|-------------------|
| **Doctor** | `doctor@hosspi.com` | Dashboard, Patient registry, OPD, Emergency, Inpatient (IPD), ICU, Clinical, Operating theater, Discharge planning, Laboratory, Radiology, Pharmacy, Communications, Reports, Settings |
| **Nurse** | `nurse@hosspi.com` | Dashboard, Patient registry, OPD, Emergency, Inpatient (IPD), Rooms & beds, ICU, Nursing, Laboratory, Communications, Reports, Settings |
| **Lab** | `lab@hosspi.com` | Dashboard, Patient registry, Laboratory, Communications, Settings |
| **Pharmacy** | `pharmacy@hosspi.com` | Dashboard, Patient registry, Pharmacy, Communications, Reports, Settings |
| **Reception** | `reception@hosspi.com` | Dashboard, Patient registry, OPD, Communications, Settings |
| **Billing** | `billing@hosspi.com` | Dashboard, Patient registry, Billing, Insurance claims, Communications, Settings |
| **Operations** | `operations@hosspi.com` | Dashboard, Operations, Communications, Settings |
| **HR** | `hr@hosspi.com` | Dashboard, Human resources, Communications, Tenant setup, Reports, Settings |
| **Biomedical** | `biomed@hosspi.com` | Dashboard, Biomedical engineering, Communications, Reports, Settings |
| **Housekeeping** | `housekeeping@hosspi.com` | Dashboard, Housekeeping, Communications, Reports, Settings |
| **Ambulance** | `ambulance@hosspi.com` | Dashboard, Emergency, Communications, Reports, Settings |

### Explicit exclusions (apply where not listed above)

Doctor: Nursing, Physiotherapy, Billing, Insurance claims, Subscription plans, Operations, Housekeeping, Biomedical engineering, Mortuary, Human resources, Integrations, Tenant setup.

Ambulance: Patient registry and all modules except Emergency.

---

## Implementation Tasks

1. **Unify dashboard shell** — Extract a reusable `HomeDashboardScaffold` with the four sections above; remove title bar and refresh button from dashboard content.
2. **Standardize quick actions & shortcuts** — Ensure shared components render identically across roles; configure per role in `home_dashboard_profiles.dart`.
3. **Enable charts** — Turn on chart section (max 4) with role-appropriate metrics from `dashboard-workspace` API; graceful empty state when no data.
4. **Align sidebar with role matrix** — Update `AppRoutes` access requirements and/or role-permission mappings so the sidebar matches the table above. Verify with `_canAccessShellRoute()` for each test account.
5. **Sync dashboard profiles** — Each role's `statusCards`, `quickActionIds`, `shortcutIds`, and chart config must reflect their scope.
6. **Verify responsive layout** — Test mobile drawer, tablet rail, and desktop sidebar at all breakpoints.

---

## Acceptance Criteria

- [ ] Dashboard has no title and no refresh button
- [ ] All roles share the same four-section layout order
- [ ] Quick actions and shortcut tiles look identical across roles (only content differs)
- [ ] Charts capped at 4; hidden when empty
- [ ] Each test account sees only its allowed sidebar items
- [ ] Doctor cannot see Nursing, Billing, HR, etc.
- [ ] Ambulance cannot see Patient registry
- [ ] Admins (super/tenant/facility) see the full menu
- [ ] No analyzer warnings; existing tests pass

---

## Test Accounts

Password for all accounts: `Hosspi@2624`

| Role | Email |
|------|-------|
| Super Admin | `super.admin@hosspi.com` |
| Tenant Admin | `tenant.admin@hosspi.com` |
| Facility Admin | `facility.admin@hosspi.com` |
| Doctor | `doctor@hosspi.com` |
| Nurse | `nurse@hosspi.com` |
| Lab | `lab@hosspi.com` |
| Pharmacy | `pharmacy@hosspi.com` |
| Reception | `reception@hosspi.com` |
| Billing | `billing@hosspi.com` |
| Operations | `operations@hosspi.com` |
| HR | `hr@hosspi.com` |
| Biomedical | `biomed@hosspi.com` |
| Housekeeping | `housekeeping@hosspi.com` |
| Ambulance | `ambulance@hosspi.com` |
| Patient portal | `patient.portal@hosspi.com` |
