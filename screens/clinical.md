# Action inventory — `/clinical`

Primary surface: `ClinicalWorkspacePage` (`frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`).

Write gate used throughout encounter mutations: `clinicalWrite` **or** `systemAdmin`, with active module `encounters-vitals` (`_writeRequirement` / `clinicalEncounterWriteRequirement`).

Dialog chrome: each `AppDialog` has an icon-only **Close** (Material close tooltip) that only dismisses; noted once here and omitted from nested sections unless behavior differs. Maximize (when shown) is chrome only.

---

## Clinical workspace screen

### Tab strip

- **Follow-ups / All / Waiting review / Urgent / Results ready / In consultation / Completed**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, and for non–Follow-ups tabs applies worklist scope (clears search). Follow-ups shows `FollowUpWorklistPanel` instead of the clinical worklist.
  - Condition: Always shown; count badges vary by section (Follow-ups count from `followUpTabCountProvider`).

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold` failure state.
  - Opens modal: No.
  - Immediate result: Retries loading clinical workspace.
  - Condition: Shown when initial workspace load fails.

Tab-strip **Refresh**, **OPD**, **Lab**, and **Discharge** shortcuts were removed; those modules remain reachable via app navigation. Worklist scopes are outpatient-only (IPD/inpatient excluded). **Completed** is same-day terminal outpatient encounters.

---

## Clinical worklist (non–Follow-ups tabs)

### Search / filters / table chrome

- **Search** (text field + submit)
  - Location: Worklist search bar.
  - Opens modal: No.
  - Immediate result: Debounced / submitted search via `applySearch`.
  - Condition: All worklist sections.

- **Clear filters** (search clear)
  - Location: Search-bar clear control (`opdClearFiltersAction` / “Clear filters”).
  - Opens modal: No.
  - Immediate result: Clears the search field / filter value path used by `AppListTableSearch`.
  - Condition: When search has content (shared search component).

- **Filters**
  - Location: Search-bar advanced Filters control (`clinicalFiltersLabel`).
  - Opens modal: Yes — shared advanced-filters panel (`commonAdvancedFiltersTitle`).
  - Immediate result: Opens filter UI (text fields, option groups, date range).
  - Condition: Always available on worklist (`showAdvancedFilterButton: true`).

#### Advanced filters panel (from **Filters**)

- **Choose date** (from / to date pickers)
  - Location: Advanced filters **Last updated** date fields (`clinicalLastUpdatedLabel` / `opdDatePickerButtonLabel`).
  - Opens modal: Native/app date picker (field chrome).
  - Immediate result: Sets `dateFrom` / `dateTo`.
  - Condition: Date filter enabled (default on clinical worklist).

- **Apply filters**
  - Location: Advanced filters footer.
  - Opens modal: No (closes panel).
  - Immediate result: Applies `ClinicalWorklistFilters` + search while preserving tab scope.
  - Condition: Always in panel.

- **Clear filters**
  - Location: Advanced filters footer (`advancedFilterResetLabel`).
  - Opens modal: No.
  - Immediate result: Resets advanced filter fields.
  - Condition: Always in panel.

- **Close** (panel dismiss)
  - Location: Advanced filters chrome.
  - Opens modal: No.
  - Immediate result: Dismisses filters panel without necessarily applying (shared component).
  - Condition: Always available.

Filter fields available: general search, patient, patient ID, phone, encounter #, queue text, provider text, status text, location text; option groups for source queue, status/stage, provider (incl. Unassigned), encounter type, location.

- **Settings** (table columns)
  - Location: List-table trailing settings (`commonTableSettingsActionLabel`).
  - Opens modal: Yes — **Table Settings** column-visibility dialog.
  - Immediate result: Opens column picker for the active section’s storage key.
  - Condition: Always on worklist table.

#### Table Settings dialog (from **Settings**)

- **Apply columns** / **Reset columns** / **Close**
  - Location: Column-visibility dialog footer (defaults: “Apply columns”, “Reset columns”, “Close”).
  - Opens modal: No.
  - Immediate result: Applies, resets, or dismisses column visibility for `clinical_{section}`.
  - Condition: Always in dialog.

- **Previous page** / **Next page**
  - Location: Worklist pagination.
  - Opens modal: No.
  - Immediate result: `changePage` for previous/next page.
  - Condition: Enabled when previous/next pages exist.

- **Row select**
  - Location: Worklist table or mobile-list row.
  - Opens modal: Yes — **Clinical encounter details** (`_ClinicalEncounterDialog`).
  - Immediate result: `selectEntry` then opens encounter dialog; clears selection on close.
  - Condition: Always for listed entries; fails with snackbar if detail load fails.

### Next-action column (per row)

Shown in the worklist table `nextAction` column (`_ClinicalWorklistNextActionCell`). Adaptive mobile list cards use row select only (no separate next-action control in `mobileItemBuilder`).

Resolution order:

1. If `apiEncounterId` is set and `WorkflowActionRegistry` resolves an action → **`WorkflowActionButton`** (compact).
2. Else if disposition is available and not terminal → disposition fallback (write-gated).
3. Else → **Review encounter**.

- **WorkflowActionButton** (dynamic label from registry / next step)
  - Location: Next-action column (table / non-mobile list presentation).
  - Opens modal: **Sometimes** — only for dialog-mode actions with a registered opener; otherwise navigates to another module route.
  - Immediate result: `WorkflowActionExecutor.execute`. Dialog-mode with opener: inline dialog. Otherwise: `context.go` to target route (billing, nursing, clinical, lab, radiology, pharmacy, IPD, discharge, emergency, theater, physiotherapy, claims, rooms/beds, etc.).
  - Condition: Encounter id present and registry resolves a code from `stage` / `nextStep`. Disabled (lock icon) when permission/module denied. Front-desk fallback may remap denied clinical-owned steps to **Assign doctor** / **Change doctor**.

  Common labels (from registry; actual label depends on backend `nextStep` / stage aliases):

  | Code (canonical) | Visible label (en) | Mode |
  | --- | --- | --- |
  | `PAY_CONSULTATION` / `PAY_SERVICE` | Pay consultation | Dialog mode → falls back to Billing route (no opener registered from clinical) |
  | `RECORD_VITALS` | Record vitals | Inline clinical dialog (`ClinicalVitalsActionDialog`) when action column is used on `/clinical` |
  | `NURSING_ASSESSMENT` | Record vitals | Route → Nursing |
  | `ASSIGN_DOCTOR` | Assign doctor (or **Change doctor** when remapped with assigned staff) | Dialog → **Assign doctor** |
  | `DOCTOR_REVIEW` | Clinical notes | Route → Clinical encounter |
  | `REVIEW_RESULTS` | Review results | Route → Clinical |
  | `REVIEW_REPORT` | Review report | Route → Clinical |
  | `MEDICINES_DISPENSED` | Medicines dispensed | Route → Clinical |
  | `COLLECT_SAMPLE` / `LAB_AND_RADIOLOGY_REQUESTED` | Collect sample / Diagnostics pending | Route → Lab |
  | `PERFORM_IMAGING` | Perform imaging | Route → Radiology |
  | `DISPENSE_MEDICINE` | Dispense medicine | Route → Pharmacy |
  | `DISPOSITION` | Disposition | Route → Clinical |
  | `ADMISSION_HANDOFF` / `APPROVE_ADMISSION` | Admit patient | Route → IPD |
  | `ADMITTED` | View admission | Route → IPD |
  | `RECORD_NURSING_NOTE` | Record nursing note | Route → Nursing |
  | `APPROVE_TRANSFER` / `START_TRANSFER` / `COMPLETE_TRANSFER` | Approve / Start / Complete transfer | Route → IPD |
  | `COMPLETE_THEATRE_HANDOVER` | Complete theatre handover | Route → Theater |
  | `FINALIZE_DISCHARGE` / `DISCHARGE_PLANNING` | Finalize discharge / Plan discharge | Route → Discharge |
  | `EMERGENCY_TRIAGE` / `EMERGENCY_STABILIZE` | Record vitals / Clinical notes | Route → Emergency |
  | `THEATRE_SCHEDULING` / `THEATRE_IN_PROGRESS` | Theatre scheduling | Route → Theater |
  | `PHYSIOTHERAPY_SESSION` | Physiotherapy session | Route → Physiotherapy |
  | `INSURANCE_PREAUTH` | Pre-authorization | Route → Claims |
  | `ASSIGN_BED` | Assign bed | Route → Rooms & beds |

#### Assign doctor dialog (from WorkflowActionButton `ASSIGN_DOCTOR`)

Opened via `showAssignDoctorDialog` / `AssignDoctorDialog` (`opd_flow_actions_dialog.dart`).

- **Cancel**
  - Location: Dialog footer.
  - Opens modal: No.
  - Immediate result: Dismisses without saving.
  - Condition: Disabled while busy.

- **Assign doctor** / **Change doctor** (primary; label matches title)
  - Location: Dialog footer.
  - Opens modal: No.
  - Immediate result: Saves provider assignment; on success pops `true` and invalidates OPD workspace.
  - Condition: Disabled while loading providers or saving; requires valid provider selection.

- **Disposition / Discharge planning / Finalize discharge / Complete disposition** (fallback compact action)
  - Location: Next-action column when no workflow action resolves but disposition is available.
  - Opens modal: Yes — either **Discharge planning** (`showDischargePlanningDialog`) for admission/IPD context, or **Clinical disposition** (`ClinicalDispositionActionDialog`).
  - Immediate result: See nested dialogs below; on success snackbar then `Navigator.pop(true)` (closes **Clinical encounter details** when that dialog is open).
  - Condition: Write gate; not terminal; `isClinicalDispositionActionAvailable` (admission discharge context, or OPD flow + triage/doctor disposition stages). Label from `clinicalDispositionActionLabel` (**Disposition**, **Complete disposition**, **Discharge planning**, or **Finalize discharge**).

- **Review encounter**
  - Location: Next-action column fallback.
  - Opens modal: Yes — **Clinical encounter details**.
  - Immediate result: Same as row select.
  - Condition: When neither workflow action nor disposition fallback applies.

---

## Follow-ups tab (`FollowUpWorklistPanel`)

- Condition: Tab **Follow-ups**; entire panel hidden unless `receptionFollowUpsRequirement` is allowed.

- **Try again**
  - Location: Follow-ups load/error state.
  - Opens modal: No.
  - Immediate result: `refreshScopedFollowUps`.
  - Condition: Load failure.

- **Search** / search clear
  - Location: Follow-ups list search.
  - Opens modal: No.
  - Immediate result: Client-side filter of follow-up entries.
  - Condition: When entries exist.

- **Settings** → Table Settings (**Apply columns** / **Reset columns** / **Close**)
  - Location: Follow-ups table chrome (`clinical_follow_ups_*` storage keys).
  - Opens modal: Yes — column visibility dialog.
  - Immediate result: Same pattern as clinical worklist Settings.
  - Condition: When entries exist.

- **Row select**
  - Location: Follow-ups table / mobile row.
  - Opens modal: Yes — **Follow-up details** (`ReceptionFollowUpDetailDialog`).
  - Immediate result: Opens detail; refreshes list if changed.
  - Condition: Always for listed entries.

### Follow-up details dialog (`ReceptionFollowUpDetailDialog`, title **Follow-ups**)

- **Reschedule follow-up**
  - Location: Dialog footer.
  - Opens modal: Yes — **Reschedule follow-up** (`ClinicalFollowUpActionDialog` titled with `receptionScheduleAnotherFollowUpAction`).
  - Immediate result: Opens reschedule form; on save updates follow-up and closes detail with `true`.
  - Condition: Front-desk write (`receptionFrontDeskWriteRequirement`); disabled while busy.

- **Mark completed**
  - Location: Dialog footer.
  - Opens modal: No.
  - Immediate result: Completes follow-up via repository; closes with `true`.
  - Condition: Front-desk write; disabled while busy.

- **Close**
  - Location: Dialog footer (read-only path).
  - Opens modal: No.
  - Immediate result: Dismisses detail.
  - Condition: Shown instead of write actions when write is not allowed.

#### Reschedule follow-up dialog (from **Reschedule follow-up**)

Same control set as encounter **Follow up** dialog (see below): **Choose date**, **Select time**, **Cancel**, **Save follow-up**.

---

## Clinical encounter details dialog (`_ClinicalEncounterDialog`)

Opened from row select / **Review encounter**.

- **Try again** (detail failure)
  - Location: Dialog body `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Re-runs `selectEntry` for the same worklist entry.
  - Condition: Detail load failure inside dialog.

