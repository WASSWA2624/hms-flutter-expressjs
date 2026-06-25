# Authentication and Session Module — Implementation Prompt

## Objective

Complete **Authentication and Session** for HOSSPI HMS: login, logout, registration, email verification, session restoration, token refresh, password changes, secure route guards, and tenant account approval — the security gateway before any OPD, IPD, or admin workflow.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Authentication and session row; Main Setup Flow step 1–6
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §5 no patient-flow actions without authenticated staff session
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — same; all IPD APIs require auth + entitlements

**Central rule:** unauthenticated users see only auth routes. Session carries tenant, facility, roles, permissions, and entitlements used by all modules. Login, registration, and email verification are **full-page auth screens** (exception to modal-first rule); post-login clinical and admin work follows modal-first workspace patterns.

---

## Global Implementation Standards

Mandatory platform rules for all work in this module.

| Area | Requirement |
| ---- | ----------- |
| Product scope | [app-write-up.mdc](../.cursor/app-write-up.mdc) — respect module boundaries; do not duplicate workflows owned elsewhere. |
| Patient flows | Align with [`.cursor/flows/`](../.cursor/flows/). Use [opd-flow.mdc](../.cursor/flows/opd-flow.mdc) and [ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) for journey touchpoints; read the module-specific flow file when one exists (lab, nursing, pharmacy, radiology, discharge, emergency, icu, theater). |
| Encounters | One active OPD encounter per outpatient visit; IPD admission as inpatient hub; overlays (ICU, Theater) and executing departments attach — never parallel admission records. |
| UI/UX | Modern, clean, minimal on-screen text; hospital workflow language (not enum names or UUIDs). Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`, `platform_guidelines.mdc`. Reuse `frontend/lib/shared/*` before creating new widgets. Responsive on Android, iOS, web, Windows, macOS, Linux. |
| Theming and i18n | Full theme support (light/dark/system). All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Modal-first workflows | **All create/edit/approve/complete/handoff actions** use **in-page dialogs, bottom sheets, or nested modals**. Do **not** navigate to new routes for within-module workflows. Shell entry routes (`/opd`, `/ipd`, etc.) and deep-link **pre-selection** of a patient/record are allowed; selecting a row opens the workspace detail panel — not a separate workflow page. |
| Realtime sync | Subscribe to relevant `RealtimeEventGroups` in workspace controllers. After mutations, refresh affected rows, detail panels, summary cards, and nav badges. Keep UI, frontend state, backend services, and database consistent. |
| Architecture | UI/controllers → repository → API (`frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`). Enforce RBAC + ABAC + tenant/facility scope + module entitlements (frontend `AccessGate` + backend authorization). |
| Database | Apply migrations for schema changes per backend standards; keep API contracts and schema aligned. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched modules. |

---


## Flow Integration Requirements

### OPD / IPD

| Concept | Auth responsibility |
| ------- | ----------------- |
| Route guards | `/opd`, `/ipd`, and all clinical routes require valid session + permissions |
| Registration bootstrap | `register` may create tenant/facility/admin — leads to setup flow |
| Session refresh | Silent refresh; logout on hard failure — no stale clinical actions |
| Entitlements | Module flags from subscription gate `opd-flow`, `ipd-flows`, etc. |

### App write-up

- Tenant account approval workflow when registration requires admin approval.
- Demo accounts from seed data must login with documented credentials in non-production.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/auth/` | login, register, verify-email, change-password dialog |
| Core | `session_manager`, `session_refresh_service`, `auth_session` | Token handling |
| Backend | `backend/src/modules/auth/` | login, register, refresh, logout, change-password, verify-email |
| Router | `app_router.dart` | Redirect unauthenticated users |
| APIs | `POST /auth/login|register|refresh|logout|change-password|verify-email` | `GET /auth/me`, CSRF |

### Known gaps

- No forgot/reset-password UI (backend may exist)
- No MFA, OAuth, or phone verification UI
- Profile page does not refresh from `/auth/me` ([prompts/06-settings-profile-module-prompt.md](./06-settings-profile-module-prompt.md))
- Limited frontend tests for session edge cases
- Tenant approval state UX after registration

---

## Scope — Core Capabilities

1. **Login / logout** — identifier + password; facility/tenant context when required.
2. **Registration** — tenant/facility bootstrap; email verification flow.
3. **Session restore** — app start refresh; secure storage of tokens.
4. **Password change** — authenticated change-password dialog.
5. **Route protection** — guards on all authenticated routes; permission-aware redirects.

---

## UI / UX Requirements

- **Full-page auth screens** — login, register, email verification, and forgot/reset password are standalone full-page routes. This is the documented **exception** to modal-first: only the auth entry screens are full-page; once authenticated, all actions follow modal-first workspace patterns.
- Clean, centered single-column layout with HOSSPI HMS branding/logo, a focused form card, and clear primary/secondary calls to action — no worklist, no summary cards.
- Validated forms with inline field validation, explicit error states, and loading/disabled states during submit. Reuse shared field widgets (`frontend/lib/shared/components/app_text_field.dart`, `app_field_error_text.dart`, `app_button.dart`).
- Post-login security actions (e.g. **change password**) are modal — use the in-page `change_password_dialog`, not a separate route.
- Full theming (light/dark/system), all strings localized via `app_en.arb`, responsive across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Pattern peers: other full-page entry screens, not clinical worklist workspaces.

---


## Architecture and Conventions

| Rule | Requirement |
| ---- | ----------- |
| Layering | Widgets → Riverpod controllers → repository interface → impl → API client. No API calls from widgets. |
| State | `AsyncNotifier` + `Result<T>` / `AppFailure` for errors. |
| Permissions | `AccessGate` / `AppAccessActionGate`; backend auth mandatory even when UI hides actions. |
| File size | Extract reusable widgets to `presentation/widgets/`; shared components to `frontend/lib/shared/`. |
| Realtime | `frontend/.cursor/realtime_sync.mdc` — partial refresh after modal success when supported. |

---


## Acceptance Criteria

- [ ] Login → session → home/opd works; logout clears session.
- [ ] Expired session redirects to login without data leaks.
- [ ] Register + verify email completes when enabled.
- [ ] OPD/IPD routes inaccessible without auth and required permissions.
- [ ] CSRF and secure cookie/header patterns per backend standards.

---

## Quality Gate

From `frontend/` when touching Flutter:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="<module>"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
frontend/lib/features/auth/
frontend/lib/core/security/
backend/src/modules/auth/
frontend/lib/app/router/app_router.dart

Related prompts: prompts/03-tenant-facility-module-prompt.md, prompts/06-settings-profile-module-prompt.md
```
