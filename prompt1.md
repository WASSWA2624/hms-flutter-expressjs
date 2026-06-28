# Task: HR workspace dialog UX polish

## Goal

Polish the Human Resources workspace dialogs so they are clean, non-redundant, and stable at every dialog size. Users should see one clear title, switch work queues without the modal feeling like it reloads, and never hit layout overflow in the default (non-maximized) dialog size.

**Prerequisite:** Land [prompt2.md](./prompt2.md) first so `AppDialog` resize and true viewport maximize behave correctly.

## Context

HR workspace lives at `/hr` (`frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`). Toolbar actions open modal dialogs via `showAppDialog` + `AppDialog`:

| Toolbar action | Dialog | Key files |
| --- | --- | --- |
| Work queues | Queue switcher + paginated table | `hr_workspace_page.dart` (`_showWorkQueueDialog`, `_HrWorkQueuePanel`), `hr_queue_switcher.dart` |
| Schedule templates | Manage list + nested create/edit form | `hr_enhanced_dialogs.dart` (`showHrManageScheduleTemplatesDialog`, `showHrShiftTemplateDialog`) |
| HR activity | Timeline feed | `hr_workspace_page.dart` (`_showActivityDialog`, `_HrActivityPanel`) |

Queue data is driven by `HrWorkspaceController.applyQueue` / `changeWorkItemsPage` (`hr_workspace_controller.dart`), which set `isRefreshingWorkItems` and refetch the current page.

Shared layout primitives:

- `AppDialog` — `frontend/lib/shared/components/app_dialog.dart`
- `AppWorkspaceDetailPanel` — `frontend/lib/shared/layout/app_workspace.dart` (title, optional description, actions row, child)
- `AppListTable` — table + pagination + empty/loading states

Design references: `frontend/.cursor/design-system.mdc`, `ui-workspace.mdc`, `ui-patterns.mdc`.

## Problems (observed at `127.0.0.1:5201/hr`)

### 1. Redundant labels in Work queues dialog

The dialog header already shows **"Work queues"**. Inside the content, `AppWorkspaceDetailPanel` repeats information:

- `title` = active queue name (e.g. **"Swap requests"**)
- `description` = **"Work queues"** again
- `actions` = `HrQueueSwitcher` tabs, with the selected tab already highlighted

This triple labeling adds noise and wastes horizontal space.

### 2. Layout overflow at default dialog size

When the Work queues dialog is **not** maximized (default ~980px width or after manual resize), the panel header `Row` (title column + `HrQueueSwitcher` `Wrap`) overflows:

- Flutter debug banner: **"RIGHT OVERFLOWED BY 158 PIXELS"**
- Queue title text wraps one character per line on the left (**"Swap requests Wor"** stacked vertically)

Maximized/full-viewport mode looks acceptable; the broken layout is in the normal dialog size users see first.

### 3. Queue tab switch feels like a full modal reload

Clicking **Leave requests**, **Swap requests**, **Roster drafts**, **Unassigned shifts**, or **Payroll drafts** should only refresh the table for the selected queue. Today the entire dialog content appears to reload (header/panel chrome flashes, scroll position may reset), which hurts UX even though `applyQueue` does not close the route.

Expected: dialog shell, queue tabs, and pagination chrome stay stable; only the table body shows a loading state, then new rows or the empty state.

### 4. Redundant footer dismiss actions

Several HR dialogs expose both a header **✕** and a footer **Close** or **Cancel** button. Footer dismiss is redundant and clutters mutation footers (e.g. Schedule template create form shows **Cancel** + **Create template**).

## Requirements

### 1. Work queues — single source of truth for labeling

- Keep **"Work queues"** only in the `AppDialog` title (and toolbar button label).
- Remove the duplicate `AppWorkspaceDetailPanel` `description` (`l10n.hrWorkQueuesTitle`) and the per-queue `title` (`hrQueueLabel(...)`) from `_HrWorkQueuePanel`.
- Rely on `HrQueueSwitcher` as the sole in-dialog indicator of the active queue (selected tab styling + label on md+).
- Do **not** remove the **Queue** column from the table — that column labels each row, not the panel chrome.

### 2. Work queues — responsive layout without overflow

