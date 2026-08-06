# Pharmacy and Facility Medicines Pricing Engine

Align pharmacy product pricing with buy, sell, and transfer lanes plus insurance overlays—extend the existing dual sell prices and `price_book` / scheme-offer engine without inventing a parallel pricing stack.

## Context

**Current behavior**

- **Pharmacy sell (walk-in / OTC):** `drug.unit_price` (UI: “Pharmacy price”), gated by `pricing:pharmacy_write`. Walk-in Create order bills with `billing_entity` / default **PHARMACY**.
- **Facility sell (encounter / cash tariff):** `facility_pharmacy_offering.unit_price` (UI: “Facility price”), gated by `pricing:facility_write`. Clinical prescribe defaults **FACILITY**.
- **Insurance differentials:** `price_book_entry` + `scheme_offer` for `catalog_type=DRUG` with `billing_entity` FACILITY|PHARMACY and SELF_PAY|INSURANCE, resolved by `price-resolver` (scheme → book → catalog fallback). Configured mainly from Claims insurance surfaces—not in the drug edit dialog.
- Catalog/drug dialog exposes the two sell prices; details are read-only. No pharmacy **buy/cost** field; no explicit **pharmacy→facility transfer** price. Dashboard sales often use `qty × drug.unit_price` only.

**Intended behavior**

- Model and configure, at drug / inventory entry (and catalog edit), the prices needed for:
  1. **Pharmacy buy** — what pharmacy pays suppliers (COGS).
  2. **Pharmacy sell (external)** — walk-in / OTC sell to clients (existing pharmacy retail).
  3. **Pharmacy sell to facility** — transfer price that is the facility’s buy cost (new; do not overload facility patient tariff).
  4. **Facility sell** — what the facility charges cash patients (existing facility offering).
  5. **Insurance overlays** — facility (and pharmacy where configured) differentials via existing price_book / scheme_offer by billing entity.
- Profit views: pharmacy margin = external sell − buy; facility margin = facility sell − transfer (pharmacy→facility) buy. Walk-in uses PHARMACY path; encounter/prescribe uses FACILITY path.
- Preserve unauthorized absence of pricing controls; unauthorized chrome must not render.

**Definitions**

- *Pharmacy buy:* supplier/landed cost used as COGS for pharmacy retail sales.
- *Pharmacy external sell:* OTC/walk-in sell price (`drug.unit_price` today).
- *Transfer price:* pharmacy→facility charge (= facility buy); distinct from facility patient sell.
- *Facility sell:* cash patient tariff (`facility_pharmacy_offering.unit_price` today).
- *Insurance overlay:* price_book / scheme_offer row for DRUG + billing entity + payment mode.

## Requirements

1. Persist and expose **pharmacy buy** (cost) on the drug/catalog pricing surface with `pricing:pharmacy_write` (or the existing pharmacy pricing permission). Optional on create if product policy allows; validate non-negative.
2. Persist and expose **transfer price** (pharmacy→facility) as its own field—not by redefining `facility_pharmacy_offering.unit_price`. Gate write with the appropriate pricing permission(s); facility read of transfer for margin context when entitled.
3. Keep **pharmacy external sell** and **facility sell** as today (pharmacy retail + facility offering); clarify labels/copy so “Facility price” means patient tariff, not transfer.
4. Keep walk-in / Create order on **PHARMACY** billing entity (external sell + pharmacy insurance book when configured) and clinical prescribe on **FACILITY** (facility sell + facility insurance book). Resolver fallbacks unchanged in spirit: FACILITY → offering then retail; PHARMACY → retail.
5. Reuse `price_book_entry` / `scheme_offer` for insurance differentials by billing entity; do not build a second insurance price table. Prefer surfacing or linking insurance DRUG tariffs from pharmacy catalog/drug edit when Claims config already owns CRUD.
6. Wire profit/sales/dashboard Amount paths that claim pharmacy or facility margin to use buy and transfer appropriately (pharmacy: external sell − buy; facility: facility sell − transfer). Do not leave Amount/profit using retail-only when cost lanes exist.
7. Cover permission, loading, empty, error, success, validation, and visible feedback on pricing edit and order billing resolve. Responsive; theme tokens; light/dark.
8. Tests: schema/API for buy + transfer; permissions (unauthorized fields absent); resolver PHARMACY vs FACILITY (+ insurance when configured); walk-in vs prescribe billing entity; catalog/drug dialog labels; margin/dashboard math when cost present; clinical callers unchanged aside from shared resolver.

## Constraints

- Reuse price-resolver, pricing permissions, facility offering, and price_book—no parallel drug-price microservice.
- Do not treat facility patient tariff as the pharmacy→facility transfer price.
- Do not require encounter on pharmacy walk-in create; do not force FACILITY billing on walk-in.
- Migrations required for new columns; follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Authorized user sets pharmacy buy and sees it on drug/catalog pricing UI; unauthorized control absent. | R1, R7–R8 |
| A2 | Authorized user sets transfer (pharmacy→facility) distinct from facility patient sell. | R2–R3, R8 |
| A3 | Walk-in charges pharmacy external sell (PHARMACY); prescribe uses facility sell (FACILITY) with existing resolver/insurance path. | R3–R5 |
| A4 | Insurance DRUG overlays still resolve via price_book/scheme_offer by billing entity. | R5 |
| A5 | Pharmacy/facility margin or Amount paths that depend on cost use buy/transfer when present. | R6 |
| A6 | Labels distinguish buy, external sell, transfer, and facility patient sell; light/dark + narrow usable. | R3, R7 |

## Relevant Files

- `backend/prisma/schema.prisma` (`drug`, `facility_pharmacy_offering`, `price_book_entry`)
- `backend/src/lib/billing/price-resolver.js`; `pricing-permissions.js`; `clinical-request-billing.js`
- `backend/src/modules/pharmacy-workspace/`; `facility-pharmacy-catalog.merge.js` / serializer
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart`
- `pharmacy_catalog_panel.dart`; `pharmacy_walk_in_order_dialog.dart`; `pharmacy_order_item_pricing_helpers.dart`; `pharmacy_access.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`
- Claims insurance config dialogs (price_book DRUG)
- Tests: drug edit pricing permissions; order item pricing helpers; facility-pharmacy-catalog / price-book / pricing-permissions BE tests

## Verification

- BE: migrate buy + transfer; create/update drug with all lanes; resolver PHARMACY vs FACILITY ± insurance; permission denials.
- FE: catalog/drug dialog shows four conceptual lanes (buy, external sell, transfer, facility sell) with correct gates; walk-in vs prescribe billing entity; unauthorized fields absent.
- Manual: configure prices → walk-in OTC vs clinical prescribe → invoice/line prices; optional insurance row; light/dark and narrow viewport.
