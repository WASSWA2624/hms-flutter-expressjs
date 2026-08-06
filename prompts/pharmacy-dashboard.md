# Pharmacy Dashboard: Summary Cards Clarity, Sales KPIs, and Deep-Links

Make the pharmacist home **summary metric strip** clear, facility-scoped, and clickable into the exact `/pharmacy` desk tab (and filters) that explain each number—without changing Quick actions, most-sold charts, or order-status mix beyond what the cards require.

## Context

**Current behavior (screenshot + codebase)**

- Pharmacist strip: **Orders**, **Pending**, **Dispensed**, **Low stock**. Backend already computes facility-scoped `ordersToday`, `pendingDispense` (ORDERED + PARTIALLY_DISPENSED), `dispensedToday`, and `lowStock` in the pharmacist pack.
- Labels omit period (“Orders” / “Dispensed”), so zeros look broken when “today” is empty. Demo often shows Orders/Dispensed/Low stock at **0** while Pending ~500 and status mix ~1K—seed/window mismatch or missing reseed.
- Metric routes are wrong/vague: order cards → `section=orders` (not a desk section); low stock → `section=inventory` (should be `low-stock`). Desk sections include `queue`, `in-progress`, `completed`, `all`, `low-stock`; order list API already supports `from`/`to` on `ordered_at`.
- No **Total sales today** / **Total sales this week**. `maxStatusCards` is 4 (cap 6).

**Intended behavior**

- Labels state period where needed (**Orders today**, **Dispensed today**). Pending = open dispense workload (not today-only). Low stock = current facility at/below reorder.
- Add **Total sales today** and **Total sales this week** (facility money totals; gate with pricing/billing/`reports:read`).
- Each card opens `/pharmacy` on the matching desk section **and** filters matching the KPI. Facility-scoped to the logged-in facility. Demo non-zeros when data exists.
- **Only** the summary strip—no Quick actions / most-sold / status-mix redesign.

**Definitions**

- *Orders today*: facility `pharmacy_order` with `ordered_at` in facility-local today.
- *Pending*: facility orders in `ORDERED` or `PARTIALLY_DISPENSED`.
- *Dispensed today*: facility `dispense_log` `DISPENSED` with `dispensed_at` today.
- *Low stock*: facility rows at/below reorder (existing `countLowStock` factor 1).
- *Total sales today / this week*: facility sum of pharmacy sale amounts for today or trailing week (document Mon–today vs last 7 days in labels). Prefer completed dispenses × unit price (most-sold amount basis); no invented COGS.
- *Deep-link*: `/pharmacy?section=…` plus `from`/`to` (and status as needed) so the opened table matches the card.

## Requirements

1. Clarify pharmacist strip labels: Orders today; Pending (or Pending dispense); Dispensed today; Low stock—aligned with backend metrics above.
2. Add Total sales today and Total sales this week (currency) to the pharmacist strip. Compute in the pharmacist pack; gate with money permissions. Keep ops cards first; `maxStatusCards` ≤ 6.
3. Wire deep-links to correct `/pharmacy` sections + filters:
   - Orders today → all-orders (or equivalent) with today’s `ordered_at` range.
   - Pending → queue and/or in-progress covering pending workload (not `section=orders`).
   - Dispensed today → completed with today’s range as the table supports.
   - Low stock → `section=low-stock`.
   - Sales today/week → completed (or sales desk if present) with matching range; unauthorized money cards absent.
4. Extend `PharmacyWorkspaceQuery` / desk hydration to honor deep-link `from`/`to` (and needed status). Reuse backend list date filters.
5. Keep all metrics facility-scoped to the session facility.
6. Align demo seed/verify so today/stock/sales KPIs are non-zero when volume seed is on.
7. Preserve Quick actions and charts. Cover loading, legitimate empty zero, error, permission absence. Responsive; theme tokens; light/dark.
8. Tests: labels/ids; sales permission presence/absence; card route queries; workspace from/to; facility scope; seed/fixture non-zeros.

## Constraints

- Change **only** pharmacist summary cards, aggregation, labels, routes, and minimal pharmacy query wiring for deep-links.
- Reuse home metric strip, pharmacist profile, dashboard summary, `/pharmacy` sections, existing date-range filters—no parallel KPI stack.
- Backend RBAC authoritative; unauthorized UI absent.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/demo-data.mdc` (if seeding), `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Labels make today vs open-pending vs stock unambiguous. | R1 |
| A2 | Authorized users see sales today/week; unauthorized money cards absent. | R2, R7 |
| A3 | Each card opens matching `/pharmacy` section + filters. | R3–R4 |
| A4 | Metrics facility-scoped to the logged-in facility. | R5 |
| A5 | Demo shows non-zero today/stock/sales when data exists. | R6 |
| A6 | Quick actions and charts unchanged. | R7 |
| A7 | Tests cover labels, permissions, deep-links, and scope. | R8 |

## Relevant Files

- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`
- `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart`, metric strip/mapper
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`; `pharmacy_workspace_page.dart`
- `backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js`
- `backend/src/lib/dashboard/summary.js`; pharmacy-workspace list `from`/`to`
- Demo seeders/verify; profile route + workspace query + summary tests

## Verification

- Backend: today/pending/dispensed/low-stock/sales aggregates facility-scoped; week rule documented.
- Flutter: labels; taps land on correct section + filters; money cards gated; strip ≤6.
- Manual pharmacist: each card’s table matches KPI; reseed if demo zeros persist. Light/dark; narrow viewport.
