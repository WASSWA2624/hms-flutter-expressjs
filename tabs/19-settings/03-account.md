# Settings section — Account and security

## 1. Section chrome

- Strip label: `settingsAccountSectionTitle` (body key exists but **section does not render** `AppCollapsibleSection` with title/body)
- Icon: `shield_outlined`
- Deep-link `tab`: `account`
- Nested `panel`: `profile` (`SettingsAccountSection.profilePanel`), `change-password`
  - `change-password`: post-frame open dialog → `onPanelChanged('profile')` clears URL panel
  - Denied change-password deep link: snackbar `routeForbiddenTitle`
- Gate: `SettingsAccountAtomPermissions.tab` = `profileReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search / Filters / Table Settings / Export / Print: absent
- Context toolbar (right): Change password + Edit profile when authorized

## 3. Inner surfaces

- Profile summary avatar / name / status badge / title·facility meta
- Nested collapsibles:
  - `profileAccountSectionTitle`/`Body` — email, phone, user id (copyable), status
  - `profileProfessionalSectionTitle`/`Body` — overall role, user type, title, tenant, facility, facility type, staff number (copyable)
  - `profileRolesSectionTitle`/`Body` — chips or `profileRolesEmpty`
  - `profilePermissionsSectionTitle`/`Body` — chips if ≤8 else `AppPermissionGroupedView`; empty `profilePermissionsEmpty`
- Copy: `copyUserIdAction` / `userIdCopiedMessage`; `copyIdentifierAction` / `identifierCopiedMessage`
- Empty identity: `profileUnavailableTitle` / `profileUnavailableBody`

## 4. Advanced filters / search fields

- Absent

## 5. Primary / secondary / row actions

- Secondary: `settingsChangePasswordActionTitle` (`AppTabToolbarAction`) — ∩ `profile:read`
- Primary: `profileEditActionTitle` (`AppTabToolbarPrimary`) — ∩ `profile:update`; disabled while `isSaving`
- Create/delete: ∩ `facility:admin` — **not mounted**
- Unused arb action tiles: `settingsProfileActionTitle`/`Body`, `settingsChangePasswordActionBody`

## 6. Dialogs from this section

| Dialog | Owner |
| --- | --- |
| `ChangePasswordDialog` (`authChangePasswordTitle`) | **reused** auth |
| `EditUserProfileDialog` (`profileEditDialogTitle`) | **reused** profile |

## 7. Nested / follow-on

- Change password success → `authPasswordChangedMessage` → `go(login)` (session restart)
- Edit → `saveProfile` → `profileSaveSuccessMessage` / `profileSaveErrorMessage`

## 8. Forms (summary)

- Change password: current / new / confirm (`authCurrentPasswordLabel`, `authNewPasswordLabel`, `authConfirmPasswordLabel`); cancel `commonCancelActionLabel`; submit `authChangePasswordActionLabel`
- Edit profile: first / middle / last / gender (`profileEdit*`); Save `commonSaveActionLabel`

## 9. Print / labels / preview

- Absent

## 10. Loading / empty / error / success

- Loading: `profileLoadingTitle` / `profileLoadingBody`
- Error: `AppFailureStateView` + `profileUnavailableTitle` + retry refresh
- Success: password / profile snackbars above

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / summary / detail / roles / permissions / copy / loading / empty / retry | ∩ `profile:read` |
| Change password | ∩ `profile:read` |
| Edit profile / success / validation | ∩ `profile:update` |
| Create / delete | ∩ `facility:admin` — not mounted |
