# Role-Scoped Home Dashboards (Pharmacy Pattern Parity)

Bring every listed demo account’s Home dashboard to pharmacy’s quality bar—role-tailored KPIs, permissioned deep-links, focused actions/shortcuts, and interactive domain charts—while keeping the shared shell, profile packs, and live metrics unless a gap requires change.

## Context

**Current behavior (codebase status; no screenshots attached)**

- **Shared shell:** Home renders `RoleDashboardScaffold` (`metrics → next-steps → priority → charts`) via `frontend/lib/shared/dashboard/`. Layout tiers: `home_dashboard_layout.dart`.
- **Profile packs:** `homeDashboardProfiles` + `homeProfileForAccessPolicy` / `expandHomeProfileForPermissions`. Backend: `summary.js` → `dashboard-widget.repository.js` → `dashboard-workspace.service.js`.
- **Pharmacy (benchmark / preserve):** `pharmacist` — wide KPI strip, `/pharmacy?section=…` deep-links that apply the same desk/table filters the KPI counts, focused actions, shortcuts, home queue off, `PharmacyMostSoldCharts`, cross-domain expansion blocked.
- **Reception (near parity):** `ReceptionDeskCharts`, desk KPIs, queue off. Peer pattern—do not diverge.
- **Filter tally gap:** Some non-pharmacy profiles declare `metricRouteTargets` or chart taps that open a workspace without selecting the matching table/section/queue filter, so the desk shows a broader set than the KPI. Counts and destination filters must use the same predicates.
- **Other listed roles:** Profiles and many live KPIs exist; most use generic `DashboardChartsRow`, thinner deep-links, and still show the home queue. Gaps: lab week/month cards computed but not emitted; nurse vitals/tasks; doctor clinical-notes KPI; ops security/utilities; patient history/radiology KPIs.
- **Demo accounts:** `demo_credentials.dart` / seed catalog. Scope is Home only—not Reports (`prompts/reporting-analytics.md`).

**Intended behavior**

- Each account gets a job-specific Home: domain KPIs with routes into the owning workspace that apply the matching table filters, role-appropriate actions/shortcuts, specialty charts where the desk has a clear analytic story, and pharmacy-parity layout (suppress redundant home queue when the module desk owns the worklist).
- Extend packs, mappers, metric routes, and shared widgets—no new shells.

**Definitions**

- *Pharmacy pattern:* Profile KPI catalog + permissioned deep-links + `RoleDashboardScaffold` + interactive specialty charts + desk-owned worklist + focused shortcuts/actions.
- *Specialty chart:* Period-aware, reloadable, tappable host like `PharmacyMostSoldCharts` / `ReceptionDeskCharts`.
- *Filter tally:* A Home KPI, alert, queue row, or chart segment opens (or filters) the owning workspace so the visible table uses the same section/queue/status/date predicates as the metric; row count and KPI value agree for the same scope.

**Account → profile / maturity**

| Demo account | Profile id | Maturity |
| --- | --- | --- |
| `pharmacy@hosspi.com` | `pharmacist` | Benchmark — freeze |
| `reception@hosspi.com` | `receptionist` | Near parity — keep |
| `lab@hosspi.com` | `lab_tech` | Strong KPIs; weak charts; emit week/month if computed |
| `billing@hosspi.com` | `billing` | Strong KPIs/actions; generic charts |
| `doctor@hosspi.com` | `doctor` | Strong clinical; generic charts |
| `nurse@hosspi.com` | `nurse` | Strong + context; fill KPI gaps when data exists |
| `hr@hosspi.com` | `hr` | Strong workforce |
| `facility.admin@hosspi.com` | `facility_admin` | Broad command strip |
| `operations@hosspi.com` | `operations` | Mid; fill gaps when data exists |
| `super.admin@hosspi.com` | `super_admin` | Platform chrome |
| `tenant.admin@hosspi.com` | `tenant_admin` | Org chrome |
| `biomed@hosspi.com` | `biomed` | Mid / thin |
| `housekeeping@hosspi.com` | `house_keeper` | Task-first / thin |
| `ambulance@hosspi.com` | `ambulance_operator` | Thin |
| `patient.portal@hosspi.com` | `patient` | Thin / safe |

Manager/radiology/mortuary packs outside this list: do not break; do not expand scope to them.

## Requirements

