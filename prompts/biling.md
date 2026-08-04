# Separate facility vs pharmacy price ownership (billing / accountant)

## Objective

Stop one finance or catalog actor from setting both **pharmacy retail** and **facility tariff** under one write gate. Add pricing permissions, enforce them on API and UI, and map role packs so Billing/Accountant own facility tariffs and Pharmacy owns retail—without new billing engines or parallel catalogs.

## Context

**Status quo**

- Dual drug prices already exist: pharmacy retail on `drug.unit_price` (`pharmacy_unit_price`); facility tariff on `facility_pharmacy_offering.unit_price` (`facility_unit_price`).
- Order defaults already work: clinical/encounter → **FACILITY**; walk-in → **PHARMACY**. Lines/price books already use `billing_entity` / `price_source` (`FACILITY` | `PHARMACY`).
- Catalog create/edit (`pharmacy_drug_edit_dialog.dart`) edits both prices under catalog write ∪ `pharmacy:write` | `operations:write`. Matching backend routes use the same coarse scopes.
- `BILLING` owns invoices/claims/`financial:approve`. `ACCOUNTANT` aliases `BILLING` (backend templates + frontend `access_policy.dart`). Neither owns a distinct pricing tier. Price-book writes use only `billing:write`.

**Intended behavior**

- Fine-grained **pricing permissions** (not a second accountant job) separate who sets each tier.
- Unauthorized pricing write controls must not render; backend RBAC is authoritative.
- Preserve dispense, stock, payments, dual-price resolution, and the single billing pipeline.

**Definitions**

- **Pharmacy retail**: counter/OTC / `PHARMACY` sell price on `drug`.
- **Facility tariff**: encounter / `FACILITY` sell price on facility pharmacy offerings (lab/radiology only if same path is touched).
- **Pricing write**: mutating sell price or activating an offering that requires unit price—not dispense, stock, or cash collection.

## Requirements

1. Add permissions in backend catalog, metadata, seeds/sync, and frontend `AppPermissions` parity: `pricing:pharmacy_read`, `pricing:pharmacy_write`, `pricing:facility_read`, `pricing:facility_write`.
2. Keep `billing:*`, `pharmacy:*`, and `financial:approve` for existing ops (queues, payments, dispense, stock). Do not use them as the sole price-edit gates.
3. Role packs (admins keep both via existing admin expansion):
   - `PHARMACIST` / `PHARMACY_TECHNICIAN`: add pharmacy pricing read/write; do **not** add facility tariff write.
   - `BILLING` and `ACCOUNTANT` (keep alias unless explicitly split later): add facility pricing read/write; do **not** add pharmacy retail write.
4. Backend: mutating `drug.unit_price`/`currency` requires `pricing:pharmacy_write`. Upserting offering `unit_price` or activating an offering that requires price requires `pricing:facility_write`. Reject forbidden price fields with 403; allow non-price identity/stock updates without those fields. Price-book write: `billing_entity=FACILITY` → facility pricing write; `PHARMACY` → pharmacy pricing write (admins exempt as today).
5. Frontend: render pharmacy price controls only with `pricing:pharmacy_write`; facility price controls only with `pricing:facility_write`. No disabled stubs for unauthorized tiers. Non-price catalog fields stay under existing catalog write. Manual `price_source` override requires write for the target tier (not every dispenser). Read-only price columns may stay for matching pricing/pharmacy/billing read.
6. Preserve clinical→facility and walk-in→pharmacy defaults; do not change invoice posting or coverage split except for auth.
7. After authorized price saves, refresh catalog/order state so tiers are not stale.
8. Reuse existing dialog loading/empty/error/success/validation. Active offerings still require a non-negative price when the actor is allowed to set that tier. Surface 403 via existing failure handling; no routine “no access” chrome.

## Optional enhancements (out of scope unless requested)

- Cost floor + `pricing:approve`; distinct ACCOUNTANT vs BILLING packs; dedicated pricing-only roles; full lab/radiology tariff gates beyond pharmacy offerings + price-book entity split.

## Constraints

- Reuse dual-price model, `billing_entity`/`price_source`, AccessRequirement gates, authorize middleware, and design-system fields.
- No second billing engine, invoice schema, or parallel catalog; no unrelated refactors; no `screens/` inventories.
- Keep backend↔frontend↔seed↔metadata permission parity. Unauthorized write UI must not render.

## Acceptance Criteria

- AC1 (1–3): Pricing permissions exist end-to-end; role packs match Requirement 3.
- AC2 (4): API denies retail mutation without pharmacy pricing write and facility offering price mutation without facility pricing write; allowed calls persist only the permitted tier.
- AC3 (4): Price-book writes enforce pricing write by `billing_entity`.
- AC4 (5): Only-pharmacy write → facility price edits absent; only-facility write → pharmacy price edits absent; admin → both present.
- AC5 (5–6): Dispense, stock, payments, and default price-source selection unchanged for existing ops holders.
- AC6 (7–8): Authorized save updates visible catalog prices; forbidden tier is not half-updated.
- AC7: Tests prove unauthorized pricing UI absent / authorized present, and backend 403/success per tier.

## Relevant Files

- `backend/src/config/permissions.js`, `permission-catalog-metadata.js`
- `backend/scripts/seeders/seed-access-pack.js`, `seed-catalog.js`
- `backend/src/modules/pharmacy-workspace/routes/pharmacy-workspace.routes.js`, `services/pharmacy-workspace.service.js`
- `backend/src/modules/facility-pharmacy-catalog/routes|services`
- `backend/src/modules/price-book-entry/routes/price-book-entry.routes.js`
- `frontend/lib/core/permissions/access_policy.dart` (+ permission catalog/parity)
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`, `widgets/pharmacy_drug_edit_dialog.dart`, `widgets/pharmacy_catalog_panel.dart`, `pharmacy_order_item_pricing_helpers.dart`
- `frontend/lib/shared/clinical_actions/clinical_request_billing_panel.dart`
- Tests: `backend/src/tests/config/permissions.test.js`, pharmacy/facility-catalog/price-book auth tests, `frontend/test/core/permissions/*parity*`, `frontend/test/features/pharmacy/presentation/pharmacy_access_test.dart`

## Verification

- Backend route/service tests: allow/deny per pricing permission on retail, facility offering, and price-book entity.
- Frontend access/widget tests: unauthorized tier controls absent; authorized/admin present.
- Catalog parity + metadata tests pass.
- Manual: pharmacist retail-only; billing/accountant facility-only; admin both; walk-in vs clinical defaults; dispense/payment unchanged; one- and two-field dialog layouts on mobile/tablet/desktop; light/dark via theme tokens.
