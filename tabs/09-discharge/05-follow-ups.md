# Discharge tab — Follow-ups

## 1. Tab strip

- Label: `dischargeSectionFollowUps`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'IPD'))`; active tab uses narrowed callback from panel (`onNarrowedCountChanged`)
- Sibling tabs: dedicated unfiltered `DischargeSectionCounts` for queue sections; this tab uses follow-up provider + narrowed count
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `DischargeFollowUpsAtomPermissions.tab` = workspace read ∪
- Host: **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: discharge_follow_ups`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search: `receptionFollowUpsSearchHint`; Clear `receptionClearFiltersAction`
- Filters: **on** (`commonFiltersActionLabel` → advanced filters; Apply/Reset/Close shared OPD/common labels)
- Date filter: **on** (`dischargeDateFilterLabel` / From / To)
- Settings: `commonTableSettings*` + `receptionApplyColumnsAction` / `receptionResetColumnsAction`
- Export: enabled; gated ∩ `evidence:export` (`canExportDischargeWorkspace`)
- Print: `commonPrintActionLabel` → preview-first `printDischargeWorkspaceList` (same export gate)
- Plan / Clearance / pharmacy strip: **not mounted** (justified)

## 3. Table

- Row model: `ReceptionFollowUpEntry`
- Row select → **reused** follow-up detail
- Default columns: patient, phone, email, follow-up date, follow-up time
- Storage: `discharge_follow_ups_cols` / `discharge_follow_ups_cw`

## 4. Advanced filters / search fields

- Advanced filters: **enabled** by Discharge host (`showAdvancedFilterButton: true`)
- Date range: **on**

## 5. Primary / secondary / row actions

- Row → detail; mutations inside detail when write ∩

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` |

## 7. Nested / follow-on

Mark completed / Reschedule / Save follow-up when `DischargeFollowUpsAtomPermissions.write` (∩ `clinical:write` + module). Close for read-only. No hard delete.

## 8. Forms (summary)

Detail read tiles + nested reschedule scheduled_at/notes.

## 9. Print / labels / preview

- Table Print: preview-first `printDischargeWorkspaceList` (`Print` label; ∩ `evidence:export`)
- Detail: no print surface

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Hard failure: `errorUnexpectedTitle` / `errorUnexpectedMessage` + `commonRetryActionLabel`
- Unauthorized empty desk (no tabs): `AppFailureStateView` forbidden (`AppRoutes` / entry ∩ `discharge:read`)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / detail / close | `DischargeFollowUpsAtomPermissions.*` → workspace read ∪ |
| reschedule / markCompleted / saveFollowUp / write | follow-ups write ∩ |
| Export / Print (toolbar) | ∩ `evidence:export` |
| Planning / clearance / pharmacy / billing UI | n/a (not mounted on this tab) |
