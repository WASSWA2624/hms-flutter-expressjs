# Nursing tab — Medication due

## 1. Tab strip

- Label: `nursingScopeMedicationDueLabel`
- Icon: `Icons.medication_outlined`
- Count source: `state.medicationDueCount` (null when 0)
- Count tone: `AppTabCountTone.warning`
- Deep-link `scope`: `medication-due` (aliases `medication_due`, `medication`)
- Tab gate: `NursingMedicationDueAtomPermissions.tab` = `nursingWorkspaceReadRequirement` (matrix View ∩ is `readIntersection`, not strip gate)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Shared toolbar; Print absent; Shift context when authorized; date enabled.

## 3. Table

- Default columns: patient, **medication_due_count** (if pharmacy:read), location, status + next_action
- Storage: `nursing_medicationDue` / `nursing_cw_medicationDue`

## 4. Advanced filters / search fields

Shared nursing filters + date.

## 5. Primary / secondary / row actions

- Next-action always Administer medication → `NursingMedicationDialog`
- Next-action column gated by `nextActionMedication`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| `NursingMedicationDialog` | Nursing-owned |
| Patient detail + complementary Nursing/Clinical dialogs | Nursing / **reused** |

Deep link `panel=medication` → focused med dialog when administer allowed.

## 7. Nested / follow-on

- Medications panel in detail (`pharmacy:read`)
- Complementary vitals / note / print / clinical orders when source write allows

## 8. Forms (summary)

- Med admin: medication, dose, unit, route (`ORAL`…`OTHER`), administered date/time, confirm (`nursingConfirmMedicationLabel` / `Subtitle`)

## 9. Print / labels / preview

Detail print summary only.

## 10. Loading / empty / error / success

Shared nursing feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome | read ∪ |
| readIntersection / medicationDueCount / medicationsPanel | clinical+pharmacy read / pharmacy:read |
| success / validation / write / nextActionMedication / administerMedication / panelDeepLink / nestedWrite | medication administer ∩ |
| create / update / delete / clinicalWrite | clinical write ∩ |
| complementaryWrite / checklist / vitals / note / print | source write ∪ |
| shiftContext | shift req |
