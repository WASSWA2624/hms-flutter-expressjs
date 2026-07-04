# Request Lab dialog — toolbar, table, and patient context polish

Refine the **Request Lab** dialog (`ClinicalLabOrderActionDialog`) layout and styling. The selected-items table and overall flow are good; apply the changes below.

## Scope

Primary files:
- `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart` (`ClinicalRequestFlowToolbar`, `ClinicalRequestSelectedCatalogTable`)
- `frontend/lib/l10n/app_en.arb` (new/updated labels)
- `frontend/test/shared/clinical_actions/clinical_lab_order_action_dialog_test.dart`

Reuse existing components and patterns; keep changes minimal and consistent with other clinical request dialogs.

---

## 1. Toolbar layout

Replace the current left-aligned `Wrap` toolbar with a single horizontal row:

| Left | Right |
|------|-------|
| Patient context (see §2) | Action buttons |

**Right-aligned actions** (order left → right):
1. **Remove selected** — leftmost in the right group; red/destructive icon (treat as a flagged destructive action)
2. **Add items**
3. **Review billing**

- **Remove selected** is enabled only when one or more table rows are checked.
- **Review billing** stays disabled when the list is empty.
- Use `MainAxisAlignment.spaceBetween` (or equivalent) so patient info stays left and actions stay right.

---

## 2. Patient context strip (toolbar left)

Show who the request is for on **one row** (no wrapping to multiple lines):

```
Name: {patient name}   ID: {patient ID}   Encounter ID: {encounter ID}
```

- Use the `label: value` pattern above.
- Source values from the dialog’s patient/encounter context (e.g. pass `patientName`, `patientId`, and `encounterId` into `ClinicalLabOrderActionDialog` from existing call sites such as `openPatientLabOrderDialog`).
- Omit a field only if the value is genuinely unavailable; do not show empty placeholders.

---

## 3. Selected-items table

### Container
- Remove corner radius — **sharp, square edges** on the table border (no `borderRadius`).

### Column headers & alignment
- Rename the **Name** column to a clearer label such as **Test name** (pick the clearest option; update l10n).
- Left-align all table cell content (name, type, price) so long test/panel names read cleanly.

### Actions column
- Replace the icon-only delete control with a labeled action: **Remove item**.
- Style the delete icon and/or label as **red/destructive** to signal a flagged removal.
- Clicking **Remove item** removes that row (existing `onDeleteItem` behavior).

### Bulk remove
- Row checkboxes + header select-all stay as-is.
- **Remove selected** in the toolbar removes all checked rows (existing `onRemoveSelected` behavior).

---

## 4. Out of scope

Do **not** change:
- Catalog picker (“Add items”) flow
- Billing review dialog
- Submit / “Request lab” footer action
- Pricing, totals, or row data logic

---

## 5. Acceptance criteria

- [ ] Toolbar: patient context left; **Remove selected**, **Add items**, **Review billing** right-aligned in that order.
- [ ] **Remove selected** uses a red/destructive icon and is disabled until rows are selected.
- [ ] Patient strip shows `Name`, `ID`, and `Encounter ID` on a single row.
- [ ] Table has square corners (no border radius).
- [ ] **Name** column renamed to a clear test-name label; cells are left-aligned.
- [ ] Per-row **Remove item** action is labeled and uses destructive/red styling.
- [ ] Existing widget tests updated; new cases cover toolbar alignment, patient strip, and remove actions where practical.
