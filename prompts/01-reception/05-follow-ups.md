# Reception Follow-ups tab — rule compliance

## Context

Make the Follow-ups section (`ReceptionDeskSection.followUps`, query `follow-ups`) fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/01-reception/05-follow-ups.md`.

Today Filters, Advanced filters, date filter, and search-field picker are omitted. For **100%** `tables.mdc` / `tabs.mdc` compliance, restore a synchronized filter surface unless a numbered justified exception is impossible—default is to implement filters.

## Requirements

1. Keep strip label `receptionSectionFollowUps`; omit tab unless `receptionFollowUpsRequirement` allows (`last_office:read` alone must not show the tab) (`tabs.mdc`).
2. Keep authoritative count via `ReceptionFollowUpState.totalCount` (server total). When filters/search apply, active badge must show the filtered total for the same query; do not badge from visible page length alone (`tabs.mdc`).
3. Use `AppTabCountTone.info` by default; use `warning` only with a test-documented attention justification (`tabs.mdc`).
4. **Enable Filters** on this tab: Advanced filters must cover follow-up domain fields (at least status, scheduled date range, and other meaningful narrowing fields present on the row model). Wire `onFilterChanged` to the same model used by the table and active count (`tabs.mdc`, `tables.mdc`).
5. Enable date filter labeled with follow-up date (`opdFollowUpDateLabel`) and search field choices consistent with other Reception tabs where fields exist (`tables.mdc`).
6. Toolbar order: Filters → Settings → Export → Print → Schedule → Register; labels exactly `Filters` / `Settings` / `Export` / `Print` (`tables.mdc`, `printing.mdc`).
7. Mount Print with shared preview-first options for the follow-up worklist (or omit Print only when a workspace-wide “printing not allowed for this table” policy is explicit and tested). Prefer enabling Print for parity with other desk tables.
8. Prefer **5** default columns (today 4: patient, phone, date, time — add one justified default such as status or patient id, or document a 4-column exception in test) (`tables.mdc`). Settings must expose all optional columns (expand beyond patient id if exportable fields exist).
9. Detail dialog keeps generic title; read-only users see Close only; writers get reschedule / mark completed omitted when write ∩ denied (`dialogs.mdc`). Reschedule uses **reused** `ClinicalFollowUpActionDialog` with shared date/time/notes fields (`forms.mdc`).
10. No hard-delete control. Stay in-desk (`screens.mdc`). Cover loading/empty/error/retry/success (including detail banners). Refresh table + all affected tab counts after complete/reschedule.

## Constraints

- Do not leave Follow-ups as search-only if Requirements 4–5 are unmet.
- Do not fork a new follow-up form widget when `ClinicalFollowUpActionDialog` / shared fields suffice.
- Do not mount cashier or clinical order surfaces here.

## Acceptance Criteria

- [ ] Filters, date filter, and search fields are present and synchronized with table + active count.
- [ ] Count uses server total and filtered active total per Requirements 2–3.
- [ ] Toolbar order includes Print after Export (or an explicit tested “print not allowed” omission).
- [ ] Default/settings columns satisfy Requirement 8.
- [ ] Unauthorized tab/write actions are absent; detail Close-only for readers.
- [ ] `tabs/01-reception/05-follow-ups.md` updated to match (remove “intentionally omitted filters” once fixed).

## Verification

- Tests: tab omit without patient/clinical read; write actions omit; filter apply updates rows + badge; Print/Export gates.
- Manual: reschedule + complete; empty/error retry; light/dark.

## Relevant Files

- `tabs/01-reception/05-follow-ups.md`
- `prompts/01-reception/00-shared-chrome.md`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_follow_up_detail_dialog.dart`
- `frontend/lib/features/reception/presentation/controllers/reception_follow_up_controller.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_follow_up_action_dialog.dart`
- `frontend/test/features/reception/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
