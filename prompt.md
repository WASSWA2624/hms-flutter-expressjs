# Inline Profile and Change Password into the Settings "Account and security" Accordion Section

## Objective

Eliminate the standalone Profile page (`/profile`) and relocate its content — along with the Change Password action — into nested sub-panels within the existing **Account and security** accordion section (`id: 'account'`) on the Settings page (`/settings?tab=account`). All entry points that currently navigate to the profile page must redirect to the appropriate settings sub-panel instead.

---

## Current State

### Profile page (`frontend/lib/features/profile/presentation/pages/user_profile_page.dart`)
- Rendered at route `/profile` (`AppRoutes.profile`).
- `_ProfileContent` displays:
  - **Header actions**: Edit profile (`EditUserProfileDialog`), Change password (`ChangePasswordDialog`), Refresh.
  - **Profile summary** (`_ProfileSummary`): avatar, name, email, title, role/permission badges.
  - **Section grid** (`_ProfileSectionGrid`): Account details, Professional details, Roles list, Permissions list.

### Settings "Account and security" section (`frontend/lib/features/settings/presentation/pages/settings_page.dart`)
- Accordion entry `id: 'account'` currently renders a `_SettingsActionList` with two navigation tiles:
  - **Profile** — navigates to `AppRoutes.profile.location()` (the standalone page).
  - **Change password** — opens `ChangePasswordDialog` in-place.

### User menu (`frontend/lib/shared/layout/responsive_shell_scaffold.dart`, wired in `app_router.dart`)
- `_UserMenuAction.profile` → `context.go(AppRoutes.profile.location())`.
- `_UserMenuAction.changePassword` → opens `ChangePasswordDialog` directly.

---

## Target Design

Replace the two-item action list inside the **Account and security** accordion section with a **nested sub-panel layout** (similar to how the settings workspace section uses `initialPanel` / `onPanelChanged`). The section must contain two sub-panels:

### 1. Profile sub-panel (`panel=profile`)
- Render the full profile content currently in `_ProfileContent`:
  - Profile summary (avatar, name, email, title, badges).
  - Account details, Professional details, Roles, and Permissions sections (the same `_ProfileSectionGrid` content).
- Include an **Edit profile** action button that opens `EditUserProfileDialog`.
- Include a **Refresh** action to reload profile data via `userProfileControllerProvider`.
- This panel must use the same `userProfileControllerProvider` for state, handling loading/error/success states.

### 2. Change password sub-panel (`panel=change-password`)
- Render the `ChangePasswordDialog` content **inline** (not as a dialog), or provide a clear action button that opens `ChangePasswordDialog`.
- On successful password change, redirect to login as currently implemented.

### Sub-panel navigation
- When the **Account and security** tab is selected, display a secondary navigation (e.g. a vertical list, tab bar, or segmented control) that switches between the Profile and Change Password sub-panels.
- The active sub-panel should be reflected in the URL via the existing `panel` query parameter: `/settings?tab=account&panel=profile`, `/settings?tab=account&panel=change-password`.
- Default panel when none is specified: `profile`.

---

## Routing and Navigation Changes

### Redirect `/profile` → `/settings?tab=account&panel=profile`
- Update `AppRoutes.profile` or add a redirect in `app_router.dart` so that navigating to `/profile` seamlessly redirects to `/settings?tab=account&panel=profile`.
- Alternatively, remove the `/profile` route entirely and update all references.

### User menu callbacks (`app_router.dart`)
- `onProfileSelected` → navigate to `/settings?tab=account&panel=profile` instead of `/profile`.
- `onChangePasswordSelected` → navigate to `/settings?tab=account&panel=change-password` instead of opening the dialog directly from the shell.

### Settings "Account and security" section (`settings_page.dart`)
- Replace the current `_SettingsActionList` builder for `id: 'account'` with a widget that renders the nested sub-panel layout described above.

---

## Files to Modify

| File | Change |
|---|---|
| `frontend/lib/features/settings/presentation/pages/settings_page.dart` | Replace `account` accordion builder with nested profile/change-password sub-panels. Import and reuse profile widgets. |
| `frontend/lib/app/router/app_router.dart` | Redirect `/profile` to `/settings?tab=account&panel=profile`. Update `onProfileSelected` and `onChangePasswordSelected` callbacks. |
| `frontend/lib/app/router/app_routes.dart` | Remove or deprecate `AppRoutes.profile` if the route is fully replaced. Update `shellRoutes` and `all` lists accordingly. |
| `frontend/lib/shared/layout/responsive_shell_scaffold.dart` | Remove the `profile` entry from `_UserMenuAction` if Profile is no longer a separate destination, or keep and re-route. |
| `frontend/lib/features/profile/presentation/pages/user_profile_page.dart` | Refactor `_ProfileContent` (and supporting widgets) into a reusable widget that can be embedded in the settings page. Keep the feature folder for controllers, state, entities, and repository. |

---

## Files to Remove (after migration)

- `frontend/lib/features/profile/presentation/pages/user_profile_page.dart` — the standalone page widget becomes unnecessary once the content is inlined into settings. The profile **feature folder** (`controllers/`, `state/`, `domain/`, `data/`) must be preserved.

---

## Technical Constraints

- **State management**: continue using `userProfileControllerProvider` (Riverpod) for profile data. No new providers needed for expand/collapse — use local `StatefulWidget` state, consistent with the existing accordion pattern.
- **Reusable components**: if the nested sub-panel navigation widget is generic enough, place it in `frontend/lib/shared/components/` for reuse (e.g. by the workspace section).
- **URL-driven state**: the active sub-panel must be controlled via the `panel` query parameter on `SettingsPageQuery`, which already supports this field.
- **Localization**: reuse existing `l10n` keys from both the profile and settings features. Add new keys only if new labels are needed for the sub-panel navigation.
- **Responsiveness**: the inlined profile content must remain fully responsive, adapting its grid layout for mobile, tablet, and desktop as it does today.
- **Accessibility**: sub-panel navigation items must be focusable and activatable via keyboard (Enter/Space). Respect `reduceMotion` for any transitions.
- **No regressions**: Edit profile, Change password, Refresh, and all profile data display must continue to function identically.
