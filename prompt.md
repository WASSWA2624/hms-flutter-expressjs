# Feature: Refine Radiology workflow detail dialog

## Goal

Redesign the **Radiology workflow** detail dialog (opened from the worklist) so it is scannable, role-aware, and free of duplicate metadata. Radiographers and radiologists should immediately see **who**, **what study**, **order status**, and **what to do next**—without hunting across repeated sections.

## Current problems (from screenshots)

| Area | Issue |
|------|-------|
| **Dialog title** | Order ID (`RAD0000001`) repeats in the title subtitle and again in the patient header |
| **Patient header** | Avatar adds noise; order ID and study appear as tile fields while the same data is shown again below |
| **Header actions** | Icon-only buttons (assign, start, perform study, cancel) lack visible labels—purpose is unclear |
| **View-mode toggle** | *Imaging floor* vs *Reporting* purpose is not obvious to users |
| **Metadata placement** | *Order metadata* (ordered at, modality, encounter, payment) is separated from patient context and overlaps header fields (payment, priority) |
| **Request details** | Study, priority, body region, laterality, and clinical notes duplicate header/metadata content |
| **Studies and assets** | Copy is verbose; acquisition paths (perform study, upload, camera, PACS sync) and sync status are not clearly communicated |
| **Report** | Empty state persists after imaging; reporting workspace is not clearly surfaced for the radiologist once studies exist |

## Information hierarchy

Each datum appears **once**, in the section below. Use `Label: value` inline pairs (Lab `_LabContextInlineFact` pattern)—not subtitle stacking or tile grids for scalar fields.

### 1. Dialog chrome

- **Title:** `Radiology workflow` only—**remove order ID** from the dialog title/subtitle.
- Order ID remains available once in the consolidated metadata block (see §3).

### 2. Patient & order context (top block)

Replace the current avatar + tile layout with a compact **inline fact row** (no avatar):

| Field | Source | Notes |
|-------|--------|-------|
| Patient | `patientDisplayName` | |
| Patient ID | `patientId` | Copy affordance |
| Status | order status | `AppWorkspaceStatusBadge` |
| Study | `testDisplayName` | Procedure name only |
| Billing alert | `hasBillingGate` | Warning chip when gate unavailable |

**Do not** repeat order ID, priority, modality, encounter, or payment here—they belong in §3.

**Header actions:** Keep workflow actions (assign, start imaging, perform study, draft/release report, cancel) but ensure every control has a **visible label or unambiguous tooltip** (`semanticLabel`, `tooltip`). Prefer labeled secondary buttons over icon-only where space allows; icon-only is acceptable only with tooltip + accessibility label.

Use `AppWorkspacePatientContextHeader` with `showAvatar: false` and `fieldStyle` aligned to inline pairs—or extract a shared inline-context header if Lab and Radiology would duplicate the same layout.

### 3. Order metadata (immediately below patient context)

Single **Order metadata** section—move `_WorkflowSummarySection` directly under the patient block. Fields:

| Field | Source |
|-------|--------|
| Order | `effectiveDisplayId` |
| Ordered | `orderedAt` |
| Modality | `modality` |
| Encounter | `encounterId` |
| Priority | `priority` |
| Payment | `effectivePaymentStatus` (or billing-gate unavailable state) |
| Authorization | `authorizationStatus` (when present) |

Show *Not available* only when the value is genuinely null/empty—do not duplicate fields already shown above.

### 4. View mode toggle (keep, clarify)

Retain **Imaging floor** / **Reporting** segmented control but add brief helper text or subtitle:

- **Imaging floor** — perform studies, acquire/upload assets, PACS sync (radiographer workflow).
- **Reporting** — draft, finalize, and release the radiology report (radiologist workflow).

Default mode stays role-inferred (`canRequest && !canWork` → Reporting; else Imaging floor).

### 5. Workflow progress (keep)

Keep `_WorkflowProgressSection` and step-to-section scroll behavior unchanged for now.

### 6. Studies and assets

Simplify copy; emphasize **actions and state**:

