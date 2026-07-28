# Action inventory — `/auth-required`

Primary surface: `AuthRequiredPage` (`frontend/lib/app/router/route_status_pages.dart`).

Public status route. Route guards send unauthenticated users to `/login` directly; this page is for explicit `/auth-required` visits (and optional `?from=`).

No write gates, dialogs, or mutations.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Primary **Go to dashboard** while copy asks to sign in | Home (then guard → login if signed out) | **Replaced** — single **Sign in** entry opens `/login` (preserves `from`) |
| Dashboard hop before login for signed-out users | Extra intermediate step | **Removed** — sign-in is one labeled tap |

---

## Auth-required status screen

- **Sign in** (primary)
  - Location: Page `AppStateScaffold` action (`authLoginActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/login`, forwarding `?from=` when present.
  - Condition: Always shown (public route; no unauthorized chrome).

- **Intended path** (`from` query)
  - Location: Progressive detail under the body when `from` is set.
  - Opens modal: No.
  - Immediate result: Shows the blocked destination; does not change navigation by itself.

No loading, empty, no-results, or validation surfaces — static status only. Retry/success belong to `/login` after sign-in.

---

## Verification (Req 7)

- Widget tests in `frontend/test/app/router/auth_required_page_test.dart` prove:
  - **Go to dashboard** is absent; exactly one **Sign in** primary control.
  - **Sign in** opens `/login` and preserves `from`.
  - Title/body copy remain visible on light/dark and narrow viewports.
