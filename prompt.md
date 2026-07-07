# OPD Encounter Dialog — Visual Polish

## Objective

Improve the **OPD Encounter** modal (`FlowActionsDialog`) so encounter context, clinical services, and workflow actions read clearly at a glance on desktop, tablet, and mobile. The dialog structure is already solid; this task is **visual hierarchy and layout only** — no workflow, API, or permission changes.

**Reference state:** encounter at stage *Imaging pending* with vitals completed, radiology orders in *Ordered* / *In Process*, and a full action grid visible.

---

## Scope

| Section | File(s) | Problem (from review) |
| ------- | ------- | --------------------- |
| Encounter context | `frontend/lib/shared/opd_actions/opd_action_context.dart` | Flat label/value row; busy fields (stage, triage, payment, next step) lack visual weight and color cues |
| Clinical services | `frontend/lib/shared/opd_actions/opd_encounter_clinical_services.dart` | Table does not fill dialog width — large empty area on the right; status/location values are plain text |
| Actions | `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart` (+ shared `AppActionSection`) | Button grid alignment uneven; columns feel ragged at common dialog widths |

**Out of scope:** new actions, stage logic, billing rules, clinical data mapping, routing, or backend changes.

---

## Requirements

### 1. Encounter context

- Replace the single-line `Wrap` of `label: value;` pairs with a **responsive summary layout**:
  - **Desktop (≥900px):** 2–3 column grid of compact info tiles.
  - **Tablet / mobile:** stacked tiles or wrapped chips — no horizontal overflow.
- Apply **semantic color** using existing tokens (`AppWorkspaceStatusBadge`, `opdStageStatusTone`, theme `colorScheme`):
  - **Current stage** and **next step** — badge or tinted value (info/warning as appropriate).
  - **Triage level** — severity tone (e.g. Level 1 → error/urgent).
  - **Payment status** — paid → success; unpaid/due → warning.
- Keep **copyable** patient ID and encounter ID behavior (`AppCopyableIdentifier`).
- **Journey** trail: retain content; improve legibility (muted prefix, stage chips or arrow-separated badges instead of one long plain string).
- Reuse shared components (`AppInfoTile`, `AppSectionPanel`, `AppWorkspaceStatusBadge`) before adding new widgets.

### 2. Clinical services

- Make the table **full-width** inside the dialog:
  - Prefer `LayoutBuilder` + fixed/flex column widths over a narrow `DataTable` inside `SingleChildScrollView` when space allows.
  - Distribute columns: Service and Result wider; Requested, Status, Location proportional.
  - Only enable horizontal scroll on **compact** breakpoints (<640px), where card layout already exists.
- **Color-code status** per row (reuse or extend `opdStageStatusTone` / workspace tone helpers):
  - *Completed* → success
  - *Ordered* / *In Process* / *Pending* → info or warning
  - *Cancelled* / *Failed* → error
- Render status (and optionally location) as **`AppWorkspaceStatusBadge`** or equivalent compact chip — not raw `Text`.
- Emphasize **result values** (e.g. vitals, measurements) with slightly stronger typography; keep *Not available* muted.
- Preserve existing row builders (`buildOpdClinicalServiceRows`, location logic) and responsive card fallback.

### 3. Actions grid

- Tune `AppActionSection` usage in `_actionGrid`:
  - Consistent **column count** and **equal button widths** per row at dialog `maxWidth` (860) and common breakpoints.
  - Align primary (next-step) action visually — first in reading order or full-width on narrow screens.
  - Use `minItemWidth` / `maxColumns` so buttons do not leave large gaps (target: 3–4 balanced columns on desktop, 2 on tablet, 1–2 on mobile).
- Do not change which actions appear or their RBAC gates.

---

## Standards

- Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`.
- All new user-visible strings → `app_en.arb` (likely none if reusing existing labels).
- Light/dark theme safe; no hardcoded colors.
- Responsive: mobile, tablet, desktop.
- Extend existing helpers in `opd_status_display.dart` rather than duplicating tone maps.

---

## Acceptance criteria

1. Encounter context shows stage, triage, payment, and next step with clear visual priority and color coding.
2. Clinical services table uses available dialog width; no large unused right margin on desktop.
3. Service statuses appear as color-coded badges/chips consistent with OPD worklist tones.
4. Action buttons form an even, aligned grid at 860px and narrower breakpoints.
5. `flutter analyze` and `flutter test` pass; update/add widget tests in `frontend/test/shared/opd_actions/` where layout helpers change.

---

## Verification

1. Open OPD workspace → select encounter **ENC0000003** (or any encounter with vitals + radiology orders).
2. Confirm the three sections above at **~1200px**, **~768px**, and **~400px** widths.
3. Run: `cd frontend && flutter analyze && flutter test test/shared/opd_actions/`