- Empty state: short title + one-line body; primary CTA **Perform study**; secondary **Upload images** (disabled until study exists).
- After perform: show study row with asset count, PACS sync status, and acquisition options—**upload file**, **capture photo**, **sync from PACS** (wire existing `canPacsSync` / `uploadStudyAssets` flows).
- When a draft/final report exists, surface a collapsible **report preview** here (already partially implemented)—this is where reporting output is visible on the imaging floor.

Reduce section description text; let actions and status badges carry meaning.

### 7. Request details

Show only fields **not already in §2–3**, or collapse this section into §3 if nothing remains unique:

- Body region (`bodyRegion`)
- Laterality (`laterality`)
- Clinical notes (`clinicalNote`)

Remove duplicate study and priority rows. Keep edit affordance for radiology staff who can amend request details.

### 8. Report (reporting view)

When imaging is complete (`studies.isNotEmpty` or workflow step ≥ report):

- Replace generic empty state with an actionable reporting workspace: inline draft editor, draft/finalize/release actions, and print.
- In **Reporting** view, promote report editing above studies; in **Imaging floor** view, keep report section secondary (preview/link only).

Ensure `_ReportingSection` inline editor and dialog flows work end-to-end after study performance.

### 9. Workflow timeline (keep)

No structural change; remains at the bottom as audit trail.

## Section order

**Imaging floor view:** Patient context → Order metadata → View toggle → Workflow progress → Studies and assets → Request details (unique fields only) → Report (preview/link) → Timeline

**Reporting view:** Patient context → Order metadata → View toggle → Workflow progress → Report (primary) → Request details → Studies and assets → Timeline

## Reference implementation

**Primary file:** `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`

Key widgets: `_RadiologyDetailBody`, `_WorkflowSummarySection`, `_WorkflowProgressSection`, `_StudiesSection`, `_RequestSection`, `_ReportingSection`, `_TimelineSection`, `_openRadiologyDetailDialog`

**Inline fact pattern:** `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart` (`_LabResultContextHeader`, `_LabContextInlineFact`)

**Shared components:** `AppWorkspacePatientContextHeader`, `AppWorkspaceDetailPanel`, `AppWorkspaceStatusBadge`, `AppDialog` — `frontend/lib/shared/layout/app_workspace.dart`

**Entities:** `frontend/lib/features/radiology/domain/entities/radiology_entities.dart` (`RadiologyOrder`, `RadiologyWorkflow`, `ImagingStudy`)

## Implementation rules

- **Eliminate duplicates** — grep for `effectiveDisplayId`, `testDisplayName`, `priority`, `modality`, `encounterId` in the detail dialog and ensure each appears in one section only.
- **No new visual language** — match Lab inline-context spacing, typography, and existing `AppWorkspace*` primitives.
- **Localization** — add/adjust keys in `frontend/lib/l10n/app_en.arb` for clarified view-mode helper text and shortened studies/report copy.
- **Accessibility** — every icon action must have `tooltip` and `semanticLabel`.
- **Scope** — detail dialog UX only; worklist table changes are out of scope (see `prompt1.md`).

## Acceptance criteria

- [ ] Dialog title is `Radiology workflow` with no order ID in the header chrome.
- [ ] Patient block uses inline `Label: value` pairs, no avatar, no duplicate order/study/priority/modality.
- [ ] Order metadata sits directly under patient context with order ID, timing, modality, encounter, priority, and payment in one place.
- [ ] Header workflow actions are identifiable (label and/or tooltip).
- [ ] Imaging floor vs Reporting toggle includes brief role-oriented helper text.
- [ ] Workflow progress section unchanged and still scrolls to the correct section on step tap.
- [ ] Studies section clearly supports perform → acquire (upload/camera/PACS) with concise copy and visible sync status.
- [ ] Request details shows only non-duplicated clinical fields.
- [ ] Report section becomes actionable after imaging is performed; reporting view prioritizes the editor.
- [ ] No regression to existing radiology workflow actions (assign, start, perform, upload, PACS sync, draft, finalize, cancel).
