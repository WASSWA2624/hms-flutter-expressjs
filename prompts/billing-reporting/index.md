# Billing & Finance Reporting Index

First-dense Reporting chrome for the **finance** owned pack (demo: `billing@hosspi.com`). Parent scope: `prompts/reporting-analytics.md`.

## Context

- Overview mounts `ReportsDomainReportingGroups` with `reportsDomainCatalog(finance)`.
- Runnable today: `billing_collections_open_balances`, `insurance_claims_aging` (pass-through via `DomainReportingDataProvider`).
- Gaps (honest **unavailable** until child prompts land runners/seed): `cashier_productivity`, `denied_claims`, `price_list_changes`, `payer_mix`.

## Data accuracy rules

1. Money math for collections/refunds/write-offs/`profit_proxy` comes only from `buildBillingFinancialAnalytics`—extend that builder; do not fork formulas.
2. Claims aging buckets and status enum match `runInsuranceClaimsDataset` / `InsuranceClaimStatus` (`REJECTED` = denied).
3. Do not invent cashier/actor or tax columns; migrate, join, or keep unavailable.
4. Seed volume: ≥1,000 rows on each applicable fact table when a report becomes runnable (`payment`, `invoice`, `refund`/`billing_adjustment`, `insurance_claim`, …). Assert in verify/seed tests. Prefer volume packs; no production seeding.
5. Currency via `effectiveDefaultCurrencyProvider` (seeded UGX).

## Requirements

1. Keep finance category/report ids stable in `domain_reporting_catalogs.dart`.
2. Prefer extending existing billing/claims dataset builders over parallel formulas.
3. Execute category prompts `01`–`03` below before claiming deep completeness.
4. Follow parent epic + `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Constraints

- Do not change pharmacy catalog/dialogs or admin infra panels.
- Unauthorized export absent; pack matrix stays green.

## Relevant Files

| # | Prompt |
| --- | --- |
| 1 | `01-collections.md` |
| 2 | `02-claims.md` |
| 3 | `03-revenue.md` |
| Spec | `prompts/reporting-analytics.md` |
| Catalog/provider | `domain_reporting_catalogs.dart`, `domain_reporting_data_provider.dart` |
| Datasets | `backend/src/lib/reports/datasets.js`, `constants.js` |

## Verification

- Implement 01→03. Per-file verification: dialog totals = dataset summary for same from/to/scope.
- After seed: floors ≥1,000 on applicable facts for newly wired reports.
- Manual: `billing@hosspi.com` Reporting matches finance job; doctor ≠ billing catalog.
