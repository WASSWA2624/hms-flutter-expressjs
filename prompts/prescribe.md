# Implementation prompt: Prescribe — Add medicine via catalog table

## Goal

Change the clinical **Prescribe** flow so **Add medicine** opens a **catalog table** of available drugs for selection (not a single-drug detail form). Selected medicines are added to the existing prescribe list; prescription details (quantity, dose, route, frequency, duration, instructions) are completed afterward on the prescribe dialog (via the existing edit path).

Primary surface: `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`.

Closest UX precedent: lab / radiology / procedure request flows that open a catalog picker table, then manage selected items on the parent request dialog (`clinical_lab_request_catalog_dialog.dart`, `clinical_radiology_request_catalog_dialog.dart`, `clinical_procedure_catalog_dialog.dart`).

## Current behavior (as implemented)

Screenshots and code agree on this flow today:

### Prescribe dialog (`ClinicalPrescriptionActionDialog`)

| Area | Behavior |
| --- | --- |
| Shell | `AppDialog` titled **Prescribe**, max width ~880, pin actions |
| Body | `AppListTable` of pending prescription lines |
| Empty state | “No medicines added yet” |
| Search / tools | Search by medicine/dose/route/frequency; Filters; Settings (column visibility); Export; **Remove selected**; **Add medicine**; **Review billing** |
| Footer | Cancel · Prescribe (enabled when `_lines` is non-empty) |
| Billing | Optional review; submit still attaches bill-later billing when not reviewed |

### Add medicine (current)

Tapping **Add medicine** calls `_openLineDialog()` with no `editIndex`, which opens a nested **Add medicine** dialog containing `_PrescriptionLineCard`:

1. **Available drug** — searchable `AppSelectField` over `referenceData.drugs` (required)
2. Quantity + quantity unit
3. Dose amount + dose unit (dose amount required)
4. Route (default `ORAL`) + frequency (default `BID`)
5. Duration + duration unit (default days)
6. Instructions

**Done** validates the form, then appends that single line to `_lines`. One medicine per open.

### Edit medicine (current)

Row **Edit** reuses the same nested form dialog (`clinicalPrescriptionEditLineDialogTitle`) against an existing line. This path must remain available for completing/changing prescription details.

### Submit payload (preserve)

Each line still submits roughly:

- `drug_id`, `quantity`, `quantity_unit`, `dose_amount`, `dose_unit`, `route`, `frequency`, `duration_value`, `duration_unit`, `instructions`

Do not change the API contract unless a field is already optional today and remains optional.

## Intended behavior

Split **drug selection** from **prescription detail entry**:

1. User opens **Prescribe** (unchanged list shell).
2. User taps **Add medicine**.
3. A nested dialog opens as a **table of available / prescribable medicines** (from the same drug catalog the form dropdown uses today: `widget.referenceData.drugs`), with search/select patterns consistent with other clinical catalog pickers.
4. User selects one or more medicines and confirms (e.g. **Done**).
5. Selected drugs are **appended as rows** on the prescribe list (with existing line defaults: quantity `1`, route `ORAL`, frequency `BID`, empty dose until edited).
6. On the prescribe dialog, the user completes prescription details — primarily via the existing **Edit medicine** dialog (form fields for quantity/dose/route/frequency/duration/instructions). Changing the drug in edit may remain allowed if it already is; selection of *new* drugs for the list happens only through the catalog table.
7. **Prescribe** / **Review billing** / **Remove selected** / filters / column settings / submit semantics stay as today, except validation must cover lines that were added without completing required dose fields in the old Add form.

## Gap to close

| Area | Gap |
| --- | --- |
| Add medicine entry | Opens detail form + drug dropdown instead of a catalog **table** picker |
| Multi-add | Only one medicine can be configured per Add open |
| Separation of concerns | Drug pick and sig/qty entry are coupled in one dialog on add |
| Validation timing | Required dose is enforced on Add Done today; after the change it must be enforced before Prescribe (and/or when leaving Edit) |
| Tests | `_addAmoxicillinLine` assumes Add medicine → drug field → dose → Done |

## Requirements

### 1. Catalog picker for Add medicine

Replace the **create** path of `_openLineDialog()` (when `editIndex == null`) with a medicine catalog picker dialog:

1. Present available drugs as an `AppListTable` (or the same table/list pattern used by lab/radiology catalog pickers), not as a lone searchable dropdown form.
2. Support search over drug display fields (name / subtitle / code if present on `ClinicalActionCatalogOption`).
3. Support **multi-select** so several medicines can be added in one Done.
4. Confirming selection creates one `_PrescriptionLineFormState` per newly selected drug, sets `drugId` from `option.apiId`, applies existing defaults, and appends to `_lines`.
5. Prefer excluding (or disabling) drugs already present on the prescribe list (`drug_id` already in `_lines`) to avoid accidental duplicates; if a duplicate is still possible, skip re-add rather than creating a second identical row.
6. Cancel / dismiss leaves `_lines` unchanged.
7. Reuse shared catalog picker chrome where practical (`AppDialog`, `AppListTable`, selection column, Done / Cancel, existing l10n such as `clinicalRequestCatalogPickerDoneAction`). A dedicated `showClinicalPrescriptionCatalogDialog` (or inline private dialog in the same file) is fine; do not invent a parallel design system.

