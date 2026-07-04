# Lab workspace UX improvements

## Context

Improve the **Laboratory → Patient lab worklist** screen and the **Lab result entry** dialog. Primary files: `lab_workspace_page.dart`, `lab_result_entry_dialog.dart`, `lab_workspace_controller.dart`, and related l10n keys in `app_en.arb`.

Reference screenshots show the current patient worklist table and the result-entry dialog for Joshua Suuna (order `LAB0000006`).

---

## 1. Worklist panel header

- **Remove the subtitle** under “Patient lab worklist” (`labPatientsWorklistDescription` — e.g. “Patients with active lab orders and result-entry work.”).
- Keep the title only. Do not leave redundant or duplicated heading text elsewhere on the panel.

---

## 2. Worklist table — column layout

Split the overloaded **Patient** column into dedicated columns. Each field gets its own column (sortable where practical):

| Column | Content |
|--------|---------|
| **Patient** | Patient display name only |
| **Patient ID** | e.g. `PAT0000002` |
| **Encounter** | Clinical encounter ID (e.g. `ENC0000002`) |
| **Lab encounter** | Lab-specific encounter / lab ID (e.g. `LAB0000006` or equivalent field from `LabOrderSummary`) |
| **Source / location** | Encounter source (e.g. OPD) and location if available |
| **Orders** | Active order count + order IDs (unchanged intent, see §3) |
| **Entry status** | Existing badge |
| **Result status** | Existing badge |

- Remove stacked multi-line identity blocks from a single cell (`_LabOrderIdentity` currently joins name, patient ID, encounter, order count, OPD, etc.).
- Preserve column-visibility settings support (`AppListTableColumnVisibilityController`).
- Ensure cells use stable single-line layout (`maxLines: 1`, ellipsis) so rows stay a consistent height.

---

## 3. Orders column

- **Remove copy-to-clipboard** from order identifiers in the worklist (`AppCopyableIdentifier` in `_LabOrderIdentifier`). Show plain text only.
- For patient-group rows, keep “N active order(s)” plus a truncated list of order IDs.
- Detailed identifiers remain accessible in the result-entry dialog (see §5).

---

## 4. Worklist table — row stability

Rows currently flicker or visually “break” during background refresh (likely realtime/polling updates in `lab_workspace_controller.dart`).

- Identify and fix unnecessary full-table rebuilds or loading-state toggles during silent refresh.
- Preserve scroll position, selection, and row content while data updates in place.
- Avoid blanking or resizing rows when only status fields change.
- Verify with the worklist open while realtime events fire: no layout jump, no row height change, no momentary empty state.

---

## 5. Lab result entry dialog

### 5a. Open maximized by default

- Set `initialMaximized: true` on `AppDialog` in `LabResultEntryDialog` (and/or `showAppDialog` call site) so the dialog opens full-screen on desktop without requiring a manual maximize click.

### 5b. Status display clarity

Screenshots show conflicting badges at the same level (e.g. **Verified** and **Rejected** together on the patient header and on order `LAB0000006`).

- Audit aggregate status logic (`_aggregateOrderStatus`, `_entryStatus`, `_resultStatus`, per-item badges).
- Show **one primary status** at patient/order summary level that reflects the dominant workflow state.
- Surface item-level rejection separately (e.g. per-test row or a “N rejected” sub-badge), not as competing top-level badges.
- Do not show both “Verified” and “Rejected” as peer summary badges unless that accurately reflects business rules; if mixed, prefer labels like “Partially verified” or “Partially rejected.”

### 5c. Workflow timeline deduplication

The workflow section lists duplicate steps (e.g. “Result reported for Brucella Agglutination Test” appears three times).

- Deduplicate `workflow.timeline` entries before rendering in `_LabWorkflowProgressIndicator`.
- Match on a stable key (step id + type, or normalized label); keep the most recent / highest-priority entry when duplicates exist.
- Timeline chips should reflect unique workflow events only.

### 5d. General dialog layout

- Ensure all sections (patient context header, order blocks, workflow progress, result-entry table) render cleanly at maximized size without overflow or awkward wrapping.
- Copyable identifiers (patient ID, encounter) stay in the dialog; not in the worklist orders column.

---

## Acceptance criteria

- [ ] Patient worklist shows title only — no subtitle.
- [ ] Table has separate columns for patient name, patient ID, encounter, lab encounter, and source/location.
- [ ] Order IDs in the worklist are plain text (no copy icon).
- [ ] Table rows remain stable during background refresh — no flicker, jump, or height change.
- [ ] Clicking a row opens the lab result entry dialog **maximized by default**.
- [ ] Dialog status badges are unambiguous — no conflicting Verified/Rejected pair at the same summary level.
- [ ] Workflow timeline shows no duplicate step labels.
- [ ] Existing sort, filter, search, pagination, and column-visibility behavior still work.
- [ ] Add/update l10n keys for any new column headers; run codegen if needed.
