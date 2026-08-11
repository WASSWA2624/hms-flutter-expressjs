# Claims — Active claims

## Context

Implement the **Active claims** desk section (`?section=active-claims`) on `/claims` per `claims.md`. This queue lists submitted and in-flight insurance claims awaiting response or close. Remittance settle posts through shared Billing claim-remittance; patient residual opens Billing receive-payment. Source of truth: root `claims.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Active claims tab with label **Active claims** (≤2 words) and tooltip: *Submitted and in-flight insurance claims awaiting response or close*.
2. Persist and write URL `/claims?section=active-claims` (accept aliases `active_claims`, `claims`, `open-claims`, `?tab=active-claims`).
3. Render shared work-queue chrome in order: Search · Filters · Table settings · Export · trailing **Prepare** only when the user has write ∩ `insurance-claims`.
4. Default columns (≤5): Reference · Patient · Coverage · Status · Next. Optional via settings: Invoice · Amount · Submitted. Persist as `claims_activeClaims_v1`.
5. Search with ~350ms debounce and hint *Search reference, coverage, invoice, or patient*. Filter chips: Submitted · Approved · Partial · Rejected (tab-scoped only).
6. Show empty copy *No claims in this queue.* when empty; show loading, error, and success (snackbar) states.
7. Resolve one Next per row by status: draft/ready → **Submit** · REJECTED → **Resubmit** · SUBMITTED/PARTIAL → **Respond** · APPROVED → **Close**. Omit when unauthorized.
8. On Next, open the matching one-step modal, save, snackbar, and refresh without requiring Detail first.
9. Trailing **Prepare** opens Prepare claim (links existing Billing invoice — no new charge); **before save** run similarity against near-duplicate open claims for same invoice / coverage (`claims.md` §18).
10. Gate the tab with `billing:read` ∩ `insurance-claims`. Write mutations require `billing:write` ∩ `insurance-claims`. **Close** / PAID·PARTIAL remittance require `financial:approve` ∩ `insurance-claims`.
11. Row click opens shared Detail with secondary **Sync** (write) and **Collect** (→ Billing when residual due). Omit unauthorized actions.
12. **Print** opens shared print preview with claim statement section options (`claims.md` §17); never print silently.
13. Keep count tone **warning**. Enable realtime + light poll while active.
14. Deep link `?section=active-claims&action=prepare` opens Prepare when authorized.
15. Never display raw UUIDs — use claim references, patient name/MRN, coverage codes, invoice numbers (`claims.md` §19).

## Constraints

- Do not implement Collect / Charge / Issue as claims-local cashier logic — deep-link Billing only.
- Do not place Request, Insurance setup creates, or Settled mutate on this tab.
- Do not require Detail before Submit / Respond / Close / Prepare happy paths.
- Do not skip Prepare similarity review or print-preview for Print.
- Reuse Claims workspace page, controller, `claims_access`, Detail shell, reconcile/remittance paths, `AppPrintPreviewWorkspace`, and `AppSimilarity*` patterns.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Active claims is visible with the specified label and tooltip when claims read ∩ `insurance-claims` allow it. (R1, R10)
- [ ] AC2: `/claims?section=active-claims` and aliases select Active claims and write `section=active-claims`. (R2)
- [ ] AC3: Search bar order is Search · Filters · Table settings · Export · Prepare (Prepare omitted without write). (R3, R10)
- [ ] AC4: Default columns are Reference · Patient · Coverage · Status · Next; settings key `claims_activeClaims_v1`. (R4)
- [ ] AC5: Empty state shows *No claims in this queue.*; loading and error states are visible. (R6)
- [ ] AC6: Authorized Next Submit / Resubmit / Respond / Close completes in one modal → save → snackbar → refresh without Detail. (R7, R8)
- [ ] AC7: Close / PAID·PARTIAL absent without `financial:approve`; unauthorized actions are absent (not disabled). (R10)
- [ ] AC8: Prepare runs similarity review when matches exist and does not create a new charge. (R9)
- [ ] AC9: Detail Sync and Collect (→ Billing) mount only when authorized and applicable. (R11)
- [ ] AC10: Print opens preview with section toggles; no silent print. (R12)
- [ ] AC11: No raw UUIDs appear in Active claims UI, Detail, or print. (R15)
- [ ] AC12: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: tab/mutations/Close gates; Collect omitted without billing write ∩ `billing-payments`.
- Flow tests: Prepare → similarity → save; Submit / Respond / Close remittance; Collect deep-link; Print → preview.
- Manual check: empty/loading/error, filter chips, optional columns, print layout, viewports, themes.
- Confirm no local cashier; confirm no UUID strings in UI/print.

## Relevant Files

- `claims.md` (§§17–19)
- `billing.md` (Collect due / remittance ownership)
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart`
- `frontend/lib/features/claims/domain/entities/claims_active_claims_financial_inventory.dart`
- `backend/src/lib/billing/claim-remittance.js`
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/test/features/claims/presentation/claims_active_claims_permissions_test.dart`
- `frontend/test/features/claims/presentation/claims_active_claims_billing_sections_scan_test.dart`
- `frontend/test/features/claims/presentation/claims_workspace_page_test.dart`
