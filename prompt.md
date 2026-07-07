# Clinical module — patient encounter detail dialog UX overhaul

**Scope:** `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` (`_ClinicalEncounterDialog` and its child panels).

**Goal:** Make the clinical patient encounter dialog scannable at a glance. A clinician should immediately understand who the patient is, where they are in the workflow, what has been ordered, and what needs attention next.

---

## 1. Dialog header

- **Title:** `{Patient name} — Clinical details` (not patient name alone).
- **Subtitle (optional):** encounter public ID and source queue (e.g. OPD).
- Keep the existing medical-services icon and responsive max-width.

## 2. Encounter context panel

Replace the current loose inline layout with a consistent **label → value** pattern (reuse `AppInfoTileGrid` / `AppWorkspacePatientContextField` conventions).

| Field | Example |
|---|---|
| Patient ID | PAT-4E73222F7B (copyable) |
| Encounter | ENC0000003 |
| Assigned staff | Jordan Demo |
| Encounter queue / type | OPD |
| Location | DemoCare General Hospital |
| Phone | +15550000001 |
| Date of birth / Age / Gender | Feb 24, 1994 · 32 · Female |
| Last updated | Jul 7, 2026 9:25 AM |

- Render workflow **status badges** (e.g. Radiology Requested, Urgent, Results ready) as a dedicated badge row beneath the patient ID — not mixed into free text.
- Use existing tone helpers (`AppWorkspaceStatusTone`) for urgency and result-ready states.

## 3. Triage & workflow stage

Improve `_ClinicalTriageHandoffPanel` so workflow position is obvious:

- **Current stage** — highlighted prominently (e.g. "Imaging pending").
- **Workflow steps** — show completed → current → upcoming as a compact stepper or timeline when step history is available from `ClinicalTriageHandoff`.
- **Next step** — call out clearly (e.g. "Perform Imaging") with distinct visual weight.
- **Triage level** — keep existing level label and tone (e.g. Level 1 – Immediate).
- **Arrival / queued time** — retain timestamp.
- **Vitals** — keep grid; abnormal values and the overall vitals status badge must remain visible.
- **Clinical alerts** — keep; ensure high-severity alerts (e.g. high diastolic BP) stand out.

If stage data is editable, gate edits behind permission checks and require a **reason** before saving (follow existing OPD edit-with-reason patterns in `opd_flow_actions_dialog.dart`).

## 4. Lab orders — tabular layout

Replace the nested card/list layout in `_ClinicalLabOrdersPanel` with a **responsive data table** (horizontal scroll on narrow screens).

**Parent order row** (one row per lab order, newest first):

| Column | Content |
|---|---|
| Order / test | Order title or grouped test names |
| Value | Result value when released; `—` otherwise |
| Status | Ordered · In process · Completed · Cancelled |
| Result flag | Normal · Abnormal · Critical · Pending |
| Ordered at | Timestamp |
| Actions | Edit · Void · Delete (permission-gated, status-aware) |

**Child test rows** (expandable or indented sub-rows under the parent order):

| Column | Content |
|---|---|
| Test name | e.g. Acetone [Presence] in Urine \| 5569-9 |
| Category / specimen | CHEMISTRY · URINE |
| Value | Positive/Negative or numeric result |
| Status | Per-test completion status |
| Result flag | Per-test normality |

- Preserve existing edit/cancel/delete flows and confirmation dialogs.
- Sort all orders and nested items **latest → earliest**.

## 5. Radiology orders — tabular layout

Apply the same table treatment to `_ClinicalRadiologyOrderRow` / `_ClinicalRecordSection` radiology block:

| Column | Content |
|---|---|
| Study | e.g. Abdomen and pelvis CT 3D reconstruction |
| Modality | CT · Ultrasound · … |
| Body region | Abdomen and pelvis |
| Status | Ordered · In process · Completed |
| Ordered at | Timestamp |
| Actions | Cancel · Delete (permission-gated) |

Sort **latest → earliest**.

## 6. Result review & record sections

- **Result review** — list only released results ready for sign-off; newest first.
- **Other record sections** (notes, diagnoses, prescriptions, etc.) — keep sectioned layout but ensure each entry shows title, status, and timestamp in a consistent row format.
- Avoid duplicating the same order in both Lab orders and Result review unless the duplication serves a distinct purpose (orders vs. sign-off queue).

## 7. Global rules

- **Sort order:** all time-ordered lists default to **newest first**.
- **Responsive:** tables scroll horizontally on mobile; collapse to stacked label-value cards below ~480 px if needed.
- **Reuse:** `AppWorkspaceDetailPanel`, `AppWorkspaceStatusBadge`, `AppInfoTileGrid`, existing l10n keys; add new keys only when missing.
- **Permissions:** respect `_writeRequirement`, `_labOrderRequirement`, `_radiologyOrderRequirement`; no new permission bypasses.
- **Tests:** update `clinical_workspace_page_test.dart` for title text, table column presence, and sort order.

## 8. Acceptance criteria

- [ ] Dialog title reads "{Name} — Clinical details".
- [ ] Patient/encounter metadata uses uniform label-value tiles; status badges are grouped and color-coded.
- [ ] Triage shows current stage, next step, and workflow progression clearly.
- [ ] Lab orders render in a table with value, status, result flag, and actions columns.
- [ ] Radiology orders render in a comparable table.
- [ ] All lists sorted newest → oldest.
- [ ] Stage edits (where allowed) require a documented reason.
- [ ] Layout is usable on mobile, tablet, and desktop widths.
