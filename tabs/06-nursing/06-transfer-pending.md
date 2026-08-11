# Nursing tab — Transfer pending

## 1. Tab strip

- Label: `nursingScopeTransferPendingLabel`
- Icon: `Icons.transfer_within_a_station_outlined`
- Count source: `state.transferPendingCount` (null when 0)
- Count tone: `AppTabCountTone.warning`
- Deep-link `scope`: `transfer-pending` (aliases `transfer_pending`, `transfer`)
- Tab gate: `NursingTransferPendingAtomPermissions.tab` = `nursingWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Shared toolbar; Print absent; Shift context when authorized; date enabled.

## 3. Table

- Default columns: patient, location, **transfer_status**, status + next_action
- Storage: `nursing_transferPending` / `nursing_cw_transferPending`

## 4. Advanced filters / search fields

Shared filters including `transfer_status` (REQUESTED…CANCELLED) + date.

## 5. Primary / secondary / row actions

- Next-action Acknowledge transfer → `NursingTransferDialog`
- No `panel=transfer` deep link

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| `NursingTransferDialog` | Nursing-owned |
| Patient detail + complementary | Nursing / **reused** |

## 7. Nested / follow-on

- Meds panel; Open ICU
- Atom class omits billingPanel / openBilling (detail may still show billing via shared gate)

## 8. Forms (summary)

- Transfer: action select (APPROVE / START / COMPLETE / CANCEL) + optional to-bed if COMPLETE + confirm

## 9. Print / labels / preview

Detail print summary only.

## 10. Loading / empty / error / success

Shared nursing feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | read ∪ |
| Stage write / acknowledgeTransfer / success / validation | `nursingClinicalWriteRequirement` |
| complementaryWrite | source write ∪ |
| panelDeepLink | **n/a** (no transfer panel) |
| shiftContext | shift req |
| billingPanel / openBilling atoms | **not declared** on transfer class |