### Quick actions bar (`_ClinicalActionBar`)

All clinical write actions below use write gate; disabled when not allowed (except Print summary).

- **Add clinical note**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Add patient clinical note** (`ClinicalFreeTextActionDialog`).
  - Immediate result: Opens note dialog; on success snackbar.
  - Condition: Write gate.

- **Record vitals** / **Edit vitals**
  - Location: Encounter quick actions (label switches to Edit when handoff already has vitals).
  - Opens modal: Yes — **Record/Edit vitals** (`ClinicalVitalsActionDialog` on `AppRecordVitalsDialog`).
  - Immediate result: Writes OPD `record-vitals` for the encounter flow; refreshes triage handoff.
  - Condition: Write gate; non-terminal; encounter has `opdFlowApiId`.
  - Worklist: When next step is `RECORD_VITALS`, the Action column opens this dialog in clinical (does not route to Nursing).

- **Add diagnosis**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Add diagnosis** (`ClinicalDiagnosisActionDialog`).
  - Condition: Write gate.

- **Request lab**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Request lab** (`ClinicalLabOrderActionDialog`).
  - Condition: Write gate.

- **Request radiology**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Request radiology** (`ClinicalRadiologyOrderActionDialog`).
  - Condition: Write gate.

- **Prescribe**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Prescribe** (`ClinicalPrescriptionActionDialog`).
  - Condition: Write gate.

