# Task: Enforce access boundaries — Settings vs HR vs Platform Access Admin

## Goal

Correct **permission boundaries** so HR users (e.g. NHRA demo account) see only **personal settings** on `/settings`, while **staff user, role, and permission management** lives entirely inside the **Human Resources** workspace (`/hr`). Platform-level access administration (`/admin/access`) must remain visible only to tenant/facility/platform administrators — not HR.

**Prerequisite:** HR workspace scaffold and staff-detail dialogs already exist (`hr_workspace_page.dart`, `hr_enhanced_dialogs.dart`).

---

## Context

| Actor | Expected Settings view | Expected access-management home |
| --- | --- | --- |
| **HR user** (`AppRole.hr`, `hrWrite`) | Preferences, Accessibility, Account and security (Profile, Change password) only | `/hr` — users, roles, permissions for clinical/operational staff |
| **Tenant / facility / platform admin** | Above + Administration boundaries (deep links) + Administrative setup workspace | `/admin/access` — full access admin including demo accounts and module entitlements |

**Repro (observed at `127.0.0.1:5201`, NHRA account):**

1. Open **Settings** (`/settings`).
2. HR user incorrectly sees **Administration boundaries** with **Users and access** and **User and security settings** — both route to `/admin/access`.
3. HR user also sees **Administrative setup workspace** rendered as a locked empty state: *"Settings workspace unavailable — You do not have permission."* This section must **not render at all** for unauthorized users (never show a forbidden placeholder).
4. On `/admin/access`, HR can reach tabs they should not use: Overview, User directory, Roles, Permissions, **Module entitlements**, **Demo accounts** — with empty states such as *"No access records found"*.

**Reference screenshots (current UI):**

- Settings: Preferences + Accessibility visible (correct); Administration boundaries + locked Administrative setup workspace visible (incorrect for HR).
- `/admin/access` → Module entitlements tab empty (HR should never reach this route).

**Related prompts:** [prompts/04-access-admin-module-prompt.md](./prompts/04-access-admin-module-prompt.md) (platform access admin), [prompts/06-settings-profile-module-prompt.md](./prompts/06-settings-profile-module-prompt.md) (personal settings hub), [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md) (HR workspace — update permission-editing guidance per this task).

**Root cause (frontend):** `_accessAdminRequirement` in `settings_page.dart` includes `AppPermissions.hrWrite` and `AppRole.hr`, which keeps Administration-boundary rows and `SettingsWorkspaceSection` visible for HR. Backend `SETTINGS_WORKSPACE_ROLES` correctly excludes HR, producing the forbidden empty state.

**Root cause (product gap):** HR has partial access hooks (assign role dialog, create-user dialog, read-only module-access preview with link to Access Admin) but lacks a complete in-HR workspace for directory-level user/role/permission CRUD.

---

## Problems

### 1. Settings exposes platform admin surfaces to HR

`settings_page.dart` gates Administration-boundary actions with `_accessAdminRequirement` that treats HR like an access administrator. When any admin action passes the filter, `SettingsWorkspaceSection` is also rendered — even when the user lacks backend authorization for the settings workspace API.

### 2. Locked “Administrative setup workspace” should never appear

Forbidden UI (lock icon + *"You do not have permission"*) must not be shown as a teaser. Hide the entire section unless the user satisfies a **dedicated** requirement aligned with backend `SETTINGS_WORKSPACE_ROLES` (`superAdmin`, `tenantAdmin`, `facilityAdmin`).

### 3. HR is routed to the wrong module for access management

`/admin/access` is a **platform/tenant administration** workspace. HR must not navigate there from Settings, staff-detail dialogs, or sidebar. All HR-owned access flows belong under `/hr`.

### 4. HR access capabilities are incomplete

HR needs full CRUD for **tenant-scoped** staff access within HR boundaries:

