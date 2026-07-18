# Action Button Inventory — `/reception`

Source of truth: Flutter presentation widgets under
`frontend/lib/features/reception/` and dialogs they open.
English labels from `app_en.arb`.

**Convention:** Every `AppDialog` also exposes chrome **Close** (dismiss only).
Noted once here; not repeated under each dialog.

---

## Screen — Reception workspace

**Page:** `ReceptionWorkspacePage`
(`frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`)

### Loading / error chrome

| Label | Location | Opens modal? |
|---|---|---|
| Try again | Failure scaffold retry | No — refreshes OPD workspace |

### Tab strip (section navigation)

| Label | Location | Opens modal? |
|---|---|---|
| Appointments | Tab | No — switches section |
| Desk queue | Tab | No — switches section |
| Active visits | Tab | No — switches section |
| Payment gate | Tab | No — switches section |

### Primary toolbar

| Label | Section | Opens modal? |
|---|---|---|
| Schedule appointment | Appointments | Yes → **Select patient** → **Schedule appointment** |
| Register patient | Desk queue, Active visits | Yes → **Register new patient** |
| Billing | Payment gate | No — navigates to Billing |

### Secondary toolbar

| Label | Section | Opens modal? |
|---|---|---|
| Register patient | Appointments only | Yes → **Register new patient** |
| Refresh | All sections | No |
| Full registry | Appointments | No — navigates to Patients |
| Full OPD | Desk queue, Active visits, Payment gate | No — navigates to OPD |

### List / search chrome (`AppListTable` + `AppSearchBar`)

| Label | Location | Opens modal? |
|---|---|---|
| Clear filters | Search clear | No |
| Filters | Advanced filter button | Yes → **Advanced filters** |
| Settings | Column visibility | Yes → **Table Settings** |

#### Nested — Advanced filters

| Label | Opens modal? |
|---|---|
| Clear filters | No — resets filters |
| Apply filters | No — applies and closes |

#### Nested — Table Settings

| Label | Opens modal? |
|---|---|
| Reset columns | No |
| Apply columns | No — applies and closes |

### Row interactions

| Label / control | Location | Opens modal? |
|---|---|---|
| Row tap / mobile row | Any section list row | Yes — section-specific detail (see trees below) |
| Start OPD encounter / Queue / Reschedule (status-dependent) | Appointments Actions column | Yes → **Appointment actions** |
| Start consultation (`WorkflowActionButton` or fallback `AppButton`) | Desk queue Actions column | WAB: execute/navigate; empty-id fallback opens **Queue actions** or **Appointment actions** |
| Dynamic next-step (`WorkflowActionButton`; label from flow `displayNextStep`) | Active visits / Payment gate | Usually navigate; **ASSIGN_DOCTOR** opens **Assign doctor** |

---

## Dialog tree A — Schedule appointment

Opened by **Schedule appointment**.

### Select patient

**File:** `reception_patient_actions.dart` (`_ReceptionPatientPickerDialog`)

| Label | Opens modal? |
|---|---|
| Cancel | No — dismiss |
| Select | No — returns patient, then opens **Schedule appointment** |

### Schedule appointment

**File:** `patient_appointment_quick_dialog.dart`
**Title:** Schedule appointment (`patientsAppointmentDialogTitle`)

| Label | Opens modal? |
|---|---|
| Select date | Native date picker |
| Select time | Native time picker |
| Cancel | No — dismiss |
| Schedule appointment | No — submits |

---

## Dialog tree B — Register patient

Opened by **Register patient**.

### Register new patient

**File:** patients register dialog (`showRegisterNewPatientDialog`)
**Title:** Register new patient

| Label | Opens modal? |
|---|---|
| Cancel | No — dismiss |
| Register patient | No — creates patient |
| Save anyway | No — creates despite duplicates (when shown) |

---

## Dialog tree C — Appointment actions

Opened by appointment row, Check-in column button, or queue row with linked appointment.

**Wrapper:** `reception_appointment_actions_dialog.dart` → `OpdAppointmentActionsDialog`
**Title:** Appointment actions

### Hub

| Label | When | Opens modal? |
|---|---|---|
| Queue | Can queue | No — mutates, closes hub |
| Reschedule | Can reschedule | Yes → **Reschedule** |
| Cancel appointment | Can cancel | Yes → **Cancel appointment** |
| Start OPD encounter | Can check in | Yes → **Start OPD encounter** |
| Cancel | Always | No — dismiss hub |

### Nested — Reschedule

**File:** `opd_reschedule_appointment_dialog.dart`

| Label | Opens modal? |
|---|---|
| Select date / Select time (start & end) | Native pickers |
| Cancel | No |
| Edit | No — submits |

### Nested — Cancel appointment

**File:** `OpdCancelAppointmentDialog` / `AppConfirmActionDialog`

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Cancel appointment | No — confirms cancellation |

### Nested — Start OPD encounter

**File:** `opd_encounter_dialog.dart` via `buildOpdWorkspaceEncounterDialog`
(`includeEncounterLifecycleCallbacks: false` from reception — Close/Cancel encounter buttons omitted)

| Label | When | Opens modal? |
|---|---|---|
| Start new encounter | Active encounter exists | Yes → replace confirm |
| Continue encounter | Active encounter | No |
| Cancel | Always | No |
| Start encounter / Edit encounter / Create patient | Mode-dependent primary | No — submit |

#### Nested confirm — Replace active encounter?

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Cancel old and start new | No — confirms |

---

## Dialog tree D — Queue actions

Opened when queue row has **no** linked appointment.

**Wrapper:** `reception_queue_actions_dialog.dart` → `QueueActionsDialog`
**Title:** Queue actions

### Hub

