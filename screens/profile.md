# Action inventory — `/profile`

Primary surface: `SettingsAccountSection` on Settings Account tab
(`frontend/lib/features/settings/presentation/widgets/settings_account_section.dart`).

Route: `/profile` redirects to Settings with `tab=account&panel=profile`
(`AppRoutes.profile` → `SettingsPageQuery`). Access: authenticated
(`AppRouteAccess.authenticated`); Account strip entry requires `profile:read`
(`profileReadRequirement`). Backend remains authoritative for profile
update and change-password mutations.

Permission helpers: `frontend/lib/features/profile/presentation/profile_access.dart`
(`profileReadRequirement`, `profileUpdateRequirement`).

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses;
noted once here.

---

## Permission atom map

| Atom | Intent | Requirement |
| --- | --- | --- |
| Settings Account accordion entry | read | `profile:read` ∩ (`profileReadRequirement`) |
| Identity summary + Account / Professional / Roles / Permissions sections | read | `profile:read` ∩ |
| Copyable user id / staff number | read | `profile:read` ∩ |
| Load / **Try again** | read chrome | `profile:read` ∩ |
| **Edit profile** + `EditUserProfileDialog` | update | `profile:update` ∩ (`profileUpdateRequirement`) |
| **Change password** + `ChangePasswordDialog` | update | `profile:update` ∩ (`profileUpdateRequirement`) |
| Nested cross-module UI | — | _(n/a)_ |
| Union entry | — | _(n/a — matrix is intersection-only)_ |

Profile rights are core/platform (not plan-module mapped); subscription module
stripping does not apply to these keys. Own-scope is inherent to the
current-user profile API.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Account tabs **Profile** + **Change password** | Switch surfaces for the same account tasks | **Removed** tabs — one profile surface owns both actions |
| Change-password panel body + **Change password** button | Open change-password dialog | **Removed** intermediate panel — toolbar **Change password** opens the dialog |
| User-menu / deep link `panel=change-password` → panel → button | Same change-password goal with an extra step | **Merged** — deep link opens the dialog and clears panel to `profile` |
| Summary badges (role / user type / role count / permission count) | Restate professional + roles + permissions sections | **Removed** — summary is identity only (name, email \| title) |
| **Edit profile** / **Change password** when `profile:update` missing or no record | Unauthorized / impossible write | **Removed** — controls absent unless `profileUpdateRequirement` allows (edit also needs a loaded record) |
| Account accordion when `profile:read` missing | Unauthorized read surface | **Removed** — strip entry collapsed |

---

## Profile / account screen

### Load / retry

- **Try again**
  - Location: `AppFailureStateView` on profile load failure.
  - Opens modal: No.
  - Immediate result: Reloads current profile via `userProfileController.refresh`.
  - Condition: Load failure under `profile:read`.

### View profile

- **Account / Professional / Roles / Permissions** sections
  - Location: Profile body under identity summary.
  - Opens modal: No.
  - Immediate result: Shows required identity, org context, roles, and permissions (empty copy when lists are empty). Copyable user id / staff number when present.
  - Condition: Authenticated profile load success and `profile:read` granted.

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
  - Condition: `profile:update` granted; absent otherwise. Restricted `panel=change-password` deep link without update clears to `profile` and shows forbidden SnackBar.

### Deep links / shell entry

- `/profile` → Settings account profile panel (requires Account strip `profile:read`).
- `?tab=account&panel=change-password` (user menu **Change password**) → opens change-password dialog when `profile:update` allowed; otherwise forbidden feedback and panel clears to `profile`.

### States

- Loading: profile loading state view.
- Empty / unavailable: empty identity state when display name and subject missing; roles/permissions empty copy in their sections.
- Error / retry: failure state with **Try again**.
- Validation: change-password and edit dialogs keep field validators.
- Success: edit SnackBar; password change SnackBar + login redirect.
- Unauthorized: Account strip / profile body absent without `profile:read`; **Edit profile** and **Change password** absent without `profile:update` (no disabled stubs).
- Responsive: actions wrap; detail rows stack under 520px width. Theme tokens only.

---

## Verification (Req 7)

- Widget tests in
  `frontend/test/features/settings/presentation/widgets/settings_account_section_test.dart`
  and unit tests in
  `frontend/test/features/profile/presentation/profile_access_test.dart`
  prove:
  - No Profile / Change password tab pair; single **Change password** entry when update granted; no intermediate panel body.
  - **Change password** opens the dialog directly; deep link clears panel to `profile`.
  - **Edit profile** and **Change password** present with `profile:update`, absent without it (∩ denial).
  - Profile body present with `profile:read`, absent without it.
  - Helpers reuse `profileReadRequirement` / `profileUpdateRequirement`.
  - Matrix has no ∪ rows — union allowance N/A; nested cross-module N/A.
  - Authorized edit refreshes detail; loading / empty / error / validation / success remain.
  - Narrow + desktop viewports; light + dark themes.
  - Summary omits role/permission count badges.
