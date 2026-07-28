# Simplify inventory — `/verify-email`

Primary surface: `VerifyEmailPage` (`frontend/lib/features/auth/presentation/pages/verify_email_page.dart`).

Public auth route under `AuthShellLayout`. No RBAC write gate (unauthenticated verification). Mutations via `AuthController`: `verifyEmail`, `resendEmailVerification`.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Post-verify **Email verified** hub + **Sign in** + **Back to sign in** | Two login exits after verify | **Removed** hub — successful verify goes straight to `/login` with one SnackBar |
| Dead `!_awaitingPlatformApproval` Login branch | Never shown | **Removed** with hub |
| Shared auth failure / reset shells bleeding onto fresh visit | Stale banners | **Cleared** on first frame via auth controller clears |

---

## Verify-email screen

### Form (only surface)

- **Verify** (primary)
  - Location: Form `AuthPrimaryButton` (`authVerifyEmailActionLabel`).
  - Opens modal: No.
  - Immediate result: Validates 6-digit code; on success navigates to `/login` and shows verified + awaiting-approval SnackBar once.
  - Condition: Disabled while submitting/resending.

- **Send new code** (secondary)
  - Location: Form `AppButton.secondary` (`authSendNewCodeActionLabel`).
  - Opens modal: No.
  - Immediate result: Resends verification email; shows resent banner on this page.
  - Condition: Requires email query; disabled while busy; disabled when email missing.

- **Back to sign in**
  - Location: Form `AuthTextLink` (`authBackToLoginActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/login` without verified SnackBar.
  - Condition: Disabled while busy.

No nested dialogs. No post-verify hub on this route.