1. **Freeze pharmacy (keep reception peer):** No regression of pharmacist KPIs, deep-links, specialty charts, queue suppression, or expansion block. Reception stays unless fixing parity drift.
2. **Tailor each listed profile:** Job-specific labels, KPI set within layout caps, actions, shortcuts, metric routes. Do not clone pharmacy stock/sales KPIs onto unrelated roles.
3. **Tally dashboard ↔ table filters:** For every tappable Home metric (status card, chart segment, priority/queue item), wire `metricRouteTargets` / chart navigation / workspace `section`·`queue` query params so the destination desk applies the filter that produced that count. Prefer existing workspace section ids (pharmacy `pending` / `low-stock` pattern). If no desk filter exists, add or map one—do not deep-link to an unfiltered list that contradicts the KPI. Backend pack predicates and workspace list filters must stay equivalent for the same scope.
4. **Reuse shared kit:** Extend scaffold, metric strip, priority panel, chart painters, `home_dashboard_actions.dart`, `home_metric_routes.dart`, profile merge/access filters, and backend packs. Add specialty charts only when `DashboardChartsRow` cannot express the desk story.
5. **Close known gaps with real data:** Wire metrics already computed (e.g. lab week/month). Add KPIs only when backend/seed can supply truthful values—never fabricate client numbers.
6. **Pharmacy-parity layout where the desk owns work:** Suppress redundant home queue for department/task desks that own worklists in-module. Clinical/admin may keep priority/alerts when that is the job’s worklist.
7. **Permissions & states:** Atoms stay permission-gated; unauthorized absent (not disabled). Loading/empty/error/success for workspace and chart reloads; soft-refresh after Home-affecting mutations. Theme tokens; light/dark; responsive.
8. **Tests:** Keep profile/layout/access tests green; cover matrix profile resolution, authorized KPIs/routes, and filter-tally route params; pharmacy + reception regression; unauthorized atoms absent.

## Constraints

- Reuse Home + shared dashboard architecture. No per-role page shells or parallel summary APIs when packs exist.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.
- Out of scope: Reports Overview (`prompts/reporting-analytics.md`), new manager-only emails, production seeding.
- Optional: deeper specialty charts for admin/HR/patient only if a clear interactive desk story fits shared patterns.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | `pharmacy@` Home unchanged: KPI strip, deep-links, specialty charts, queue off, expansion block. | R1 |
| A2 | Each matrix account resolves its profile with job-specific KPIs/actions/shortcuts (not a generic clone). | R2 |
| A3 | Tapping a Home KPI/chart/queue item opens the owning desk with the matching table filter; visible rows tally with the metric for the same scope. | R3 |
| A4 | New UI reuses scaffold/actions/routes/packs; specialty charts only where pharmacy/reception pattern applies. | R4 |
| A5 | Computable gaps (e.g. lab week/month) emit live values; no fabricated client metrics. | R5 |
| A6 | Desk-owned roles suppress redundant home queue; clinical/admin keep priority when appropriate. | R6 |
| A7 | Unauthorized atoms absent; themes/viewports usable; load/empty/error/success covered. | R7 |
| A8 | Profile/layout/access + route-param tally tests and pharmacy/reception regression pass for the matrix. | R8 |

## Relevant Files

- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`, `home_dashboard_layout.dart`, `home_dashboard_access.dart`, `home_dashboard_atom_permissions.dart`, `home_dashboard_guided_content.dart`
- `frontend/lib/features/home/presentation/pages/home_page.dart`, `widgets/home_dashboard_mapper.dart`, `home_dashboard_actions.dart`, `home_metric_routes.dart`, `pharmacy_most_sold_charts.dart`, `reception_desk_charts.dart`
- `frontend/lib/shared/dashboard/`
- `backend/src/lib/dashboard/summary.js`, `backend/src/modules/dashboard-widget/`, `backend/src/modules/dashboard-workspace/`
- Tests: `frontend/test/features/home/`, `backend/src/tests/lib/dashboard/`, `backend/src/tests/modules/dashboard-*`

## Verification

- Unit: profile resolution per matrix role; pharmacy/reception layout flags; unauthorized atoms filtered; `metricRouteTargets` / chart taps emit section·queue params that match desk filters.
- Integration: workspace summary card ids and pack predicates align with destination list filters for packs touched.
- Manual: `pharmacy@`, `reception@`, `lab@`, `doctor@`, `billing@`, `facility.admin@`, `patient.portal@` — Home matches the job; each KPI tap shows the filtered table that explains the count; pharmacy remains the quality bar; no cross-role KPI cloning.