- **Record procedure**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Record procedure** (`ClinicalProcedureActionDialog`).
  - Condition: Write gate.

- **Refer**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Refer** (`ClinicalReferralActionDialog`).
  - Condition: Write gate.

- **Request admission**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Request admission** (`ClinicalAdmissionActionDialog`, `requiresBed: false` → reason/notes only).
  - Condition: Write gate.

- **Follow up**
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Follow up** (`ClinicalFollowUpActionDialog`).
  - Condition: Write gate.

- **Disposition / Complete disposition / Discharge planning / Finalize discharge** (dynamic label)
  - Location: Encounter quick actions.
  - Opens modal: Yes — **Discharge planning** or **Clinical disposition** (same as worklist disposition fallback).
  - Immediate result: On success snackbar and closes encounter dialog (`Navigator.pop(true)`).
  - Condition: Write gate; entry not terminal; disposition available. Label from `clinicalDispositionActionLabel`.

- **Print summary**
  - Location: Encounter quick actions.
  - Opens modal: No in-app dialog (calls `printFormTemplateDocument` → `printHtmlDocument`).
  - Immediate result: Builds consultation summary HTML and triggers print pipeline.
  - Condition: Always enabled (not write-gated).

### Lab orders panel (`ClinicalLabOrdersTablePanel`)

