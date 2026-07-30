# Lab Result Entry — Placeholder Weight, Bold Section Headers, Unit–Range Sync, Chevron Alignment

Fix lab result entry so empty Result-column fields read as placeholders (not values), make collapsible section titles bolder app-wide, keep expand chevrons flush-right and aligned across patient/panel headers, and keep reference ranges plus live result status in sync when the result unit changes.

## Context

- Surface: `LabResultEntryDialog` (worklist → Lab Result Entry). Rows use `LabResultValueUnitFields` + notes (`AppTextField` / `AppSelectField`). Panels use `_LabResultPanelSection` → `AppCollapsibleSection`; patient strip uses `AppPatientDetails` → same section chrome.
- Observed defects (CBC panel): empty labels like “Result value (optional)”, “Result unit (optional)”, “Notes (optional)” look bold/value-like; Hemoglobin can show range `13.5 - 17.5 g/dL` while unit is `g/L` (mismatched); panel delete sits to the right of the expand chevron so chevrons do not stack with the patient strip.
- Shared chrome: `AppCollapsibleSection` title uses `titleMedium`; layout today is `[title + chevron][headerActions]` — chevron is not extreme-right when delete is present.
- Interpretation today: `_computedNumericFlagToken` / `_isAbnormalEntry` compare the draft value to `resolveLabReferenceRangeForPatient` bounds without converting for the selected result unit. `LabUnitOption` has `unit` / `ucumCode` but no conversion factor field.
- Permissions: `lab:write` (mutate) / existing read gates. Follow `prompts/.cursor/prompt.mdc` and lab access rules. Backend RBAC remains authoritative.

## Requirements

1. **Placeholder / empty-label weight (Result column and shared inputs).** Empty `AppTextField` / `AppSelectField` labels and hints must read as placeholders: muted (`onSurfaceVariant` / theme hint color), light weight (≤ `FontWeight.w400`, prefer `w300` for hints). They must not use semibold/bold or value-color text. Entered values stay normal body weight/color. Apply via theme (`inputDecorationTheme` label/hint) and/or field defaults so Result value, Result unit, and Notes match; do not special-case only lab if the shared fix is theme-level.

2. **Bolder collapsible section headers (global).** In `AppCollapsibleSection`, titled headers use a bolder style than body text (e.g. `titleMedium` + `FontWeight.w600` or `w700`). Affects patient details, lab panels, and every other consumer. Keep theme tokens; light and dark.

3. **Header action order — chevron extreme right.** In `AppCollapsibleSection`, when collapsible: render `headerActions` (e.g. panel delete) immediately left of the expand/collapse icon; chevron is always the rightmost header control. Patient strip and panel chevrons must align vertically on the trailing edge. Header actions must not toggle expand/collapse (keep outside the title InkWell). Icon-only delete semantics unchanged.

4. **Synchronize reference range display with selected result unit.** On numeric rows, when the draft result unit changes (or on first paint with a unit), show the applied patient reference range with numeric bounds (and unit suffix) expressed in the selected result unit. Reuse `formatLabReferenceRangeDisplay` / `resolveLabOrderItemDisplayReferenceRange` paths. Prefer converting from the range’s stored unit using a shared helper driven by unit strings and/or `ucumCode` for common lab pairs (at least mass/volume aliases such as `g/dL` ↔ `g/L`). If conversion is impossible, keep the native range unit visible and do not silently rewrite bounds.

5. **Live result status tracks value + unit + range.** When value or unit changes, recompute the live flag/tint (`NORMAL` / `LOW` / `HIGH` / `CRITICAL` / clear) by comparing the entered numeric value in the selected unit against the same-unit bounds (converted or native). Update value styling immediately. Respect interpretation overrides and qualitative options (unchanged). Manual override still wins.

6. **UI states.** Preserve loading/error/retry, validation, save/preview, and mutate gating. No overflow/clipping on mobile/tablet/desktop. Unauthorized mutate controls stay absent (not disabled stubs).

7. **Tests.**
   - Theme/field: empty label/hint style is light + muted; value style is not bold-as-placeholder.
   - `AppCollapsibleSection`: title uses bold weight; with `headerActions`, chevron is last (rightmost).
   - Unit sync: changing unit from `g/dL` to `g/L` (or fixture pair) updates displayed range bounds/unit and flips status when the same raw number crosses thresholds (e.g. `15` normal in `g/dL`, abnormal/critical in `g/L` against a 13.5–17.5 g/dL adult range).
   - Impossible conversion: range stays native; no crash.

## Constraints

- Scope: shared input theme/`AppTextField`/`AppSelectField` as needed, `AppCollapsibleSection`, lab result entry + shared lab range format/conversion helpers and their tests. Do not redesign the lab worklist or catalog editors.
- Reuse existing interpretation helpers; add a small shared conversion utility rather than duplicating bounds logic per widget.
- Do not invent unit options or fake ranges; do not weaken permissions.
- Optional enhancement (out of scope unless already trivial): persist converted display unit only as `result_unit`; do not rewrite catalog reference-range records on save.

## Acceptance Criteria

- Empty Result-column fields look like placeholders, not filled values (req 1).
- All `AppCollapsibleSection` titles are clearly bolder than body copy (req 2).
- Panel delete sits left of the expand chevron; chevrons align with the patient details control on the far right (req 3).
- Changing result unit recalculates displayed reference range into that unit when convertible (req 4).
- Result status/tint updates live from value + unit + range; overrides still win (req 5).
- Responsive, themed, permission-safe; tests in req 7 pass (req 6–7).

## Relevant Files

- `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`
- `frontend/lib/shared/lab_catalog/lab_result_value_unit_fields.dart`
- `frontend/lib/shared/lab_catalog/lab_reference_range_format.dart`
- `frontend/lib/shared/components/app_collapsible_section.dart`
- `frontend/lib/shared/components/app_patient_details.dart`
- `frontend/lib/shared/components/app_text_field.dart`
- `frontend/lib/shared/components/app_select_field.dart`
- `frontend/lib/app/theme/app_theme.dart`
- `frontend/lib/features/lab/domain/entities/lab_entities.dart` (`LabUnitOption`, `LabReferenceRange`)
- `frontend/test/app/theme/`, `frontend/test/shared/`, `frontend/test/features/lab/`
