# Prompt — Auth Layout, Phone Input, and Session Continuity

## Context

- **Scope:** `auth-layout` — the shared authentication shell, the phone input used across auth and clinical forms, and end-to-end session/authorization coordination.
- **Surfaces:** all routes rendered inside `AuthShellLayout` (login, register, verify, forgot/reset password) plus any surface that shows an authorization failure after a successful sign-in.
- **Frontend entry points:** `frontend/lib/features/auth/presentation/widgets/auth_shell_layout.dart`, `frontend/lib/features/auth/presentation/widgets/auth_page_frame.dart`, `frontend/lib/shared/components/app_phone_field.dart`, `frontend/lib/core/security/`, `frontend/lib/core/network/api_interceptors.dart`, `frontend/lib/core/workspace/workspace_bootstrap_helpers.dart`.
- **Backend entry points:** `backend/src/modules/auth/`, the auth/CSRF middleware chain, and the patient registration route's authorization guard.
- **Rule sources:** `.cursor/authentication_session.mdc`, `frontend/docs/decisions/0003-auth-session-security-and-permissions.md`, `prompts/.cursor/responsiveness.mdc`, `prompts/.cursor/forms.mdc`, `prompts/.cursor/theming.mdc`, `prompts/.cursor/localization.mdc`.

Treat backend authorization as the source of truth. The frontend may only relax presentation, never the permission decision.

## Current Behavior (verified in code)

1. `AuthShellLayout` composes a full-bleed `Column`: `_AuthBrandHeader` band spanning 100% width, then an `Expanded` surface holding a `SingleChildScrollView`. The form is width-clamped (480 at `md`, 520 at `lg`+) but the **brand band and the surrounding surface still span the full viewport width** on desktop and tablet.
2. The form column is `Alignment.topCenter` inside the scroll view, so on tall desktop viewports it is horizontally centered but vertically top-anchored, with the surface fill extending beneath it.
3. `_AuthBrandHeader` already pins `AppLogo(size: brandHeight)` and the title `fontSize: brandHeight, height: 1.0` (28 compact / 36 otherwise), and `test/features/auth/presentation/widgets/auth_shell_layout_test.dart` asserts logo box height == title font size at 390×780 and 1280×800. Any residual mismatch is **optical** (transparent padding inside `assets/logos/logo.png`, aspect `AppLogo.defaultAspectRatio = 0.9798`), not layout math.
4. `AppPhoneField` → `_UnifiedPhoneInput` gives the country button a fixed width via `LayoutBuilder`: `104` under 360 px, `124` under 520 px, `148` otherwise. The button renders flag + `+<code>` + caret inside that fixed box with `TextOverflow.ellipsis`, so long dialling codes (e.g. `+1242`, `+1787`, `+3906`) are clipped on narrow viewports while the national-number field renders correctly.
5. Session plumbing exists: `SessionController`, `SessionRefreshCoordinator`, `AuthInterceptor` (401 → single refresh → replay), `CsrfInterceptor` (403 CSRF → refetch token → replay), and `normalizeWorkspaceBootstrapFailure`, which rewrites bootstrap 401s to `workspace.bootstrap_auth_unavailable` so the shell does not flash sign-in copy.
6. Despite (5), production shows `errorUnauthorizedMessage` ("Sign in again to continue.") to an authenticated clinical user attempting patient registration. The failure is therefore either (a) a 401 raised outside the bootstrap normalization path, (b) a refresh race on a mutation, (c) a CSRF/session-cookie mismatch surfaced as an auth failure, or (d) a genuine permission/entitlement denial mis-mapped to `AppFailureCategory.unauthorized` instead of `forbidden`. **Diagnose before changing behavior.**

## Requirements

### 1. Audit before writing code

- Trace the actual production failure for "register a patient while signed in as a doctor" across: `AuthInterceptor.onError`, `SessionRefreshCoordinator`, `network_failure_mapper.dart`, `validation_message_presenter.dart`, backend auth middleware, backend RBAC/entitlement guard, and the patient registration route.
- Record whether the backend returned 401 or 403, and with which error code, before proposing a fix. Do not "fix" it by widening the frontend's tolerance of 401s.
- Reuse existing session, permission, responsive, and design-system primitives. Do not add a second breakpoint helper, a parallel session store, a new phone-input widget, or a duplicate auth failure mapper.
- State the audit outcome in the change description: what already existed, what is extended, and what genuinely did not exist.

### 2. Constrain the auth shell horizontally on large screens

