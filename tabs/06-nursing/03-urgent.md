# Nursing tab — Urgent

## 1. Tab strip

- Label: `nursingScopeUrgentLabel`
- Icon: `Icons.priority_high_outlined`
- Count source: `state.urgentCount` (null when 0)
- Count tone: `AppTabCountTone.danger`
- Deep-link `scope`: `urgent` (alias `critical`)
- Tab gate: `NursingUrgentAtomPermissions.tab` = `nursingWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same shared toolbar; Print absent; Shift context when authorized; date enabled.

## 3. Table

- Default columns: patient, **priority**, location, status + next_action
- Mobile meta includes priority
- Storage: `nursing_urgent` / `nursing_cw_urgent`

## 4. Advanced filters / search fields

Shared filters; priority group especially relevant.

## 5. Primary / secondary / row actions

- Next-action: if `hasCriticalAlert` → Escalate; else task-type cascade
- Detail: `NursingEscalationDialog` / complementary actions

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Escalation (`NursingEscalationDialog` → handover escalated) | Nursing-owned |
| Handover / med / transfer / discharge / vitals / detail | Nursing-owned |
| Clinical free-text / orders | **reused** |

## 7. Nested / follow-on

- Meds panel when pharmacy:read; Open ICU
- Atom class omits `billingPanel`/`openBilling`, but shared detail still mounts billing when `canViewNursingBillingClearance`

## 8. Forms (summary)

Escalation / handover notes; shared nursing forms when complementary actions run.

## 9. Print / labels / preview

Detail print summary only.

## 10. Loading / empty / error / success

Shared nursing feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | read ∪ |
| write / nextActionEscalate / escalate / complementary writes | write ∪ |
| Medication stage | medication administer ∩ |
| Stage handover / transfer / discharge next-actions | pending-tab clinical write ∩ |
| shiftContext | shift req |
| billingPanel / openBilling atoms | **not declared** on urgent class |
