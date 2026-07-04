# Lab result entry & report preview — UI polish and correctness

## Context

The lab result entry dialog (`lab_result_entry_dialog.dart`) opens maximized by default — keep that behavior. The result report preview dialog works for test selection but has flag/print correctness issues. Screenshots show duplicated patient/order metadata, redundant workflow status, and a **WBC result of 15** flagged **High** in the entry table but **Normal** in the report preview.

Primary file: `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`

---

## 1. Dialog titles (all dialogs)

- Use **Title Case** for every dialog title (e.g. **Lab Result Entry**, **Result Report Preview**), unless a product exception already exists.
- Update l10n strings in `app_en.arb` (and generated localizations) as needed.

---



## 2. Lab result entry — header & metadata (remove duplication)

**Problem:** Patient name, order status, and encounter info appear multiple times (dialog subtitle, context header, order section).

**Target layout:**

- **Dialog title area:** Title only (no repeated patient/order subtitle).
- **Single patient context strip** immediately below the title, using inline `Label: Value` pairs in a `Wrap`:
  - Patient name, Patient ID, Encounter (if any), Orders included — each as `Label: Value`.
  - Fill horizontally until space runs out, then wrap to the next row.
  - Keep copy-to-clipboard on identifiers where it exists today.
- **Order section:** Show order ID, ordered-at date, and encounter **once**. Do **not** repeat the aggregate order status badge if it already appears in the patient strip (show it in one place only).

**Remove** the workflow progress block (`_LabWorkflowProgressIndicator` — “Current step: Rejected”, timeline chips). Order-level rejection/progress belongs in the test rows, not a separate workflow panel.

---



## 3. Lab result entry — test table

- **Group tests by panel** (panel header → child tests). Standalone tests stay ungrouped. Preserve current panel ordering from catalog/panel metadata.
- **Per-test status** (Cancelled, Not entered, Verified, etc.) lives in the test rows only — not in a separate workflow section.
- **Cancelled/rejected tests:** Use theme **error/danger** styling (badge, row tint, or both) so they are immediately distinguishable.
- **Result flags** must match reference ranges and stored overrides — same logic as the entry table today:
  - Numeric: derive High/Low/Normal/Critical from reference ranges when no explicit flag override exists.
  - Qualitative: respect option flags (e.g. Negative/Positive).
  - Verified entry table is the source of truth; preview/print must reuse that logic (see §5).

**Delete / reject behavior:**

- **Reject (delete request):** Require a **mandatory reason** before confirming. After success, the test row is removed or clearly marked cancelled per existing workflow rules.
- **Panel child tests:** Do **not** offer delete for individual tests inside a panel (administrative constraint). Show blank/disabled action or **Restore test** only where applicable — never a standalone delete that breaks panel integrity.
- Verify **Edit verified result** and **Delete request** actions complete successfully end-to-end.

---



## 4. Result report preview dialog

- Open **maximized by default** (`initialMaximized: true` on `AppDialog`), consistent with the entry dialog.
- Keep existing test-selection UX (include checkboxes, select all/clear, include-order-details toggle, print action).
- **Fix flag column** in both on-screen preview and print HTML: flags must match the entry table for the same item (e.g. WBC 15 → **High**, not Normal).
  - Do not rely solely on `item.resultFlag ?? item.effectiveResultStatus` when a computed flag from reference range is available.
  - Reuse or extract the same flag-resolution path used by `_resultFlagLabel` / `_submittedResultStatus` in the entry table.
- Printed output should render cleanly: correct flags, reference ranges, result values, and cancelled/pending states.

---



## 5. Acceptance criteria


| Area            | Expected                                                                                      |
| --------------- | --------------------------------------------------------------------------------------------- |
| Titles          | All lab dialog titles in Title Case                                                           |
| Header          | No duplicate patient name or order status; metadata shown as `Label: Value` in a wrapping row |
| Workflow block  | “Current step” / timeline section removed from entry dialog                                   |
| Panels          | Tests nested under panel headers in correct order                                             |
| Cancelled tests | Visually distinct (danger styling)                                                            |
| Entry flags     | WBC 15 outside 4.0–11.0 shows **High** with abnormal row styling                              |
| Preview flags   | Same WBC row shows **High** in preview and printed report                                     |
| Preview dialog  | Opens maximized                                                                               |
| Delete          | Cannot proceed without a reason; row updates after success                                    |
| Panel tests     | No per-test delete inside panels                                                              |


---



## 6. Out of scope

- Backend/API changes unless required to fix flag persistence.
- New administrative panel-editing flows.

