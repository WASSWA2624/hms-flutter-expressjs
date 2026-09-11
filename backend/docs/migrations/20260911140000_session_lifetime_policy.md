# Session lifetime anchors (20260911140000)

## Affected tables

- `user_session` (altered): two nullable timestamps that give a refresh chain a
  memory.
  - `chain_started_at` — when the chain's original sign-in happened. Every
    rotation inherits it, so the absolute timeout is anchored to the login
    rather than to the newest refresh.
  - `last_used_at` — the last successful refresh. Reset on every rotation; the
    idle timeout is measured from it.
  - `@@index([last_used_at])` — supports operational queries over idle sessions.
- No table is created and no column is dropped or renamed.

Both columns are nullable on purpose. The application treats a missing anchor as
*unknown*, not as the epoch, so a row it cannot date is never revoked for being
too old.

## Behaviour change

Before this migration every refresh reset `expires_at` to
`now + AUTH_SESSION_TTL_DAYS`, so a chain that kept refreshing never expired.
After it, `expires_at` is clamped to `chain_started_at + AUTH_SESSION_ABSOLUTE_TIMEOUT_HOURS`
and a chain that goes unused for longer than `AUTH_SESSION_IDLE_TIMEOUT_MINUTES`
is revoked on its next refresh.

With the shipped defaults — idle 10080 minutes (7 days), absolute 720 hours
(30 days) — no session that works today is cut short: the idle window equals the
existing `AUTH_SESSION_TTL_DAYS`, and the absolute ceiling only bounds chains
that would previously have lived forever.

## Backfill

Included in the migration and idempotent; no separate script.

```sql
UPDATE `user_session` SET `chain_started_at` = `created_at` WHERE `chain_started_at` IS NULL;
UPDATE `user_session` SET `last_used_at`     = `created_at` WHERE `last_used_at`     IS NULL;
```

`created_at` is the honest origin for a session that predates the policy: the
rotation history was never recorded, so each surviving row is treated as its own
chain. Re-running the migration touches nothing, because both updates are
guarded on `IS NULL`.

## Deployment

1. Deploy application code. `createSession` retries without the two columns when
   the database does not have them yet, so the code is safe to ship first.
2. Set `AUTH_SESSION_IDLE_TIMEOUT_MINUTES` and
   `AUTH_SESSION_ABSOLUTE_TIMEOUT_HOURS` in `.env.development` **and**
   `.env.production`. Both environments must carry the same values — the policy
   is never derived from `NODE_ENV`.
3. Apply migration `20260911140000_session_lifetime_policy`
   (`npm run prisma:migrate:deploy`).
4. Verify:
   - A fresh login writes `chain_started_at` and `last_used_at`.
   - A refresh writes a new row whose `chain_started_at` equals the previous
     row's, and revokes the previous row.
   - A session whose `chain_started_at` is older than the absolute timeout is
     refused with `errors.auth.session_absolute_timeout`.
   - A session whose `last_used_at` is older than the idle timeout is refused
     with `errors.auth.session_idle_timeout`.

## Recovery

Forward-only, and safe to leave in place. Dropping the two columns restores the
previous behaviour without data loss — sessions keep working and only the idle
and absolute limits stop being enforced. Add
`rollback_20260911140000_session_lifetime_policy` dropping both columns if
required.
