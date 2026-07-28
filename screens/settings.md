# Action inventory — `/settings`

Primary surface: `SettingsPage`
(`frontend/lib/features/settings/presentation/pages/settings_page.dart`) with
section widgets under `frontend/lib/features/settings/presentation/widgets/`.

Route: `/settings` (`AppRoutes.settings`). Query: `tab` (section id),
`panel` (account deep links only: `profile` / `change-password`). Access:
authenticated core destination; Administration / Configuration / Workspace
sections gate on RBAC. Backend remains authoritative for mutations.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses;
noted once here. Account dialogs are inventoried in `screens/profile.md`.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Administration **Tenant and facility setup** + **Users and access** when Workspace is visible | Navigate to same setup destinations | **Removed** from Administration when Workspace shows — Workspace modules own Open/Create; Administration keeps **Subscriptions** only |
| Workspace nested tabs Overview / Setup / Modules | Extra hop before modules | **Removed** — one scroll: context → filters → modules |
| Workspace **Quick actions** + module **Create** | Create setup entity | **Removed** Quick actions — module **Create** is the sole create entry |
| Workspace **Setup checklist** chips (+ former manage taps) | Restate module readiness / parallel open | **Removed** — module row state + **Open** are the sole readiness / open path |
| Workspace context summary + summary cards | Restate selector / module counts | **Removed** — selector + module rows keep required context |
| Retapping the selected settings tab | Collapse to empty body | **Removed** — always keep one section selected |
| Standalone currency field + amount currency (Configuration) | Set currency | **Merged** earlier into `AppCurrencyAmountField` only |
| Account Profile / Change password tabs + intermediate password panel | Same account tasks | **Merged** earlier — see `screens/profile.md` |
| Module **Unavailable** Open/Create when unauthorized or unmapped | No-access / dead route chrome | **Removed** — Open/Create render only when permitted and mapped |

---

## Settings screen

### Section strip

- **Preferences / Accessibility / Account and security / Administration boundaries / Configuration / Administrative setup workspace**
  - Location: Page `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Shows that section; updates `?tab=…`. Retap does not collapse.
  - Condition: Administration only when authorized actions remain after Workspace merge. Configuration when tenant/facility config allowed. Workspace when settings-workspace or HR workspace requirement allowed.

### Preferences

- **Theme mode** (System / Light / Dark)
  - Location: Preferences body.
  - Opens modal: No.
  - Immediate result: Persists theme; SnackBar on save error.
  - Condition: Always for authenticated settings.

### Accessibility

- **Reduce motion**, **Bold text**, **Text scale**
  - Location: Accessibility body.
  - Opens modal: No.
  - Immediate result: Persists preference; SnackBar on save error.
  - Condition: Always for authenticated settings.

### Account and security

- See `screens/profile.md` (**Change password**, **Edit profile**, profile detail, deep links).

### Administration boundaries

- **Subscriptions** (`Subscription plans`)
  - Location: Administration action list (primary when Workspace is visible).
  - Opens modal: No.
  - Immediate result: Navigates to subscriptions route.
  - Condition: Super-admin. Absent when unauthorized.

- **Tenant and facility setup** / **Users and access**
  - Location: Administration action list only when Workspace section is **not** shown.
  - Opens modal: No.
  - Immediate result: Navigates to tenant-facility setup or access admin.
  - Condition: Matching admin requirements; hidden when Workspace is the primary entry.

### Configuration

- **Save** / **Reset** (tenant and facility panels)
  - Location: Configuration panels.
  - Opens modal: Reset confirmation only.
  - Immediate result: Saves or clears currency + consultation fee; SnackBar success/error.
  - Condition: Tenant and/or facility config requirements; panels absent without access or context.

### Administrative setup workspace

- **Tenant / Facility context** selectors
  - Location: Workspace top when reference options exist.
  - Opens modal: No.
  - Immediate result: Reloads workspace for selected context.
  - Condition: Backend returns tenants/facilities; required when status is tenant-context-required.

- **Search / Group / State / Actionable only**
  - Location: Filters panel.
  - Opens modal: No.
  - Immediate result: Filters module list.
  - Condition: Workspace ready with modules.

- **Open** / **Create** (module row)
  - Location: Each module row.
  - Opens modal: No — navigates to mapped tenant-facility or access-admin route.
  - Immediate result: Leaves settings for the dedicated setup surface.
  - Condition: Open only when `canRead` and route mapped; Create only when `canCreate` and create route mapped. Absent otherwise.

### States

- Loading: preferences/accessibility immediate; account and workspace use loading state views; configuration spinner.
- Empty: workspace empty refresh; module no-results after filters; profile empty identity / empty roles-permissions copy.
- Error / retry: account and workspace failure views with **Try again**; configuration refresh; preference save SnackBar.
- Validation: configuration and account dialogs keep field validators; reset confirms destructive clear.
- Success: configuration / profile SnackBars; password change SnackBar + login.
- Unauthorized: gated sections and actions absent (not disabled).
- Responsive: section strip and workspace filters wrap; theme tokens only.

---

## Verification (Req 7)

- Widget tests in
  `frontend/test/features/settings/presentation/pages/settings_page_test.dart`
  and
  `frontend/test/features/settings/presentation/widgets/settings_workspace_section_test.dart`
  prove:
  - HR with workspace: no Administration **Tenant and facility setup** duplicate; workspace modules remain.
  - Workspace has no nested Overview/Setup/Modules tabs, no Quick actions, no Setup checklist.
  - Module **Open** present when readable; absent when `canRead` is false.
  - Retapping Preferences keeps preferences content visible.
  - Account paths covered by `settings_account_section_test.dart` / `screens/profile.md`.