- **Expand / collapse** (icon-only expand_more / expand_less)
  - Location: Lab order row when child tests exist.
  - Opens modal: No.
  - Immediate result: Toggles nested test rows.
  - Condition: Order has `labOrderItems`.

- **Edit order** (icon-only)
  - Location: Lab order actions column / mobile card.
  - Opens modal: Yes — **Update lab order** (`ClinicalLabOrderActionDialog` with `existingOrder`).
  - Condition: Write gate; status `ORDERED` / `PENDING` / `IN_PROCESS`.

- **Cancel order** (icon-only)
  - Location: Lab order actions.
  - Opens modal: Yes — **AppConfirmActionDialog** (cancel lab title/body).
  - Immediate result: On confirm `cancelLabOrder`; snackbar.
  - Condition: Write gate; status `ORDERED` / `PENDING` / `IN_PROCESS`.

- **Delete order** (icon-only)
  - Location: Lab order actions.
  - Opens modal: Yes — **AppConfirmActionDialog** (delete lab title/body).
  - Immediate result: On confirm `deleteLabOrder`; snackbar.
  - Condition: Write gate; status `ORDERED` / `PENDING` / `CANCELLED`.

### Radiology orders panel (`ClinicalRadiologyOrdersTablePanel`)

- **Cancel order** (icon-only)
  - Location: Radiology order actions.
  - Opens modal: Yes — confirm cancel radiology.
  - Condition: Write gate; status `ORDERED` / `PENDING` / `IN_PROCESS`.

