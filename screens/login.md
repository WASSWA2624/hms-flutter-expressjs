# Action inventory — `/login`

Primary surface: `LoginPage` (`frontend/lib/features/auth/presentation/pages/login_page.dart`).

Public auth route under `AuthShellLayout`. No RBAC write gate (unauthenticated entry). Mutation: `login` via `authControllerProvider`.

Reachable nested routes from this screen: `/forgot-password`, `/register`, and (on pending verification) `/verify-email`.

Authenticated visitors are redirected to `/` by route guards (auth entry routes).

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Page title **Sign in** + primary **Sign in** | Same label on chrome and the only submit control | **Split** — title is **Welcome back**; single primary remains **Sign in** |
| Decorative `Divider` between **Forgot password?** and **Create account** | Split the same secondary-link stack into fake sections | **Removed** — one secondary stack under **Sign in** |
| Stale `authController` failure / identify / reset-submitted shells from sibling auth routes | Misleading banner on a fresh login visit | **Removed** — mount clears failure, identify tenants, and password-reset submitted |
| Parallel Sign in controls | Same submit goal | **Kept** one `AuthPrimaryButton` only (keyboard submit uses the same path) |

---

## Login screen

- **Sign in** (primary)
  - Location: Form `AuthPrimaryButton` (`authLoginActionLabel`).
  - Opens modal: No.
  - Immediate result: Validates identifier + password; on success navigates to `from` (or `/` when absent / self). On `auth.account_pending`, opens `/verify-email` with email when the identifier is an email. On other failures (including `auth.account_pending_approval`), stays on login with the failure banner.
  - Condition: Always shown (public route). Disabled visually while submitting (loading on the same control).

- **Forgot password?**
  - Location: Form `AuthTextLink` (`authForgotPasswordActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/forgot-password`.
  - Condition: Disabled while submitting.

- **Create account**
  - Location: Form `AuthTextLink` (`authCreateAccountActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/register`.
  - Condition: Disabled while submitting.

### States

- Loading: primary button shows submitting; fields and secondary links disabled.
- Validation: required identifier / password before submit; inline field errors.
- Error / retry: failure banner on the form; edit fields or submit again (no separate retry control).
- Success: navigation away (no success shell on `/login`). Password-reset completion shows a one-shot banner when arriving from `/reset-password` (see `screens/reset-password.md`).
- Empty / no-results: N/A (credential form). Unauthorized chrome: N/A (public).

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/auth/presentation/pages/login_page_test.dart` prove:
  - Exactly one **Sign in** primary (`FilledButton`); one **Forgot password?**; one **Create account**; no `Divider`.
  - Fresh visit clears a stale sibling failure banner.
  - Forgot / Create account open their routes.
  - Validation failure stays on `/login`.
  - Wrong-password / account-not-found messages remain visible after failed login.
  - Pending account opens `/verify-email`.
  - Successful login leaves `/login`.
  - Narrow viewport + dark theme still show the primary Sign in control.