Restructure `_HrWorkQueuePanel` so queue tabs and table never compete for width in one `Row`:

- Place `HrQueueSwitcher` in its own full-width row **above** the table (below the dialog header), with adequate horizontal padding.
- On compact widths, preserve existing icon-only tabs; on md+, keep icon + label tabs.
- Ensure no horizontal overflow from tab `Wrap`, table columns, or pagination at `maxWidth: 980` and at minimum resizable width (~360px per `AppDialog` mins).
- Maximized layout should continue to look balanced (tabs may use a single row with more breathing room).

Suggested approach: stop using `AppWorkspaceDetailPanel` for work queues, or use it with an empty/minimal header and move the switcher outside the title `Row`. Prefer the pattern that matches other workspace modules (e.g. Subscriptions filters above table).

### 3. Work queues — localized tab updates only

- `HrQueueSwitcher` → `controller.applyQueue(queue)` must **not** close or re-open the dialog.
- When the queue changes, update only:
  - `AppListTable` data (`state.workItems`)
  - `isLoading` on the table (`state.isRefreshingWorkItems`)
  - empty state copy (unchanged strings)
- Preserve dialog scroll offset where possible (avoid rebuilding the entire `AppDialog` subtree when only `workItemsQuery.queue` changes).
- Disable only the non-selected queue tabs while loading (`enabled: !state.isRefreshingWorkItems` is fine); do not disable the whole dialog.
- Verify notification deep-links that call `_applyQueueAndShow` still open the dialog once with the correct queue pre-selected.

### 4. Remove redundant footer Close/Cancel on HR dialogs

Remove footer dismiss buttons where the header **✕** already closes the dialog. Keep primary/destructive workflow actions in the footer.

| Dialog | Remove | Keep |
| --- | --- | --- |
| Work queues | (none today) | — |
| Work item detail (`_showWorkItemDialog`) | `commonCloseActionLabel` | Approve/reject/etc. actions if present |
| HR activity | footer Close if present | — |
| Staff detail | footer Close if present | — |
| Schedule templates manage | — | **+ Create template** |
| Schedule template create/edit (`showHrShiftTemplateDialog`) | `commonCancelActionLabel` | **Create template** / save action |

For `showAppWorkspaceMutationDialog` usages in HR, pass an empty/no-op cancel path or extend the shared helper with `showCancelButton: false` **only if needed** — prefer the smallest change that removes the visible Cancel button while header ✕ remains enabled (except during submit).

### 5. Regression checks on related HR surfaces

After Work queues changes, smoke-test without new features:

- Toolbar order unchanged: **Work queues → Schedule templates → HR activity**
- Schedule templates manage dialog: list, create nested dialog, edit/delete still work
- Staff directory row → detail dialog still opens; maximize/resize per prompt2.md
- Queue pagination (`changeWorkItemsPage`) still works per tab

## Acceptance criteria

1. Open Work queues at default size: no overflow stripes, no vertically stacked title characters.
2. Dialog shows **"Work queues"** once (header only); active queue is clear from the selected tab, not a second heading.
3. Switching queue tabs updates the table/empty state with a brief loading indicator; dialog does not flash/rebuild as if closed and reopened.
4. Maximize dialog: layout remains clean; restore returns to prior size without layout regression.
5. HR dialogs listed above have no redundant footer Close/Cancel; header ✕ dismisses read-only dialogs; mutation dialogs retain submit action only.
6. `flutter analyze` and `flutter test` pass; add or update widget tests for `_HrWorkQueuePanel` / `HrQueueSwitcher` layout at narrow and wide constraints if practical.

## Out of scope

- Backend or API changes for queue data
- New queue types or workflow logic (approve/reject handlers)
- Full schedule-template CRUD beyond footer cleanup
- Staff detail field reorganization (separate follow-up unless needed to remove footer Close)
- `AppDialog` sizing/maximize fixes (owned by prompt2.md)

## Key files

```
frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart
frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart
frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart
frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart
frontend/lib/shared/layout/app_workspace.dart          # AppWorkspaceDetailPanel
frontend/lib/shared/components/app_dialog.dart
frontend/lib/shared/layout/app_workspace_mutation_dialog.dart
frontend/test/features/hr/                            # add/update as needed
```