- **Delete order** (icon-only)
  - Location: Radiology order actions.
  - Opens modal: Yes — confirm delete radiology.
  - Condition: Write gate; status `ORDERED` / `PENDING` / `CANCELLED`.

### Pharmacy orders (record section rows)

- **Cancel order** (icon-only)
  - Location: Pharmacy order row trailing actions.
  - Opens modal: Yes — confirm cancel pharmacy.
  - Condition: Write gate; status `ORDERED` / `PARTIALLY_DISPENSED`.

- **Delete order** (icon-only)
  - Location: Pharmacy order row trailing actions.
  - Opens modal: Yes — confirm delete pharmacy.
  - Condition: Write gate; status `ORDERED` / `CANCELLED`.

### Confirm mutation dialog (`AppConfirmActionDialog`)

Used for lab / radiology / pharmacy cancel & delete from encounter detail.

- **Cancel**
  - Location: Confirm dialog footer.
  - Opens modal: No.
  - Immediate result: Dismisses without mutating.
  - Condition: Disabled while confirming/saving.

- **{Confirm label}** (e.g. Cancel order / Delete order)
  - Location: Confirm dialog footer (primary; matches `confirmLabel` passed by caller).
  - Opens modal: No.
  - Immediate result: Runs mutation; pops `true` on success.
  - Condition: Disabled while saving.

---

## Nested dialogs from encounter quick actions

### Add patient clinical note (`ClinicalFreeTextActionDialog`)

- **Cancel** / **Add clinical note**
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Dismiss / submit note via `addClinicalNote`.
  - Condition: Disabled while saving.

### Add diagnosis (`ClinicalDiagnosisActionDialog`)

Dialog opens maximized by default. Diagnosis type uses dense borderless radios (Primary / Secondary / Differential) with semantic label only (no on-screen title). Catalog is facility offerings only (no source chips). Transfer panes use dense `AppListTable` surfaces with content-tight rows; search + transfer actions share a fixed 40px toolbar height; Name columns are not sortable; row click toggles check.

- **Diagnosis type** (Primary / Secondary / Differential borderless radios)
  - Location: Dialog body (radios only; no visible label).
  - Opens modal: No.
  - Immediate result: Sets batch diagnosis type (default Primary).
  - Condition: Enabled when not saving.

- **Search diagnosis**
  - Location: Available pane table surface header (dense field, hint-only; height matched to transfer action).
  - Opens modal: No.
  - Immediate result: Filters / reloads facility diagnosis catalog.
  - Condition: Enabled when not saving.

- **Add selected diagnosis** (available pane)
  - Location: Available pane table surface header (with search; dense height matched to field).
  - Opens modal: No.
  - Immediate result: Moves checked available rows to selected (skips duplicates).
  - Condition: ≥1 checked available row; not saving.

