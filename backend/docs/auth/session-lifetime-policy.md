# Session lifetime and persistence

How a signed-in session survives a closed app, a dead network, and an expired
access token — and the only four things that may end it.

Companion to [`registration-transaction-map.md`](registration-transaction-map.md).
Migration notes: [`20260911140000_session_lifetime_policy.md`](../migrations/20260911140000_session_lifetime_policy.md).

## The rule

**An expired access token is a normal, recoverable event.** It is not an error,
not a sign-out, and never reaches the user. The client refreshes and replays the
request.

A session ends only when:

1. the refresh token is invalid, already rotated, or revoked;
2. the user logs out;
3. the chain breaches the idle timeout; or
4. the chain breaches the absolute timeout.

Everything else — a 5xx, a timeout, an offline device, a CSRF failure, a dropped
connection mid-workflow — leaves the stored credentials in place and the session
usable once connectivity returns.

## The four limits

All four are configuration, never `NODE_ENV`. Development and production must
carry identical values; the policy resolves them in
[`backend/src/config/session-policy.js`](../../src/config/session-policy.js).

| Limit | Key | Default | What it bounds |
| ----- | --- | ------- | -------------- |
| Access-token TTL | `JWT_ACCESS_TOKEN_EXPIRATION` | `15m` | How long a bearer token is accepted. Expiry is recoverable. |
| Refresh-token TTL | `AUTH_SESSION_TTL_DAYS` | `7` | How long one issued refresh token stays usable. Rotation restarts it. |
| Idle timeout | `AUTH_SESSION_IDLE_TIMEOUT_MINUTES` | `10080` (7 days) | How long a chain may go **without a successful refresh**. |
| Absolute timeout | `AUTH_SESSION_ABSOLUTE_TIMEOUT_HOURS` | `720` (30 days) | Hard ceiling from the original sign-in. Rotation cannot push past it. |

Idleness is the gap between *refreshes*, not the gap between requests and not an
expired access token. A user working continuously is never signed out by the
idle rule.

The absolute timeout is the limit that did not exist before: each refresh used to
reset `expires_at` to `now + AUTH_SESSION_TTL_DAYS`, so a chain that kept
refreshing never expired at all.

## Refresh chains

`POST /api/v1/auth/refresh` **rotates**: it revokes the presented session row and
writes a new one with a new refresh token. The chain is the sequence of rows this
produces.

```
login ──► session A ──refresh──► session B ──refresh──► session C
          chain_started_at = T          inherited = T          inherited = T
          last_used_at     = T          reset to T+1h          reset to T+3h
          expires_at = min(now + refresh TTL, T + absolute timeout)
```

- `chain_started_at` is inherited by every rotation — the absolute deadline is
  anchored to the login.
- `last_used_at` resets on every rotation — the idle window restarts.
- `expires_at` is clamped to the absolute deadline, so the last token in a chain
  expires exactly at the ceiling rather than past it.

A revoked chain writes a `SESSION_POLICY_REVOKED` audit entry carrying the reason
(`idle_timeout` or `absolute_timeout`), and the client receives HTTP 401 with
`errors.auth.session_idle_timeout` or `errors.auth.session_absolute_timeout`.

## Client side

| Concern | Where | Behaviour |
| ------- | ----- | --------- |
| Storage | `core/storage/secure/app_secure_storage.dart` | Per-platform mechanism, pinned explicitly — see the table in `AppSecureStorageOptions`. |
| Startup restore | `app/startup/app_startup_initializer.dart` | Reads tokens and decides the session **before `runApp`**, so no frame renders an unauthenticated view for a valid session. |
| Readiness | `core/security/session_state.dart` | `unknown` → `authenticated` / `unauthenticated`. Routes wait on `unknown` rather than redirecting. |
| Single-flight refresh | `core/security/session_refresh_coordinator.dart`, `session_token_provider.dart` | Concurrent 401s share one refresh; queued callers replay with the new token. Necessary because rotation invalidates the old refresh token — parallel refreshes would kill each other. |
| Failure triage | `core/security/session_refresh_service.dart` (`isSessionRejectionFailure`) | Only `unauthorized`/`forbidden` end the session. Network, timeout, offline and 5xx keep the tokens. |
| Logout | `core/security/session_controller.dart` + `session_isolation.dart` | Revokes server-side, clears secure storage, then disposes caches, realtime connections and user-scoped local data. |

### Storage per platform

Stated in full in the `AppSecureStorageOptions` doc comment. Summary:

| Platform | Mechanism | Survives close | Survives reboot |
| -------- | --------- | -------------- | --------------- |
| Web | `localStorage`, AES-GCM encrypted | Yes | Yes |
| Android | SharedPreferences + AES-GCM data key wrapped by an RSA-OAEP KeyStore key | Yes | Yes |
| Windows | DPAPI credential store, per Windows user | Yes | Yes |
| iOS / macOS | Keychain, `kSecAttrAccessibleAfterFirstUnlock` | Yes | After first unlock |
| Linux | libsecret (GNOME Keyring / KWallet) | Yes | Once the keyring unlocks |

Tokens are never written to preferences, URLs, or logs. `SessionTokens.toString`
redacts both token values.

## Tuning

Lowering either timeout tightens security and shortens sessions; both must be
changed in `.env.development` **and** `.env.production` together, or the two
environments stop behaving identically. Changing a value takes effect on the next
refresh — the policy is read per call, not captured at boot, and deadlines are
computed from the stored anchors rather than baked into rows.
