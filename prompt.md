# Radiology Module — Review, Refinement, and Implementation Prompt

## Objective

Improve the Radiology module in the HMS (Hospital Management System) so the workflow is intuitive, dialogs and forms behave consistently with the rest of the app, UI updates reflect saved data immediately, reporting and printing are production-ready, and completed radiology data is visible across authorized modules without manual refresh.

Deliver focused, reviewable changes. Follow existing architecture and shared components; do not introduce parallel patterns.

---

## Project Context

| Layer | Location | Notes |
|---|---|---|
| Frontend | `frontend/lib/features/radiology/` | Feature-first clean architecture: `data/`, `domain/`, `presentation/` |
| Primary UI | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` | Workbench, workflow detail, dialogs, reporting, printing |
| State | `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart` | Riverpod `AsyncNotifier`; HTTP writes + realtime refresh |
| Backend | `backend/src/modules/radiology-workspace/` | REST API, Prisma persistence, WebSocket event broadcast |
| Route | `/radiology` | Module flag: `radiology-workflows`; permissions: `radiologyRead`, `radiologyWrite`, clinical/billing as configured |
| Shared UI | `frontend/lib/shared/components/` | `AppDialog`, `AppSelectField`, `AppFormShell`, `AppFormActions` |
| Dialog helper | `frontend/lib/shared/layout/app_workspace.dart` → `showAppWorkspaceActionDialog` | Standard modal wrapper over `AppDialog` |
| Body region catalog | `frontend/lib/shared/clinical_actions/clinical_radiology_catalog_helpers.dart` → `clinicalRadiologyBodyRegionOptions` | Already used in clinical radiology order dialogs; reuse here |
| Realtime rules | `frontend/.cursor/realtime_sync.mdc` | Controllers refresh via HTTP after WebSocket events; widgets must not parse socket payloads |
| UI patterns | `frontend/.cursor/ui-patterns.mdc`, `frontend/.cursor/components.mdc` | Forms, selects, dialog behavior, localization |
| Reference module | `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart` | Mature dialog footer pattern, save flow, and report UX |

**Stack:** Flutter 3.41+ (Riverpod, GoRouter) · Express.js + Prisma backend · WebSocket realtime sync.

---

## Scope

**In scope:** Radiology module UI/UX, shared dialog/select fixes where radiology exposes the defect, controller save/refresh behavior for radiology mutations, backend radiology endpoints only when required to support the above.

**Out of scope unless required by an in-scope item:** Unrelated modules, broad refactors, new dependencies, schema changes without a documented need.

---

## Known Root Causes (from code review)

1. **Duplicate title** — `_openRadiologyDetailDialog` sets `AppDialog` title to `radiologyDetailTitle`, and `_RadiologyOrderDetail` wraps content in `AppWorkspaceDetailPanel` with the same title.
2. **Body region as free text** — `_RequestDetailsEditForm` uses `AppTextField` for body region; clinical flows already use `AppSelectField` + `clinicalRadiologyBodyRegionOptions`.
3. **STAT label** — `radiologyPriorityStatLabel` is `"STAT"` only; no explanatory subtitle (STAT = *statim*, immediately).
4. **Dialog actions in scroll body** — Forms embed `AppFormActions` inside `AppFormShell` content passed to `showAppWorkspaceActionDialog`, so Cancel/Save scroll with the form instead of staying in the dialog footer (`AppDialog.actions`).
5. **Stale UI after save** — Dialogs pop payload immediately; parent awaits controller mutation but does not block close on success or show in-flight feedback before refresh completes.
6. **Select first-click failure** — Likely shared `AppSelectField` / focus issue; fix at shared component level if reproducible app-wide.

---

## Implementation Tasks

Work in priority order. Each task includes acceptance criteria.

### Task 1 — Workflow detail layout and title

**Goal:** Single, clear heading; organized patient context; readable workflow summary.

**Actions:**
- Remove duplicate `radiologyDetailTitle` — keep it on `AppDialog` only, or on the inner panel only, not both.
- Improve patient header layout in `_RadiologyDetailBody` / `AppWorkspacePatientContextHeader` usage (name, identifiers, status chips, alerts).
- Redesign `_WorkflowSummarySection` for scannability (group related fields, consistent `_DetailLine` spacing, responsive columns on wide viewports).

**Acceptance criteria:**
- [ ] "Radiology workflow" appears once when opening a patient workflow.
- [ ] Patient context is visible above the fold without clutter.
- [ ] Workflow summary is readable on desktop and mobile.

---

### Task 2 — Request details form

**Goal:** Correct fields, shared conventions, first-click select behavior.

**Actions:**
- Replace body region `AppTextField` in `_RequestDetailsEditForm` with `AppSelectField<String>` populated via `clinicalRadiologyBodyRegionOptions` (same source as `clinical_radiology_order_action_dialog.dart`).
- Extend priority options so STAT displays as **STAT (Immediately)** or equivalent localized label + optional helper text via `AppSelectOption` subtitle/hint.
- Investigate and fix `AppSelectField` first-click failure in `frontend/lib/shared/components/` if reproducible; verify priority, laterality, and body region selects in radiology dialogs.

**Acceptance criteria:**
- [ ] Body region is a dropdown with predefined options consistent with clinical radiology ordering.
- [ ] STAT meaning is clear to clinical users.
- [ ] All dropdowns open/select on the first interaction.

---

### Task 3 — Optimistic, visible save and realtime refresh

**Goal:** Users never see stale data immediately after a successful save.

**Actions:**
- Refactor radiology dialog save flows (`_showEditRequestDetailsDialog` and similar) to:
  1. Show loading/disabled state on submit (`isMutating` or dialog-level `closeEnabled: false`).
  2. Await controller mutation success before closing the dialog.
  3. On success, update `RadiologyWorkspaceController` state (optimistic patch or re-fetch selected workflow) so detail panels reflect new values instantly.
  4. On failure, keep dialog open and surface error via `_showMutationResult` / form-level error.
- Ensure `listenForRealtimeRefresh` in the controller defers refresh while `isMutating` (per `realtime_sync.mdc`).
- Apply the same pattern to report draft, release, assign, and study dialogs in this module.

**Acceptance criteria:**
- [ ] After saving request details, the workflow view shows updated priority, body region, laterality, and notes without manual refresh.
- [ ] A visible saving indicator appears during mutation.
- [ ] Dialog closes only after success (or stays open on error).

---

### Task 4 — Dialog footer standardization (radiology first, reusable pattern)

**Goal:** Scrollable content, fixed footer actions.

**Actions:**
- Move `AppFormActions` out of scrollable form bodies into `AppDialog.actions` (or extend `showAppWorkspaceActionDialog` to accept footer actions built from form state).
- Prefer a reusable pattern: form exposes `GlobalKey` / callback for submit validation; dialog footer hosts Cancel + primary action.
- Preserve `AppDialog` auto-resize and maximize behavior (`showMaximizeButton`, desktop resize).
- Align radiology report dialog (Cancel, Save Draft, Release Report) with this pattern.

**Reference:** Lab result entry dialog footer structure in `lab_result_entry_dialog.dart`.

**Acceptance criteria:**
- [ ] Footer buttons remain fixed while form content scrolls.
- [ ] Pattern is reusable for other radiology dialogs in this file.
- [ ] Dialog sizing still adapts to content or maximizes on desktop.

---

### Task 5 — Findings, conclusions, and rich text reporting

**Goal:** Professional editing experience for radiology reports.

**Actions:**
- Audit `_ReportForm`, `_FinalizeReportForm`, and related editors for consistent rich-text or multiline UX (match lab/clinical report forms if a shared editor exists).
- Ensure Findings and Conclusions fields support comfortable editing ( adequate height, formatting if supported elsewhere, localized labels).

**Acceptance criteria:**
- [ ] Draft and release flows use a consistent editing experience.
- [ ] Findings and Conclusions are clearly labeled and editable.

---

### Task 6 — Release report workflow

**Goal:** Clear, functional release path with correct visibility.

**Actions:**
- Trace `_showReleaseReportDialog` → controller → backend finalize/release endpoint.
- Document and implement UX: draft → review → release; status badges on order/result reflect released state.
- Confirm released reports appear for authorized roles (clinical read, radiology read) in patient context and radiology workbench.

**Acceptance criteria:**
- [ ] Release Report action completes successfully end-to-end.
- [ ] Released status is visible in UI after release.
- [ ] Authorized users see released report content without manual refresh.

---

### Task 7 — Print preview and printed report layout

**Goal:** Reliable, professional print output.

**Actions:**
- Improve `_RadiologyPrintDialog` and `PrintFormTemplate` integration in `radiology_workspace_page.dart`.
- Print layout must include: patient information, study details, findings, conclusions, radiologist information, report date/time.
- Optional: include selected study asset images when user opts in.
- Verify Print action across Chrome (primary web target) and at least one desktop target.

**Acceptance criteria:**
- [ ] Print preview renders a clean clinical report layout.
- [ ] Print button produces correct output consistently.
- [ ] Required fields are present on printed report.

---

### Task 8 — Study assets (images and captions)

**Goal:** Support imaging documentation in the workflow.

**Actions:**
- Enhance `_StudiesSection` / study asset display beyond metadata lines (`_DetailLine` for `ImagingAsset`).
- Support: multi-image upload, caption per image, inline preview, edit caption, remove image.
- Wire upload/remove to existing backend study/asset endpoints; add backend support only if missing.
- Allow optional inclusion of captioned images in print output (Task 7).

**Acceptance criteria:**
- [ ] Users can upload, preview, caption, edit, and remove study images.
- [ ] Assets persist and reload correctly on workflow reopen.
- [ ] Selected images can appear on printed reports when enabled.

---

### Task 9 — Workflow simplification

**Goal:** Linear radiology path with minimum friction.

**Target flow:**
1. Receive imaging request
2. Review study details
3. Perform imaging study
4. Upload study assets
5. Enter findings and conclusions
6. Finalize and release report

**Actions:**
- Map current `workflow.nextActions` steps against the target flow; hide or consolidate redundant panels/actions.
- Use progressive disclosure: show only actions valid for the current stage.
- Keep billing/authorization gates intact.

**Acceptance criteria:**
- [ ] Typical study completion follows the six steps without unnecessary screens.
- [ ] Invalid actions are disabled/hidden, not error-prone.

---

### Task 10 — Cross-module visibility and sync

**Goal:** Completed radiology data propagates across HMS.

**Actions:**
- Verify backend publishes radiology CRUD events consumed by `RealtimeEventGroups.radiology`.
- Ensure clinical workspace, patient records, encounters, orders, and dashboards refresh when radiology orders complete or reports release (controller listeners + scope filters).
- No manual page refresh required for authorized viewers.

**Acceptance criteria:**
- [ ] Doctors, nurses, radiologists, and other authorized staff see completed radiology data in their modules.
- [ ] Updates appear via realtime refresh or immediate post-mutation re-fetch.

---

### Task 11 — Responsive design

**Goal:** Usable on desktop, laptop, tablet, and mobile.

**Actions:**
- Apply `PageMaxWidth`, `AppWorkspace`, and design-system spacing tokens throughout radiology views.
- Touch-friendly controls (min 40–48px targets per `components.mdc`).
- Test workflow detail dialog and workbench at breakpoints defined in `frontend/.cursor/layouts.mdc`.

**Acceptance criteria:**
- [ ] No horizontal overflow or clipped actions on mobile.
- [ ] Dialogs and tables degrade gracefully (cards/lists where needed).

---

## Technical Constraints

- **Localization:** All new labels, hints, and STAT descriptions go in ARB files (`frontend/lib/l10n/`), not hard-coded strings.
- **Architecture:** No business logic in widgets beyond presentation; mutations through `RadiologyWorkspaceController` → repository → HTTP.
- **Shared components:** Extend `AppDialog` / `AppSelectField` rather than duplicating; body region options from `clinicalRadiologyBodyRegionOptions`.
- **Realtime:** Follow `listenForRealtimeRefresh` + HTTP re-fetch; debounce 250ms; defer while mutating.
- **Permissions:** Respect `AppPermissions.radiologyRead`, `radiologyWrite`, and `AppAccessPolicy` checks already in the page.
- **Tests:** Add/update tests in `frontend/test/features/radiology/` and `backend/src/tests/modules/radiology-workspace/` for changed DTO mapping, controller behavior, and critical dialog/save flows where practical.

---

## Verification Checklist

Before marking complete, manually verify:

1. Open radiology workbench → select patient → workflow dialog: single title, clean layout.
2. Edit request details: body region dropdown, STAT label, selects on first click, save shows loading, UI updates, dialog closes on success.
3. Complete draft report → release report → status visible; clinical/radiology views show released content.
4. Upload study image with caption → preview → print with image option.
5. Print report: layout, content, browser reliability.
6. Resize to mobile width: usable layout, fixed dialog footers.
7. Second user/session (or simulated realtime event): sees updates without refresh.

---

## Expected Outcome

A production-quality Radiology module with:

- Clean, linear workflow UX
- Consistent dialog and form patterns aligned with Lab and shared components
- Immediate, trustworthy UI updates after saves
- Reliable backend/frontend synchronization via HTTP + WebSocket refresh
- Professional reporting, release workflow, and print output
- Image upload, caption, and optional print inclusion
- Responsive experience across devices
- Cross-module visibility of completed radiology data per user permissions