| Capability | HR | Platform Access Admin |
| --- | --- | --- |
| Create / edit / deactivate staff user accounts | Yes | Yes |
| Assign **multiple roles** per user | Yes | Yes |
| Create / edit / delete **roles** (tenant-wide) | Yes | Yes |
| Create / edit / delete **permissions** | Yes | Yes |
| Assign roles — one-by-one or **batch** | Yes | Yes |
| Assign permissions — one-by-one or **batch** | Yes | Yes |
| **Module entitlements** (subscription flags) | No | Yes |
| **Demo accounts** | No | Yes |
| API keys, break-glass, system-critical roles | No | Yes (safeguarded) |

Roles define the primary access level; effective permissions must be previewed before save.

---

## Requirements

### A. Settings page — tighten visibility (`settings_page.dart`)

1. **Remove HR from access-admin settings gates.** Update `_accessAdminRequirement` (and any shared constant) so **Users and access** and **User and security settings** require tenant/facility/platform admin roles or permissions — **not** `hrWrite` / `AppRole.hr`.

2. **Split Administration boundaries from Administrative setup workspace.**

   | Section | Show when |
   | --- | --- |
   | Administration boundaries (`AppScreenSection` with deep-link rows) | User passes **platform admin** requirement (tenant/facility/subscriptions/access-admin boundaries — each row keeps its own requirement) |
   | Administrative setup workspace (`SettingsWorkspaceSection`) | User passes **`_settingsWorkspaceRequirement`** matching backend `SETTINGS_WORKSPACE_ROLES` only |

3. **Never render forbidden placeholders.** If the user fails `_settingsWorkspaceRequirement`, omit `SettingsWorkspaceSection` entirely — no API call, no locked empty state.

4. **HR Settings layout** must contain only:

   - **Preferences** — app language, app theme
   - **Accessibility** — reduce motion, bold text, text size
   - **Account and security** — Profile, Change password

5. Add/adjust widget tests asserting an HR policy sees the three personal sections and **does not** find Administration boundaries or Administrative setup workspace labels.

### B. Access Admin route — block HR entry (`/admin/access`)

1. Gate `AccessAdminWorkspacePage` (router or page-level `AccessGate`) with a requirement that **excludes** `AppRole.hr` unless the user also holds tenant/facility/platform admin privileges.

2. Backend `access-admin-workspace` routes: align `canWriteAccess` / authorize middleware with the same boundary — HR should receive **403** if they deep-link to `/admin/access`.

3. Remove or hide HR-facing escape hatches:

   - `hrOpenAccessAdminAction` button in `showHrModuleAccessDialog` (`hr_enhanced_dialogs.dart`)
   - Any Settings or nav links that send HR to `/admin/access`

### C. HR workspace — own user/role/permission administration

Implement (or extend) an **Access** area inside `/hr` — toolbar tab, work-queue panel, or dedicated sub-panel — without new shell routes. All mutations stay **modal-first** (nested modals where needed).

#### C1. User directory (HR scope)

- List staff-linked and standalone user accounts relevant to the tenant (doctors, nurses, reception, billing, etc.).
- Search/filter consistent with existing HR workspace patterns.
- **Create user** — extend `showHrCreateUserDialog` to support optional initial role(s) and permission batch.
- **Edit user** — email, status (activate/deactivate), link/unlink staff profile.
- **Assign multiple roles** — multi-select or repeated assign with facility/department scope where applicable.
- **Revoke roles** — per assignment, with confirmation modal.

#### C2. Role management (tenant-wide)

- List tenant roles HR may manage (exclude system-critical roles such as `SUPER_ADMIN` — mirror backend safeguards in `access-admin-workspace.service.js`).
- **Create role** modal — name, description.
- **Edit / delete role** modal — block delete when assignments exist; show effective-permission preview.
- **Assign permissions to role** — grouped permission matrix inside modal; support selecting all in a group (batch).

#### C3. Permission management

