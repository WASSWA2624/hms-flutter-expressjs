# Action inventory — `/mortuary`

Primary surface: `MortuaryWorkspacePage` (`frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart`).

Read gate: any of `mortuaryRead` / `mortuaryWrite` / `mortuaryApprove` / `mortuaryRelease` / `mortuaryAudit`. Print gate: `mortuaryExport` or `reportsRead` (facility context). Unauthorized print control does not render. Write mutations are not enabled on this screen yet; no-op mutation chrome was removed rather than shown disabled.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip disabled panel primaries (Receive case / Assign storage / Record custody / Approve release / Post-mortem) | No-op chrome | **Removed** — mutations not wired; do not show disabled placeholders |
| Detail **Actions unavailable** panel (8 disabled buttons) | Same no-op restatement | **Removed** — detail is read-only context + print when authorized |
| Tab-strip **Refresh** | Reload worklist | **Removed** — realtime / adaptive poll / scaffold **Try again** |
| Toolbar queue chips (identification pending, storage exceptions, release ready, unsettled billing, post-mortem pending) | Same as Filters → Queue | **Removed** — Filters → Queue is the sole queue entry; deep link `?queue=` kept |
| Toolbar **In storage** chip | Same as Storage tab (no-op on Storage panel) | **Removed** — Storage tab is the sole panel entry |
| Row **Next action** button opening detail | Same as row select | **Replaced** — next-action is guidance text only; row select opens detail |
| Filters chip counting default panel resource as active | False “Filters (1)” | **Fixed** — default panel resource omitted from active filter value |

---

## Mortuary workspace screen

### Tab strip

- **Overview / Intake / Storage / Custody / Release / Reports**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_currentPanel`, updates URL `?panel=…`, reloads worklist for panel default resource.
  - Condition: Always when workspace loads.
  - Counts: Panel summary counts from workspace payload.

Tab-strip mutation primaries, queue/summary shortcuts, and **Refresh** were removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Retries workspace load.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (resource / queue / status / identification / facility / storage / date preset), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Server search / filters / column visibility for the active panel.
  - Condition: Always when workspace is loaded.
  - Queue focus: Filters → Queue is the sole labeled entry (no parallel toolbar chips).

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy for current panel / filters.
  - Condition: No rows after panel / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Case detail dialog (identity, storage, custody, viewing, post-mortem, release, billing, documents).
  - Immediate result: Loads item detail; sole open path into detail.
  - Condition: Always when rows exist.

- **Next action** (stage guidance label)
  - Location: `next_action` column (always visible).
  - Opens modal: No — plain text only (Verify identity / Assign storage / … / Released); taps on this cell do not open detail.
  - Immediate result: Shows suggested next step; row select remains the sole open path.
  - Condition: Always when rows exist (desktop table; mobile list shows status in meta instead).

### Detail dialog

- **Close**
  - Location: Dialog chrome.
  - Opens modal: No.
  - Immediate result: Dismisses detail.

- **Print documents**
  - Location: Patient context actions.
  - Opens modal: Print flow.
  - Immediate result: Prints mortuary report; snackbar on success.
  - Condition: Export / reports-read gate; unauthorized control absent.

Read-only sections: Identity, Storage, Custody, Viewing, Post-mortem, Release, Billing, Documents.

### Deep links

- **`?panel=`** — selects tab and loads panel worklist.
- **`?queue=`** — applies queue (and its panel/resource) without toolbar chips (e.g. `IDENTIFICATION_PENDING`).
- **`?search=`** — applies search.
- **`?id=`** — opens matching row detail when present in the loaded page.

---

## Custody tab — permission mapping (`?panel=custody`)

Atom map: `MortuaryCustodyAtomPermissions` in `frontend/lib/features/mortuary/presentation/mortuary_access.dart`. Unauthorized atoms do not mount (no disabled stubs / routine “no access” banners). Nested write ∪ and fine-grained gates are kept for helpers / future chrome; inventory removed no-op mutation buttons.

| Atom | Kind | Gate |
| --- | --- | --- |
| Custody strip tab / count | navigate | ∩ `mortuary:read` (+ module + facility) |
| Search / Clear / Filters / Settings / pagination | read chrome | ∩ `mortuary:read` |
| Empty / loading / error / retry | read chrome | ∩ `mortuary:read` |
| Success snackbar / validation (authorized) | visible feedback | ∩ `mortuary:write` |
| Row select → detail | read / navigate | ∩ `mortuary:read` |
| Next action (guidance text only) | read | ∩ `mortuary:read` |
| Detail Identity / Storage / Custody / Viewing / Post-mortem / Release / Documents | read | ∩ `mortuary:read` |
| Detail Billing events | read | ∩ `mortuary:billing_event` + `billing:read` |
| Detail Print documents | export | ∪ `mortuary:export` \| `reports:read` |
| Nested post-mortem request / approve / record custody | create / update / approve | ∪ `mortuary:post_mortem_request` \| `approve` \| `write` — not mounted |
| Assign storage | update | ∩ `mortuary:manage_storage` — not mounted |
| Release / approve release | approve / update | ∩ `mortuary:release` / `approve` — not mounted |
| Audit panel | read | ∩ `mortuary:audit` — not mounted |
| Route entry (deep link `/mortuary`) | navigate | ∪ `read`\|`write`\|`approve`\|`release`\|`audit` |

Automated: `frontend/test/features/mortuary/presentation/mortuary_custody_permissions_test.dart`.

---

## Manual checks (Req 7)

- [ ] Tab strip has no Refresh, no disabled Receive case / Assign storage primaries, and no queue / In storage chips.
- [ ] Filters → Queue still focuses identification-pending (and other queues).
- [ ] Row tap opens Case detail; next-action label is not a button and does not open detail.
- [ ] Detail has no Actions unavailable strip or disabled mutation buttons.
- [ ] Without export permission, Print documents is absent; with export, Print documents is present.
- [ ] Deep link `/mortuary?queue=IDENTIFICATION_PENDING` applies queue without toolbar chips.
- [ ] Loading / empty / error-retry still render; mobile and desktop keep row select reachable; theme tokens only.

Automated: `frontend/test/features/mortuary/presentation/mortuary_workspace_page_test.dart`, `frontend/test/features/mortuary/presentation/mortuary_workspace_ux_simplify_test.dart`.
