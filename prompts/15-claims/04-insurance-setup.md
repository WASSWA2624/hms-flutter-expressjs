# Claims Insurance Setup tab — rule compliance

## Context

Make the Insurance Setup desk section fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/15-claims/04-insurance-setup.md`. Apply shared chrome fixes from `prompts/15-claims/00-shared-chrome.md` first when this tab depends on them (counts, Print, Export gate, tones, shared filter labels).

## Requirements

1. Keep strip label `claimsSectionInsuranceSetup`, deep-link `insurance-setup`, and omit the tab when gate denies access (`ClaimsInsuranceSetupAtomPermissions.tab` = ∪ `billing:read` \| `facility:admin` \| `tenant:admin` ∩ `insurance-claims`) — never show a disabled placeholder (`tabs.mdc`). Align `ClaimsDeskSection` / query helpers with `tabs/15-claims/00-overview.md`.
2. **Omit** the tab count badge (`count: null`) — Insurance Setup is a catalog hub, not a countable worklist. Do **not** paint badge `0` (`tabs.mdc`). Recorded + tested in `tabs/15-claims/99-convention-gaps.md`.
3. Count tone is unused while count is null; keep inventoried `AppTabCountTone.info` if a count is ever added (`tabs.mdc`).
4. **No** Filters / Settings / Export / Print table toolbar on this tab (justified non-table catalog hub — same pattern as Pharmacy Catalog). Do not invent a queue table to satisfy template chrome (`tables.mdc`, `printing.mdc`).
5. Table Print / Export / column Settings: **N/A** — no `AppListTable` on this surface.
6. Default columns / Settings / Reset: **N/A** (no table).
7. Advanced filters: **Absent** (no worklist filter model).
8. Preserve in-desk actions for this surface via shared dialogs/forms; omit unauthorized actions (`dialogs.mdc`, `forms.mdc`, `screens.mdc`). Inventoried dialogs to keep compliant: Company / Scheme / Offer / Enrollment / Price book / Insurer integration.
9. Reuse shared form fields and validators; hide tenant/facility/session context the operator already knows; reset dependent fields when parents change (`forms.mdc`).
10. Print entry: **Absent** on this tab (justified — no printable worklist). Nested hub prints are out of scope for this catalog strip.
11. Cover empty, loading, error/retry, success, and validation feedback. Catalog mutations refresh workspace reference data via controller `refresh` (`prompt.mdc`, `tabs.mdc`).

## Constraints

- Do not fork parallel table/tab/dialog/print chrome when a shared path exists or can be extended.
- Do not add nested feature routes for multi-step work on this tab.
- Do not invent columns that duplicate the same fact (`tables.mdc`).
- Do not broaden into unrelated modules except allowed ownership handoffs (`screens.mdc`).

## Acceptance Criteria

- [x] Tab count omitted (`null`); no badge `0` (Requirements 2–3).
- [x] No Filters / Settings / Export / Print table chrome (Requirements 4–7 justified N/A).
- [x] Unauthorized tab and create actions are absent (not disabled).
- [x] Create dialogs stay in-desk with generic titles and shared field reuse.
- [x] `tabs/15-claims/04-insurance-setup.md` updated to match.

## Verification

- Tests: tab omit gate; `count: null`; no Export/Print tooltips on Insurance Setup; create strip omit-when-unauthorized; in-desk Add company dialog (`claims_insurance_setup_permissions_test.dart`).
- Manual: primary happy-path mutation(s) remain in-desk; light/dark + narrow viewport.

## Relevant Files

- `tabs/15-claims/04-insurance-setup.md`
- `prompts/15-claims/00-shared-chrome.md`
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/test/features/claims/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
