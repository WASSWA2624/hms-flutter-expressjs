# Selectable Formatted OPD Print Summary

Upgrade Print summary with section ticks, shared-template formatting, and non-freezing print. Follow `prompts/.cursor/prompt.mdc`.

## Context

`PrintOpdSummaryDialog` dumps plain-text counts into one note block; Print can stick busy and freeze the UI. Reception needs selectable sections and formatted output—not UI chrome or retry labels.

**Print sections:** visit/stage, payment, vitals, notes, diagnoses, procedures, lab/radiology/pharmacy, referrals/follow-ups, timeline. Empty or unauthorized sections stay disabled.

**Pending:** incomplete recorded work labeled pending when selected.

## Requirements

1. Add section picker via `AppReportSectionPicker` and `report_section_selection`; default-select enabled sections with data.
2. Preview/print only selected sections using `PrintFormTemplate` section/kv/list/table helpers—not one escaped note.
3. Print full clinical and payment detail from flow/detail (not counts alone); mark pending items as pending.
4. Exclude UI chrome, retry labels, and error banners from preview and print.
5. Clear Print/Copy busy after success or failure; keep UI interactive; never leave stuck loading.
6. Preserve loading, empty, error, busy, permission states; omit unauthorized UI; keep authorized Reception read-only print access.

## Constraints

- Reuse `PrintOpdSummaryDialog`, `printFormTemplateDocument`, report section picker, Flow Actions, auth, localization, design-system; no parallel path.
- Do not invent clinical writes or change billing/clinical contracts.
- Support themes and viewports.

## Acceptance Criteria

- R1–R2: Section ticks drive preview/print; template sections used.
- R3–R4: Full selected detail including pending; no Try again/UI chrome.
- R5–R6: Print never freezes UI; states intact; unauthorized UI absent.
- Update print-summary tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/opd_print_summary_dialog.dart`
- `frontend/lib/shared/reporting/report_section_selection.dart`
- `frontend/lib/shared/components/app_report_section*.dart`
- `frontend/lib/shared/printing/`
- `frontend/test/shared/opd_actions/opd_print_summary_dialog_test.dart`