- On `md` and larger, the branded lockup **and** the form panel must occupy a single centered column no wider than the form measure (keep the existing 480/520 clamps unless the design token file says otherwise). They must not stretch edge to edge.
- The page backdrop (gradient) continues to fill the viewport; only the content column is constrained.
- On `xs`/`sm` the current full-width behavior is correct and must be preserved.
- The brand band and the form surface must remain visually one connected panel — same width, shared border/radius treatment, no gap or width step between them.

### 3. Make the auth panel span the viewport vertically

- On every breakpoint, the auth panel runs from the top to the bottom of the available `SafeArea` height, with the form content vertically centered inside it when the content is shorter than the viewport.
- When content exceeds the viewport, the panel scrolls and the content anchors to the top — no clipping, no unreachable submit button, no nested-scroll conflict. Use the established `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: constraints.maxHeight)` + `IntrinsicHeight`-free centering pattern; do not introduce `Expanded` inside a scrollable.
- Verify with the on-screen keyboard raised on mobile (viewport insets) and at 200% text scale.

### 4. Match logo and app-name height on all breakpoints

- Keep one `brandHeight` driving both the mark and the title (`height: 1.0` on the title so its line box equals its font size).
- Correct the remaining **optical** mismatch: either trim the transparent padding in the logo asset or apply a compensating scale/aspect constant in `AppLogo`. If the asset is regenerated, update `tool/generate_hosspi_logo.py` and `AppLogo.defaultAspectRatio` together.
- Cap-height alignment (not baseline drift) must hold at `xs`, `sm`, `md`, `lg`, and at 200% text scale.

### 5. Fix the country-code segment of `AppPhoneField`

- The country segment must size to its content — flag + full dialling code + caret — instead of the fixed `104/124/148` widths, so **every** dialling code including 4-digit codes renders in full on mobile, tablet, and desktop.
- Give the segment a sensible minimum width so short codes do not make the control jitter, and let the national-number field take the remaining space. Never let the dialling code ellipsize or clip.
- Preserve current behavior: digits-only input formatter, `LengthLimitingTextInputFormatter(maxNationalDigits)`, `commitPhoneToController`, external-controller hydration, the country picker dialog, the speech-to-text button, validation messages, and the `InputDecorator` floating-label geometry.
- The control must stay within the shared input height (`inputDecorationTheme.constraints.minHeight`) and satisfy `theme.appTokens.minInteractiveDimension` for the tap target.
- Verify at 320, 360, 390, 768, 1024, and 1440 px widths, in light and dark themes, with the longest catalog dialling code and the longest national number.

### 6. Make the session robust end to end

- **Correct the failure classification.** Backend permission/entitlement denials must return 403 with a specific code and map to `AppFailureCategory.forbidden`; only genuine authentication failures (missing/expired/invalid token) may return 401 and map to `unauthorized`. Fix whichever side is currently wrong for patient registration.
- **Serialize refresh across all in-flight requests.** A 401 on any request — including mutations and non-bootstrap calls — must funnel through the single refresh coordinator, replay once on success, and only clear the session when refresh genuinely fails. Concurrent 401s must produce exactly one refresh call.
- **Keep the CSRF path from masquerading as auth loss.** A CSRF token invalidated by a backend restart must be re-fetched and the request replayed (existing `CsrfInterceptor` behavior) without touching session state or surfacing sign-in copy.
- **Hydrate authorization before gating.** Do not render permission-denied or sign-in copy while `isAuthorizationHydrated` / `isModuleCatalogHydrated` is false or `needsMeEnrichment` is true; hold with a loading state until `/auth/me` resolves, then decide.
- **Distinguish the three user-facing outcomes** with distinct localized copy and distinct recovery affordances: session expired (re-authenticate), permission denied (contact admin; no sign-in prompt), module not entitled (subscription/plan message). A signed-in user must never see "Sign in again to continue." for a permission or entitlement problem.
- **Preserve session across reload and deep link.** Restoring from secure storage must re-hydrate permissions and entitlements before route guards evaluate, so a deep link to a permitted route does not bounce to login.
- Log auth decisions server-side with enough context (user, tenant, facility, permission, entitlement) to diagnose denials, without logging tokens.

### 7. Localization, theming, accessibility

- All new or changed copy goes to `frontend/lib/l10n/app_en.arb` with `@` metadata; no hard-coded UI strings.
- Semantics: the brand lockup stays a single header node; the country button keeps its `Semantics(button: true, label: '<label> <callingCode>')`; the number field keeps its text-field semantics and autofill hints.
- Verify light and dark themes at every breakpoint listed above.

### 8. Verification

