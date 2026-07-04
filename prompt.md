# Laboratory Result Report — Print Layout Refinement

## Objective

Refine the **Laboratory result report** print template (shared `PrintFormTemplate` standard layout) so the document reads like a clean clinical report: compact facility header, inline patient metadata, lab-order and print timestamp under the title, unchanged results table, and a single-row signature block.

**Reference:** attached screenshots of the current report (DemoCare General Hospital / Joshua Suuna / LAB0000006).

---

## Scope

| In scope | Out of scope |
| -------- | ------------ |
| Shared print template layout (`PrintFormTemplate` standard layout) | Lab result table columns, abnormal-row styling, or result-entry logic |
| Facility header ordering and fields | New data sources or API changes |
| Patient / order / print metadata presentation | Legacy (non-standard) print layout |
| Signature row layout | Footer note text |

**Primary files:**

- `frontend/lib/shared/printing/print_form_template.dart` — HTML/CSS layout
- `frontend/lib/app/printing/print_form_template_context.dart` — facility branding data (contacts, address, details)
- `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart` — lab report invocation (`printFormTemplateDocument`, `_reportContextReference`)
- `frontend/test/shared/printing/print_form_template_test.dart` — update/add layout assertions

---

## Layout Requirements

### 1. Facility header (top block)

**Order (top → bottom):**

1. **Facility name** (bold, prominent)
2. **Address** — full address on **one line** (join line 1, city, country with commas; no line breaks)
3. **Contacts** — only when present, comma-separated on one line:
   - `Phone: {value}` if phone exists
   - `Email: {value}` if email exists
   - Example: `Phone: +2567001000, Email: info@democare.ug`

**Remove from header:** facility **Type** and **Tenant** (stop populating `PrintFormBranding.details` for facility branding, or omit from render).

Keep logo placement as today (left of facility block).

---

### 2. Patient information (no bordered boxes)

Replace the current 3-column bordered key-value grid with **plain inline text** — no borders, no boxed cells.

**Single line** (comma-separated pairs):

```
Patient name: {name}, Patient ID: {id}, Encounter ID: {id}
```

- Omit any field whose value is empty.
- Use existing l10n labels (`printFormPatientNameLabel`, `printFormPatientIdLabel`, `printFormEncounterIdLabel`).
- Format: `{Label}: {value}` with `, ` between pairs.

---

### 3. Report title block

Keep the main title (e.g. **Laboratory result report**) as `h1`.

**Directly below the title** — one row with lab order and print timestamp:

```
Lab order: {LAB0000006}, Printed on: {date}, Printed at: {time}
```

| Field | Rule |
| ----- | ---- |
| Lab order | Move out of patient context; use `PrintFormContextReference` value (label: `labOrderFieldLabel`) |
| Printed on | Date only — locale-formatted date from `printedAt` |
| Printed at | Time only — locale-formatted time from `printedAt` |

- Add l10n keys if needed (`printFormPrintedOnLabel`, `printFormPrintedAtLabel`) — do not hardcode strings.
- Remove the separate top-right metadata box that currently shows a single combined “Printed” datetime.

---

### 4. Results table

**No changes.** Keep columns: Tests, Reference range, Result, Flag. Preserve abnormal-result row highlighting (red text / bold).

---

### 5. Signatures (footer of content)

**Printed by** and **Verified by** on the **same horizontal row** (two equal columns), each with:

- Uppercase label
- Printed name (when available)
- Ample space below for **signature / stamp** line

Ensure sufficient width and min-height so both blocks fit side-by-side on A4 without wrapping labels onto separate rows.

---

## Acceptance Criteria

- [ ] Facility header shows name → single-line address → phone/email contacts only; no Type or Tenant
- [ ] Patient name, Patient ID, and Encounter ID appear inline on one line without bordered boxes
- [ ] Lab order ID sits below the report title, not in the patient line
- [ ] Print timestamp split into **Printed on** (date) and **Printed at** (time) on the same row as lab order
- [ ] Results table and abnormal highlighting unchanged
- [ ] Printed by / Verified by share one row with room for signature and stamp
- [ ] All new user-visible strings in `app_en.arb`
- [ ] `flutter test frontend/test/shared/printing/print_form_template_test.dart` passes
- [ ] Lab report print preview matches the layout above

---

## Quality Gate

From `frontend/`:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test test/shared/printing/print_form_template_test.dart
```

Manually print/preview a lab report with at least one abnormal result row to confirm visual layout.