- **Search selected diagnosis**
  - Location: Selected pane table surface header (dense field, hint-only; height matched to transfer action).
  - Opens modal: No.
  - Immediate result: Client-side filters the selected list.
  - Condition: Enabled when not saving.

- **Remove selected diagnosis** (selected pane)
  - Location: Selected pane table surface header (with search; dense height matched to field).
  - Opens modal: No.
  - Immediate result: Moves checked selected rows back to available.
  - Condition: ≥1 checked selected row; not saving.

- **Row click / checkbox column**
  - Location: Available and selected transfer tables.
  - Opens modal: No.
  - Immediate result: Toggles that row’s checked state (multi-select before transfer).
  - Condition: Enabled when not saving.

- **Try again** (catalog load failure)
  - Location: Available pane empty/error state.
  - Opens modal: No.
  - Immediate result: Retries facility catalog load.
  - Condition: Catalog load failure; not saving.

- **Cancel** / **Add diagnosis**
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Dismiss / submit selected diagnoses with chosen type for the active encounter.
  - Condition: Primary enabled when at least one diagnosis selected and not saving.

### Request lab / Update lab order (`ClinicalLabOrderActionDialog`)

- **Remove selected**
  - Location: Request flow toolbar.
  - Opens modal: Yes — **Remove lab request?** / **Remove N lab requests?** confirmation.
  - Immediate result: After confirm, removes selected staged tests/panels.
  - Condition: At least one row selected; not saving.

- **Add items**
  - Location: Toolbar.
  - Opens modal: Yes — **Lab request catalog** (`showClinicalLabRequestCatalogDialog`).
  - Immediate result: Opens catalog picker; confirmed selections replace staged list.
  - Condition: Not saving.

- **Review billing**
  - Location: Toolbar.
  - Opens modal: Yes — **Request billing** (`showClinicalRequestBillingDialog`).
  - Immediate result: Opens billing panel; **Done** stores billing submit payload.
  - Condition: At least one staged request; not saving.

- **Remove item** (per row / mobile)
  - Location: Selected catalog table actions.
  - Opens modal: Yes — single-item remove confirmation.
  - Immediate result: Removes that staged item after confirm.
  - Condition: Not saving.

- **Select-all / row checkboxes**
  - Location: Selected table header/cells.
  - Opens modal: No.
  - Immediate result: Toggles selection for **Remove selected**.
  - Condition: Not saving.

- **Request lab** / **Update lab order** (primary; no Cancel footer button)
  - Location: Dialog footer.
  - Opens modal: No.
  - Immediate result: Submits create/update lab order (with optional billing).
  - Condition: At least one request staged; not saving.

#### Remove confirmation (from **Remove selected** / **Remove item**)

- **Cancel** / **Remove** (or **Remove selected** for multi)
  - Location: Confirmation footer.
  - Opens modal: No.
  - Immediate result: Abort or confirm removal from staged list.
  - Condition: Always.

#### Lab request catalog (from **Add items**)

- **Individual tests** / **Lab panels**
  - Location: Catalog kind radios (`clinicalLabRequestTestsModeLabel` / `clinicalLabRequestPanelsModeLabel`).
  - Opens modal: No.
  - Immediate result: Reloads catalog for tests vs panels; clears/restages selection kind.
  - Condition: Always in catalog (when parent not saving).

- **Favorite test ActionChips**
  - Location: Frequently used tests wrap.
  - Opens modal: No.
  - Immediate result: Stages that favorite test.
  - Condition: Favorites available; tests kind.

- **Catalog source chips** / search / **Laboratory filters** (advanced filters Apply / Clear)
  - Location: Catalog body.
  - Opens modal: Filters panel when Filters pressed.
  - Immediate result: Filter/search catalog; checkboxes stage selections.
  - Condition: Always in catalog.

