# Billing Reporting: Insurance Claims — Accurate Dialog Mapping

Wire all `claims` dialogs to `insurance_claim` aging/status truth—no invented denial reasons or settlement math that contradict schema.

## Context

**Catalog (`claims` category)**

| Report id | datasetKey today | Projection |
| --- | --- | --- |
| `claims_aging` | `insurance_claims_aging` | pass-through (`bucket`, `status`, `claims`) |
| `claims_status_mix` (chart) | `insurance_claims_aging` | group/sum by `status` |
| `denied_claims` | `null` | unavailable |

**Claims truth (`runInsuranceClaimsDataset`)**

- Source: `insurance_claim` where `deleted_at` null, `submitted_at` in range, invoice in tenant/(optional facility) scope.
- Selects: `submitted_at`, `status` only today.
- Aging buckets from `claimBucket(submitted_at)` vs **now**: `0-7 days`, `8-14 days`, `15-30 days`, `31+ days`.
- Status enum: `SUBMITTED|APPROVED|PARTIAL|REJECTED|PAID|CANCELLED` (not `DENIED`—use `REJECTED`).

**Schema available but unused by runner today**

- `claim_amount`, `settlement_amount`, `insurance_company_id`, `coverage_plan_id`, `payer_reference`, `notes`, `resubmitted_at`.

## Data contract

| Report id | Authoritative source | Required columns (keys) | Notes |
| --- | --- | --- | --- |
| `claims_aging` | claims aging rows | `bucket`, `status`, `claims` | Count of claims; not claim_amount unless extended |
| `claims_status_mix` | same rows aggregated by status | `status`, `claims` | Chart; totals = sum of aging rows |
| `denied_claims` | `insurance_claim` where `status=REJECTED` in range | Prefer `status`, `claims` (+ optional `claim_amount`, company label if joined) | Label “denied” as rejected; do not invent a DENIED enum |

## Requirements

1. Implement contract rows: extend `runInsuranceClaimsDataset` (filters/projections/joins) rather than parallel claim math.
2. Keep aging bucket boundaries stable unless all consumers update together.
3. Wire `denied_claims` to rejected claims or a dedicated dataset key registered in `REPORT_DATASETS` / enum.
4. Seed: ≥1,000 `insurance_claim` after `db:seed:demo`; diversify statuses (≥3 including `REJECTED`) and `submitted_at` across buckets. Assert floor in verify/seed tests.
5. Reuse shared dialog/chart/export; finance pack + `reports:read`.
6. Tests: status-mix totals equal aging row sum; denied count equals REJECTED filter for same range; unauthorized export absent.

## Constraints

- No fabricated settlement ratios. Prefer join `insurance_company` / `coverage_plan` for labels over free-text guesses.
- Rules: `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, parent `prompts/reporting-analytics.md`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Aging/status/denied use contract sources; gaps stay unavailable. | R1–R3 |
| A2 | `claims` is a count; money only when projecting `claim_amount`/`settlement_amount`. | contract |
| A3 | ≥1,000 insurance_claim rows; aging + status mix dense for default presets. | R4 |
| A4 | Dialog counts match dataset for same from/to/scope. | R6 |

## Relevant Files

- `datasets.js` (`runInsuranceClaimsDataset`, `claimBucket`), `constants.js`
- `domain_reporting_catalogs.dart`, Prisma `insurance_claim`
- Seed/verify volume packs

## Verification

- Spot-check: REJECTED count vs SQL; bucket assignment for known submitted_at fixtures.
- Manual: billing@ → Claims → aging, status mix, denied.
