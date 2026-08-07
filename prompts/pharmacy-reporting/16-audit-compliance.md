# Pharmacy Reporting: Audit & Compliance — Accurate Audit Log Mapping

Project audit reports from `audit_log` (and related PHI logs) with real `diff_json`—permission-trimmed, never synthesized.

## Context

**`audit_log` fields:** `tenant_id`, `user_id?`, `action` (`CREATE|UPDATE|DELETE|ACCESS|EXPORT|LOGIN|LOGOUT`), `entity`, `entity_id`, `diff_json?`, `ip_address?`, timestamps. **No facility_id.**

**Seed:** volume-extended audit rows. **All 10 audit report ids unavailable.**

**Pharmacy-relevant entities:** filter `entity` allow-list (pharmacy_order, dispense_log, drug, inventory_stock, stock_adjustment, payment, …)—keep list in one constant.

## Data contract

| Report id | Filter / columns |
| --- | --- |
| `who_created` | action=CREATE; `user`, `entity`, `entity_id`, `created_at` |
| `who_edited` | UPDATE |
| `who_deleted_voided` | DELETE (+ CANCELLED domain events if logged) |
| `previous_vs_new_values` | parse `diff_json` into `field`, `previous_value`, `new_value`—typed: prices currency, qty units |
| `change_date_time` | timestamp focus / same rows sorted |
| `audit_stock_adjustments` | entity in stock_adjustment/stock_movement |
| `audit_price_changes` | entity=drug with price keys in diff |
| `user_permissions` | only if permission-assignment audits exist; else unavailable |
| `unauthorized_attempts` | denied ACCESS/EXPORT attempts if logged; else empty ready |
| `prescription_controlled_audit` | entities for Rx/controlled dispense/attestation |

## Requirements

1. Do not invent diff fields—show raw keys from `diff_json`.
2. Gate entire category/actions via reports + audit entitlements; unauthorized UI absent.
3. Seed CREATE/UPDATE/DELETE on drug price + stock adjustment + failed ACCESS if supported.
4. Reuse shared table; progressive disclosure for large diffs on xs.
5. Tests: entitled sees rows; unentitled no audit buttons/export; price diff formats currency.

## Constraints

- `.cursor/access/permissions.mdc`; `index.md`; demo-safety.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Rows are real audit_log projections with entity allow-list. | contract |
| A2 | Diff typing units correct; permissions enforced. | R2 |
| A3 | Demo shows create/edit/price/stock audit samples. | R3 |

## Relevant Files

- Prisma audit_log; volume-extended seeder; reports_access; catalog audit block; provider

## Verification

- Match dialog row to audit_log id in DB.
- Manual: entitled vs unentitled Audit section.
