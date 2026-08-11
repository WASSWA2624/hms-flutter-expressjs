# Discharge tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'IPD'))`
- Sibling tabs: queue counts separate; this tab uses follow-up provider
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `DischargeFollowUpsAtomPermissions.tab` = workspace read ∪
- Host: **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: discharge_follow_ups`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search: `receptionFollowUpsSearchHint`; Clear `receptionClearFiltersAction`
- Filters: **off** (host does not enable advanced filters)
- Date filter: **off**
- Settings: `commonTableSettings*` + `receptionApplyColumnsAction` / `receptionResetColumnsAction`
- Export: AppListTable default (ungated)
- Print: **not mounted**
- Plan / Clearance / pharmacy strip: **not mounted**

## 3. Table

- Row model: `ReceptionFollowUpEntry`
- Row select → **reused** follow-up detail
- Default columns: patient, phone, email, follow-up date, follow-up time
- Storage: `discharge_follow_ups_cols` / `discharge_follow_ups_cw`

## 4. Advanced filters / search fields

- Advanced filters: **not enabled** by Discharge host

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

- Table Print: **absent**
- Detail: no print surface

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Hard failure: `errorUnexpectedTitle` / `errorUnexpectedMessage` + `commonRetryActionLabel`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / settings / detail / close | `DischargeFollowUpsAtomPermissions.*` → workspace read ∪ |
| reschedule / markCompleted / saveFollowUp / write | follow-ups write ∩ |
| Export | ungated |
| Planning / clearance / pharmacy / billing UI | n/a (not mounted on this tab) |
| Print | n/a |
