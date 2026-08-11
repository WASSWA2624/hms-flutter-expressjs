# IPD tab — Transfers

## 1. Tab strip

- Label: `ipdTransfersTabLabel`
- Icon: `Icons.swap_horiz`
- Count source: `state.transferPendingCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `transfers` (aliases `transfer-pending`, …)
- Tab gate: `IpdTransfersAtomPermissions.tab`
- **Omitted when unauthorized**
- Scope: `IpdQueueScope.transferPending`

## 2. Search / Filters / Settings / Export / Print / context

**Filters → Settings → Export → Start admission**; table Print **absent**. Manage beds not mounted.

## 3. Table

- Row model: transfer-pending `IpdAdmissionSummary`
- Row select → admission detail
- Default columns: Patient, Location, Admitted at, Status, Next action
- Column choices: Owner role, Length of stay
- Next action commonly Manage / Request transfer

## 4. Advanced filters / search fields

Same IPD filters; transfer-status group included on this tab.

## 5. Primary / secondary / row actions

- Start admission when allowed
- Next action: Manage transfer / Request transfer (operational) plus other stage kinds
- Row → detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Admission detail | IPD-owned |
| Transfer request | IPD-owned `showIpdTransferRequestDialog` |
| Transfer update | IPD-owned `showIpdTransferUpdateDialog` |
| Start admission | IPD-owned |

## 7. Nested / follow-on

Detail complementary writes + `panel=transfer` deep link (operational). Billing panel when authorized. Clinical notes/orders when clinical write.

## 8. Forms (summary)

Transfer from/to ward/bed/status; start admission; nursing/discharge/clinical as opened from detail.

## 9. Print / labels / preview

- Table Print: **absent**

## 10. Loading / empty / error / success

Shared IPD queue feedback; `_showSaved` after transfer mutations.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome | board read ∪ |
| Manage / Request transfer / Start admission | operational write ∪ |
| Nursing / Discharge / orders | clinical write ∩ |
| Billing panel / Open billing | ∩ `billing:read` |
| Manage beds | not mounted |
| `panel=transfer` | operational write ∪ |
