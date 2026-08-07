# Pharmacy Reporting: Staff & User Activity — Accurate Actor Mapping

Attribute staff reports only to **real user FKs**—attestation, audit_log, payment/order creators—never invent cashier on `pharmacy_order`.

## Context

**Exists**

- `pharmacy_dispense_attestation.attested_by_user_id`
- `audit_log.user_id` + `action` + `entity` + `diff_json`
- Payments/invoices may store creator via audit or module-specific fields (verify before use)

**Does not exist:** `dispense_log` dispenser user; `pharmacy_order` cashier; `stock_adjustment.user_id`.

**All 10 staff report ids unavailable.** Seed users via access pack; audit volume in extended pack.

## Data contract

| Report id | Actor source | Metrics |
| --- | --- | --- |
| `sales_by_staff` | attestation user joined to dispenses in range **or** audit CREATE on pharmacy sale entities | `staff`, `amount`, `quantity_dispensed` |
| `dispensing_by_staff` | attestation | `staff`, order/pack counts |
| `purchases_entered_by_staff` | audit on PO/goods_receipt CREATE | counts |
| `stock_adjustments_by_staff` | **gap** unless audit entity=`stock_adjustment` | use audit or migrate `adjusted_by_user_id` |
| `refunds_by_staff` | audit/refund creator if present | `amount` |
| `discounts_authorized` | audit on billing_adjustment | `amount`, `staff` |
| `voided_transactions` | CANCELLED orders + audit DELETE/void | counts |
| `login_activity_history` | `audit_log` action `LOGIN`/`LOGOUT` | timestamp, user |
| `user_productivity` (chart) | dispenses or sales per staff per day | count/rate |
| `audit_trail` | pharmacy-relevant `audit_log` rows | action, entity, entity_id, user, diff |

## Requirements

1. If actor FK missing, migrate + seed **or** unavailable—do not attribute to “Unknown” as real staff performance.
2. Money from consumption/payments; counts from events.
3. Seed volume: ≥2 pharmacists, and ≥1,000 attestation-linked dispenses plus ≥1,000 pharmacy-relevant `audit_log` rows in range (`index.md` rule 9).
4. Permission-gate audit_trail columns; absent when unauthorized.
5. Tests: staff totals partition (sum staff amounts ≤/＝ period sales when attribution complete); unattributed remainder shown explicitly if any.

## Constraints

- `.cursor/access/permissions.mdc`; `index.md`; no HR console.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Every staff metric cites a real user FK or stays unavailable. | contract |
| A2 | Units correct; audit gated. | R2 |
| A3 | ≥1,000 attributed activity + audit events; ≥2 staff with distinct volume. | R3 |

## Relevant Files

- Prisma attestation, audit_log; seed-access + volume-extended; datasets; provider; reports_access

## Verification

- Trace attestation user → dispensing_by_staff row.
- Manual: Staff → sales by staff, audit trail (entitled user).
