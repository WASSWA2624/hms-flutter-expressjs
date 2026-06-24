# Authentication and Session Module — Implementation Prompt

## Objective

Complete **Authentication and Session** for HOSSPI HMS: login, logout, registration, email verification, session restoration, token refresh, password changes, secure route guards, and tenant account approval — the security gateway before any OPD, IPD, or admin workflow.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Authentication and session row; Main Setup Flow step 1–6
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §5 no patient-flow actions without authenticated staff session
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — same; all IPD APIs require auth + entitlements

**Central rule:** unauthenticated users see only auth routes. Session carries tenant, facility, roles, permissions, and entitlements used by all modules.

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
- Profile page does not refresh from `/auth/me` ([prompts/27-settings-profile-module-prompt.md](./27-settings-profile-module-prompt.md))
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

## Acceptance Criteria

- [ ] Login → session → home/opd works; logout clears session.
- [ ] Expired session redirects to login without data leaks.
- [ ] Register + verify email completes when enabled.
- [ ] OPD/IPD routes inaccessible without auth and required permissions.
- [ ] CSRF and secure cookie/header patterns per backend standards.

---

## Key File References

```
frontend/lib/features/auth/
frontend/lib/core/security/
backend/src/modules/auth/
frontend/lib/app/router/app_router.dart

Related prompts: prompts/23-tenant-facility-module-prompt.md, prompts/27-settings-profile-module-prompt.md
```
