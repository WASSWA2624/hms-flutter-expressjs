# Pharmacy Reporting: Staff & User Activity Dialogs and Demo Seed

Implement Staff & User Activity report dialogs from actor-attributed pharmacy actions with count/money units and demo multi-user coverage.

## Context

**Current behavior**

- Category `staff_activity` has 10 reports; all unavailable.
- Dispense/sales/adjustment/audit rows already store acting user ids in operational tables and audit logs; Reporting does not yet aggregate by staff.

**Intended behavior**

- Dialogs break down sales, dispensing, purchases entered, adjustments, refunds, discounts authorized, voids, login/activity, productivity, and audit trail by staff for the selected period.

**Definitions**

- *Staff slice:* Aggregation keyed by user/staff display name + id.
- *Report ids:* `sales_by_staff`, `dispensing_by_staff`, `purchases_entered_by_staff`, `stock_adjustments_by_staff`, `refunds_by_staff`, `discounts_authorized`, `voided_transactions`, `login_activity_history`, `user_productivity`, `audit_trail`.

## Requirements

1. Dataset + projections for every staff report id; `user_productivity` chart; others table.
2. Units: sales/refund/discount amounts → currency; dispense/adjustment qty → quantity; event/login counts → count; productivity rates → percent where applicable.
3. Period scopes activity; empty when no attributed events; never invent staff rows without FK users.
4. Seed multiple demo pharmacist/cashier users performing distinct sales, dispenses, adjustments, refunds, voids, and discount authorizations inside the demo window.
5. Reuse audit/user activity sources and shared reporting kit; do not build a separate HR console.
6. Gate with reports read; omit privileged audit fields without entitlement; responsive; light/dark.
7. Tests: multi-staff seed; unit formatting; unauthorized audit fields absent.

## Constraints

- Follow `.cursor/access/permissions.mdc` for audit visibility.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 10 staff reports map to ready/empty/error with seed. | R1 |
| A2 | Money/qty/count units correct on staff slices. | R2 |
| A3 | Demo has ≥2 staff with differentiated activity. | R4 |
| A4 | Audit fields permission-safe; shared kit + responsive OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §9
- `pharmacy_reporting_catalog.dart`, data provider
- Audit/user activity modules + seed access pack users
- `backend/src/lib/reports/datasets.js`
- `frontend/lib/shared/reporting/**`

## Verification

- Provider tests for sales_by_staff and audit_trail projections.
- Manual: Staff section → sales by staff, voids, productivity chart; narrow width.
