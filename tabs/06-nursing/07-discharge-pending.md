# Nursing tab — Discharge pending

## 1. Tab strip

- Label: `nursingScopeDischargePendingLabel`
- Icon: `Icons.logout_outlined`
- Count source: `state.dischargePendingCount` (null when 0)
- Count tone: default (unset)
- Deep-link `scope`: `discharge-pending` (aliases `discharge_pending`, `discharge`)
- Tab gate: `NursingDischargePendingAtomPermissions.tab` = `nursingWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Shared toolbar; Print absent; Shift context when authorized; date enabled.

## 3. Table

- Default columns: patient, location, **discharge_status**, status + next_action
- Storage: `nursing_dischargePending` / `nursing_cw_dischargePending`

## 4. Advanced filters / search fields

Shared filters including `discharge_status` (PLANNED / DISCHARGE_PLANNED / COMPLETED / DISCHARGED) + date; label `dischargeStatusFilterLabel`.

## 5. Primary / secondary / row actions

- Next-action Discharge clearance → `NursingDischargeClearanceDialog`
- Detail Quick Action when discharge pending

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| `NursingDischargeClearanceDialog` | Nursing-owned |
| Patient detail + complementary | Nursing / **reused** |

Deep link `panel=discharge` / `clearance` → focused clearance when clinical write ∩ allows.

## 7. Nested / follow-on

- Billing clearance panel + Open billing (`dischargeOpenBillingAction`)
- nestedRead ∪ billing \| last_office; nestedBillingRead / nestedLastOfficeRead

## 8. Forms (summary)

- Clearance checks: medication education, wound care, follow-up, belongings returned, identity band (`nursingClearance*` labels) + notes + confirm
- Title: `nursingDischargeClearanceTitle`

## 9. Print / labels / preview

Detail print summary only.

## 10. Loading / empty / error / success

Shared nursing feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | read ∪ |
| write / panelDeepLink / stage success / validation | `nursingClinicalWriteRequirement` |
| complementaryWrite | source write ∪ |
| billingPanel / openBilling | billing read ∩ payments |
| nestedRead | billing \| last_office |
| shiftContext | shift req |
