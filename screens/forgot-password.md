# Action inventory — `/forgot-password`

Primary surface: `ForgotPasswordPage` (`frontend/lib/features/auth/presentation/pages/forgot_password_page.dart`).

Public auth route under `AuthShellLayout`. No RBAC write gate (unauthenticated recovery). Mutation: `requestPasswordReset` → identify (when needed) + `forgotPassword`.

Reachable nested surface after a successful send: `/reset-password` (success banner + code/new-password form).

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Success hub **Enter reset code** + **Back to sign in** | Two next steps after send | **Removed** hub — successful send opens `/reset-password?email=` (code entry is the next required input) |
| Sticky `passwordResetSubmitted` success shell on revisit | Blocked a new request | **Removed** — fresh visit clears submitted / tenant state |
| Stale multi-tenant list after email edit (hid **Send**) | Wrong workspaces / no resend | **Removed** — email change clears `identifyTenants`; **Send** returns |
| Tenant rows as secondary-only chrome | Same submit goal | **Merged** — each workspace is the single labeled primary for that choice |

---

## Forgot-password screen

- **Send reset instructions** (primary)
  - Location: Form `AuthPrimaryButton` (`authForgotPasswordSubmitLabel`).
  - Opens modal: No.
  - Immediate result: Validates email; identify → auto-send when one tenant; on success navigates to `/reset-password` with email. When multiple tenants, shows workspace choices instead of this button.
  - Condition: Shown when `identifyTenants.length <= 1`; omitted while a workspace choice is required.

- **Choose workspace** (primary per tenant)
  - Location: Form list after identify returns 2+ tenants (`authForgotPasswordTenantPrompt`).
  - Opens modal: No.
  - Immediate result: Sends reset for that `tenantId`; on success navigates to `/reset-password` with email.
  - Condition: Only when multiple tenants match the email.

- **Back to sign in**
  - Location: Form `AuthTextLink` (`authBackToLoginActionLabel`).
  - Opens modal: No.
  - Immediate result: Navigates to `/login`.
  - Condition: Always on the form; disabled while submitting.

### Reachable after successful send — `/reset-password`

- **Success banner** (`authForgotPasswordSubmittedTitle` / `Body`)
  - Location: Top of reset form when `passwordResetSubmitted` and not link-token mode.
  - Immediate result: Confirms instructions were sent; user enters code + new password on the same surface.

- **Back to sign in** / reset submit — owned by `/reset-password` (see that screen’s inventory).

### States

- Loading: primary / workspace buttons show submitting.
- Validation: required / invalid email before send.
- Error / retry: failure banner on the form; edit email and send again.
- Success: banner on `/reset-password` after navigation (no empty intermediate shell).
- Empty / no-results: N/A (single email field). Unauthorized chrome: N/A (public).

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/auth/presentation/pages/forgot_password_page_test.dart` prove:
  - Form shows one **Send reset instructions** primary and **Back to sign in**; no success-hub **Enter reset code**.
  - Successful send opens `/reset-password` with email and shows the success banner (no forgot success hub).
  - Multi-tenant: **Send** hidden; one primary per workspace; choosing one completes send → reset route.
  - Changing email after tenants appear restores **Send** (stale tenant chrome gone).
  - Validation failure stays on `/forgot-password`.
  - Narrow viewport + dark theme still show the primary send control.
