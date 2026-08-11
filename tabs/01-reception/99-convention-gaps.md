# Reception inventory — convention gaps

Optional enhancements vs `prompts/.cursor/*.mdc`. Separate from the inventory; no UI changes made in this pass.

## tabs.mdc

1. **Count authority:** Appointments / Desk queue / High priority / Active visits / Payment gate badges use **loaded list length** (client-filtered items), not a dedicated server `totalItemCount`. Follow-ups correctly prefer `ReceptionFollowUpState.totalCount`. When filters narrow the active tab, sibling tab counts are unfiltered scope totals from their own lists — consistent per tab, but not a shared filtered-query model across tabs.
2. **Count tone:** Every Reception tab uses `AppTabCountTone.warning`. Rule default is `info`; warning is allowed for queues needing attention — confirm product intent for Appointments / Follow-ups / Payment gate vs queue-like urgency.
3. **Filters sync on Follow-ups:** Tab intentionally has no Advanced filters / date filter; free-text search only. Documented in code comments — not a bug, but sibling-tab filter context does not apply.

## tables.mdc

1. **Print after Export:** List toolbar has Export but **no Print**. Print exists only inside Flow Actions as `opdPrintSummaryAction` (not the generic table `Print` label). Gaps vs “Print when printing is allowed for that table.”
2. **Default column count:** Most tabs default to 3–5 columns (within guidance). Payment gate defaults to 4–5 including optional next-action. Follow-ups defaults to 4. No clear violation.
3. **Export permission:** Export is always shown (`enableExport` default); no Reception-specific `canExport` RBAC gate observed.

## dialogs.mdc

1. **Titles:** Hubs use generic titles (`opdAppointmentActionsTitle`, `opdQueueActionsTitle`, `opdFollowUpsTitle`, `receptionBillingGuidanceTitle`, `patientsAppointmentDialogTitle`) — generally aligned. Identity stays in body panels.
2. **Nested dialogs:** Appointment/Queue/Flow hubs open child dialogs (reschedule, cancel, prioritize, assign, print preview) — expected progressive flow; not dialog-in-dialog chrome nesting of collapsible sections.

## forms.mdc

1. Schedule / Register / visitor / follow-up forms reuse shared shells and fields — no fork called out beyond Reception-owned visitor dialog fields.
2. Context hide: facility/tenant not prompted on desk strip actions (aligned).

## printing.mdc

1. Flow Actions print trigger label is `opdPrintSummaryAction` (content-flavored) rather than bare `Print`. Preview path uses shared `showPrintOpdSummaryDialog` + `PrintDocumentTemplates.clinicalSummary` — preview-first is satisfied; label genericity may need alignment.
2. No table-level Print entry for worklists.

## screens.mdc

1. Reception stays in-desk for flows (dialogs only); no mid-flow `context.go` to other modules from Reception presentation — aligned.
2. Payment gate correctly does **not** fork cashier; settle remains Billing ownership (handoff not mounted here — guidance-only).
