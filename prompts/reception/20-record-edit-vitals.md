# Decongest Record/Edit Vitals Actions

Move risk flags and body metrics behind action buttons; clarify filled summaries. Follow `prompts/.cursor/prompt.mdc`.

## Context

Per-vital actions exist, but risk flags stay inline and weight/height are separate. Filled summaries lack status color. Checkbox icons via `secondary` look disorganized.

**Body metrics action:** one control for weight, height, and BMI.
**Risk flags action:** one control opening a risk-flag dialog.

## Requirements

1. Replace inline risk flags with a **Risk flags** action opening a modal; persist on confirm; summarize on parent.
2. Combine weight, height, and BMI into one body-metrics action/dialog; keep other vitals separate.
3. When any two of weight/height/BMI are valid, auto-derive the third in selected units.
4. Filled summaries: **bold** name; non-bold value using normal/abnormal status colors.
5. Order `AppCheckboxField` as checkbox, icon, label.
6. Preserve loading, busy, error, success, permission, sync, and edit vs record; omit unauthorized UI.

## Constraints

- Reuse vitals dialog/form, BMI helpers, triage risk options, localization, and design-system; no new contracts.
- Do not change triage fields, route decision, or submit payload beyond risk-flag UX.
- Support themes and viewports.

## Acceptance Criteria

- R1: Risk flags via action modal; summary on parent; no inline grid.
- R2-R3: One body-metrics action; any two derive the third in selected units.
- R4: Bold name and status-colored value on filled summaries.
- R5: Checkbox, icon, then label.
- R6: States/sync intact; unauthorized UI absent.
- Update record-vitals and checkbox tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/components/{app_record_vitals_dialog,app_vitals_form,app_checkbox_field}.dart`
- `frontend/lib/shared/opd_actions/`
- `frontend/test/shared/opd_actions/`
