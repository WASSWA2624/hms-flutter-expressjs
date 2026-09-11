# Registration transaction map

What actually happens between the registration form and the response, which
steps are atomic, which are asynchronous, and where a client timeout can
diverge from backend success.

Sources: `src/modules/auth/routes/auth.routes.js`,
`src/modules/auth/controllers/auth.controller.js`,
`src/modules/auth/services/auth.service.js`,
`src/modules/auth/repositories/auth.repository.js`.

## Step sequence

| # | Step | Where | Atomic? | Can it fail the registration? |
| - | ---- | ----- | ------- | ----------------------------- |
| 1 | Rate limit (`register`: 3/hour in production) | `rateLimit.middleware` | n/a | Yes — 429, nothing created |
| 2 | Body validation (`registerBodySchema`) | `validate.middleware` | n/a | Yes — 422, nothing created |
| 3 | Claim the `Idempotency-Key` (`registration_attempt` row, `IN_PROGRESS`) | `beginRegistrationAttempt` | Single insert | No — a conflict replays instead |
| 4 | Existing-email lookup | `findUserByEmail` | Read | Diverts to the resend path (step 4a) |
| 4a | Resend verification for an existing account | `handleExistingEmailRegistration` | n/a | No — returns a success outcome |
| 5 | Password hash | `@lib/crypto` | n/a | Yes — 500, nothing created |
| 6 | **Bootstrap transaction**: tenant → facility → role → user → user_profile → user_role → `claimed_email` | `registerFacilityOwner`, one `prisma.$transaction` | **Yes** | Yes — all-or-nothing, no orphan rows |
| 7 | Verification code issued (`verification_token`) | `createEmailVerificationTokens` | Single insert | No — a failure here reports `ACCOUNT_CREATED_EMAIL_PENDING` |
| 8 | Verification email dispatch | `deliverRegistrationEmail` | **Asynchronous to the account**, and bounded by `REGISTRATION_EMAIL_WAIT_MS` | **No** — reported as `email_status`; a send still running when the budget elapses reports `PENDING` and finishes in the background |
| 9 | Follow-up tracking upsert | `persistRegistrationFollowUp` | Best-effort | No — swallowed by design |
| 10 | Audit log `USER_REGISTERED` | `createAuditLog` | Best-effort | No |
| 11 | Stamp the attempt `SUCCEEDED` with its outcome | `completeRegistrationAttempt` | Single update | No |
| 12 | HTTP response (201, or 202 for `REGISTRATION_IN_PROGRESS`) | controller | n/a | n/a |

The commit boundary is step 6. Everything before it can fail with nothing
created; nothing after it can un-create the account. Steps 7 and 8 run inside a
`try` that reports failure as `email_status`, and a released attempt row
(`releaseRegistrationAttempt`) is filtered on `claimed_email: null`, so an
account that exists never loses its claim to a post-commit error.

## Where a client timeout diverges from backend success

A client timeout is a statement about the transport, not about the backend. The
request can time out at any point in the table above:

- **Before step 6** — no account exists. `registration_attempt` is either absent
  (request never arrived) or was released on the server error.
- **After step 6** — the user, tenant, and facility exist. The verification
  email may or may not have gone out. Retrying the form here is what used to
  produce a second tenant.

The client cannot tell these apart from the transport error, so it does not
try. After a timeout it calls `POST /api/v1/auth/registration-status` with the
same idempotency key and renders the answer:

| Outcome | Meaning | UI |
| ------- | ------- | -- |
| `ACCOUNT_CREATED_EMAIL_SENT` | Account exists, email accepted | Success → verify-email |
| `ACCOUNT_CREATED_EMAIL_PENDING` | Account exists; the email is still sending, or failed | Success → verify-email. `verification.email_status` decides the copy: `PENDING` uses the normal "check your inbox", `FAILED` leads with a resend |
| `REGISTRATION_IN_PROGRESS` | The attempt is still running | Keep waiting, re-poll |
| `REGISTRATION_REJECTED` | The backend rejected it; nothing created | Show the rejection |
| `REGISTRATION_UNKNOWN` | No attempt with that key reached the backend | Show the connection failure |

A registration-failed message may render only for the last two.

## Idempotency

The client sends `Idempotency-Key` on `POST /api/v1/auth/register`, generated
once per logical submission (`frontend/lib/core/network/idempotency.dart`) and
reused across retries of that submission.

- Repeat of a `SUCCEEDED` key → the stored payload, with `"replayed": true`.
- Repeat of a `REJECTED` key → the original error, unchanged.
- Repeat of an `IN_PROGRESS` key → `REGISTRATION_IN_PROGRESS` (HTTP 202).
- An `IN_PROGRESS` attempt older than 5 minutes is assumed orphaned by a dead
  process and is taken over. The `claimed_email` unique index still prevents a
  double bootstrap if the original request is somehow alive.
- Replay is durable for `REGISTRATION_IDEMPOTENCY_TTL_HOURS` (default 24).

The generic in-memory idempotency replay in `offline.middleware.js` explicitly
skips `/api/v1/auth/*`. It is per-process and keyed on a body hash, which is
neither durable nor correct for account creation; registration carries its own
database-backed record instead.

## Duplicate protection

Three layers, in order of when they fire:

1. `findUserByEmail` diverts a repeat registration to the resend path.
2. `registration_attempt.claimed_email` is unique and is written inside the
   bootstrap transaction, so a concurrent second bootstrap for the same email
   rolls back rather than creating a second tenant.
3. `user.@@unique([tenant_id, email])` and `tenant.@@unique([slug])` remain as
   the per-tenant and tenant-identifier constraints.

A `P2002` from layer 2 or 3 maps to `errors.auth.user_exists` (409), which the
service catches and converts into the existing-email resend path — the caller
sees a success outcome, not a conflict.

## Development and production parity

Registration behaves identically under both. The former development-only branch
in `deliverAuthEmail` (queue and continue in development, await and throw a 503
in production) no longer applies to registration: `deliverRegistrationEmail`
reports the result in every environment, waiting the same
`REGISTRATION_EMAIL_WAIT_MS` for it in both. `deliverAuthEmail` still serves
`resend-verification`, where a delivery failure is the whole outcome and
reporting it is correct.

## Why the response does not wait for the mail transport

The account, facility and verification code are committed at step 7. Holding the
HTTP response open through step 8 bought nothing — the user was already
registered and the code was already on its way — but it put the mail server's
latency in front of the user as a spinner on a form they had finished with, with
no way to reach the verification screen and type the code they had just
received.

So step 8 is awaited only up to `REGISTRATION_EMAIL_WAIT_MS` (default 3000). A
send that settles inside the budget still reports `SENT` or `FAILED` exactly as
before. One that does not returns `PENDING` immediately and keeps running; when
it settles, `updateRegistrationAttemptEmailStatus` writes the real status to the
attempt row, so a later status lookup or idempotent replay reports the truth
rather than the snapshot taken at response time. `completeRegistrationAttempt`
deliberately does not write `PENDING`, leaving the column on its default so the
background write cannot lose a race with it.

This is not a longer timeout and not a shorter one: it removes a wait the client
never needed to do.
