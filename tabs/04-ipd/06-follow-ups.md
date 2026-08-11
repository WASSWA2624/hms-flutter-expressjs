# IPD tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'IPD'))`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `IpdFollowUpsAtomPermissions.tab` = board read ∪
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

**reused** `FollowUpWorklistPanel` (`storageKeyPrefix: 'ipd_follow_ups'`, read/write = IPD follow-up atoms):

- Search: `receptionFollowUpsSearchHint`
- Filters: **omitted** (`showAdvancedFilterButton: false`)
- Settings: common table settings
- Export / Print / Start admission / Manage beds: **absent** on this tab
- Date filter: **disabled**

## 3. Table

- Row model: `ReceptionFollowUpEntry` (IPD-scoped)
- Row select → Follow-up details (`showReceptionFollowUpDetailDialog`)
- Columns: Patient, Phone, Status, Follow-up date, Follow-up time (panel defaults)
- No admission next-action / bed board columns

## 4. Advanced filters / search fields

Intentionally omitted on IPD Follow-ups host.

## 5. Primary / secondary / row actions

- No Start admission / Manage beds
- Row → detail; Reschedule / Mark completed when write ∩ allows; Close footer for read-only

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up details | **reused** Reception |
| Nested reschedule save | **reused** |

## 7. Nested / follow-on

Complete / reschedule only. Hard delete not mounted. Billing panels / admission detail _(n/a)_.

## 8. Forms (summary)

Follow-up reschedule date/time/notes; complete confirmation.

## 9. Print / labels / preview

- Absent

## 10. Loading / empty / error / success

- Empty: reception follow-ups empty keys
- Retry: `refreshScopedFollowUps`
- Success after write mutations

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail / Close | `ipdFollowUpsRequirement` (read ∪) |
| Reschedule / Mark completed / Save | `ipdFollowUpsWriteRequirement` (clinical write ∩ + roles/module) |
| Start admission / Manage beds / billing panel | absent / _(n/a)_ |
| Route entry | AppRoutes ∪ (includes billing:read for shell) |
