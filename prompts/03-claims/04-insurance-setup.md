# Claims — Insurance setup

## Context

Implement the **Insurance setup** desk section (`?section=insurance-setup`) on `/claims` per `claims.md`. This panel maintains payers, schemes, offers, enrollments, price-book tariffs, and insurer API config. Catalog creates stay NOT_BILLED — they do not post invoices or payments. Tariffs and coverage enter Billing only via price-resolver / coverage-split at charge time. Source of truth: root `claims.md` §§2–8, 9–11, 17–19.

## Requirements

1. Show the Insurance setup tab with label **Insurance setup** (≤2 words) and tooltip: *Payers, schemes, offers, enrollments, tariffs, and insurer API*.
2. Persist and write URL `/claims?section=insurance-setup` (accept aliases `insurance_setup`, `setup`, `catalog`, `?tab=insurance-setup`).
3. Render the setup panel (description + quick-action creates), not the claims queue table. No Search / Filters / Next chrome on this tab.
4. Mount create actions when authorized: **Add company** · **Add scheme** · **Add offer** · **Enroll** · **Add price** · **Insurer API**. Hide the create strip when the user lacks write (no disabled stubs).
5. Each create opens one dialog with required fields only; Primary **Save**; snackbar + workspace refresh on success.
6. **Before save** run similarity review on natural keys per `claims.md` §18 (company code/name; scheme code; offer scheme+item; enrollment patient+scheme; price item+scheme+effective; insurer API identity).
7. Gate tab visibility with (`billing:read` ∪ `facility:admin` ∪ `tenant:admin`) ∩ `insurance-claims`. Creates require `billing:write` ∩ `insurance-claims`.
8. Enrollment stays PENDING until an explicit verify path activates payer context — do not silently auto-verify to ACTIVE.
9. Do not mount Collect, Issue, Settle, Adjust, Refund, or claim remittance on this tab.
10. Keep count tone **info** (or no count). Enable realtime refresh after catalog mutations.
11. Never display raw UUIDs in dialogs, snackbars, or similarity UI — use codes, names, patient name/MRN (`claims.md` §19).

## Constraints

- Do not post patient invoices, payments, or remittances from Insurance setup.
- Do not show queue Next / Prepare / Request on this tab.
- Do not skip similarity on create paths.
- Reuse `claims_insurance_config_dialogs.dart`, `claims_access`, workspace controller refresh, and `AppSimilarity*` patterns.
- No unrelated refactoring outside this section’s surface.

## Acceptance Criteria

- [ ] AC1: Insurance setup is visible with the specified label and tooltip when setup read ∪ ∩ `insurance-claims` allow it. (R1, R7)
- [ ] AC2: `/claims?section=insurance-setup` and aliases select Insurance setup and write `section=insurance-setup`. (R2)
- [ ] AC3: Panel shows description + authorized create actions; create strip hidden without write. (R3, R4, R7)
- [ ] AC4: Each create is one modal → similarity (when matches) → save → snackbar → refresh. (R5, R6)
- [ ] AC5: Enrollment remains PENDING without silent auto-verify. (R8)
- [ ] AC6: Collect / Issue / Settle / Adjust / claim remittance are absent. (R9)
- [ ] AC7: Facility/tenant admin without `billing:read` can still see the tab when ∪ allows; creates still need write ∩. (R7)
- [ ] AC8: No raw UUIDs appear in setup UI or similarity. (R11)
- [ ] AC9: Layout remains usable on mobile, tablet, and desktop in light and dark themes. (R3)

## Verification

- Permissions tests: tab ∪ visibility; creates omitted without write; billable cashier atoms never mount.
- Flow tests: Add company / scheme / offer / enroll / price / API → similarity → save → refresh.
- Manual check: empty create strip for read-only users, description copy, viewports, themes.
- Confirm no UUID strings in UI.

## Relevant Files

- `claims.md` (§§17–19)
- `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
- `frontend/lib/features/claims/presentation/claims_access.dart`
- `frontend/lib/features/claims/presentation/claims_insurance_setup_billing_inventory.dart`
- `frontend/lib/features/claims/presentation/widgets/claims_insurance_config_dialogs.dart`
- `frontend/lib/features/claims/presentation/controllers/claims_workspace_controller.dart`
- `frontend/lib/shared/components/app_similarity.dart`
- `frontend/test/features/claims/presentation/claims_insurance_setup_permissions_test.dart`
- `frontend/test/features/claims/presentation/claims_insurance_setup_billing_sections_test.dart`
- `backend/src/tests/modules/claims/insurance-setup-billing-sections.test.js`
