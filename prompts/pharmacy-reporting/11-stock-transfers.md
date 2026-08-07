# Pharmacy Reporting: Stock Transfers — Accurate Movement Mapping

Map transfer reports to `stock_movement` with `movement_type=TRANSFER` (and related fields)—extend schema only if both endpoints are not stored today.

## Context

**Exists:** `stock_movement`: `inventory_item_id`, `facility_id?`, `movement_type` (`INBOUND|OUTBOUND|ADJUSTMENT|TRANSFER`), `reason`, `quantity`, `occurred_at`.

**Likely gap:** single `facility_id` may not capture sending **and** receiving branch—verify schema; if only one facility FK, migrate `from_facility_id`/`to_facility_id` (or paired movements) before claiming sending/receiving reports.

**All 8 transfer ids unavailable.** Seed movements exist; dedicated transfer pairs may not.

## Data contract

| Report id | Requirement |
| --- | --- |
| `transfer_quantity` | rows where type=TRANSFER; `quantity` units |
| `sending_branch` / `receiving_branch` | from/to facility names—**blocked until both ends exist** |
| `transfer_date` | `occurred_at` |
| `transfer_status` | only if status field exists on transfer doc; else derive pending vs completed from paired receipts—no fake statuses |
| `products_transferred` | `inventory_item`, `quantity`, facilities, date |
| `pending_transfers` | incomplete transfers per real status model |
| `transfer_discrepancies` | shipped qty ≠ received qty when both recorded |

## Requirements

1. Inspect Prisma; if endpoints missing, migration + seed before UI ready.
2. Seed volume: ≥1,000 `stock_movement` with `TRANSFER` (or paired transfer docs) when model supports it, including completed, pending, and discrepancy cases in the mix—not just one sample (`index.md` rule 9). If endpoints missing, migrate first; else keep ids unavailable with gap comment.
3. Dataset + provider; period on `occurred_at`.
4. Tests: TRANSFER filter excludes DISPENSE outbound; discrepancy math absolute difference.

## Constraints

- Mandatories migrations; `index.md`; demo-safety.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Transfer dialogs only show when endpoint/status data is real. | contract |
| A2 | Quantities use units; facilities named from `facility`. | R2 |
| A3 | ≥1,000 transfer movements/docs when implemented; seed matches model. | R3 |

## Relevant Files

- Prisma stock_movement (+ migration if needed); inventory seeders; datasets; provider

## Verification

- SQL count TRANSFER movements = dialog row count for range.
- Manual: Transfers → products, pending (if seeded).
