# Action inventory — `/reset-password`

Primary surface: `ResetPasswordPage` (`frontend/lib/features/auth/presentation/pages/reset_password_page.dart`).

Public auth route under `AuthShellLayout`. No RBAC write gate (unauthenticated recovery). Mutation: `resetPassword` via `authControllerProvider`.

Entry modes:
- **Link-token:** `?token=` (non–six-digit) → new password + confirm only.
- **Code:** no link token (optional `?email=` / six-digit `?token=` prefill) → email + reset code + new password + confirm.

Reachable nested surface after a successful reset: `/login` (success banner + sign-in form).

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Success hub **Password updated** + **Sign in** | Extra step after mutation already succeeded | **Removed** hub — successful reset opens `/login` (sign-in is the next required action) |
| Form **Back to sign in** vs success-hub **Sign in** | Same navigate-to-login goal on two shells | **Merged** — one abandon link on the form; success auto-navigates to login |
| Sticky `passwordResetCompleted` shell on revisit | Blocked using the form again | **Removed** with hub — login shows a one-shot banner then clears the flag |

---

## Reset-password screen

- **Reset password** (primary)
  - Location: Form `AuthPrimaryButton` (`authResetPasswordActionLabel`).
  - Opens modal: No.
  - Immediate result: Validates fields; calls `resetPassword` with link token **or** email+code; on success navigates to `/login`. On failure stays with failure banner.
  - Condition: Always shown. Loading on the same control while submitting.

- **Forgot password?** (resend / request code)
  - Location: Form `AuthTextLink` (`authForgotPasswordActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/forgot-password`.
  - Condition: Code mode only (`!_usesLinkToken`); disabled while submitting.

- **Back to sign in**
  - Location: Form `AuthTextLink` (`authBackToLoginActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/login`.
  - Condition: Always on the form; disabled while submitting.

- **Check-your-email banner** (from `/forgot-password`)
  - Location: Top of form when `passwordResetSubmitted` and code mode.
  - Immediate result: Confirms instructions were sent; user continues on the same surface.

### Reachable after successful reset — `/login`

- **Success banner** (`authResetPasswordCompletedTitle` / `Body`)
  - Location: Top of login form (one-shot local flag after reading `passwordResetCompleted`).
  - Immediate result: Confirms password changed; user signs in on the same surface (no empty intermediate shell).

### States

- Loading: primary button shows submitting; fields and secondary links disabled.
- Validation: required / min-length / mismatch / invalid code before submit; inline field errors.
- Error / retry: failure banner on the form; edit fields and submit again.
- Success: navigation to `/login` with success banner (no password-updated hub).
- Empty / no-results: N/A (credential form). Unauthorized chrome: N/A (public).

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/auth/presentation/pages/reset_password_page_test.dart` prove:
  - Code mode shows one **Reset password** primary, **Forgot password?**, and **Back to sign in**; no **Password updated** hub / **Enter reset code**.
  - Link-token mode omits email/code and **Forgot password?**; still one primary + **Back to sign in**.
  - Successful reset opens `/login` with the success banner (no reset success hub).
  - Validation failure stays on `/reset-password`.
  - Invalid token / API failure keeps the form and shows the failure message.
  - Narrow viewport + dark theme still show the primary reset control.
- Check-your-email banner after forgot send is covered by `forgot_password_page_test.dart`.
