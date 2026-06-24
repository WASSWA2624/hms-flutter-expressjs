# Settings and User Profile Module — Implementation Prompt

## Objective

Complete **General Settings** and **User Profile** for HOSSPI HMS: user-level preferences (theme, language, accessibility), settings navigation hub, and profile display — distinct from tenant/facility administration.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — General settings row; Authentication row (password)
2. Platform UX rules in `frontend/.cursor/` — localization, accessibility, theme

**Central rule:** settings change **user experience** only, not hospital organizational data (that is [prompts/23-tenant-facility-module-prompt.md](./23-tenant-facility-module-prompt.md)) or clinical records.

---

## Flow Integration Requirements

### OPD / IPD (indirect)

| Concept | Settings responsibility |
| ------- | ----------------------- |
| Language | Localized OPD/IPD labels via `app_en.arb` + user locale preference |
| Theme / accessibility | Readable clinical workspaces under user preferences |
| No flow mutations | Settings never change OPD/IPD stages |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Settings | `frontend/lib/features/settings/` | `settings_page`, workspace repository |
| Backend | `settings-workspace` | `GET /settings-workspace/workspace`, reference-data |
| Profile | `frontend/lib/features/profile/` | `user_profile_page.dart` — session display only |
| Auth password | `change_password_dialog.dart` in auth feature | |

### Known gaps

- Settings workspace is largely a **navigation hub** — few mutable preferences persisted
- Security sub-routes disabled in `settings_workspace_section.dart`
- Profile does not call `user-profile` APIs — shows `AuthSession` only
- Users/roles routes stubbed → [prompts/24-access-admin-module-prompt.md](./24-access-admin-module-prompt.md)
- Feature flag `settings_workspace_v1`

---

## Scope — Core Capabilities

1. **Preferences** — theme mode, language, accessibility options; persist per user.
2. **Settings hub** — deep links to tenant facility, subscriptions, access admin, integrations.
3. **Profile page** — display name, email, roles; link to change password.
4. **Profile edit** — wire `user-profile` API when available.
5. **Localization** — all settings strings in `app_en.arb`.

---

## Acceptance Criteria

- [ ] User can change theme/language and see effect on OPD/IPD workspaces.
- [ ] Settings hub navigates to implemented admin modules.
- [ ] Profile shows accurate session roles/permissions.
- [ ] Change password works from profile or settings entry point.

---

## Key File References

```
frontend/lib/features/settings/
frontend/lib/features/profile/
backend/src/modules/settings-workspace/

Related prompts: prompts/25-auth-module-prompt.md, prompts/24-access-admin-module-prompt.md, prompts/23-tenant-facility-module-prompt.md
```
