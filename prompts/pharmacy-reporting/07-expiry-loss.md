# Pharmacy Reporting: Expiry & Loss Control — Accurate Mapping

Extend expiry/loss dialogs from `drug_batch` risk rows and `stock_adjustment`/`stock_movement` reasons—aligned with inventory classifiers and seed templates.

## Context

**Mapped:** `expiring_windows`, `already_expired` → `inventory_stock_risk` filter `EXPIRING_SOON` / `EXPIRED`.

**Accuracy note:** `expiring_windows` currently dumps all `EXPIRING_SOON`—it does **not** yet bucket 30/60/90/180. Seed templates: dayOffsets −75,−14,8,21,52,78,145 with leadDays 30–180.

**Value gap:** expiry rows have `quantity` but not currency value—compute `value = quantity × buy_unit_price` via drug name/id join.

**Reasons enum on movement/adjustment:** `PURCHASE|DISPENSE|RETURN|DAMAGE|EXPIRY|OTHER`.

## Data contract

| Report id | Logic |
| --- | --- |
| `expiring_windows` | Filter batches with `days_to_expiry` in (0,30], (30,60], (60,90], (90,180]; column `expiry_window` + existing expiry columns. Exclude already expired |
| `already_expired` | `risk_state=EXPIRED` or `days_to_expiry < 0` |
| `expired_stock_value` | sum `quantity × buy_unit_price` for expired batches; columns include `value` |
| `damaged_stock_loss` | adjustments/movements reason `DAMAGE` in range; qty + `value` |
| `lost_stock_loss` | only if reason distinguishes loss; else map `OTHER` **explicitly** in subtitle or unavailable |
| `stock_write_offs` | adjustments with EXPIRY/DAMAGE (document set); `amount`/`value` currency |
| `adjustment_reasons` | group by `reason` counts/qty |
| `expiry_losses_breakdown` | expired value by `drug` / inventory category / `drug.supplier_id` |

## Requirements

1. Implement window bucketing in provider or dataset—tests for each bucket using seed offsets.
2. Value always uses `buy_unit_price` (COGS), not sell—subtitle “at buy cost”.
3. Seed volume: keep risk templates; scale to ≥1,000 `drug_batch` rows spanning 30/60/90/180/expired windows and ≥1,000 DAMAGE/EXPIRY `stock_adjustment` (or movements) for loss reports (`index.md` rule 9).
4. Reuse inventory dataset; don’t change EXPIRING_SOON definition silently.
5. Tests: dayOffset 8 → ≤30 bucket; −14 → expired value&gt;0.

## Constraints

- `index.md` rules; demo-safety; no orphan FKs.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Windows are four exclusive buckets; expired separate. | contract |
| A2 | Values at buy cost; days unit on `days_to_expiry`. | R2 |
| A3 | ≥1,000 batches + loss adjustments; each expiry window + damage write-off present in volume. | R3 |

## Relevant Files

- `runInventoryDataset`; `PHARMACY_REPORT_RISK_BATCH_TEMPLATES`; stock_adjustment/movement; provider filters

## Verification

- Bucket counts vs raw batch expiry dates for demo tenant.
- Manual: Expiry → windows, expired value, adjustment reasons.
