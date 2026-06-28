# Auth Layout, Branding, and Forms — Implementation Prompt

## Objective

Refine **all unauthenticated auth screens** in HOSSPI HMS so branding, layout, form controls, and password-reset delivery are consistent, responsive, and polished across every device and screen size.

**Scope:** shared auth shell + form UX on login, register, forgot password, reset password, and verify email.

**Source of truth:**

1. [prompts/01-auth-module-prompt.md](./prompts/01-auth-module-prompt.md) — auth module boundaries and full-page auth exception
2. [frontend/.cursor/layouts.mdc](./frontend/.cursor/layouts.mdc) — breakpoints and responsive rules
3. [frontend/.cursor/design-system.mdc](./frontend/.cursor/design-system.mdc), [components.mdc](./frontend/.cursor/components.mdc), [ui-patterns.mdc](./frontend/.cursor/ui-patterns.mdc)

---

## Problem Statement (current gaps)

From the live auth screens:

| Issue | Current behavior | Target behavior |
| ----- | ---------------- | --------------- |
| Branding placement | `AppLogo` is duplicated inside each page/form card | Logo + app name live in a **shared auth shell**, not inside the form |
| Layout consistency | Each page builds its own `Scaffold` + centered column | One reusable **auth layout** wraps all auth routes |
| Field labels | External labels above inputs (`AppTextField` uses `FloatingLabelBehavior.never`) | **Floating labels** inside inputs to reduce vertical space |
| Secondary actions | “Forgot password?”, “Create account”, “Back to sign in” use `AppButton.tertiary` | Styled as **standard text links** (primary/link color, underline on hover for web) |
| Required fields | Asterisks inconsistent; some required fields lack `isRequired: true` | Every required field shows `*`; optional fields show “(optional)” where appropriate |
| Password reset email | Sends **link only** (`sendPasswordResetEmail` in `auth.service.js`) | Send **link + short code** (same dual-path pattern as email verification) |
| Reset password UI | Requires URL `token` query param; no manual code entry | User can reset via **link** or by entering **email + code** on `/reset-password` |
| Phone field | Country picker shows `Icons.public_outlined` + dial code — **no flags** | Country **flag** visible in picker trigger and list rows |
| Responsiveness | Single centered card at fixed max width | Adaptive layout for `xs` through `xxl` breakpoints |

---

## Global Implementation Standards

| Area | Requirement |
| ---- | ----------- |
| Product scope | Auth entry screens remain **full-page routes** (exception to modal-first). Post-login actions stay modal. |
| UI/UX | Modern, minimal, hospital workflow language. Reuse `frontend/lib/shared/*` before new widgets. Responsive on Android, iOS, web, Windows, macOS, Linux. |
| Theming and i18n | Light/dark/system themes. All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Architecture | Widgets → Riverpod controllers → repository → API. No API calls from widgets. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched auth modules. |

---

## 1. Shared Auth Shell (layout + branding)

### Create `AuthShellLayout` (or equivalent)

**Location:** `frontend/lib/features/auth/presentation/widgets/` or `frontend/lib/shared/layout/`

Wrap all auth routes in a single shell via `go_router` `ShellRoute` (preferred) or a shared widget used by every auth page.

**Routes in scope:**

- `/login`
- `/register`
- `/verify-email`
- `/forgot-password`
- `/reset-password`

Reference: `AppRouteData.isAuthEntryRoute` in `app_routes.dart` — extend to include `verifyEmail` if missing.

### Branding rules

Branding comes from app config / l10n, **not** from individual forms:

| Source | Usage |
| ------ | ----- |
| `AppConfig.appName` / `l10n.appTitle` | Full app name on large screens |
| `l10n.appShortTitle` | Short name on small screens (e.g. “HOSSPI HMS”) |
| `AppLogo` | Logo from `AppConfig.appLogoUrl` |

**Remove** per-page `AppLogo` from form/card content. The shell owns branding.

### Responsive layout

Follow [layouts.mdc](./frontend/.cursor/layouts.mdc) breakpoints:

