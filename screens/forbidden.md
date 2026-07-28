# Action inventory — `/forbidden`

Primary surface: `ForbiddenPage` (`frontend/lib/app/router/route_status_pages.dart`).

Public status route. Route guards send users here for (1) authenticated access denial on a protected route, or (2) `SessionStatus.forbidden`. Optional `?from=` names the blocked destination.

No write gates, dialogs, or mutations.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Primary **Go to dashboard** while session is forbidden | Home → guard → `/forbidden` loop | **Replaced** — single **Sign in** entry opens `/login` (preserves `from`) |
| Access-requirement denial copy for non-authenticated / session-forbidden | Misleading permission/module text | **Removed** — generic `routeForbiddenBody` only when not authenticated |
| Parallel Sign in + Go to dashboard | Two recovery goals | **Merged** — exactly one primary by session: Sign in XOR Go to dashboard |

---

## Forbidden status screen

- **Go to dashboard** (primary, authenticated denial)
  - Location: Page `AppStateScaffold` action (`commonGoHomeActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/`.
  - Condition: `sessionState.isAuthenticated`; omitted when session is forbidden / unsigned-in.

- **Sign in** (primary, session forbidden)
  - Location: Page `AppStateScaffold` action (`authLoginActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/login`, forwarding `?from=` when present.
  - Condition: Not authenticated (includes `SessionStatus.forbidden`); omitted when authenticated.

- **Intended path** (`from` query)
  - Location: Progressive detail under the body when `from` is set.
  - Opens modal: No.
  - Immediate result: Shows the blocked destination; does not change navigation by itself.

- **Denial reason** (body)
  - Location: Page body text.
  - Opens modal: No.
  - Immediate result: Authenticated + matched `from` route → `accessRequirementDenialMessage`; otherwise generic `routeForbiddenBody`.

No loading, empty, no-results, or validation surfaces — static status only. Retry/success belong to `/` or `/login` after the primary action.

---

## Verification (Req 7)

- Widget tests in `frontend/test/app/router/forbidden_page_test.dart` prove:
  - Authenticated denial: exactly one **Go to dashboard**; **Sign in** absent; opens `/`.
  - Session forbidden: exactly one **Sign in**; **Go to dashboard** absent; opens `/login` and preserves `from`.
  - Session forbidden does not show access-requirement copy for a matched `from` route.
  - Title/body remain visible on light/dark and narrow viewports.
