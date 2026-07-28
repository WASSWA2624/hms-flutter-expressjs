# Action inventory — `/profile`

Primary surface: `SettingsAccountSection` on Settings Account tab
(`frontend/lib/features/settings/presentation/widgets/settings_account_section.dart`).

Route: `/profile` redirects to Settings with `tab=account&panel=profile`
(`AppRoutes.profile` → `SettingsPageQuery`). Access: authenticated
(`AppRouteAccess.authenticated`). Backend remains authoritative for profile
update and change-password mutations.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses;
noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Account tabs **Profile** + **Change password** | Switch surfaces for the same account tasks | **Removed** tabs — one profile surface owns both actions |
| Change-password panel body + **Change password** button | Open change-password dialog | **Removed** intermediate panel — toolbar **Change password** opens the dialog |
| User-menu / deep link `panel=change-password` → panel → button | Same change-password goal with an extra step | **Merged** — deep link opens the dialog and clears panel to `profile` |
| Summary badges (role / user type / role count / permission count) | Restate professional + roles + permissions sections | **Removed** — summary is identity only (name, email \| title) |
| **Edit profile** when `profile:update` missing or no record | Unauthorized / impossible write | **Removed** — control absent unless record exists and `profileUpdate` is granted |

---

## Profile / account screen

### Load / retry

- **Try again**
  - Location: `AppFailureStateView` on profile load failure.
  - Opens modal: No.
  - Immediate result: Reloads current profile via `userProfileController.refresh`.
  - Condition: Load failure.

### View profile

- **Account / Professional / Roles / Permissions** sections
  - Location: Profile body under identity summary.
  - Opens modal: No.
  - Immediate result: Shows required identity, org context, roles, and permissions (empty copy when lists are empty). Copyable user id / staff number when present.
  - Condition: Authenticated profile load success.

### Edit profile

- **Edit profile**
  - Location: Account actions row (primary).
  - Opens modal: Yes — `EditUserProfileDialog` (name + gender).
  - Immediate result: Save updates profile then refreshes; SnackBar success/error.
  - Condition: Profile record loaded and `profile:update` granted; absent otherwise. Disabled while saving.

### Change password

- **Change password**
  - Location: Account actions row (secondary).
  - Opens modal: Yes — `ChangePasswordDialog` (current / new / confirm).
  - Immediate result: On success, SnackBar then navigate to `/login`. Cancel dismisses only.
  - Condition: Always shown for authenticated account surface.

### Deep links / shell entry

- `/profile` → Settings account profile panel.
- `?tab=account&panel=change-password` (user menu **Change password**) → opens change-password dialog on the profile surface; URL panel clears to `profile`.

### States

- Loading: profile loading state view.
- Empty / unavailable: empty identity state when display name and subject missing; roles/permissions empty copy in their sections.
- Error / retry: failure state with **Try again**.
- Validation: change-password and edit dialogs keep field validators.
- Success: edit SnackBar; password change SnackBar + login redirect.
- Unauthorized: **Edit profile** absent without `profile:update`.
- Responsive: actions wrap; detail rows stack under 520px width. Theme tokens only.

---

## Verification (Req 7)

- Widget tests in
  `frontend/test/features/settings/presentation/widgets/settings_account_section_test.dart`
  prove:
  - No Profile / Change password tab pair; single **Change password** entry; no intermediate panel body.
  - **Change password** opens the dialog directly; deep link clears panel to `profile`.
  - **Edit profile** present with `profile:update`, absent without it; opens edit dialog when authorized.
  - Summary omits role/permission count badges.
  - Narrow viewport still shows **Change password**.