- **Settings** → Lab catalog table columns (**Apply columns** / **Reset columns**)
  - Location: Catalog table chrome.
  - Opens modal: Yes — column visibility.
  - Condition: Always in catalog table.

- **Cancel** / **Confirm selected tests or panels**
  - Location: Catalog footer.
  - Opens modal: No.
  - Immediate result: Dismiss without applying / return staged selections to lab order dialog.
  - Condition: Always.

#### Request billing (from **Review billing**)

- **Bill later** / **Pay now**
  - Location: Billing panel payment-mode radios.
  - Opens modal: No.
  - Immediate result: Sets payment mode / paid-amount behavior for the submit payload.
  - Condition: Panel enabled (parent not saving).

- **Decrease quantity** / **Increase quantity** (icon-only)
  - Location: Per editable billing line quantity stepper.
  - Opens modal: No.
  - Immediate result: Adjusts line quantity (decrease disabled at qty ≤ 1).
  - Condition: Panel enabled.

- **Cancel** / **Done**
  - Location: Billing dialog footer.
  - Opens modal: No.
  - Immediate result: Discard / return `ClinicalRequestBillingSubmit` to parent request dialog.
  - Condition: **Done** requires non-empty line items; disabled when parent disabled.

### Request radiology (`ClinicalRadiologyOrderActionDialog`)

Same toolbar pattern as lab:

- **Remove selected** → remove confirmation
- **Add study** → **Radiology request catalog** (`showClinicalRadiologyRequestCatalogDialog`)
- **Review billing** → **Request billing**
- **Remove item** (per row) → remove confirmation
- **Request radiology** (primary footer)

#### Radiology request catalog (from **Add study**)

- Search / filters / row checkboxes / table Settings (same pattern as lab catalog)
- **Confirm selected studies** (primary footer; no Cancel button in source — dismiss via dialog Close)
  - Immediate result: Returns selections (with modality/laterality/priority/body region/clinical note metadata) to radiology order dialog.

### Prescribe (`ClinicalPrescriptionActionDialog`)

- **Add medicine**
  - Location: Toolbar.
  - Opens modal: Yes — **Add medicine** line dialog.
  - Immediate result: Opens line form; on **Done** adds line to list.
  - Condition: Not saving.

- **Review billing**
  - Location: Toolbar.
  - Opens modal: Yes — **Request billing**.
  - Condition: Payment mode is **Pay at prescribe** and at least one drug line; not saving.

- **Bill on dispense** / **Pay at prescribe**
  - Location: Segmented payment-mode control.
  - Opens modal: No.
  - Immediate result: Toggles whether billing is reviewed now vs at dispense.
  - Condition: Not saving.

- **Edit** / **Delete** (selected medicines manager)
  - Location: Selection manager when a line is focused.
  - Opens modal: **Edit** opens **Edit medicine** line dialog; **Delete** removes line (no confirm).
  - Condition: Edit when focused; Delete when focused and more than one line.

- **Cancel** / **Prescribe**
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Dismiss / submit prescription.
  - Condition: Disabled while saving.

#### Add medicine / Edit medicine line dialog

- **Cancel** / **Done**
  - Location: Line dialog footer.
  - Opens modal: No.
  - Immediate result: Discard line edits / validate and return to prescribe dialog.
  - Condition: Always.

### Record procedure (`ClinicalProcedureActionDialog`)

- **Add items**
  - Location: Toolbar (`showBillingAction: false`).
  - Opens modal: Yes — **Procedure catalog** (`showClinicalProcedureCatalogDialog`).
  - Condition: Not saving.

- **Delete** (selected procedures)
  - Location: Selection manager.
  - Opens modal: No.
  - Immediate result: Removes focused procedure.
  - Condition: Focused selection; not saving.

- **Cancel** / **Record procedure**
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Dismiss / submit procedures.
  - Condition: Primary requires non-empty selection.

#### Procedure catalog (from **Add items**)

