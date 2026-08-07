# Major Role-Scoped Home Dashboard Refactor (Pharmacy Pattern Parity)

**Major Home dashboard refactor:** bring every listed demo account’s Home to pharmacy’s quality bar—role-tailored KPIs, deep-links that tally with desk table filters, focused actions/shortcuts, and specialty charts—while keeping the shared shell and live metrics unless a gap requires change. Thin/mid profiles are incomplete deliverables, not optional polish.

## Context

**Current behavior (codebase status; no screenshots attached)**

- **Shared shell:** `RoleDashboardScaffold` (`metrics → next-steps → priority → charts`) in `frontend/lib/shared/dashboard/`. Layout tiers: `home_dashboard_layout.dart`.
- **Profile packs:** `homeDashboardProfiles` + access-policy resolution. Backend: `summary.js` → `dashboard-widget.repository.js` → `dashboard-workspace.service.js`.
- **Pharmacy (benchmark / preserve):** wide KPI strip, `/pharmacy?section=…` deep-links matching desk filters, focused actions, queue off, `PharmacyMostSoldCharts`, cross-domain expansion blocked.
- **Reception (near parity):** `ReceptionDeskCharts`, desk KPIs, queue off—keep peer pattern.
- **Filter tally gap:** Some non-pharmacy metric/chart taps open a workspace without the matching section/queue/table filter, so the desk shows more than the KPI. Counts and destination filters must share predicates.
- **Other roles:** Live KPIs exist; most use generic `DashboardChartsRow` and thinner deep-links. Gaps: lab week/month; nurse vitals/tasks; doctor clinical-notes; ops security/utilities; patient history/radiology KPIs.
- **Scope:** Home for demo accounts in `demo_credentials.dart`—not Reports (`prompts/reporting-analytics.md`).

**Intended behavior**

- Major refactor across the account matrix: each Home reaches pharmacy-parity for that job (KPIs, filter-tallied deep-links, actions/shortcuts, specialty charts where useful, queue layout). Pharmacy stays frozen; reception stays peer. Extend packs/routes/widgets—no new shells.

**Definitions**

- *Pharmacy pattern:* Profile KPIs + permissioned deep-links + shared scaffold + specialty charts + desk-owned worklist + focused actions.
- *Specialty chart:* Period-aware, reloadable, tappable host like `PharmacyMostSoldCharts` / `ReceptionDeskCharts`.
- *Filter tally:* A Home KPI, alert, queue row, or chart segment opens the owning workspace so the visible table uses the same section/queue/status/date predicates as the metric; row set and KPI agree for the same scope.

**Account → profile / maturity**

| Demo account | Profile id | Maturity |
| --- | --- | --- |
| `pharmacy@hosspi.com` | `pharmacist` | Benchmark — freeze |
| `reception@hosspi.com` | `receptionist` | Near parity — keep |
| `lab@hosspi.com` | `lab_tech` | Strong KPIs; emit week/month if computed |
| `billing@hosspi.com` | `billing` | Strong KPIs/actions |
| `doctor@hosspi.com` | `doctor` | Strong clinical |
| `nurse@hosspi.com` | `nurse` | Strong + context; fill gaps when data exists |
| `hr@hosspi.com` | `hr` | Strong workforce |
| `facility.admin@hosspi.com` | `facility_admin` | Broad command strip |
| `operations@hosspi.com` | `operations` | Mid; fill gaps when data exists |
| `super.admin@hosspi.com` | `super_admin` | Platform chrome |
| `tenant.admin@hosspi.com` | `tenant_admin` | Org chrome |
| `biomed@hosspi.com` | `biomed` | Mid / thin |
| `housekeeping@hosspi.com` | `house_keeper` | Task-first / thin |
| `ambulance@hosspi.com` | `ambulance_operator` | Thin |
| `patient.portal@hosspi.com` | `patient` | Thin / safe |

Manager/radiology/mortuary packs outside this list: do not break or expand.

## Requirements

