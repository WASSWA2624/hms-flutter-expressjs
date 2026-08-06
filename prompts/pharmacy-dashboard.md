# Dashboard Summary Cards: Full Labels and Bottom-Aligned Values

Update the shared dashboard **summary metric cards** so every label is fully readable (wrapping when needed) and metric values sit uniformly near the bottom of each card—without changing which KPIs appear, their routing, permissions, or other dashboard sections.

## Context

**Current behavior (codebase)**

- Home and other dashboards render KPIs through `DashboardMetricStrip` → `_DashboardMetricCard` (`frontend/lib/shared/dashboard/dashboard_metric_strip.dart`), fed by mappers such as `homeDashboardMetrics`.
- Labels use `maxLines: 1`, `softWrap: false`, and `TextOverflow.ellipsis`, so longer copy (e.g. **Orders today**, **Total sales (last 7 days)**) truncates with “…” on narrow cards.
- Values sit in an `Expanded` region with `Alignment.centerLeft`, so the number floats mid-card rather than a consistent bottom baseline across the strip.
- Cards use fixed heights (`_compactHeight` / `_regularHeight`). Wide layout is an equal-width `Row`; narrow stacks in a `Column`. Compact mode and icon/chevron chrome are unchanged in intent.

**Intended behavior**

- The full label text is always visible: when the label does not fit one line, wrap to additional line(s) instead of ellipsis (unless a single word still overflows—then allow soft wrap / visible clipping only as a last resort; prefer readable wrap over “…”).
- The metric **value** aligns near the **bottom** of each card, consistently across cards in the same strip (same vertical rhythm regardless of one- vs multi-line labels).
- Change is **global** for this shared strip (home pharmacist and all other roles/pages that use `DashboardMetricStrip`), not a pharmacy-only fork.
- Do **not** alter KPI sets, labels’ wording (except layout), deep-links, Quick actions, charts, or worklists.

**Definitions**

- *Summary card / metric card*: one tile in `DashboardMetricStrip` showing icon, label, and value.
- *Fully visible label*: complete `card.label` string readable without ellipsis truncation under normal strip widths (md+ and stacked compact).
- *Uniform bottom value*: values share a common bottom alignment within the card body (e.g. bottom-start), not vertically centered in leftover space.

## Requirements

1. In `_DashboardMetricCard`, stop ellipsis-truncating labels: allow soft wrap and enough `maxLines` for typical KPI labels (at least 2). Keep hierarchy (label secondary; value emphasis).
2. Pin the value to the bottom of the card content area so all cards in a strip share a uniform value baseline; keep `FittedBox` scale-down for long currency/number strings on one line.
3. Adjust layout/height only as needed so wrapped labels do not clip the value or overflow the card; preserve equal-width wide row and stacked narrow behavior, icon, chevron, tap/semantics, and theme tokens (light/dark).
4. Apply via the shared strip only—no duplicate pharmacy-specific card widget. Leave mappers, permissions, and metric data unchanged unless required for layout.
5. Cover loading/empty (strip still hidden when no cards), authorized/unauthorized (unchanged gating), and responsive widths without clipping actionable chrome.

## Constraints

- Scope is **summary metric card layout** in `DashboardMetricStrip` / `_DashboardMetricCard` (and tests for that widget). No KPI content, routes, backend, or unrelated dashboard redesign.
- Reuse existing `DashboardMetricCardData`, decorations, and home/reports consumers—no parallel card system.
- Follow `.cursor/mandatories.mdc`, `prompts/.cursor/prompt.mdc`. Theme tokens only; supported light/dark; mobile/tablet/desktop.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Long labels (e.g. multi-word sales/period titles) wrap and remain fully readable—no ellipsis for normal wrap cases. | R1 |
| A2 | Values align near the bottom consistently across cards in the strip. | R2 |
| A3 | Wrapped labels do not clip values or break wide/narrow strip layout; taps and semantics still work. | R3, R5 |
| A4 | All dashboards using `DashboardMetricStrip` pick up the change; no pharmacy-only fork. | R4 |
| A5 | Unauthorized/empty strip behavior unchanged; light/dark and narrow viewport OK. | R4, R5 |

## Relevant Files

- `frontend/lib/shared/dashboard/dashboard_metric_strip.dart`
- `frontend/lib/shared/dashboard/dashboard_models.dart`, `dashboard_layout.dart`
- Consumers: `home_page.dart`, `reports_overview_dashboard.dart` (verify only)
- Tests: `home_dashboard_summary_simplify_test.dart` or a focused metric-strip widget test

## Verification

- Widget/golden or layout test: multi-line label visible (no `…`); value bottom-aligned vs sibling cards.
- Manual: pharmacist (and one other role) home strip with long labels; wide and narrow; light/dark; currency values still scale down cleanly.
- Confirm Quick actions / charts untouched; strip still absent when filtered empty.
