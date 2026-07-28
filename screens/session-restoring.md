# Action inventory — `/session-restoring`

Primary surface: `SessionRestoringPage` (`frontend/lib/app/router/route_status_pages.dart`).

Public waiting route. Route guards send users here when a protected route is requested while `SessionStatus` is still unknown. Optional `?from=` names the intended destination; resume is automatic when the session becomes ready (`AppRouteGuards`).

No write gates, dialogs, mutations, or user-driven recovery controls.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Primary **Go to dashboard** while copy says session is still checking | Home (often loops back to this page while unknown, or skips `from`) | **Removed** — wait-only loading surface; no parallel exit CTA |
| Manual dashboard hop instead of resume after restore | Extra step; ignored intended `from` | **Removed** — guard resumes `from` (or home) when session is ready; login/forbidden when unsigned-in |

---

## Session-restoring status screen

- **Wait for session restore** (sole task)
  - Location: Page `AppStateScaffold` with `AppStateViewVariant.loading` (`routeSessionRestoringTitle` / `routeSessionRestoringBody`).
  - Opens modal: No.
  - Immediate result: Shows branded loading; no action button.
  - Condition: Always shown on this route while session is unknown (public; no unauthorized chrome).

- **Automatic resume** (guard, not a control)
  - Location: `AppRouteGuards.redirect` when path is `/session-restoring` and session is ready.
  - Opens modal: No.
  - Immediate result: Authenticated → `from` (or `/`); unauthenticated → `/login` with `from`; forbidden session → `/forbidden` with `from`. Absolute/`from` loops to this route fall back to `/`.

No empty, no-results, validation, or retry surfaces — waiting only. Success is leaving this route via the guard after restore.

---

## Verification (Req 7)

- Widget tests in `frontend/test/app/router/session_restoring_page_test.dart` prove:
  - Loading title/body visible; **Go to dashboard** / **Sign in** absent; `AppLoadingIndicator` present.
  - Renders on light/dark and narrow viewports.
- Guard tests in `frontend/test/app/router/route_guards_test.dart` prove:
  - Unknown session stays on `/session-restoring`.
  - Authenticated resume opens `from` (or home when missing/unsafe).
  - Unauthenticated / forbidden resume opens login / forbidden with `from`.
