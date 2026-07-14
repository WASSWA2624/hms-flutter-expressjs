# Lab module improvements (20260715120000)

## Affected tables

- `lab_sample`: `rejection_reason`, `rejection_notes`, `rejected_at`
- `lab_test_reference_range` / `facility_lab_test_reference_range`: `method`, `effective_from`, `effective_to`, `version`
- `lab_result`: `applied_reference_range_id`, `applied_reference_range_json`

## Backfill

Released results with label/summary and no snapshot receive a summary-only JSON object (`source: BACKFILL_SUMMARY`). Numeric bounds are not invented.

## Deployment

1. Deploy application code that reads new nullable columns.
2. Apply migration.
3. Verify new collects block on unpaid pay-now orders; released results include `applied_reference_range_json`.

## Recovery

Forward-only. If rollback is required, add `rollback_20260715120000_lab_module_improvements` that drops the new columns/indexes after confirming no production dependency on snapshots.
