# Clinical tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope())`; active narrowed via `onNarrowedCountChanged`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `ClinicalFollowUpsAtomPermissions.tab` = `clinicalFollowUpsRequirement`
- **Omitted when unauthorized** (AccessGate → shrink)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print**

- Search: shared follow-up search
- Filters: `commonFiltersActionLabel` → Advanced filters (status + date); Close `commonCloseActionLabel`
- Settings: `commonTableSettings*`
- Export / Print: gated by ∩ `evidence:export`; Print label `Print` (preview-first)
- Create: **not** mounted on Clinical host
- Requirements override: clinical follow-ups read/write (not Reception defaults)

## 3. Table

- Panel: **reused** `FollowUpWorklistPanel`
- Columns: patient (`opdPatientNameLabel`), phone, email, date (`opdFollowUpDateLabel`), time (`opdFollowUpTimeLabel`)
- Row select → **reused** `showReceptionFollowUpDetailDialog`
- Storage: `clinical_follow_ups_cols` / `clinical_follow_ups_cw`

## 4. Advanced filters / search fields

- Status group + scheduled date range (mounted by Clinical host)

## 5. Primary / secondary / row actions

- Detail: Reschedule / Mark completed / Save / Close
- Titles: `clinicalFollowUpDetailsTitle`, Reception follow-up copy where reused

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** Reception (clinical RW gates)

## 7. Nested / follow-on

- Nested reschedule only
- No encounter clinical action bar from this tab

## 8. Forms (summary)

- Shared Reception follow-up reschedule / complete fields

## 9. Print / labels / preview

- Toolbar Print → shared preview-first list print
- Trigger label: `Print`

## 10. Access notes

- Read/write: clinical follow-ups requirements
- Export/Print: `clinicalWorkspaceExportRequirement`