- Extend `test/features/auth/presentation/widgets/auth_shell_layout_test.dart` with cases for the constrained content width on desktop/tablet, full-height panel, vertical centering of short content, and scroll-with-top-anchor for tall content.
- Add widget tests for `AppPhoneField` asserting the full dialling code is rendered (not ellipsized) for a 4-digit code at 320 px, and that the control height and validation are unchanged.
- Add frontend tests covering: single refresh under concurrent 401s, replay-after-refresh, 403 → forbidden copy (never sign-in copy), and route-guard hold while authorization is unhydrated.
- Add backend tests covering the patient-registration authorization path: authenticated + permitted → success; authenticated + not permitted → 403 with the documented code; unauthenticated/expired → 401.
- Run `flutter analyze`, the focused Flutter tests, and the affected backend tests. Report the actual results.

## Constraints

- Implement only this scope plus directly required shared support; exclude unrelated refactoring.
- Preserve all existing behavior not explicitly changed here — auth flows, validation, routing, deep links, restoration IDs, speech-to-text, and the country picker.
- Do not widen access, weaken a permission check, or auto-grant on ambiguity to make the error disappear.
- Do not log, persist, or surface tokens, and do not include token values in diagnostics.
- Do not introduce a second phone-input widget, breakpoint system, session store, or failure mapper.
- Do not change `AppLogo`'s public API or the logo asset without updating the generator script and the aspect constant together.

## Acceptance Criteria

- **AC1 (R1):** The production "sign-in required on patient registration" failure is traced to a named status code and code path, and the fix addresses that cause; the audit outcome is documented.
- **AC2 (R2):** At `md`+ the brand lockup and form share one centered column at the form measure; neither spans the full viewport width; `xs`/`sm` remain full width.
- **AC3 (R3):** The auth panel fills the viewport height at every breakpoint; short content is vertically centered, tall content scrolls from the top with the submit action reachable, including with the keyboard raised and at 200% text scale.
- **AC4 (R4):** The logo mark and app name are optically the same height at `xs`, `sm`, `md`, `lg`, and at 200% text scale, in light and dark themes.
- **AC5 (R5):** Every dialling code in the catalog, including 4-digit codes, renders in full at 320–1440 px with no clipping or ellipsis; national-number entry, validation, commit, and picker behavior are unchanged.
- **AC6 (R6):** Concurrent 401s trigger exactly one refresh; successful refresh replays the original request; failed refresh clears the session once and routes to sign-in.
- **AC7 (R6):** A signed-in user without a permission sees permission-denied copy, never sign-in copy; an unentitled module shows the entitlement message; only genuine authentication loss shows re-authentication copy.
- **AC8 (R6):** Reload and deep-link restoration re-hydrate permissions and entitlements before guards evaluate, and no permitted route bounces to login.
- **AC9 (R7):** All new copy is localized with metadata, semantics are preserved, and both themes verify at the listed breakpoints.
- **AC10 (R8):** `flutter analyze`, the focused Flutter tests, and the affected backend tests pass with no unrelated regressions, and results are reported as observed.

## Relevant Files

- `frontend/lib/features/auth/presentation/widgets/auth_shell_layout.dart`
- `frontend/lib/features/auth/presentation/widgets/auth_page_frame.dart`
- `frontend/lib/features/auth/presentation/pages/login_page.dart`
- `frontend/lib/features/auth/presentation/controllers/auth_controller.dart`
- `frontend/lib/shared/components/app_logo.dart`
- `frontend/lib/shared/components/app_phone_field.dart`
- `frontend/lib/core/responsive/app_breakpoints.dart`
- `frontend/lib/core/security/session_controller.dart`
- `frontend/lib/core/security/session_refresh_coordinator.dart`
- `frontend/lib/core/security/session_readiness.dart`
- `frontend/lib/core/security/auth_session.dart`
- `frontend/lib/core/network/api_interceptors.dart`
- `frontend/lib/core/network/network_failure_mapper.dart`
- `frontend/lib/core/errors/app_failure.dart`
- `frontend/lib/core/errors/validation_message_presenter.dart`
- `frontend/lib/core/workspace/workspace_bootstrap_helpers.dart`
- `frontend/lib/app/router/route_guards.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/auth/presentation/widgets/auth_shell_layout_test.dart`
- `frontend/test/features/auth/presentation/pages/login_page_test.dart`
- `frontend/test/core/security/auth_session_test.dart`
- `frontend/test/app/router/auth_required_page_test.dart`
- `frontend/integration_test/auth_shell_test.dart`
- `frontend/docs/decisions/0003-auth-session-security-and-permissions.md`
- `frontend/.cursor/authentication_session.mdc`
- `frontend/tool/generate_hosspi_logo.py`
