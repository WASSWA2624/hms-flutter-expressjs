# Pharmacy Reporting and Analytics

Extend Reporting and Analytics (`/reports`) so pharmacists get deep pharmacy **Analysis**, **Analytics**, and **Reporting**—without a parallel BI product or a pharmacy-only report runner.

## Context

**Current behavior**

- `/reports` (`ReportsWorkspacePage`) exposes Overview, Catalog (definitions), and Delivery (runs + schedules). Pharmacists are tailored to those three panels (`ReportsDomainPack.pharmacy`).
- Overview shows platform infra KPIs (definitions, queued runs, due schedules, pinned widgets), attention queues (e.g. failed runs), activity/queue-mix charts, and pharmacy domain chips.
- Three pharmacy datasets/default defs already exist: `pharmacy_drug_consumption`, `pharmacy_dispense_throughput`, `inventory_stock_risk` (`lib/reports/datasets.js`; `ensureDefaultPharmacyReportDefinitions`).
- Pharmacy deep-links to `/reports?dataset=pharmacy_drug_consumption` when entitled (`canOpenPharmacyReportsAnalytics`).
- Operational pharmacy charts (most-sold, status mix, sales KPIs) live on the **Home** pharmacist dashboard—not Reports Overview.
- Shared run pipeline supports PDF/CSV/JSON/XLSX; Overview soft-refreshes via `RealtimeEventGroups.reports`. Pharmacist packs are often `reports:read` without `reports:write`.

**Intended behavior**

- Present three groups inside pharmacy Reports:
  1. **Analysis** — interactive pharmacy tables/charts with filters and periods.
  2. **Analytics** — insights/projections (consumption leaders, expiry risk, stocking suggestions, revenue/margin when pricing lanes exist).
  3. **Reporting** — create/run/schedule/export pharmacy defs via the **same** definition/run/schedule flow used elsewhere.
- Answer desk questions on stock, dispense, OTC vs clinical, expiry, money, and seasonality; reuse Home/pricing math where it exists; do not leave “near-expiry” copy without runner support.
- Preserve Overview shell, Catalog, Delivery, gates, and formats unless a requirement below changes them.

**Definitions**

- *Analysis:* filtered interactive graphs/tables over pharmacy datasets for a selected period/scope.
- *Analytics:* derived insights (rankings, projections, suggestions)—not raw dumps alone.
- *Reporting:* durable definitions + queued runs + schedules + downloadable artifacts (PDF preferred among existing formats).
- *Pharmacy domain reports:* catalog entries in pharmacy or pharmacy-owned inventory-risk categories.

## Requirements

1. Structure the pharmacist Reports UX into **Analysis**, **Analytics**, and **Reporting** groups (tabs/sections/progressive disclosure) mapped onto existing Overview/Catalog/Delivery—do not invent a second reports module or route family.
2. Keep and deepen Analysis: consumption, dispense throughput, inventory stock risk; add or complete **near/expired stock**, **OTC/walk-in vs clinical/facility split**, and **period/season filters** (date range + prior-period compare when shared filters allow).
3. Deliver Analytics for: top consumed drugs; stock-out risk; common expiry; suggested next stocking focus; revenue/margin outlook when buy/transfer/sell lanes exist (align with pharmacy pricing/Home profit math—no second cost model).
4. Render Analysis/Analytics with graphs and tables via shared dashboard/chart and list-table components; cover loading, empty, error, success; keep prior values visible during soft refresh where the shell already does.
5. Wire Reporting to the existing definition → run → schedule → download pipeline (PDF/CSV/JSON/XLSX). `reports:write` (or admin) may create/update templates, queue runs, manage schedules; read-only users browse defs and entitled artifacts only.
6. Keep Pharmacy → Reports entry and Overview domain chips on **live** dataset keys (no stale `pharmacy_dispenses` product paths).
7. Enforce RBAC/ABAC (`reports:read`/`write`, `evidence:export`, `pharmacy:read`, plus inventory/operations where stock-risk needs them); unauthorized UI must not render. Soft-refresh Overview and pharmacy Analysis data without blanking the workspace.
8. Responsive (mobile/tablet/desktop), theme tokens, light/dark, and visible feedback for permission, loading, empty, error, success, validation.
9. Tests: runners for new/fixed pharmacy lenses; unauthorized UI absent; pharmacist grouping visible; Reporting reuses shared APIs; `?dataset=` opens the correct pharmacy def; soft-refresh does not blank-remount the shell.

## Constraints

- Reuse `reports-workspace`, `report-definition`, `report-run`, `report-schedule`, `lib/reports/*`, FE Reports page/controller/overview mapper, and shared charts/tables—no parallel pharmacy reporting stack or PDF path outside existing exporters.
- Do not remove Home pharmacist KPIs/charts; Reports complements Home.
- Do not grant pharmacists platform admin panels (Dashboards/Monitor/Activity) unless policy already does.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`. Prefer extending datasets/runners over unbounded ad-hoc queries.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Pharmacist `/reports` shows Analysis, Analytics, and Reporting groups without a separate reports app. | R1 |
| A2 | Analysis covers consumption, throughput, stock/expiry risk, OTC vs clinical, and period filters with charts/tables. | R2, R4, R8 |
| A3 | Analytics shows consumption leaders, stock-out/expiry insights, stocking suggestions, and margin/revenue when cost lanes exist. | R3, R4 |
| A4 | Reporting creates/runs/schedules/downloads pharmacy defs via the shared pipeline; unauthorized write/export chrome absent. | R5, R7 |
| A5 | Pharmacy entry and Overview chips use live dataset keys; soft-refresh updates values without blank remount. | R6, R7 |
| A6 | Tests/manual checks cover runners, permissions, grouping, deep-link, viewports, and themes. | R8, R9 |

## Relevant Files

- `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_overview_dashboard.dart`, `reports_overview_mapper.dart`
- `frontend/lib/features/reports/presentation/reports_role_tailoring.dart`, `reports_access.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`
- `frontend/lib/features/home/presentation/widgets/pharmacy_most_sold_charts.dart`
- `backend/src/modules/reports-workspace/`, `report-definition/`, `report-run/`, `report-schedule/`
- `backend/src/lib/reports/constants.js`, `datasets.js`, `runtime.js`
- Tests: `backend/src/tests/lib/reports/datasets.pharmacy.test.js`; FE reports overview/access tests

## Verification

- BE: pharmacy runners return correct series for consumption, throughput, stock/expiry risk, OTC vs clinical; unauthorized category denied.
- FE: Analysis/Analytics/Reporting grouping; chips and `?dataset=` open live pharmacy defs; write/export gates; soft-refresh keeps shell; light/dark + narrow usable.
- Manual: Pharmacy → Reports → Analysis chart/table → Analytics insights → run/schedule pharmacy PDF/CSV → Delivery/Overview update without full-page blank reload.
