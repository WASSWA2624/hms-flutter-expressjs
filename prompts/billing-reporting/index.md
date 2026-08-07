# Billing & Finance Reporting Index

First-dense Reporting chrome for the **finance** owned pack (demo: `billing@hosspi.com`). Parent scope: `prompts/reporting-analytics.md`.

## Context

- Overview mounts `ReportsDomainReportingGroups` with `reportsDomainCatalog(finance)`.
- Runnable today: `billing_collections_open_balances`, `insurance_claims_aging`.
- Other subcategory buttons stay honest **unavailable** until child prompts add runners/seed.

## Requirements

1. Keep finance category/report ids stable in `domain_reporting_catalogs.dart`.
2. Prefer extending existing billing dataset builders over parallel formulas.
3. Deep subcategory accuracy → child prompts under this folder (add as needed).
4. Follow pharmacy data-accuracy pattern: no invented columns; ≥1,000 fact rows when wiring new datasets.

## Relevant Files

- `frontend/lib/features/reports/presentation/domain_reporting_catalogs.dart`
- `backend/src/lib/reports/constants.js`, `datasets.js`
- `prompts/reporting-analytics.md`
