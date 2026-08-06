# Pharmacy Drug Pricing: Cost, Sell Tiers, and Insurance Differentials

Implement a three-tier drug price model (pharmacy buy, pharmacy sell, facility sell) plus insurance sell overlays so pharmacy and facility profit/loss and billable charges use the correct price role—without a parallel catalog or breaking existing sell surfaces.

## Context

**Current behavior (codebase)**

- Two cash sell prices exist: `drug.unit_price` (pharmacy retail/OTC) and `facility_pharmacy_offering.unit_price` (facility tariff). Catalog UI shows pharmacy + facility price. Permissions: `pricing:pharmacy_*` / `pricing:facility_*`.
- No pharmacy buying/cost field. Dashboard Most sold **Amount** and sales KPIs value dispenses as `qty × drug.unit_price` (live catalog). **Profit** is always empty. Order status mix stays qty-only.
- Walk-in should use pharmacy retail, but auto-billing resolves `billingEntity: 'FACILITY'`. Workspace already distinguishes pharmacy vs facility price sources.
- Insurance overlays already use `price_book_entry` + `price-resolver.js` (`payment_mode`, `billing_entity`, coverage/insurer). Keep one resolver path.

**Intended behavior**

- Cash prices per drug include three roles: (1) **pharmacy buying** (COGS), (2) **pharmacy selling** (walk-in/OTC; also facility’s buying price for margin math), (3) **facility selling** (existing offering tariff).
- Pharmacy and facility may have insurance (non-cash) sell prices; reuse price-book/resolver.
- Profit/loss and dashboard Amount/sales/profit use the sell price for the sale channel, with cost from pharmacy buying price when required.

**Definitions**

- *Pharmacy buying price*: acquisition cost; pharmacy margin basis; facility cost when facility buy = pharmacy sell.
- *Pharmacy selling price*: cash OTC/walk-in charge on `drug`; equals facility buying price for margin math.
- *Facility selling price*: cash facility tariff on `facility_pharmacy_offering`.
- *Insurance sell price*: non-cash sell overlay for billing entity PHARMACY or FACILITY via price-book + payment mode/insurer/coverage.
- *Sale channel*: PHARMACY (walk-in / no clinical encounter) vs FACILITY (encounter / facility-billed).

## Requirements

1. Persist **pharmacy buying price** with existing pharmacy and facility sell. Drug create/edit (and API validation) capture buying + pharmacy sell; facility sell stays on the offering. Unauthorized price fields must not render. Validate non-negative decimals and currency; use existing validation/error patterns.
2. Map roles in serializers/UI: buying cost; pharmacy sell (`drug.unit_price` or renamed with backward-compatible API); facility sell (offering). Facility buy for profit = pharmacy sell. Surface buying price on catalog list/detail/edit when pharmacy pricing read/write allows; hide when unauthorized.
3. Support insurance sell differentials for PHARMACY and FACILITY via `price_book_entry` + price-resolver. Cash falls back to base sell by billing entity. No parallel overlay stack. Gate with existing pricing/billing permissions; no “no access” placeholders.
4. Select charge by sale channel: pharmacy walk-in / pharmacy orders without clinical encounter auto-bill and display **pharmacy sell** (or pharmacy insurance overlay when required). Facility/clinical orders keep **facility sell** (+ facility insurance). Fix walk-in `billingEntity: 'FACILITY'`. Snapshot charged unit prices on billing lines so catalog edits do not rewrite history.
5. Align pharmacist home money metrics: Most sold Amount and sales KPIs for pharmacy-channel dispenses use pharmacy sell (prefer billed/snapshot unit price, else pharmacy sell). Show **Profit** when buying price exists: (sell − buy) × qty. Keep Order status mix qty-only. Gate Amount/Profit/sales as today. Empty/loading/error/forbidden and post-mutation sync follow existing dashboard patterns.
6. Preserve catalog, offering, order-line price-source switch, and permissions unless required above. Light/dark and responsive price fields.

## Constraints

- Scope: three cash price roles, insurance overlays via price-book/resolver, walk-in billing-entity fix, dashboard Amount/sales/profit alignment.
- Reuse `drug`, `facility_pharmacy_offering`, `price_book_entry`, price-resolver, pharmacy catalog/edit, walk-in create, most-sold aggregations—no parallel drug catalog or billing engine.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.
- Migrations backward compatible: existing `unit_price` remains pharmacy sell; missing buying price → profit empty/hidden until set.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Buying + pharmacy sell + facility sell stored/editable for authorized users; unauthorized fields absent. | R1–R2 |
| A2 | Insurance overlays resolve via price-book for PHARMACY and FACILITY; cash uses base sell. | R3 |
| A3 | Walk-in/pharmacy-channel bills pharmacy sell (or pharmacy insurance); clinical keeps facility sell. | R4 |
| A4 | Dashboard Amount/sales use pharmacy-channel sell (snapshot preferred); Profit when buy price + perms; status mix qty-only. | R5 |
| A5 | Existing authorized pricing UX preserved; validation/sync/themes/viewports OK. | R1–R2, R6 |

## Relevant Files

- `backend/prisma/schema.prisma` (`drug`, `facility_pharmacy_offering`, `price_book_entry`)
- `backend/src/lib/billing/price-resolver.js`, `clinical-request-billing.js`
- `backend/src/modules/pharmacy-order/services/pharmacy-order.service.js`
- `backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js`
- `backend/src/lib/dashboard/summary.js`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`, `pharmacy_drug_edit_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart`, `pharmacy_access.dart`
- `frontend/lib/features/home/presentation/widgets/pharmacy_most_sold_charts.dart`
- Tests: price schemas; walk-in billing entity; resolver cash vs insurance; most-sold amount/profit; unauthorized price UI absent

## Verification

- Schema/unit: buying + sell fields; price-book pharmacy/facility insurance; resolver by billing entity + payment mode.
- Integration: walk-in bills pharmacy sell; facility order facility sell; KPI/most-sold Amount match channel sell; Profit = (sell − buy) × qty when buy set.
- Auth: pricing gates; unauthorized buy/sell controls absent.
- Manual: configure three cash prices + insurance overlay; pharmacist Amount/Profit; light/dark; mobile/desktop.
