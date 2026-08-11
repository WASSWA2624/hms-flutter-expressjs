# HR tab — Shift roster

## 1. Tab strip

- Label: `hrQueueRosterDrafts`
- Icon: `Icons.calendar_month_outlined`
- Count source: `summary.draftRosters`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `shift-roster` (aliases `shift`, `roster`, `roster-drafts`, `shifts`)
- Queue deep-link: `ROSTER_DRAFTS`
- Tab gate: `HrShiftsAtomPermissions.tab` = `hrReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Shared `_HrWorkQueueTable`:

- Search: `hrSearchLabel` / `hrSearchHint`
- Clear: `hrClearFiltersAction`
- Filters: Status (+ queue facet **hidden** on desk — 1:1 section↔queue); Apply `opdApplyFiltersAction`
- Settings / Export (ungated) / no Print
- Context: `hrShiftTemplateAction` when `HrShiftsAtomPermissions.scheduleTemplates` (∩ `roster:write`); bulk Delete/Permanent delete when selection + write
- Date: advanced UI default-on; `onFilterChanged` **does not** write `from`/`to` (preserves existing only)

## 3. Table

- Row model: `HrWorkItem` (`HrQueue.rosterDrafts`)
- Row select → `showHrRosterDetailDialog`
- Defaults: select (if write), roster, assignments, recurring, status, actions (Edit/Delete or Restore/Permanent)
- **No** next-action column on roster queue
- Choices: `hrQueueColumnLabel`, `hrPositionLabel`, `hrReasonLabel`, `hrQueueItemColumnLabel`
- Storage: `hr_work_queue_rosterDrafts_v2`

## 4. Advanced filters / search fields

- Status multi-choice (REQUESTED…CANCELLED set)
- Queue facet only in dialog / overdue special case
- Date UI present but not applied from Filters apply

## 5. Primary / secondary / row actions

- Strip: Schedule templates → create → open roster detail
- Row: Edit / Delete / Restore / Permanent delete
- Detail quick actions: Preview / Generate / Publish (`HrShiftsAtomPermissions.*`) — omitted when denied

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Create/edit roster (similarity, weekly schedule) | HR-owned |
| Publish (`hrPublishRosterDialogTitle` + `HrRosterPublishFields`) | HR-owned |
| Preview / generate | HR-owned |
| Print from roster detail | HR-owned (`HrRosterPrintOptionsController`) |

## 7. Nested / follow-on

- Publish notify / partial / note fields
- Print options → registry preview

## 8. Forms (summary)

- Period, recurring, holidays/weekends, week hours
- Publish notify / partial / note

## 9. Print / labels / preview

- Detail Print (`commonPrintActionLabel`), preview-first; not list Print

## 10. Loading / empty / error / success

- Empty: `hrNoQueueItemsTitle` / `Body`
- `isRefreshingWorkItems`; mutation snackbars `hrSavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list | ∩ `hr:read` |
| Schedule templates / select / row mutations | ∩ `roster:write` / shift atoms |
| Detail publish / generate / preview | `HrShiftsAtomPermissions.*` |
| Export | ungated |
| List Print | absent |
