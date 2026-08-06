# Pharmacy Dashboard: KPIs, Most-Sold Analytics, and Status Navigation

Refine the pharmacist home dashboard so KPIs and charts reflect real pharmacy workload, most-sold analytics are controllable, and order-status segments deep-link into filtered pharmacy tables—without removing Quick actions or breaking pharmacy / Reports flows.

## Context

**Current behavior**

- Pharmacist profile defines four KPIs: `orders_today`, `pending_dispense`, `dispensed_today`, `low_stock`. `expandHomeProfileForPermissions` can raise the strip to six and surface cross-domain cards (Admissions, Appointments) when the session also grants `patient:read`—visible in current screenshots.
- Demo/volume seed often leaves **today** metrics empty (Orders / Dispensed / Low stock at 0) while Pending is high. `aggregateMostSoldDrugs` (trailing ~30 days, limit 8) often returns empty; `PharmacyMostSoldCharts` falls back to the 7-day dispense trend, showing a flat zero line under “Most sold drugs (last month).”
- Qty / Amount (/ Profit) uses a standalone `SegmentedButton` above the charts—not in the most-sold header. Order status mix is display-only. `/pharmacy` already maps status desks via query (`queue`, `in-progress`, `completed`, `cancelled`). Quick actions remain; keep them.

**Intended behavior**

- Pharmacist home shows a **pharmacy-only** KPI strip (no Admissions / Appointments). Seeded data makes Orders, Pending, Dispensed, and Low stock confirmable.
- Most sold: period, top-N, and chart-type controls; Qty/Amount(/Profit) in that section header as a borderless checkbox-like toggle. Default **bar** chart of top drugs; optional line. Real ranked drugs when dispenses exist—not a mislabeled zero date-trend.
- Order status mix segments/legend open `/pharmacy` filtered to that status.
- Add a companion **sold-drugs list** for the same period (ranked table/list).
- Preserve Quick actions, pharmacy KPI routing, money gating, and other role dashboards.

**Definitions**

- *Pharmacy KPI strip*: the four pharmacist cards; excludes cross-domain clinical KPIs on pharmacist home.
- *Most-sold period*: Today, Last week, Last month, Last 3 months, Last 6 months, Last year, Last 5 years (facility timezone per existing dashboard helpers).
- *Top-N*: 5, 10, 20, 100 (default near current backend ~8).
- *Chart type*: bar (default) or line (X = drug; Y = active metric).
- *Checkbox-like metric toggle*: selected like a check—**no** border, fill, or segmented track; theme tokens only.
- *Status deep-link*: `ORDERED`→queue/ready, `PARTIALLY_DISPENSED`→in-progress, `DISPENSED`→completed, `CANCELLED`→cancelled.
- *Sold-drugs list*: ranked drugs + metric values for the same period/top-N/metric as the chart.

## Requirements

1. On pharmacist department dashboard, omit Admissions/Appointments (and other non-pharmacy cross-domain cards) from the metric strip. Keep the four pharmacy KPIs; do not turn pharmacist home into a clinical command center.
2. Align seed/verify (and/or summary windows) so demo facilities show non-empty pharmacy KPIs and most-sold series when dispenses/stock exist—not all zeros beside Pending.
3. In the most-sold section header: period dropdown, top-N selector, chart-type (bar | line), and relocated Qty/Amount(/Profit) as checkbox-like (no border/background). Gate Amount/Profit with existing pricing/billing/`reports:read`; Profit only when cost data exists.
4. Load ranked drugs for selected period and top-N from facility-scoped completed dispenses. If empty, show an explicit empty state—do not substitute a zero date trend under the most-sold title. Default bar; optional line.
5. Add one companion sold-drugs list for the same period/top-N/metric. Progressive disclosure allowed; same chart permissions.
6. Make order-status mix segments and legend activatable; navigate to the matching `/pharmacy` desk section. Unauthorized pharmacy chrome absent.
7. Preserve Quick actions and existing pharmacy KPI deep-links. Cover loading, empty, error/retry. Responsive; theme tokens; light/dark.
8. Tests: strip excludes admissions/appointments; period/top-N/chart-type/header toggle; empty most-sold behavior; status→section deep-links; fixtures/seed for non-empty most-sold; unauthorized money metrics absent.

## Constraints

- Reuse `PharmacyMostSoldCharts`, shared dashboard charts, `aggregateMostSoldDrugs` / summary, pharmacist profile + metric routes, and `/pharmacy` section queries—no parallel stack.
- Do not remove Quick actions. Backend RBAC authoritative; unauthorized UI absent.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/demo-data.mdc` (if seeding), `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Pharmacist strip has no Admissions/Appointments; pharmacy KPIs remain. | R1 |
| A2 | Demo facility shows meaningful non-zero KPIs and most-sold when data exists. | R2, R4 |
| A3 | Most-sold header hosts period, top-N, chart type, and borderless metric toggle. | R3 |
| A4 | Bar/line shows top drugs; empty state when no sales—no mislabeled zero date line. | R4 |
| A5 | Sold-drugs list matches period/top-N/metric. | R5 |
| A6 | Status segment/legend opens the matching pharmacy table. | R6 |
| A7 | Quick actions present; money metrics gated; unauthorized chrome absent. | R3, R7 |
| A8 | Tests cover strip, controls, empty behavior, deep-links, permissions. | R8 |

## Relevant Files

- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`, layout + expand-profile helpers
- `frontend/lib/features/home/presentation/widgets/pharmacy_most_sold_charts.dart`, `home_dashboard_mapper.dart`, `home_metric_routes.dart`, `home_page.dart`
- `frontend/lib/shared/dashboard/dashboard_charts_row.dart`, `dashboard_models.dart`
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- `backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js`; `backend/src/lib/dashboard/summary.js`; demo seeders / verify as needed
- Tests: `pharmacy_most_sold_charts_test.dart`, `home_dashboard_layout_test.dart`, summary/seed verify

## Verification

- Backend: most-sold respects period + limit; demo seed populates pharmacist metrics; status counts feed the donut.
- Flutter: pharmacy-only strip; header controls; bar/line + list; empty vs data; segment taps → correct `/pharmacy` section; Amount/Profit absent without grants.
- Manual pharmacist home: confirm KPIs, switch period/top-N/chart type, open status tables, keep Quick actions. Light/dark and narrow viewport.