1. **Freeze pharmacy (keep reception peer):** No regression of pharmacist KPIs, deep-links, specialty charts, queue suppression, expansion block, or filter tally. Reception stays unless fixing parity drift.
2. **Tailor each listed profile:** Job-specific labels, KPIs within layout caps, actions, shortcuts, metric routes. Do not clone pharmacy stock/sales KPIs onto unrelated roles.
3. **Tally dashboard ↔ table filters:** Every tappable Home metric (status card, chart segment, priority/queue item) must wire `metricRouteTargets` / chart navigation / workspace `section`·`queue` params so the destination desk applies the filter that produced that count (pharmacy `pending` / `low-stock` pattern). If no desk filter exists, add or map one—do not deep-link to an unfiltered list that contradicts the KPI. Backend pack predicates and workspace list filters must stay equivalent for the same scope.
4. **Reuse shared kit:** Extend scaffold, metric strip, priority panel, chart painters, `home_dashboard_actions.dart`, `home_metric_routes.dart`, profile merge/access filters, and backend packs. Specialty charts only when `DashboardChartsRow` cannot express the desk story.
5. **Close known gaps with real data:** Wire metrics already computed (e.g. lab week/month). Add KPIs only when backend/seed can supply truthful values—never fabricate client numbers.
6. **Pharmacy-parity layout where the desk owns work:** Suppress redundant home queue for desks that own worklists in-module. Clinical/admin may keep priority/alerts when that is the job’s worklist.
7. **Permissions & states:** Atoms permission-gated; unauthorized absent. Loading/empty/error/success for workspace and chart reloads; soft-refresh after Home-affecting mutations. Theme tokens; light/dark; responsive.
8. **Tests:** Profile/layout/access green; matrix resolution, authorized routes, and filter-tally params; pharmacy + reception regression; unauthorized atoms absent.

## Constraints

- Reuse Home + shared dashboard kit. No per-role shells or parallel summary APIs when packs exist.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.
- Out of scope: Reports Overview, manager-only emails, production seeding.
- Optional: deeper specialty charts for admin/HR/patient only if patterns fit.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | `pharmacy@` Home unchanged: KPIs, deep-links, specialty charts, queue off, expansion block, filter tally. | R1 |
| A2 | Each matrix account resolves its profile with job-specific KPIs/actions/shortcuts. | R2 |
| A3 | Tapping a Home KPI/chart/queue item opens the owning desk with the matching table filter; rows tally with the metric for the same scope. | R3 |
| A4 | New UI reuses scaffold/actions/routes/packs; specialty charts only where pharmacy/reception pattern applies. | R4 |
| A5 | Computable gaps emit live values; no fabricated client metrics. | R5 |
| A6 | Desk-owned roles suppress redundant home queue; clinical/admin keep priority when appropriate. | R6 |
| A7 | Unauthorized atoms absent; themes/viewports usable; load/empty/error/success covered. | R7 |
| A8 | Profile/layout/access + route-param tally tests and pharmacy/reception regression pass. | R8 |

## Relevant Files

- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`, `home_dashboard_layout.dart`, `home_dashboard_access.dart`, `home_dashboard_atom_permissions.dart`
- `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart`, `home_dashboard_actions.dart`, `pharmacy_most_sold_charts.dart`, `reception_desk_charts.dart`
- `frontend/lib/shared/dashboard/`
- `backend/src/lib/dashboard/summary.js`, `backend/src/modules/dashboard-widget/`, `dashboard-workspace/`
- Tests: `frontend/test/features/home/`, `backend/src/tests/lib/dashboard/`, `backend/src/tests/modules/dashboard-*`

## Verification

- Unit: matrix profiles; unauthorized atoms filtered; metric/chart taps emit section·queue params matching desk filters.
- Integration: pack predicates align with destination list filters.
- Manual: `pharmacy@`, `reception@`, `lab@`, `doctor@`, `billing@` — KPI taps show the filtered table; pharmacy remains the quality bar.