| Breakpoint | Shell layout |
| ---------- | ------------ |
| `≥ lg` (840px+) | **Horizontal brand bar:** logo on the left, full app name immediately to its right. Form/content area below or beside (centered, readable max width). |
| `< lg` | **Stacked brand header:** logo, then short app name (`appShortTitle`), then page title + subtitle, then form fields. |
| All sizes | SafeArea, scroll when content overflows, sensible horizontal padding from `theme.spacing`. |

### Page content structure (inside shell)

Each auth page supplies only:

1. **Page title** (e.g. “Sign in”, “Create facility account”, “Reset your password”)
2. **Optional subtitle/body** (one short line)
3. **Form fields + primary action**
4. **Secondary links** (not buttons)

Do **not** repeat logo or full app name inside the form card.

---

## 2. Form fields — floating labels and validation

### Floating labels

Update shared form components so auth screens use **Material floating labels** consistently:

| Component | File | Change |
| --------- | ---- | ------ |
| `AppTextField` | `shared/components/app_text_field.dart` | Add opt-in `useFloatingLabel` (default `false` globally; **enable in auth** or flip default after auditing non-auth usage). When enabled: use `labelText` on `InputDecoration`, set `floatingLabelBehavior: FloatingLabelBehavior.auto`, remove external `AppFieldLabel` above the field. |
| `AppEmailField` | `shared/forms/` | Same floating-label behavior |
| `AppSelectField` | `shared/forms/` | Match floating-label pattern (already partially similar on register) |
| `AppPhoneField` | `shared/components/app_phone_field.dart` | Floating label for the number input; country selector aligned with field height |

**Required field indicator:** show asterisk on the floating label (via `appFieldLabelWidget` / `isRequired: true`), not as a separate row above the field.

### Validation

Keep existing `AppValidators` patterns. Ensure:

- Required fields: `isRequired: true` + validator
- Email: format validation via `AppEmailField`
- Password: min length 8 on register/reset
- Confirm password: match validator on reset
- Phone (optional on register): validate format when non-empty
- Submit triggers `AutovalidateMode.onUserInteraction` after first failed submit (existing pattern)

### Auth pages to update

| Page | File |
| ---- | ---- |
| Login | `features/auth/presentation/pages/login_page.dart` |
| Register | `features/auth/presentation/pages/register_page.dart` |
| Forgot password | `features/auth/presentation/pages/forgot_password_page.dart` |
| Reset password | `features/auth/presentation/pages/reset_password_page.dart` |
| Verify email | `features/auth/presentation/pages/verify_email_page.dart` |

---

## 3. Link styling for secondary actions

Replace `AppButton.tertiary` for navigation-style actions with a shared **`AuthTextLink`** (or `AppTextLink`) widget:

| Screen | Actions |
| ------ | ------- |
| Login | “Forgot password?”, “Create account” |
| Register | “Back to sign in” |
| Forgot password | “Back to sign in” |
| Reset password | “Back to sign in” |
| Verify email | “Back to sign in”, resend link (if present) |

**Style:**

- Color: `theme.colorScheme.primary` (or design-system link token)
- Font: `bodyMedium`, normal weight
- Web/desktop: underline on hover
- Adequate tap target on mobile (min 48dp height via padding)
- Disabled while `isSubmitting`

---

## 4. Password reset — link **and** code (backend + frontend)

### Current behavior

- **Email verification (register):** sends a **6-digit code** (`buildVerificationEmailMessage`)
- **Password reset:** sends **link only** (`sendPasswordResetEmail` → `buildResetPasswordLink`)

### Target behavior

Password reset should mirror verification: email contains **both**:

1. **Reset link** — `{baseUrl}/reset-password?token={token}&email={email}`
2. **Reset code** — 6-digit numeric code (same format/storage pattern as email verification)

User can complete reset by either path:

| Path | Flow |
| ---- | ---- |
| Link | Open link → `/reset-password?token=…` → enter new password |
| Code | Go to `/reset-password` (or `/forgot-password` success state) → enter email + code + new password |

### Backend (`backend/src/modules/auth/`)

1. When creating password-reset token, also generate/store a **6-digit code** (reuse verification token model if it supports `code`, or extend schema if needed).
2. Update `sendPasswordResetEmail` HTML/text templates to include the code prominently (match verification email styling).
3. Add or extend API: `POST /auth/reset-password` accepts `{ token, new_password }` **or** `{ email, code, new_password, tenant_id? }`.
4. Add i18n keys under `messages.auth.password_reset.*` for code copy.
5. Keep generic “email sent” response (no account enumeration).

