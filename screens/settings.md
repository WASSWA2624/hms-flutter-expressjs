# Action inventory — `/settings`

Primary surface: `SettingsPage`
(`frontend/lib/features/settings/presentation/pages/settings_page.dart`)
with section widgets under
`frontend/lib/features/settings/presentation/widgets/`.

Route: `/settings` (`AppRoutes.settings`). Access: authenticated
(`AppRouteAccess.authenticated`). Section visibility is gated by
RBAC/ABAC; backend remains authoritative for mutations.

Account tasks are inventoried in `screens/profile.md` (Settings Account
tab / `/profile` redirect). Dialog chrome: each `AppDialog` has an
icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Administration **Tenant and facility setup** + **Users and access** when workspace is visible | Open same setup / access destinations | **Removed** from Administration when workspace shows; workspace modules own Open/Create |
| Workspace nested tabs (Context / Setup checklist / Modules) | Extra shell before modules | **Removed** — one scroll: context → checklist → filters + modules |
| Context summary + tenant/facility selectors | Restate the same context | **Removed** summary; selector is the sole context control |
| Summary cards + checklist counts + module states | Restate readiness | **Removed** summary cards; checklist is status-only |
| Checklist tap + Quick actions + module Open/Create | Same open/create goals | **Removed** checklist taps and Quick actions; modules keep sole **Open** / **Create** |
| Administration **Subscriptions** | Unique billing destination | **Kept** — only Administration entry when workspace is visible |
| Administration full list when workspace absent | Tenant setup / access / subscriptions | **Kept** for roles without workspace (e.g. operations → Users and access) |
| Configuration standalone currency + amount embedded currency | Two currency controls | **Merged** — one `AppCurrencyAmountField` (currency + fee) |

---

## Settings screen

### Section strip

- **Preferences / Accessibility / Account / Administration / Configuration / Workspace**
  - Location: Page `AppTabStrip` (authorized sections only).
  - Opens modal: No.
  - Immediate result: Expands the matching section; updates `?tab=…`.
  - Condition: Administration only when authorized admin actions remain; Configuration / Workspace when their access requirements allow.

### Preferences

- **Theme mode** (System / Light / Dark)
  - Location: Preferences body.
  - Immediate result: Persists theme; SnackBar on save failure.
  - Condition: Always for authenticated users.

### Accessibility

- **Reduce motion**, **Bold text**, **Text scale**
  - Location: Accessibility body.
  - Immediate result: Persists preference; SnackBar on save failure.
  - Condition: Always for authenticated users.

### Account and security

See `screens/profile.md` — **Edit profile**, **Change password**, profile detail sections.

### Administration boundaries

- **Subscriptions** (when workspace visible and super-admin)
  - Location: Administration action list.
  - Immediate result: Navigates to subscriptions route.
  - Condition: Super-admin; absent otherwise.

- **Tenant and facility setup** / **Users and access** / **Subscriptions**
  - Location: Administration action list.
  - Immediate result: Navigates to dedicated routes.
  - Condition: Only when workspace section is **not** shown and the matching access requirement allows; unauthorized tiles absent.

### Configuration

- **Save** / **Reset** tenant or facility currency + consultation fee
  - Location: Tenant / Facility configuration panels.
  - Opens modal: Reset confirm only.
  - Immediate result: Persists via tenant-facility submission; SnackBar success/error.
  - Condition: Tenant and/or facility config requirements; panels absent when unauthorized. Loading / error+retry when snapshot load fails.

### Administrative setup workspace

- **Tenant / Facility context selectors**
  - Location: Top of workspace (and when tenant context required).
  - Immediate result: Reloads workspace for selected tenant/facility.
  - Condition: Reference options present; otherwise omitted.

- **Setup checklist** (status only)
  - Location: Below context.
  - Immediate result: Shows completed vs remaining readiness; does not open workflows.
  - Condition: Checklist items from backend.

- **Search / group / state / actionable filters**
  - Location: Above module list.
  - Immediate result: Filters module groups client-side via workspace controller.

- **Open** / **Create** (per module)
  - Location: Module row actions.
  - Immediate result: Navigates to mapped tenant-facility or access-admin route when `canRead` / `canCreate` and route exists; disabled unavailable controls show tooltip only (no parallel shortcuts).
  - Condition: Backend module flags; unauthorized create omitted when `canCreate` is false.

### States

- Loading: preferences immediate; account/workspace/configuration use loading state views.
- Empty: workspace empty modules; profile unavailable identity; config no-tenant copy.
- Error / retry: account profile, workspace, configuration failure views with refresh.
- Validation: change-password / edit-profile dialogs; configuration amount field validators.
- Success: SnackBars for preference save errors, profile, password, configuration.
- Unauthorized: section tabs and action tiles absent when requirements fail.
- Responsive: tab strip and module actions wrap; theme tokens only.

---

## Verification (Req 7)

- `frontend/test/features/settings/presentation/pages/settings_page_test.dart`
  - HR: workspace present; Administration / Tenant and facility setup absent.
  - Super-admin with workspace: Administration shows **Subscriptions** only; tenant/access tiles absent.
- `frontend/test/features/settings/presentation/widgets/settings_workspace_section_test.dart`
  - Flattened surface: no Context summary / Quick actions; sole **Open** / **Create**.
  - Checklist does not open manage dialogs.
  - Tenant-context-required still shows selector.
- Account paths covered by
  `frontend/test/features/settings/presentation/widgets/settings_account_section_test.dart`
  (see `screens/profile.md`).
