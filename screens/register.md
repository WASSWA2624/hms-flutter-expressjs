# Action inventory — `/register`

Primary surface: `RegisterPage` (`frontend/lib/features/auth/presentation/pages/register_page.dart`).

Public auth route under `AuthShellLayout`. No RBAC write gate (unauthenticated self-registration). Mutation: `register` via `authControllerProvider`.

Reachable nested route after success: `/verify-email?email=` (verification is the next required input).

Authenticated visitors are redirected away by route guards (auth entry routes).

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Page title **Create facility account** + primary **Create account** | Same create-goal wording on chrome and submit | **Split** — title is **Set up your facility**; single primary remains **Create account** |
| **Organization name** + **Facility name** | Two labels for one bootstrap workspace (backend `tenant_name` optional; uses `facility_name` when omitted) | **Removed** Organization name — facility name is the sole workspace name entry; `tenant_name` omitted from payload |
| Stale `authController` failure / identify / reset-submitted shells from sibling auth routes | Misleading banner on a fresh register visit | **Removed** — mount clears failure, identify tenants, and password-reset submitted |
| Parallel Create account controls | Same submit goal | **Kept** one `AuthPrimaryButton` only (keyboard done on location uses the same path) |

---

## Register screen

- **Create account** (primary)
  - Location: Form `AuthPrimaryButton` (`authRegisterActionLabel`).
  - Opens modal: No.
  - Immediate result: Validates admin name, email, password (min 8), facility name, facility type, phone; optional location. On success navigates to `/verify-email` with email. On failure stays on register with the failure banner.
  - Condition: Always shown (public route). Loading on the same control while submitting.

- **Back to sign in**
  - Location: Form `AuthTextLink` (`authBackToLoginActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/login`.
  - Condition: Disabled while submitting.

### Reachable after successful register — `/verify-email`

- Verification code entry / resend / back to sign in — owned by `/verify-email` (required next step after create; no intermediate success hub on `/register`).

### States

- Loading: primary button shows submitting; fields and back link disabled.
- Validation: required fields + email / phone / password rules before submit; inline field errors.
- Error / retry: failure banner on the form; edit fields or submit again (no separate retry control).
- Success: navigation to `/verify-email` (no success shell on `/register`).
- Empty / no-results: N/A (registration form). Unauthorized chrome: N/A (public).

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/auth/presentation/pages/register_page_test.dart` prove:
  - Exactly one **Create account** primary (`FilledButton`); one **Back to sign in**; title **Set up your facility**; no **Organization name**.
  - Fresh visit clears a stale sibling failure banner.
  - Back to sign in opens `/login`.
  - Validation failure stays on `/register`.
  - Successful register opens `/verify-email` with email and omits `tenant_name` from the mutation payload.
  - Narrow viewport + dark theme still show the primary Create account control.