- **Catalog source chips** (All / Favorites / Facility / Global)
  - Location: Catalog layer selector.
  - Opens modal: No.
  - Immediate result: Reloads procedure catalog for selected source.
  - Condition: Always in catalog.

- **Add**
  - Location: Catalog footer.
  - Opens modal: No.
  - Immediate result: Adds active procedure to parent selection (keeps catalog open).
  - Condition: Active procedure set and not already selected.

- **Done**
  - Location: Catalog footer.
  - Opens modal: No.
  - Immediate result: Closes catalog.
  - Condition: Always.

### Refer (`ClinicalReferralActionDialog`)

- **Cancel** / **Save referral**
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Dismiss / submit referral.
  - Condition: Disabled while saving.

### Request admission (`ClinicalAdmissionActionDialog`, request-only)

From clinical workspace: `requiresBed: false` → reason + optional notes only (no ward/room/bed pickers).

- **Cancel** / **Request admission**
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Dismiss / `requestAdmission(reason, notes)`.
  - Condition: Disabled while saving.

### Follow up (`ClinicalFollowUpActionDialog`)

- **Choose date** / **Select time**
  - Location: Date/time fields.
  - Opens modal: Date/time pickers.
  - Immediate result: Sets scheduled date/time.
  - Condition: Not saving.

- **Cancel** / **Save follow-up**
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Dismiss / `scheduleFollowUp`.
  - Condition: Disabled while saving.

### Clinical disposition (`ClinicalDispositionActionDialog`)

Used when disposition is not admission/IPD discharge context.

- **Cancel** / **{actionLabel}** (primary = same dynamic disposition label)
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Dismiss / `completeDisposition(reason, notes)` then snackbar + close encounter dialog.
  - Condition: Disabled while saving.

### Discharge planning (`DischargePlanningDialog` via `showDischargePlanningDialog`)

Used when admission discharge context applies (has admission + IPD/active admission state/location).

- **Refresh** (load error body action, and footer **Refresh**)
  - Location: Error body / footer secondary (`commonRefreshActionLabel`).
  - Opens modal: No.
  - Immediate result: Reloads admission discharge detail.
  - Condition: Error body when load failed; footer when detail loaded.

- **Cancel**
  - Location: Footer.
  - Opens modal: No.
  - Immediate result: Closes without saving.
  - Condition: Disabled while submitting.

- **Save plan**
  - Location: Footer primary when discharge not yet planned.
  - Opens modal: No.
  - Immediate result: Saves discharge plan.
  - Condition: Detail loaded and not planned; disabled while submitting.

- **Finalize discharge** / **Discharge planning** (primary label from `clinicalDispositionActionLabel`)
  - Location: Footer when already planned.
  - Opens modal: No.
  - Immediate result: Finalizes discharge when allowed (`_canFinalize`); may require override notes for blockers.
  - Condition: Planned state; primary disabled when finalize not allowed.

When planned, additional resolve actions:

- **Continue** (per pending order / open pharmacy / open invoice row)
  - Location: Pending orders / related records list tiles.
  - Opens modal: No.
  - Immediate result: Navigates to Lab / Radiology / Pharmacy / Clinical / Billing as appropriate, then refreshes detail.
  - Condition: Planned view; enabled when not submitting.

- **Open nursing** / **Open pharmacy** / **Open billing** / **Open IPD**
  - Location: Cross-module links section.
  - Opens modal: No.
  - Immediate result: Navigates to that module (IPD with admission id when available) and refreshes.
  - Condition: Planned view; Open IPD only when admission display id present.

---

## Notes on non-button surfaces

- Status badges, triage handoff, vitals grid, results chronology, and generic clinical record rows are display-only (no row actions except pharmacy cancel/delete above). Record/Edit vitals is available from Clinical actions (and worklist next-action for `RECORD_VITALS`).
- Copyable patient/encounter/admission identifiers in context tiles expose copy affordances from shared `AppCopyableIdentifier` / field `copyable: true` (not separate labeled page actions).
- Empty clinical worklist has no primary empty-state button (state panel only).
