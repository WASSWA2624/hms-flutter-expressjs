# Pharmacy Reporting: Per-Category Implementation Index

Implement every pharmacy Reporting category with **schema-accurate** mappings, formulas, and demo seed—reuse the shared kit; never invent columns or money math that contradict existing runners.

## Context

**Current behavior**

- Shell/catalog exist (`pharmacyReportingCatalog`, `ModuleReportingReportDialog`). Only three backend datasets back pharmacy Reporting today: `pharmacy_drug_consumption`, `pharmacy_dispense_throughput`, `inventory_stock_risk` (`REPORT_DATASET_MAP` in `backend/src/lib/reports/constants.js`). Billing has `billing_collections_open_balances` but **no** pharmacy catalog report wires to it yet.
- Most subcategory `datasetKey`s are null → unavailable. Dialogs already format via `moduleReportingMetricUnitForKey` and `effectiveDefaultCurrencyProvider` (fallback `UGX`).

**Intended behavior**

- Execute `01`–`17` below. Each dialog’s numbers must match the Data contract in that file (source rows, filters, formulas). Prefer extending existing builders over parallel math.

## Data accuracy rules (all category prompts)

1. **Single source of truth:** Dispense revenue/profit = `buildPharmacyDrugConsumptionAnalytics` rules: `amount = round(unit_price × quantity_dispensed, 2)` where `unit_price` prefers `drug.unit_price` else matching `pharmacy_order.billing_snapshot.line_items[].unit_price`; `profit = round((unit_price − buy_unit_price) × qty, 2)` via `pharmacyRetailMarginUnit`—**null profit when `buy_unit_price` unset**. Do not recompute with different rounding.
2. **Throughput counts** come only from `pharmacy_order.status` buckets (`DISPENSED|PARTIALLY_DISPENSED|CANCELLED`) + `dispense_log.status=RETURNED` (`buildPharmacyDispenseThroughputAnalytics`). `returns` is a **count of return logs**, not pack qty.
3. **Stock risk** uses `runInventoryDataset` classifiers exactly: qty≤0 `OUT_OF_STOCK`; qty≤floor(reorder/2) `CRITICAL`; qty≤reorder `LOW`; qty≥reorder×3 `OVERSTOCK`; else `OK`. Expiry rows only `EXPIRED|EXPIRING_SOON` from `drug_batch` + `resolveBatchExpiryAlertStatus`.
4. **Do not invent schema.** If a report needs a field that does not exist (examples: `drug.category`, `drug.barcode`, `drug.controlled`, `pharmacy_order.payment_method`, `pharmacy_order.cashier_user_id`, tax/VAT columns, PO line amounts), either (a) add a Prisma field + migration + seed, (b) join an **existing** related table that holds the truth, or (c) keep unavailable with an explicit gap note—never fake client-side values.
5. **Branch = `facility`.** Demo seed has **one** facility (`DemoCare General Hospital`). Multi-branch reports must be honest single-row ready or extend seed with ≥2 facilities—do not invent a `branch` table.
6. **Payment method** lives on `payment.method` (`PaymentMethodType`), not on pharmacy orders. Pharmacy payment slices must filter `billing_entity=PHARMACY` (and/or drug catalog invoice items) when scoping pharmacy cash.
7. **Currency:** Display with `effectiveDefaultCurrencyProvider`. Prefer row/`drug.currency` or `invoice.currency`/`payment` currency when projecting money; seeded pharmacy catalog uses **UGX**.
8. **Column keys must match unit inference:** money → `amount`/`profit`/`collections`/`refunds`/…; qty → `quantity`/`quantity_dispensed`/`reorder_*`; days → `days_to_expiry`/`*_days`; rates → `*_rate`/`margin`/`percent`; counts → `*_count`/`orders_created`/`dispensed` (throughput dispense is **order count**, not packs).
9. **Seed volume (minimum 1,000 rows where applicable):** Every category implementation must extend volume seed so each **primary transactional/fact table** that report reads has **≥ 1,000** demo rows after `db:seed:demo` with default `SEED_RECORD_COUNT` (**1000**, see `.cursor/access/demo-data.mdc`). “Where applicable” means volume/fact graphs (e.g. `dispense_log`, `pharmacy_order`, `payment`, `refund`, `invoice`, `stock_movement`, `stock_adjustment`, `drug_batch`, `audit_log`, PO/receipt lines once they exist)—**not** intentional singletons/catalogs (one tenant/facility/subscription; role/permission catalogs). Diversify statuses/dates/methods across the 1,000+ rows so default period presets are dense. Assert floors in `verify-demo-data` (or category seed tests). Prefer extending `seed-volume-pack` / `seed-volume-extended-pack` with deterministic keys; curated packs stay for hero scenarios only.

## Requirements

1. Treat `prompts/pharmacy-reporting.md` as chrome-only; category files own data mapping + seed.
2. Keep catalog report ids stable (`PharmacyReportingCategoryIds` + report id strings).
3. Extend `PharmacyReportingDataProvider` projections and `REPORT_DATASET_MAP` runners; register new keys in `report-definition` enum/schema when adding datasets.
4. Extend demo seed packs under `demo-safety.js` so each category’s applicable fact tables meet the **≥1,000-row** floor (rule 9); do not ship category work that only adds a handful of curated rows for reportable facts.
5. Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.

## Constraints

- Analytics chips unchanged. Unauthorized export absent. No production seeding.
- Do not lower `SEED_RECORD_COUNT` to satisfy tests; raise seed output or verify floors instead.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Every category file’s Data contract is implemented without conflicting formulas. | R1–R3 |
| A2 | Schema gaps use migration, real join, or honest unavailable—never fabricated numbers. | Data rules 4 |
| A3 | Demo seed meets ≥1,000 rows on each applicable fact table and keeps primary reports dense for default presets. | R4, rule 9 |
| A4 | Units/currency match shared formatters + seeded UGX/org default. | Data rules 7–8 |

## Relevant Files

| # | Prompt |
| --- | --- |
| 1–17 | `01-sales-revenue.md` … `17-management-executive.md` |
| Spec | `.cursor/reporting-analytics.md/pharmacy-reporting.md` |
| Catalog/provider | `frontend/lib/features/reports/presentation/pharmacy_reporting_catalog.dart`, `widgets/pharmacy_reporting_data_provider.dart` |
| Datasets | `backend/src/lib/reports/datasets.js`, `constants.js`, `@lib/billing/pharmacy-drug-margins` |
| Seed | `backend/scripts/seeders/seed-clinical-catalog-pack.js` (+ clinical/volume/operations packs) |

## Verification

- Implement 01→17 (management last). Per-file verification + spot-check: dialog totals equal dataset summary for same from/to/scope.
- After seed: `db:verify:demo` (or category tests) asserts ≥1,000 rows on each applicable fact table listed in category prompts.