- List permissions HR may assign (respect backend allow-list if one exists; otherwise tenant-scoped non-system permissions).
- **Create permission** modal.
- **Edit / delete permission** modal — safeguard when attached to roles.
- **Direct user permissions** (if supported by API) — assign/revoke individually or in batch via nested modal from user detail.

#### C4. Staff detail integration

- Keep per-staff **Assign role**, **Create user**, and access summary in the staff-detail dialog Actions section.
- Replace read-only module-access dialog link to Access Admin with in-HR modals (role assign, permission preview, batch assign).
- Show linked user’s **roles** (plural) and effective permissions in the staff detail overview/info sheet.

#### C5. Explicitly out of scope for HR UI

- Module entitlements tab/panel
- Demo accounts tab/panel
- Settings Administrative setup workspace
- Subscriptions, tenant/facility setup shortcuts (remain Settings/platform admin only)

### D. Backend alignment

1. Add or extend **HR-scoped APIs** under `hr-workspace` (preferred) or tighten existing `user`, `role`, `permission`, `user-role`, `role-permission` endpoints so HR can CRUD within tenant scope while platform-only resources stay blocked.

2. Enforce authorization server-side:

   - HR: tenant-scoped user/role/permission CRUD; deny demo-users, module-entitlements, api-key mutations.
   - Platform admin: unchanged full access-admin workspace.

3. Return clear `403` for HR on disallowed resources — frontend gates are not sufficient alone.

### E. Global UX rules

- **Modal-first:** every create/edit/assign/revoke/delete action uses `AppDialog` / `AppWorkspaceMutationDialog`; batch flows may use nested modals or a second step inside the same dialog.
- **Access gating:** `AccessGate` / `AppAccessActionGate` on every action; mirror backend permissions.
- **Copy:** hospital workflow language in `app_en.arb` — no raw enum names or UUIDs in UI.
- **Theming / i18n / responsive:** follow `frontend/.cursor/design-system.mdc`, `ui-workspace.mdc`, `ui-patterns.mdc`.

---

## Files to touch (starting points)

| Area | Path |
| --- | --- |
| Settings visibility | `frontend/lib/features/settings/presentation/pages/settings_page.dart` |
| Settings workspace section | `frontend/lib/features/settings/presentation/widgets/settings_workspace_section.dart` |
| Access admin page gate | `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`, `frontend/lib/app/router/app_router.dart` |
| HR dialogs & actions | `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart`, `hr_staff_detail_actions.dart`, `hr_workspace_page.dart` |
| HR controller / repository | `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`, `hr_repository_impl.dart` |
| Backend HR / access | `backend/src/modules/hr-workspace/`, `backend/src/modules/access-admin-workspace/services/access-admin-workspace.service.js` |
| Localization | `frontend/lib/l10n/app_en.arb` |
| Tests | `frontend/test/features/settings/`, `frontend/test/features/hr/`, targeted backend tests |

---

## Acceptance criteria

- [ ] NHRA (HR) account on `/settings` sees **only** Preferences, Accessibility, and Account and security — no Administration boundaries, no Administrative setup workspace (locked or otherwise).
- [ ] NHRA cannot open `/admin/access` from UI; direct URL returns forbidden / access-denied scaffold.
- [ ] NHRA manages users, roles, and permissions entirely from `/hr` via modals (create, edit, assign single/batch, revoke, delete where allowed).
- [ ] User creation supports **multiple roles**; role creation is **tenant-wide**; permissions assignable individually or in batch.
- [ ] Module entitlements and Demo accounts are **absent** from HR UI and blocked by backend for HR role.
- [ ] Tenant/facility/platform admin retains Settings administration links and full `/admin/access` workspace unchanged.
- [ ] `flutter analyze` and `flutter test` pass; targeted backend tests pass for touched authorization paths.

---

## Quality gate

From `frontend/`:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` (touched modules):

```bash
npm test -- --testPathPattern="hr-workspace|access-admin"
```
