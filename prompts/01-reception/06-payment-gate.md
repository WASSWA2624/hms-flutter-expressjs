# Reception Payment gate tab — rule compliance

## Context

Make the Payment gate section (`ReceptionDeskSection.paymentGate`, query `payment-gate`) fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`, while preserving **guidance-only** billing behavior (no cashier). Inventory baseline: `tabs/01-reception/06-payment-gate.md`.

## Requirements

1. Keep strip label `receptionSectionPaymentGate`; omit tab without `billing:read` + `billing-payments` (`tabs.mdc`).
2. Badge count = authoritative payment-gate total for scope (prefer controller/server total when available; do not use painted page length alone). Active filtered total when filters/search apply (`tabs.mdc`).
3. Use urgency tone justified for clearance pressure (`warning` allowed with test note) (`tabs.mdc`).
4. Toolbar: Filters → Settings → Export → Print → Schedule → Register; exact shared labels (`tables.mdc`, `printing.mdc`).
5. **Enable date filter** for a domain-meaningful date (arrival / invoice / outstanding-as-of — pick the field already on the row model or payload and label it consistently). Remove the “date filter omitted” exception (`tables.mdc`).
6. Keep Advanced filters comprehensive (clearance status, next action, provider, source, gender, plus date) on the shared filter model (`tabs.mdc`, `tables.mdc`).
7. Mount Print with shared preview-first options for guidance/invoice summary fields exportable from this tab; omit Print/Export when unauthorized. Do **not** add Receive payment / Collect controls (`screens.mdc`, `printing.mdc`).
8. Default columns: prefer **5** (patient, encounter, clearance, next-action guidance, amount due is already aligned when next-action mounts). Settings exposes all optional columns (`tables.mdc`).
9. Detail dialog stays read-only guidance with generic title `receptionBillingGuidanceTitle` (or equivalent generic surface name); Close only; identity in body; reuse billing tiles without nesting collapsible-in-collapsible (`dialogs.mdc`).
10. Schedule / Register remain ∩ `patient:write` desk strip actions; no Billing workspace fork for settle—operators use shell/Billing ownership handoff outside this tab if needed (`screens.mdc`).
11. Cover empty/loading/error/retry; synchronize counts after strip mutations; never show disabled Collect placeholders.

## Constraints

- Payment gate must not mount `billing:write` collect UI even when the user has billing write.
- Do not navigate to Billing mid-detail unless adding an explicit allowed ownership handoff control labeled as such (default: no handoff button required for compliance).
- Do not invent a second invoice engine.

## Acceptance Criteria

- [ ] Counts/tone and date filter satisfy Requirements 2–5.
- [ ] Toolbar Print after Export with preview-first; Collect/Receive payment remain absent for all roles.
- [ ] Filters include date + comprehensive groups on the shared model.
- [ ] Unauthorized tab/Export/Print/Schedule/Register omitted.
- [ ] Detail remains Close-only guidance with generic title.
- [ ] `tabs/01-reception/06-payment-gate.md` updated to match.

## Verification

- Tests: tab omit without billing read; collect controls absent even with billing write; date filter applies; Print/Export omit matrix; count authority.
- Manual: open detail invoices; confirm no pay CTA; light/dark.

## Relevant Files

- `tabs/01-reception/06-payment-gate.md`
- `prompts/01-reception/00-shared-chrome.md`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_payment_gate_detail_dialog.dart`
- `frontend/lib/features/reception/presentation/controllers/reception_payment_gate_controller.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/test/features/reception/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
