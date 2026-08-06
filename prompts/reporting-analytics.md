# Reporting and Analytics: Role-Tailored Workspace and Overview Dashboard

Rename `/reports` to **Reporting and Analytics**, make **Overview** a true reports/analytics dashboard (default tab), and give each staff role account tailored tabs and content for creating reports and viewing analytics—without weakening create/run/export/compliance or inventing a parallel stack.

## Context

**Current behavior**

- Shell label is **Reports**; workspace title is **Reports and audit** (`reportsTitle`). Route stays `/reports`; feature module code is already `reporting-analytics`.
- Workspace panels are infrastructure-shaped: Overview, Catalog, Runs and delivery, Dashboards, KPI monitor, Analytics activity, plus compliance (Audit / PHI / Processing). Overview is the default panel but renders the **same worklist table** as other catalog panels—not a dashboard.
- Backend overview returns `summary`, `queue_summaries`, `panel_summaries`, and related workload signals; Flutter parses them into entities but **does not surface** them as Overview dashboard chrome.
- Panel gating is binary (`reports:read` vs `compliance:read`); every entitled user sees the same non-compliance panel set. Dataset catalog spans patients, appointments, billing, pharmacy, inventory, HR, biomedical, communications, but is **not** role-curated into tailored tabs.
- Create/run/schedule, print/export (`evidence:export`), deep link `?dataset=`, and Home charts (`reports:read`) already exist. Domain analytics also live elsewhere (e.g. Billing financial panel, pharmacy home charts).

**Intended behavior**

- Entitled users open a workspace clearly named **Reporting and Analytics** (nav + title), specialized for **creating reports** and **viewing analytics**.
- **Overview** is the default tab and reads as a **Reports and Analytics dashboard** (KPIs, charts/shortcuts, progressive disclosure)—not a duplicate flat worklist.
- **For each staff role account**, tabs and tab content are **tailored** to that role’s domain (finance for accountant/billing, pharmacy for pharmacist, reception/ops for receptionist, clinical/ops for clinical roles, etc.), aligned with `default_user_roles.mdc` reporting scope and existing dataset categories / module permissions.
- Existing create/run/schedule/export/compliance and deep links remain; unauthorized chrome stays absent.

**Definitions**

- *Reporting and Analytics workspace*: `/reports` (`ReportsWorkspacePage` / reports-workspace APIs)—same route, renamed product surface.
- *Role account*: a staff role (or equivalent custom role) with `reports:read` (and compliance panels only when `compliance:read` / review). Tailoring follows effective permissions and active modules, not hard-coded single-role UI forks when multi-role.
- *Overview dashboard*: default Overview tab showing facility-scoped analytics summary (reuse overview summary/queue data and shared `DashboardChartsRow` / widget patterns), plus clear paths to create/run reports relevant to the user—distinct from Catalog/Delivery worklists.
- *Tailored tabs*: the visible panel set and primary datasets/analytics on those panels, curated for the user’s role domain; infra panels (Catalog, Delivery, Dashboards, Monitor, Activity) may remain when useful, reordered or filtered—not dumped identically for every role.
- *Create report*: save/run a definition against an allowed dataset via existing Reports APIs/permissions.

## Requirements

1. Rename user-facing chrome to **Reporting and Analytics** (at least `navigationReportsLabel` / short label and `reportsTitle`; update related loading/empty copy that still says only “Reports and audit” where it would contradict the rename). Keep path `/reports` and deep links stable unless a redirect is required.
2. Make **Overview** the default tab and implement it as a **dashboard**: surface backend overview summary/queue (and available chart/KPI signals) with progressive disclosure; primary CTA path to create/run reports. Do not leave Overview as a worklist-only clone of Catalog/Delivery.
3. For each staff role account with Reports access, show **tailored tabs and content** (datasets, analytics emphasis, optional panel presence/order) matching that role’s reporting domain and module permissions. Multi-role users see the union of allowed tailored content; still permission-gated.
4. Preserve Catalog, Delivery, Dashboards, Monitor, Activity, schedule/timeline, and create/run/schedule/retry/cancel/print/export for entitled users; omit panels the user cannot use (absence, not disabled stubs). Keep compliance panels behind existing compliance grants.
5. Prefer reuse: `reports_access`, reports-workspace APIs, `REPORT_DATASETS` categories, Home/`DashboardChartsRow` patterns, and existing Billing/Pharmacy analytics deep links—do not build a second reporting product. Overview may deep-link or pre-filter to domain datasets already used by those modules.
6. Cover loading, empty, error/retry, success, and validation on Overview and tailored panels. Responsive; theme tokens; light/dark. Unauthorized UI absent; backend authoritative.
7. Update tests for rename strings where asserted, Overview-as-dashboard presence, role-tailored panel/dataset visibility (authorized present / unauthorized absent), and regression of create/run/export/compliance. Reuse design-system and Reports components.

## Constraints

- Reuse `frontend/lib/features/reports/`, `backend/src/modules/reports-workspace/`, `backend/src/lib/reports/`—no parallel analytics stack.
- Do not remove operational create/run/export or compliance for users who already have them unless a panel is intentionally out of role scope.
- No unrelated Home/Billing/Pharmacy refactors beyond deep-link or shared-chart reuse needed for Overview/tailoring.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/default_user_roles.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Nav and workspace title read Reporting and Analytics; `/reports` still opens the workspace. | R1 |
| A2 | First open lands on Overview as a dashboard (KPIs/charts/shortcuts), not worklist-only. | R2 |
| A3 | Distinct role accounts see tailored tabs/content for their domain; unauthorized panels/datasets absent. | R3–R4 |
| A4 | Entitled users can still create/run/export; compliance panels only with compliance grants. | R4–R5 |
| A5 | Loading/empty/error/validation handled; responsive light/dark. | R6 |
| A6 | Tests cover rename, Overview dashboard, role tailoring, and authorized create/run paths. | R7 |

## Relevant Files

- `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart`, `reports_access.dart`, `controllers/reports_workspace_controller.dart`, `domain/entities/reports_entities.dart`
- `frontend/lib/l10n/app_en.arb` (`reportsTitle`, `navigationReportsLabel`); `frontend/lib/app/router/app_router.dart`
- `frontend/lib/shared/dashboard/dashboard_charts_row.dart`; Home chart mappers as reuse reference
- `backend/src/modules/reports-workspace/services/reports-workspace.service.js`; `backend/src/lib/reports/constants.js`, `datasets.js`
- Tests: `reports_workspace_*`, `reports_access_test.dart`, related permission/UI tests

## Verification

- Flutter: Overview dashboard default; rename visible; role A vs role B tab/dataset differences; create/run still works; unauthorized chrome absent.
- Backend: overview summary still drives dashboard; dataset access remains permission/scope safe.
- Manual: accountant vs pharmacist vs receptionist (each with `reports:read`) — tailored tabs; Overview dashboard; create/run one domain report. Light/dark and narrow viewports.
