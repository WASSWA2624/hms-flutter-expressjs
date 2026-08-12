# Lab tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle` (not a `labScope*` key)
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope())`; narrowed via `onNarrowedCountChanged`
- Sibling tabs: patient-view summary for worklist tabs; this tab uses follow-up provider
- Count tone: `AppTabCountTone.info` (`labSectionCountTone`)
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `LabFollowUpsAtomPermissions.tab` = ∩ `lab:read` + `lab-workflows`
- Host: **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: lab_follow_ups`)
- **Omitted when unauthorized** (also omitted for route-only clinical readers without `lab:read`)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Create Lab Order**

- Search: `receptionFollowUpsSearchHint`; Clear `receptionClearFiltersAction`
- Filters: `commonFiltersActionLabel` / `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Date: `labFollowUpDateFilterLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`
- Settings: panel-owned follow-up column dialog (`lab_follow_ups_cols`) — not Lab desk settings
- Export: gated `LabFollowUpsAtomPermissions.export` (∩ `evidence:export`)
- Print: preview-first `printLabWorkspaceList` / `commonPrintActionLabel` when print ∩
- Create: `labCreateAction` via `LabFollowUpsAtomPermissions.create`

## 3. Table

- Row model: `ReceptionFollowUpEntry`
- Default columns (**5**; `patient` alwaysVisible): patient, phone, status, date, time
- Column choices: patient ID, email, notes (Settings exposes all; Reset restores defaults)
- Panel storage keys: `lab_follow_ups_cols` / `lab_follow_ups_cw`
- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`

## 4. Advanced filters / search fields

- Group `follow_up_status`: `labFollowUpStatusFilterLabel` — Pending / Completed (`labFollowUpStatusPending` / `labFollowUpStatusCompleted`)
- Search: `labPatientFilterLabel`, `labPatientIdFilterLabel`, `patientsPhoneLabel`
- Date range on follow-up date (narrowed count syncs active badge)

## 5. Primary / secondary / row actions

- Strip: Create Lab Order (when write ∩)
- Row → follow-up detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` |
| Create order path | shared / **reused** clinical (same as worklist) |
| Follow-up column settings | panel-owned |

## 7. Nested / follow-on

When `LabFollowUpsAtomPermissions.write`: Mark completed / Reschedule → Save follow-up (`opdSaveFollowUpAction`). Close for read-only. Hard delete **not mounted** (`delete` atom exists).

## 8. Forms (summary)

Detail read + nested reschedule; create-order forms if Create used.

## 9. Print / labels / preview

- Table Print: preview-first follow-up list print when ∩ `evidence:export`
- Detail: no print surface

## 10. Loading / empty / error / success

- Hard failure: `errorUnexpectedTitle` / `errorUnexpectedMessage` + `commonRetryActionLabel`
- Empty: Reception follow-up empty keys

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / empty / loading / retry / detail / close | ∩ `lab:read` |
| create / reschedule / markCompleted / saveFollowUp / write | ∩ `lab:write` |
| createPatient | ∩ `patient:write` |
| Export | ∩ `evidence:export` (`LabFollowUpsAtomPermissions.export`) |
| Print | ∩ `evidence:export` (`LabFollowUpsAtomPermissions.print`) |
