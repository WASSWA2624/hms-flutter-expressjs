# Nursing tab — Handover pending

## 1. Tab strip

- Label: `nursingScopeHandoverPendingLabel`
- Icon: `Icons.swap_horiz_outlined`
- Count source: `state.handoverPendingCount` (pending handovers list; null when 0)
- Count tone: default (unset)
- Deep-link `scope`: `handover-pending` (aliases `handover_pending`, `handover`)
- Tab gate: `NursingHandoverPendingAtomPermissions.tab` = `nursingWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Shared toolbar; Print absent; Shift context when authorized (also lists pending handovers); date enabled.

## 3. Table

- Default columns: patient, **responsible_nurse**, location, status + next_action
- Responsible nurse cell is synthetic summary (`nursingHandoverPendingSummaryLabel` / shift label), not a raw assignee field
- Storage: `nursing_handoverPending` / `nursing_cw_handoverPending`

## 4. Advanced filters / search fields

Shared filters including `handover_status` (PENDING / NONE) + date.

## 5. Primary / secondary / row actions

- Next-action always Create handover → `NursingHandoverDialog`
- Detail: accept handover (`ClinicalFreeTextActionDialog`), complementary actions

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| `NursingHandoverDialog` | Nursing-owned |
| Accept handover free-text | **reused** clinical |
| Patient detail + complementary | Nursing / **reused** |

Deep link `panel=handover` → focused handover when clinical write ∩ allows.

## 7. Nested / follow-on

- Billing panel / open billing atoms present
- nestedRead = billing \| last_office
- Attachments on handover (pdf/png/jpg/jpeg/doc/docx)

## 8. Forms (summary)

- Handover: to-user, notes, optional attachments; cancel / submit
- Accept: free-text clinical dialog

## 9. Print / labels / preview

Detail print summary only.

## 10. Loading / empty / error / success

Shared nursing feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | read ∪ |
| write / nextActionHandover / createHandover / acceptHandover / success / validation / panelDeepLink | `nursingClinicalWriteRequirement` |
| complementaryWrite / addNote / vitals / prescribe / … | source write ∪ |
| billingPanel / openBilling | billing read |
| nestedRead | billing \| last_office |
| openIcu / navigation | empty |
| shiftContext | shift req |
