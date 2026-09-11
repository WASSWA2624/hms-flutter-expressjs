# Registration attempt records (20260911120000)

## Affected tables

- `registration_attempt` (new): one row per self-serve registration submission,
  keyed by the client's `Idempotency-Key`.
  - `@@unique([idempotency_key])` — makes a repeated submission replay the
    original outcome instead of bootstrapping a second workspace.
  - `@@unique([claimed_email])` — the database-level duplicate guard. Written
    inside the transaction that creates the tenant, facility, and user, so a
    concurrent second bootstrap for the same email is rejected and rolled back.
    `NULL` for attempts that created nothing (rejections, verification
    resends); MySQL permits many `NULL`s in a unique index, so only real claims
    compete.
  - `result_json` holds the replay payload only. It never stores credentials,
    verification codes, or verification links.
- No existing table is altered. `tenant.slug` already carried `@@unique([slug])`,
  which remains the tenant-identifier constraint.

## Backfill

Required before the unique index is trusted on a populated host.

```bash
npm run db:backfill:registration-claims:dry-run   # report only
npm run db:backfill:registration-claims           # apply
```

The script walks `registration_follow_up` (the record of every self-serve
registration), keeps the earliest registration per email as the claim holder,
and prints every later duplicate for an operator to merge or retire. It creates
claim rows only — it never deletes, merges, or rewrites an account, and it is
safe to re-run: an email that already holds a claim is skipped.

Duplicates do **not** block the migration: the pre-existing rows keep working,
and only one of them gains a claim. Resolve the reported duplicates before
relying on the constraint for support workflows.

## Deployment

1. Deploy application code. It tolerates the table being absent (`P2021`/`P2022`
   degrade to a non-idempotent registration), so code may ship first.
2. Apply migration `20260911120000_registration_attempt`
   (`npm run prisma:migrate:deploy`).
3. Run the backfill dry run, review duplicates, then apply it.
4. Verify:
   - Registering twice with the same `Idempotency-Key` returns one workspace
     and `"replayed": true` on the second call.
   - `POST /api/v1/auth/registration-status` returns the true outcome for a
     known key and `REGISTRATION_UNKNOWN` for an unknown one.
   - With SMTP disabled, registration returns
     `ACCOUNT_CREATED_EMAIL_PENDING` with HTTP 201 rather than a 503.

## Recovery

Forward-only. Dropping `registration_attempt` restores the previous behaviour
(registration still works; idempotency and the status lookup stop working), so
a rollback needs no data migration — add
`rollback_20260911120000_registration_attempt` dropping the table if required.
