# Pharmacy Reporting: Inventory / Stock — Accurate Dialog Mapping

Map all `inventory_stock` reports to `inventory_stock`, `drug_batch`, and `stock_movement`/`stock_adjustment` with the **same** risk classifiers as `runInventoryDataset`.

## Context

**Already mapped** (dataset `inventory_stock_risk`): `current_stock_quantity` (OK/LOW/CRITICAL/OVERSTOCK/OUT_OF_STOCK), `overstock`, `expired_stock`, `near_expiry_stock`, `understock` (LOW+CRITICAL), `out_of_stock` (qty≤0).

**Runner columns:** `facility`, `inventory_item`, `quantity`, `reorder_level`, `risk_state`, `expiry_date`, `expiry_alert_status`, `days_to_expiry`, `batch_number`.

**Classifiers (must not diverge)**

- Stock: qty≤0 → `OUT_OF_STOCK`; qty≤floor(reorder/2) → `CRITICAL`; qty≤reorder → `LOW`; qty≥reorder×3 → `OVERSTOCK`; else `OK`.
- Expiry rows: only alert batches → `EXPIRED` | `EXPIRING_SOON`; `days_to_expiry` from wall clock vs `drug_batch.expiry_date`; lead = `expiry_alert_lead_days` ?? 30.

**Seed today:** `PHARMACY_REPORT_RISK_BATCH_TEMPLATES` (−75…+145d), `resolveDemoStockQuantity` profiles 0–3 for OOS/critical/low/overstock; movements in catalog/volume packs.

**Gaps:** Dataset has **no stock value column**; movements/adjustments not in `inventory_stock_risk`. `stock_adjustment` has **no actor user_id**.

## Data contract

| Report id | Source | Columns / formula |
| --- | --- | --- |
| `current_stock_quantity` | stock rows (non-expiry) | existing filter; `quantity` units, `reorder_level` units |
| `stock_value` | `inventory_stock.quantity ×` cost | Prefer `drug.buy_unit_price` via `drug_inventory_map`; fallback `unit_price`; column `value` (currency). Document chosen cost basis in subtitle |
| `opening_closing_stock` | movements reconstruct or snapshot | `opening_quantity`, `closing_quantity`, `inventory_item` — same UOM as `inventory_item.unit` |
| `stock_received` | `stock_movement` `INBOUND` + reason `PURCHASE` (and receipts if linked) | `quantity`, `occurred_at`, `inventory_item` |
| `stock_issued` | `OUTBOUND` + `DISPENSE` | `quantity` |
| `stock_adjustments` | `stock_adjustment` **or** movement `ADJUSTMENT` | `quantity`, `reason` (`DAMAGE\|EXPIRY\|OTHER`…) |
| `damaged_stock` | reason `DAMAGE` | `quantity` (+ `value` if cost joined) |
| `lost_stock` | reason `OTHER`/explicit loss only if distinguishable—**do not relabel DAMAGE** | document mapping |
| `expired_stock` / `near_expiry_stock` | existing expiry filters | keep `days_to_expiry` days unit |
| `overstock` / `understock` / `out_of_stock` | existing | unchanged classifiers |
| `reorder_level` / `reorder_quantity` | `inventory_stock.reorder_level`; reorder qty = max(0, reorder−qty) if no separate field | keys `reorder_level`, `reorder_quantity` |
| `stock_turnover` (chart) | issued qty / avg on-hand for period | `stock_turnover` ratio or `days_of_stock`; subtitle states formula |
| `fast_moving` / `slow_moving` / `dead_stock` | dispense qty or OUTBOUND over period vs on-hand | thresholds documented in code comments + tests |
| `stock_movement_history` | `stock_movement` chronologically | `occurred_at`, `movement_type`, `reason`, `quantity`, `facility`, `inventory_item` |

## Requirements

1. Implement contract; extend dataset(s) rather than changing risk thresholds.
2. `expiring_windows` (expiry category) depends on `days_to_expiry` buckets 30/60/90/180—keep batch leadDays seed aligned (`window-60/90/180` templates).
3. Seed volume: ≥1,000 `stock_movement` and ≥1,000 `stock_adjustment` rows; keep risk templates and ensure DAMAGE + INBOUND/OUTBOUND/TRANSFER appear inside the volume mix. Scale `drug_batch` / stock rows so risk filters stay populated at volume (`index.md` rule 9).
4. Reuse shared kit; currency for `value` via effective default (UGX seed).
5. Tests: classifier golden cases; stock_value = qty×buy for a known seeded drug; movement history ordered.

## Constraints

- Do not invent parallel risk enums. Follow `index.md` accuracy rules + `.cursor/access/demo-data.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All inventory ids ready/empty/error with contract sources. | R1 |
| A2 | Risk labels match `runInventoryDataset`; value/qty/days units correct. | contract |
| A3 | ≥1,000 movements/adjustments; OOS, LOW/CRITICAL, OVERSTOCK, EXPIRED, EXPIRING_SOON, DAMAGE still present in the mix. | R3 |

## Relevant Files

- `datasets.js` `runInventoryDataset`; `seed-clinical-catalog-pack.js`; Prisma `inventory_stock`, `drug_batch`, `stock_movement`, `stock_adjustment`, `drug_inventory_map`
- `pharmacy_reporting_data_provider.dart` filters; `seed-clinical-catalog-pharmacy-reporting.test.js`

## Verification

- Compare dialog risk counts to dataset summary keys (`low_stock`, `expired`, …).
- Manual: Inventory → current stock, stock value, movement history.
