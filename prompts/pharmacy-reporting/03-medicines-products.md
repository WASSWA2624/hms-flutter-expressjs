# Pharmacy Reporting: Medicines & Products — Accurate Catalog Mapping

Project medicines reports from real `drug` / `drug_batch` / `inventory_item` fields—map gaps explicitly (no barcode/controlled/category on `drug`).

## Context

**`drug` fields that exist:** `name`, `brand_name`, `generic_name`, `code`, `form`, `strength`, `buy_unit_price`, `unit_price`, `transfer_unit_price`, `currency`, `supplier_id`.

**Do not exist on `drug`:** `category`, `barcode`, `controlled`, dedicated UOM (use `inventory_item.unit` via `drug_inventory_map`), `dosage_form` name (use `form`).

**Related:** `drug_batch` (`batch_number`, `manufactured_at`, `expiry_date`, `quantity`); `facility_pharmacy_offering` facility sell price; storage via `storage_room`/`storage_shelf` on batch.

**All 16 medicines report ids currently `datasetKey: null`.**

**Seed:** Uganda-style catalog in `seed-clinical-catalog-pack.js` sets form/strength/brand, UGX prices (`buy_unit_price`/`unit_price`), `supplier_id`, batches with mfg/expiry.

## Data contract

| Report id | Source fields | Output columns |
| --- | --- | --- |
| `medicine_name` | `drug.name` (+ `code`, HFI) | `name`, `code`, `human_friendly_id` |
| `generic_brand_name` | `generic_name`, `brand_name` | those keys; empty string → null/— not `"null"` |
| `medicine_category` | `inventory_item.category` via default map | `category`, `name` |
| `strength` | `drug.strength` | plain text (e.g. `500 mg`)—not numeric currency |
| `dosage_form` | `drug.form` | key `form` or label `dosage_form` consistently |
| `unit_of_measure` | `inventory_item.unit` | `unit` plain |
| `batch_lot` | `drug_batch` | `batch_number`, `quantity`, `expiry_date`, `name` |
| `manufacturing_date` | `drug_batch.manufactured_at` | date column |
| `expiry_date` | `drug_batch.expiry_date` | date + optional `days_to_expiry` |
| `selling_price` | `drug.unit_price` (facility overlay: `facility_pharmacy_offering.unit_price` when scoped) | `selling_price` or `unit_price` **currency** + `currency` code column |
| `purchase_price` | `drug.buy_unit_price` | currency |
| `profit_per_unit` | `pharmacyRetailMarginUnit(unit_price, buy_unit_price)` | currency; **null if buy unset** |
| `profit_margin` | margin/unit_price when unit_price&gt;0 | percent key `profit_margin` |
| `barcode` | **gap** | migrate onto drug/inventory **or** unavailable—do not use `asset.barcode` |
| `prescription_controlled_status` | **gap** on drug | use attestation/custody JSON only if productizing controlled; else migrate boolean `is_controlled` + seed Morphine/Tramadol flags |
| `storage_requirements` | batch `storage_room`/`storage_shelf` names | plain location labels |

Period: date filters apply to batch mfg/expiry; price/name lists are catalog snapshots (subtitle: “as of {to}”).

## Requirements

1. Add pharmacy catalog dataset runner; set all medicines `datasetKey`s; project per-id column subsets from one row model.
2. Money columns must use `drug.currency` when set else effective default (seed UGX).
3. Seed: fill `generic_name`/`brand_name` where missing; ensure map+unit on inventory items; decide barcode/controlled via migration+seed or leave unavailable. Where volume applies, seed ≥1,000 `drug_batch` rows (and inventory maps/stocks as needed) so batch/expiry/price dialogs are dense—catalog drug masters may stay curated (`index.md` rule 9).
4. Reuse shared table/dialog; no Catalog CRUD rewrite.
5. Tests: margin matches helper; selling vs buy for Paracetamol seed row; form/strength not formatted as currency.

## Constraints

- Follow `index.md` gap rule. `.cursor/flows/pharmacy-flow.mdc` unchanged for dispense.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Mapped attributes match Prisma field names above. | contract |
| A2 | Price/margin units correct; strength/form plain. | R2 |
| A3 | Gaps (barcode/controlled) migrated or explicitly unavailable. | R3 |
| A4 | UGX prices with buy for margins; ≥1,000 batches where batch reports apply. | R3 |

## Relevant Files

- Prisma `drug`, `drug_batch`, `inventory_item`, `drug_inventory_map`, `facility_pharmacy_offering`
- `pharmacy-drug-margins.js`; clinical catalog seeder; reporting catalog/provider

## Verification

- Spot-check one seeded drug: dialog sell/buy/profit_per_unit vs DB.
- Manual: Medicines → selling price, batch/lot, unit of measure.
