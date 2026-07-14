# Billing engine idempotency (20260715160000)

## Affected tables

- `billable_charge_event` (new): idempotent charge ledger with unique
  `(tenant_id, source_module, source_id, charge_key)`
- `admission`: `billing_snapshot` JSON
- `nursing_note`: `billing_snapshot` JSON

## Backfill

None. Existing clinical invoices remain valid; new charges post through the
central engine and write `billable_charge_event` rows. Historical consultation
invoices without events are not rewritten.

## Deployment

1. Deploy application code that treats `billing_snapshot` / `billable_charge_event`
   as optional (nullable).
2. Apply migration `20260715160000_billing_engine_idempotency`.
3. Verify:
   - OPD consultation start creates invoice line items via the engine
   - Retrying the same consultation source does not create a second invoice
   - IPD admission / nursing note accept optional `billing` payloads
   - Payment / refund / closeout responses include `X-Online-Only: 1`

## Recovery

Forward-only. If rollback is required, add
`rollback_20260715160000_billing_engine_idempotency` that drops
`billable_charge_event` and the new snapshot columns after confirming no
production dependency on those rows.
