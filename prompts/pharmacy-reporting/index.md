# Pharmacy Reporting: Per-Category Implementation Index

Implement every pharmacy Reporting catalog category so each subcategory dialog loads mapped, unit-correct demo data—without reinventing the shared reporting shell.

## Context

**Current behavior**

- Catalog UI, filters, and `ModuleReportingReportDialog` shell exist (`pharmacyReportingCatalog`, `PharmacyReportingDataProvider`). Most subcategory `datasetKey`s are null → honest **unavailable**. Only a subset projects `pharmacy_drug_consumption`, `pharmacy_dispense_throughput`, or `inventory_stock_risk`.
- Shared kit already formats currency / quantity / percent / days / counts (`moduleReportingMetricUnitForKey`), exports Excel/PDF, and adapts tables/charts responsively.
- Demo seed packs (`seed-clinical-catalog-pack`, volume packs) already diversify stock risk and pharmacy activity; coverage is incomplete for many catalog reports.

**Intended behavior**

- Execute one prompt file per category below. Each leaves that category’s report buttons opening dialogs with period-filtered, unit-labeled data suitable for demos—reusing shared UI, datasets, seeders, and permissions.

**Definitions**

- *Category prompt:* One markdown file under `prompts/pharmacy-reporting/` covering all subcategory report ids for that category.
- *Mapped report:* Catalog entry with `datasetKey` + provider projection that returns ready/empty/error (not unavailable) when seed/API data exists.

## Requirements

1. Treat `prompts/pharmacy-reporting.md` as the shell/catalog contract; do not re-build sections/filters/dialog chrome in category prompts.
2. Implement categories via the files in this folder (one category per file); keep ids aligned with `PharmacyReportingCategoryIds` and catalog report ids.
3. Prefer extending existing datasets, projectors, and seed helpers over new microservices or parallel dialog frameworks.
4. After each category, demo seed + period presets must yield non-empty rows for at least the primary reports in that category (see per-file acceptance).
5. Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.

## Constraints

- Do not change Analytics chips or non-pharmacy Overview except shared kit fixes that pharmacy Reporting already depends on.
- Do not invent production-only seed paths; gate with `demo-safety.js`.
- Unauthorized export/write UI must remain absent.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Shell/catalog prompt remains the single chrome contract. | R1 |
| A2 | Each category file below is implemented with stable catalog ids. | R2 |
| A3 | Implementations reuse shared reporting + seed infrastructure. | R3 |
| A4 | Demo presets show data for primary reports per category file. | R4 |
| A5 | Rules for access, demo safety, responsiveness, and prompt standards are followed. | R5 |

## Relevant Files

| # | Category | Prompt |
| --- | --- | --- |
| 1 | Sales & Revenue | `01-sales-revenue.md` |
| 2 | Inventory / Stock | `02-inventory-stock.md` |
| 3 | Medicines & Products | `03-medicines-products.md` |
| 4 | Purchasing & Suppliers | `04-purchasing-suppliers.md` |
| 5 | Dispensing | `05-dispensing.md` |
| 6 | Patients / Customers | `06-patients-customers.md` |
| 7 | Expiry & Loss Control | `07-expiry-loss.md` |
| 8 | Financial Reports | `08-financial.md` |
| 9 | Staff & User Activity | `09-staff-activity.md` |
| 10 | Branch / Multi-Store | `10-branch.md` |
| 11 | Stock Transfers | `11-stock-transfers.md` |
| 12 | Prescription & Clinical | `12-prescription-clinical.md` |
| 13 | Controlled / Regulated | `13-controlled-medicines.md` |
| 14 | Supplier & Procurement Analytics | `14-supplier-procurement.md` |
| 15 | Operational KPIs | `15-operational-kpis.md` |
| 16 | Audit & Compliance | `16-audit-compliance.md` |
| 17 | Management / Executive | `17-management-executive.md` |

Also: `.cursor/reporting-analytics.md/pharmacy-reporting.md`, `frontend/lib/features/reports/presentation/pharmacy_reporting_catalog.dart`, `frontend/lib/shared/reporting/**`, `backend/src/lib/reports/datasets.js`, `backend/scripts/seeders/**`.

## Verification

- Run category prompts in order 01→17 (or by dependency: inventory/medicines before expiry/KPIs/management).
- Per-file verification plus manual: Reporting → category → each button → non-unavailable body with correct units → export when entitled → xs/lg/xxl + light/dark.
