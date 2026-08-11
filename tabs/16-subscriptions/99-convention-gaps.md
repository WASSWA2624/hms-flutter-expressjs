# Subscriptions inventory — convention gaps

Optional findings vs `prompts/.cursor/*.mdc` (inventory only; no UI changes).

## Gaps

- No worklist Export/Print across Subscriptions panels — differs from Accounts/Reception list Print conventions.
- `enableDateFilter: false` while date_preset lives in advanced Filters — intentional but easy to miss in audits.
- Overview is non-table; Modules/Billing omit create while sharing Filters/Settings chrome — document as progressive disclosure.
- Hard-coded English `_SubscriptionsText` (not l10n keys) for most labels — flag if forms.mdc/tabs.mdc expect l10n keys everywhere.
- Route entry is ∪ `platform:admin` while tab atoms use `subscriptions:*` ∩ module — elevated sessions without subscriptions permissions may enter shell but see empty panels (SizedBox) depending on policy composition.
