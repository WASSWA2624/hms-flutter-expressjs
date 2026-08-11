# Claims — Authorizations

## Context

Implement the **Authorizations** desk section (`?section=authorizations`) on `/claims` per `claims.md`. This queue lists pre-authorizations awaiting request, approval, or status update. Approved limits constrain Billing coverage splits; this tab does not collect cash. It is the fallback tab when other sections are unauthorized. Source of truth: root `claims.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Authorizations tab with label **Authorizations** (≤2 words) and tooltip: *Pre-authorizations awaiting request, approval, or status update*.
2. Persist and write URL `/claims?section=authorizations` (accept aliases `preauth`, `pre-auth`, `?tab=authorizations`).
3. Render shared work-queue chrome in order: Search · Filters · Table settings · Export · trailing **Request** only when the user has write ∩ `insurance-claims`.
4. Default columns (≤5): Reference · Patient · Coverage · Status · Next. Optional via settings: Approved · Requested. Persist as `claims_authorizations_v1`.
5. Search with ~350ms debounce and hint *Search reference, coverage, invoice, or patient*. Filter chips: Pending · Approved · Denied · Expired (tab-scoped only).
6. Show empty copy *No authorizations in this queue.* when empty; show loading, error, and success (snackbar) states.
7. Row Next is **Update** when authorized; omit when unauthorized. Happy path: Next → Update modal → save → snackbar → refresh. Do not require Detail first.
8. Trailing **Request** opens Request pre-authorization; **before save** run similarity review against near-duplicate open pre-auths (patient · coverage · encounter · amount window) per `claims.md` §18.
9. Gate the tab with `billing:read` ∩ `insurance-claims`. Mutations require `billing:write` ∩ `insurance-claims`. Omit unauthorized Next / Request / Detail actions; no disabled “no access” chrome.
10. Row click opens shared Detail (pre-auth kind) with capable secondary actions including **Print** when authorized.
11. **Print** opens shared print preview with authorization statement section options (`claims.md` §17); never print silently.
12. Keep count tone **warning**. Enable realtime + light poll while active.
13. Deep link `?section=authorizations&action=preauth` opens Request when authorized.
14. Never display raw UUIDs — use auth references, patient name/MRN, coverage codes (`claims.md` §19).

## Constraints

- Do not collect payments or post remittances on this tab.
- Do not place Prepare, Close, Sync, or Insurance setup creates as trailing here.
- Do not require Detail before Update / Request happy paths.
- Do not skip Request similarity review or print-preview for Print.
- Reuse Claims workspace page, controller, `claims_access`, Detail shell, form dialogs, `AppPrintPreviewWorkspace`, and `AppSimilarity*` patterns; mirror `/hr` · `/billing` · `/accounts` chrome.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Authorizations is visible with the specified label and tooltip when claims read ∩ `insurance-claims` allow it. (R1, R9)
- [ ] AC2: `/claims?section=authorizations` and aliases select Authorizations and write `section=authorizations`. (R2)
- [ ] AC3: Search bar order is Search · Filters · Table settings · Export · Request (Request omitted without write). (R3, R9)
- [ ] AC4: Default columns are Reference · Patient · Coverage · Status · Next; settings key `claims_authorizations_v1`. (R4)
- [ ] AC5: Empty state shows *No authorizations in this queue.*; loading and error states are visible. (R6)
- [ ] AC6: Authorized Next Update completes in one modal → save → snackbar → refresh without Detail. (R7)
- [ ] AC7: Request runs similarity review when matches exist; unauthorized actions are absent. (R8, R9)
- [ ] AC8: Row click opens shared Detail for pre-auth. (R10)
- [ ] AC9: Print opens preview with section toggles; no silent print. (R11)
- [ ] AC10: `action=preauth` opens Request when authorized. (R13)
- [ ] AC11: No raw UUIDs appear in Authorizations UI, Detail, or print. (R14)
- [ ] AC12: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: tab absent without `insurance-claims` / billing read; mutations absent without write ∩ insurance.
- Flow tests: Request → similarity → save; Update happy path; Print → preview; deep link `action=preauth`.
- Manual check: empty/loading/error, filter chips, optional columns, print layout, viewports, themes.
- Confirm no Collect / Prepare trailing on this tab; confirm no UUID strings in UI/print.

## Relevant Files

- `claims.md` (§§17–19)
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart`
- `frontend/lib/features/claims/domain/entities/claims_authorizations_financial_inventory.dart`
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/test/features/claims/presentation/claims_authorizations_permissions_test.dart`
- `frontend/test/features/claims/presentation/claims_authorizations_billing_sections_scan_test.dart`
- `frontend/test/features/claims/presentation/claims_workspace_page_test.dart`
