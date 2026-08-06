# Pharmacy Dashboard: Most-Sold Section Layout, Defaults, and Custom Period

Redesign the pharmacist **Most sold drugs** block so its filters sit cleanly in a shared collapsible section (actions below chart + sold-drugs list), with clearer defaults, line/bar charts, quantity-first metrics, and a custom date-range option—without changing summary cards, Quick actions, or order-status mix behavior beyond what this section needs.

## Context

**Current behavior (codebase)**

- Most-sold UI: `PharmacyMostSoldCharts` → `DashboardChartsRow` / `AppSectionPanel` with period, top-N, chart type, and quantity/amount(profit) controls in `headerTrailing` (`_MostSoldHeaderControls`). A sold-drugs list is already a `footer` under the chart.
- Controls wrap awkwardly in the header on narrow widths; selects are ad-hoc `_HeaderDropdown`s, not the shared collapsible section action slot.
- Defaults today: period **last month**, top **10**, chart **bar**, metric **qty**. Backend `buildDashboardSummary` / `resolveMostSoldWindow` / `normalizeMostSoldLimit` default to `last_month` and `10`.
- Periods: `HomeMostSoldPeriod` presets only (today → last 5 years). No **custom** from/to window for most-sold aggregation.
- Shared chrome: `AppCollapsibleSection` already supports `headerActions` (header) and `actions` (body), but **`actions` render above `child`**, not below the content/table.

**Intended behavior**

- Globally: collapsible section optional **action** controls appear **below** the section body (after chart/table content), while `headerActions` stay in the header. Existing call sites keep working aside from that actions placement.
- Most sold: host the block in that collapsible section; move period, top-N, chart type, and metric controls into the section **actions** area under the chart and sold-drugs list so they align cleanly on all breakpoints.
- Defaults: period **Today**, top **5**, chart **line** (bar still available), metric **Quantity**. Unauthorized money metrics remain absent.
- Period includes a **Custom** option that collects from/to and reloads most-sold for that window. Preset periods keep working. Selects are polished and responsive.

**Definitions**

- *Most sold drugs*: ranked dispensed-drug series (qty / amount / profit when allowed) for the selected window and top-N.
- *Section actions*: optional controls in `AppCollapsibleSection.actions`, placed after the body content.
- *Custom period*: user-chosen inclusive or exclusive date range (`from`/`to`) scoped to the facility, not a preset key.
- *Top-N*: allowed set remains `5 | 10 | 20 | 100` unless product already constrains otherwise.

## Requirements

1. Update `AppCollapsibleSection` so `actions` render **below** `child` (and description stays readable—prefer description above child, actions after child). Keep `headerActions` in the header. Do not break non-pharmacy section usages beyond the intentional actions reorder.
2. Rebuild Most sold drugs with that collapsible section: title/subtitle for the series; chart + sold-drugs list in the body; period, top-N, chart type, and metric controls as section actions under the list—not in the chart header trailing.
3. Set defaults to **Today**, **Top 5**, **Line**, **Quantity**. Align initial client state and backend summary defaults (`most_sold_period` / `most_sold_limit`) so first paint matches without an extra round-trip when possible.
4. Keep bar chart support; default chart style is line. Metric radios/toggles: Quantity default; Amount/Profit only when pricing/billing/`reports:read` (and profit data) allow—unauthorized controls absent.
5. Add **Custom** period: UI to pick from/to; pass range to dashboard most-sold load; extend backend aggregation to honor custom from/to (facility-scoped). Presets continue via `most_sold_period`.
6. Restyle period/top-N/chart selects for readable, consistent layout on mobile, tablet, and desktop (theme tokens; no overflow/clip of controls).
7. Preserve loading, empty (“no sales in period”), and error refresh states; money metrics gated; light/dark. Do not redesign status-mix, summary strip, or Quick actions.

## Constraints

- Scope: `AppCollapsibleSection` actions placement + pharmacist most-sold section/controls/defaults/custom range (+ minimal API/query for custom window).
- Reuse existing most-sold aggregation, dashboard request/query params, chart painters, sold-drugs list, and permissions—no parallel analytics stack.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Collapsible section `actions` appear below body content globally. | R1 |
| A2 | Most-sold filters sit under chart + sold list, not cramped in the header. | R2, R6 |
| A3 | First load defaults: Today, Top 5, Line, Quantity (money metrics gated). | R3, R4 |
| A4 | User can switch bar/line and presets; Custom from/to refreshes ranked drugs. | R4, R5 |
| A5 | Loading/empty/error and unauthorized money controls behave correctly; other dashboard sections unchanged. | R7 |

## Relevant Files

- `frontend/lib/shared/components/app_collapsible_section.dart`
- `frontend/lib/features/home/presentation/widgets/pharmacy_most_sold_charts.dart`
- `frontend/lib/shared/dashboard/dashboard_charts_row.dart`, `dashboard_models.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard.dart` (periods / request)
- `backend/src/lib/dashboard/summary.js`; `dashboard-widget.repository.js` / schema (`most_sold_*`, custom from/to)
- Tests: collapsible actions order; most-sold defaults; custom range query; money metric gating

## Verification

- Widget tests: section actions below child; most-sold defaults; line/bar toggle; custom range triggers reload params.
- Backend: custom from/to facility-scoped; preset windows unchanged; default period/limit today/5.
- Manual pharmacist: filters readable on narrow/wide; light/dark; empty and loading; Amount absent without money permission.