### 2. Prescribe list after selection

- Newly added rows appear immediately on the prescribe table with medicine name resolved from catalog.
- Dose / sig / quantity cells may show defaults or placeholders until the user edits (quantity already defaults to `1`; dose may be empty/`—` until set).
- Do **not** require opening the detail form before the row is listed.

### 3. Edit medicine (preserve, still the detail editor)

- Keep **Edit medicine** as the nested `_PrescriptionLineCard` form for completing quantity, dose, route, frequency, duration, and instructions.
- On edit, drug may remain selectable as today **or** be locked to the already-chosen catalog drug if that better matches “pick first, then prescribe” — prefer locking only if it simplifies UX without blocking legitimate corrections; default to preserving current edit-time drug changeability unless product clearly wants lock.
- Edit Cancel must not discard unrelated lines; same dispose rules as today for failed create no longer apply to the new create path.

### 4. Validation before Prescribe

Because Add no longer validates dose amount:

1. **Prescribe** must not submit incomplete required fields. At minimum, each line needs a `drug_id` and a valid positive dose amount (same rules as today’s form validators). Quantity remains required positive integer (default `1` already satisfies this).
2. On validation failure: show the existing failure banner / validation failure pattern; do not close the dialog; optionally focus or mark the first incomplete line.
3. Edit **Done** should keep its current form validation.

### 5. Preserve unrelated prescribe behavior

Do not regress:

- Search, filters (route/frequency), column visibility, export, remove selected (+ confirm), review billing resolve + dialog, bill-later default on submit, mobile row layout, empty/search-empty copy, save loading/`closeEnabled` while saving.

### Localization

- Prefer existing keys (`clinicalPrescriptionAddMedicineAction`, `clinicalPrescriptionLineDialogTitle`, catalog Done, etc.).
- Add new arb keys only where needed (e.g. picker title/search empty “No medicines match…”, “Select medicines to prescribe”). No hard-coded user-facing English in widgets beyond existing repo patterns.
- Regenerate l10n the way this repo already does.

### Tests

Update `frontend/test/shared/clinical_actions/clinical_prescription_action_dialog_test.dart`:

- **Add medicine** opens a catalog **table** picker (not the old single-card “Available drug” form as the primary add UI).
- Selecting one or more catalog rows and confirming adds those medicines to the prescribe list.
- Cancel on picker adds nothing.
- Duplicate / already-listed drug is not added twice (per chosen duplicate policy).
- Edit medicine still opens the detail form and can set dose/quantity.
- Prescribe is blocked (or shows validation) when a listed line lacks required dose.
- Submit payload still includes `drug_id` and detail fields after edit.
- Existing toolbar / empty-state / remove-selected / review-billing-disabled-when-empty coverage remains green.

## Non-goals / preserve

- Do not redesign the outer Prescribe dialog chrome or billing flow.
- Do not change pharmacy dispense / instructions print / backend prescribe APIs.
- Do not move prescription detail entry to fully inline table editors unless already supported by shared table components; nested Edit dialog is the intended detail surface.
- Do not require live remote drug search unless `referenceData.drugs` is already insufficient and another clinical catalog in this app already does remote search for drugs — default to the in-memory `referenceData.drugs` list used today.
- Do not change non-prescription clinical action dialogs.

## Acceptance criteria

- [ ] **Add medicine** opens a selectable **table** of available drugs.
- [ ] Confirming selection adds those medicines as rows on the Prescribe list without forcing detail entry first.
- [ ] Multi-select add works in one picker session.
- [ ] Prescription details are completed on the prescribe side via **Edit medicine** (existing form fields).
- [ ] Prescribe validates required line fields before submit.
- [ ] Remove selected, filters, billing review, and submit payload shape remain intact.
- [ ] Widget tests cover picker add, edit details, validation, and submit.

## Implementation notes

- Mirror lab order’s split: parent dialog owns selected lines; nested catalog dialog only returns selected `ClinicalActionCatalogOption`s (or ids), then parent materializes `_PrescriptionLineFormState`.
- Keep `_openLineDialog(editIndex: …)` for edit; introduce `_openCatalogPicker()` (name flexible) for add.
- When creating lines from catalog options, set `drugId` immediately; leave dose empty until edit unless catalog metadata already supplies a safe default (today’s catalog option does not require inventing dose).
- Dispose any temporary line state only for abandoned create flows; catalog add should create lines only after Done.
- Prefer extracting a small private/catalog dialog file next to the prescription dialog if the picker grows past ~200 lines, matching `clinical_*_catalog_dialog.dart` layout.