### Frontend

1. **Forgot password submitted state:** tell user to check email for **link or code**.
2. **Reset password page:** support both modes:
   - Token from query param (existing)
   - Manual entry: email + code fields when no token (similar to `VerifyEmailPage`)
3. Update `auth_controller`, repository, and DTOs for code-based reset.
4. Localize all new strings in `app_en.arb`.

### Register / verify email

Registration already sends a verification **code**. Confirm the verify-email page and success copy mention the code clearly. Optionally add a verification **link** in the registration email (same dual-path UX as password reset) if not already present — align both flows for consistency.

---

## 5. Phone field — country flags

**File:** `frontend/lib/shared/components/app_phone_field.dart`

**Problem:** `_PhoneCountryButton` and picker rows use `Icons.public_outlined` instead of country flags.

**Fix:**

1. Render ISO country flags in the country selector button and picker list (e.g. emoji flags from `IsoCode`, or a small flag asset/icon package if already in `pubspec.yaml` — prefer zero new dependencies if emoji works on all targets).
2. Verify flags render on **web, Android, iOS, and desktop** (test Windows specifically — common emoji/font gap).
3. Keep calling code visible alongside the flag.
4. Ensure picker search still works by country name, ISO code, and dial code.

---

## 6. Router integration

Use a **`ShellRoute`** in `app_router.dart` for auth paths so the shell persists across navigation:

```
AuthShellLayout
├── /login
├── /register
├── /verify-email
├── /forgot-password
└── /reset-password
```

Child routes render in the shell’s content slot. Branding does not remount on route change.

Update `isAuthEntryRoute` (or add `isAuthShellRoute`) to include `verifyEmail`.

---

## 7. Responsive form card

| Breakpoint | Form container |
| ---------- | -------------- |
| `< md` | Full width minus padding; optional subtle card or flat surface |
| `md–lg` | `maxWidth: 480–520` centered |
| `≥ lg` | `maxWidth: 420–480`; brand bar spans full width above form |

Login may keep a card on large screens; register may use slightly wider max width. Both share the same shell branding.

---

## Acceptance Criteria

- [ ] All five auth routes share one shell; logo + app name never appear inside the form card.
- [ ] Large screens: logo left, full app name right of logo in shell header.
- [ ] Small screens: logo → short app name → page title → fields.
- [ ] All auth inputs use floating labels with correct required `*` indicators.
- [ ] Secondary navigation uses blue/link styling, not tertiary buttons.
- [ ] Password reset email includes link **and** 6-digit code; reset page supports both paths.
- [ ] Register/verify flow copy and UX aligned with dual-path pattern where applicable.
- [ ] Phone field shows country flags in selector and picker on all platforms.
- [ ] Forms validate correctly; loading/disabled states during submit.
- [ ] Light/dark themes; all strings localized.
- [ ] `flutter analyze` and `flutter test` pass; backend auth tests pass for reset changes.

---

## Files to touch (starting points)

| Area | Paths |
| ---- | ----- |
| Auth shell (new) | `frontend/lib/features/auth/presentation/widgets/auth_shell_layout.dart` |
| Auth pages | `frontend/lib/features/auth/presentation/pages/*.dart` |
| Router | `frontend/lib/app/router/app_router.dart`, `app_routes.dart` |
| Form components | `frontend/lib/shared/components/app_text_field.dart`, `app_phone_field.dart`, `shared/forms/*` |
| Link widget (new) | `frontend/lib/features/auth/presentation/widgets/auth_text_link.dart` or `shared/components/` |
| Backend reset | `backend/src/modules/auth/services/auth.service.js`, routes, schemas, i18n messages |
| Localization | `frontend/lib/l10n/app_en.arb` |
| Tests | `frontend/test/features/auth/**`, `frontend/test/shared/components/app_phone_field_test.dart`, backend auth tests |

---

## Out of scope

- MFA, OAuth, or phone-SMS verification
- Authenticated shell / workspace layout changes
- Post-login change-password dialog (already modal)