| Label | Opens modal? |
|---|---|
| Prioritize | Yes → **Prioritize queue entry** |
| Move | Yes → **Move queue entry** |
| Start consultation | Yes → **Start consultation** confirm |
| Cancel | No — dismiss hub |

### Nested — Prioritize queue entry

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Prioritize | No — submits |

### Nested — Start consultation (confirm)

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Start consultation | No — confirms |

### Nested — Move queue entry

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Move | No — submits |

---

## Dialog tree E — Flow actions

Opened by Active visits / Payment gate row detail (`showFlowActionsDialog`).

**File:** `opd_flow_actions_dialog.dart`
**Title:** Flow actions

Visibility of body actions depends on stage, display code, permissions, and terminal state.

### Hub footer

| Label | Opens modal? |
|---|---|
| Cancel | No — dismiss hub |

### Hub body actions

| Label (EN) | Opens modal / navigates? |
|---|---|
| Pay consultation / Edit consultation billing / Manage consultation billing | Yes → **Manage consultation billing** |
| Record vitals / Edit vitals | Yes → **Record vitals** / **Edit vitals** |
| Route decision | Yes → **Route decision** |
| Assign doctor / Change doctor | Yes → **Assign doctor** / **Change doctor** |
| Doctor review | Yes → **Doctor review** |
| Disposition | Yes → **Disposition** (+ possible handoffs) |
| Open inpatient admission | Navigates to IPD (may confirm first) |
| Department handoff (localized next-step, e.g. diagnostics pending) | Navigates to lab / radiology / pharmacy |
| Add diagnosis | Yes → **Add diagnosis** |
| Request lab | Yes → **Request lab** (+ catalog) |
| Request radiology | Yes → **Request radiology** (+ catalog) |
| Prescribe | Yes → **Prescribe** (+ catalog) |
| Record procedure | Yes → **Record procedure** (+ catalog) |
| Refer | Yes → **Referral** |
| Follow up | Yes → **Follow up** |
| Correct stage | Yes → **Correct stage** |
| Print summary | Yes → **Print summary** |

### Nested — Manage consultation billing

**File:** `opd_consultation_payment_dialog.dart`

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Pay consultation / Edit consultation billing | No — submits |

### Nested — Record / Edit vitals

**File:** `record_vitals_dialog.dart`

| Label | Opens modal? |
|---|---|
| Choose date / Select time | Native pickers |
| Cancel | No |
| Record vitals / Edit vitals | No — submits |

### Nested — Route decision

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Save routing decision | No — submits |

### Nested — Assign / Change doctor

Also reachable from row `WorkflowActionButton` when next step is `ASSIGN_DOCTOR`.

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Assign doctor / Change doctor | No — submits |

### Nested — Doctor review

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Doctor review | No — submits |

### Nested — Disposition

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Save disposition | No — submits |

#### After ADMIT — Admission handoff

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Open inpatient admission | No — navigates / confirms handoff |

#### After physiotherapy refer — Physiotherapy referral placed

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Open physiotherapy | No — navigates |

### Nested — Correct stage

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Correct stage | No — submits |

### Nested — Print summary

| Label | Opens modal? |
|---|---|
| Copy summary | No — copies to clipboard |
| Cancel | No |
| Print | No — prints |

### Nested — Referral

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Save referral | No — submits |

### Nested — Follow up

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Save follow-up | No — submits |

### Nested — Add diagnosis

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Add diagnosis | No — submits |

### Nested — Request lab

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Request lab / Update lab order | No — submits |
| Catalog: Done / Cancel | Nested catalog picker |
| Item tools: Edit, Delete, Remove selected, Review billing, Remove item | In-flow request tools |

### Nested — Request radiology

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Request radiology | No — submits |
| Catalog: Done / Cancel | Nested catalog picker |

### Nested — Prescribe

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Prescribe | No — submits |
| Remove medicine | No |
| Catalog: Done / Cancel | Nested catalog picker |

### Nested — Record procedure

| Label | Opens modal? |
|---|---|
| Cancel | No |
| Record procedure | No — submits |
| Catalog: Done / Cancel | Nested catalog picker |

---

## Row `WorkflowActionButton` (no hub)

**Files:** `workflow_action_button.dart`, `workflow_action_executor.dart`, `workflow_action_registry.dart`

| Behavior | Opens modal? |
|---|---|
| Most next-steps (Pay consultation, Record vitals, Doctor review, Disposition, Admit patient, department handoffs, …) | No — navigates to target module |
| ASSIGN_DOCTOR (and remapped Assign/Change doctor) | Yes → **Assign doctor** / **Change doctor** |

Queue hard-codes `nextStep: 'START_CONSULTATION'` with display label **Start consultation**.

---

## Reachability map

```
ReceptionWorkspacePage
├─ Chrome: Schedule / Register / Billing / Refresh / Full registry / Full OPD
├─ Search: Clear filters → Filters dialog; Settings → Columns dialog
├─ Row → Appointment actions → Reschedule | Cancel appointment | Start OPD encounter (+ nested)
├─ Row → Queue actions → Prioritize | Move | Start consultation confirm
├─ Row → Flow actions → billing | vitals | route | doctor | clinical | disposition | correct | print → nested
└─ Row WorkflowActionButton → navigate | Assign doctor dialog
```

---

## Not reachable from current `/reception` UI

Helpers exist under reception widgets but have **no call sites** from `reception_workspace_page`:

| Helper | Would open |
|---|---|
| `openReceptionPatientEditor` | Patient detail dialog |
| `openReceptionInsuranceCapture` | Claims enrollment dialog |
| `ReceptionBillingGuidancePanel` → Open billing | Navigates to Billing |

These are excluded from the reachable inventory above.
