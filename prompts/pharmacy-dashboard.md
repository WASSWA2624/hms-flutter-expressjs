# Pharmacy Drug Pricing: Cost, Sell Tiers, and Insurance Differentials

Implement a three-tier drug price model (pharmacy buy, pharmacy sell, facility sell) plus insurance-specific sell overlays so pharmacy and facility profit/loss and billable charges use the correct price role—without inventing a parallel catalog or breaking existing pharmacy/facility sell surfaces.

## Context

**Current behavior (codebase)**

- Catalog already exposes two cash sell prices: `drug.unit_price` (pharmacy retail / OTC) and `facility_pharmacy_offering.unit_price` (facility encounter tariff). Pharmacy catalog UI columns: pharmacy price + facility price. Permissions: `pricing:pharmacy_write` / `pricing:facility_write` (and matching read).
- There is **no** pharmacy buying / cost price on `drug` (or equivalent). Dashboard **Most sold** Amount and KPI **sales today/week** value dispenses as `qty × drug.unit_price` (live catalog), not billed snapshots. **Profit** series is always empty. Order status mix remains qty-only (do not reintroduce Amount there unless a later prompt requires it).
- Walk-in / pharmacy-created orders should bill at pharmacy retail, but auto-billing currently resolves with `billingEntity: 'FACILITY'` (preferring facility offering). Workspace line UX already distinguishes pharmacy vs facility price sources.
- Insurance / coverage differentials already exist via `price_book_entry` (`payment_mode`, `billing_entity`, coverage/insurer keys) and `price-resolver.js`. Cash base prices and insurance overlays must stay one resolver path.

**Intended behavior**

- Every drug’s configured cash prices include three roles:
  1. **Pharmacy buying price** — what pharmacy pays to acquire stock (COGS / cost basis).
  2. **Pharmacy selling price** — what pharmacy charges walk-in / direct pharmacy sales (OTC). This is also the **facility’s buying price** when the facility “buys” from pharmacy for clinical/facility dispensing.
  3. **Facility selling price** — what the facility charges patients for facility/clinical pharmacy use (existing facility offering tariff).
- Pharmacy and facility may each have **insurance** (or other non-cash) sell prices that differ from cash; reuse price-book / resolver patterns rather than a second overlay stack.
- Profit/loss and dashboard Amount/sales/profit must use the price role that matches the sale channel (pharmacy walk-in vs facility clinical), with cost from pharmacy buying price where required.

**Definitions**

- *Pharmacy buying price*: acquisition cost to pharmacy; basis for pharmacy margin and for facility-side cost when facility buy = pharmacy sell.
- *Pharmacy selling price*: cash OTC / walk-in charge on the drug catalog (`drug` retail); equals facility buying price for margin math.
- *Facility selling price*: cash facility tariff on `facility_pharmacy_offering`.
- *Insurance sell price*: non-cash sell overlay for a billing entity (PHARMACY or FACILITY), resolved via existing price-book + payment mode / insurer / coverage—not a free-form third catalog table unless reuse is impossible.
- *Sale channel*: PHARMACY (walk-in / no clinical encounter) vs FACILITY (encounter / facility-billed dispense).

## Requirements

1. Persist **pharmacy buying price** at database/catalog level alongside existing pharmacy sell and facility sell. Drug create/edit (and API validation) must capture buying + pharmacy sell; facility sell continues on the facility offering (create/update offering as today). Unauthorized price fields/actions must not render (`pricing:pharmacy_*` / `pricing:facility_*` as today). Validate non-negative decimals, currency consistency, and required fields per write surface; show field/API validation errors via existing patterns.
2. Map roles explicitly in serializers/UI: buying cost; pharmacy sell (`drug.unit_price` or renamed field with backward-compatible API); facility sell (`facility_pharmacy_offering.unit_price`). Document that facility buy for profit = pharmacy sell. Catalog list/detail/edit must surface buying price where pharmacy pricing write/read allows; hide when unauthorized.
3. Support **insurance (non-cash) sell differentials** for pharmacy and facility billing entities by extending or configuring `price_book_entry` + `price-resolver` (payment mode INSURANCE / coverage / insurer). Cash still falls back to pharmacy or facility base sell by billing entity. Do not bypass resolver for new overlays. Gate management with existing pricing/billing permissions; no “no access” placeholders.
4. Align charge selection by sale channel: pharmacy walk-in / anonymous or patient pharmacy orders without clinical encounter must auto-bill and display using **pharmacy sell** (and insurance pharmacy overlay when payment mode requires it). Facility/clinical orders continue to use **facility sell** (+ facility insurance overlay). Fix the current walk-in `billingEntity: 'FACILITY'` mismatch. Snapshot charged unit prices on billing lines so later catalog edits do not rewrite historical invoices.
5. Align pharmacist home money metrics with the same roles: Most sold **Amount** and sales KPIs for pharmacy-channel dispenses use pharmacy sell (prefer snapshot/billed unit price when present, else pharmacy sell at dispense time). Enable **Profit** when buying price exists: profit ≈ sell − buy × qty for the channel’s sell price. Keep Order status mix qty-only. Gate Amount/Profit/sales as today (`pricing:pharmacy_read` and existing chart money ORs). Empty/loading/error/forbidden follow existing dashboard patterns; sync after price or dispense mutations.
6. Preserve existing pharmacy catalog, offering, order line price-source switch, and permissions unless a change is required above. Light/dark and responsive layout for new/updated price fields.

## Constraints

- Scope: drug/facility pharmacy price model, insurance overlays via existing price-book/resolver, walk-in billing entity fix, dashboard Amount/sales/profit alignment.
- Reuse `drug`, `facility_pharmacy_offering`, `price_book_entry`, `price-resolver`, pharmacy catalog/edit dialogs, walk-in create, dashboard most-sold aggregations—no parallel drug catalog or duplicate billing engine.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.
- Migrations must be backward compatible: existing `unit_price` remains pharmacy sell; missing buying price → profit stays empty/hidden until configured.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Buying + pharmacy sell + facility sell are stored and editable on authorized catalog/offering flows; unauthorized fields absent. | R1–R2 |
| A2 | Insurance sell overlays resolve via price-book for PHARMACY and FACILITY billing entities; cash uses base sell prices. | R3 |
| A3 | Walk-in / pharmacy-channel orders bill and display pharmacy sell (or pharmacy insurance overlay); clinical/facility orders keep facility sell. | R4 |
| A4 | Dashboard Amount/sales use pharmacy-channel sell (snapshot preferred); Profit appears when buying price exists and permissions allow; status mix stays qty-only. | R5 |
| A5 | Existing authorized pharmacy/facility pricing UX remains; validation/sync/themes/viewports OK. | R1–R2, R6 |

## Relevant Files

- `backend/prisma/schema.prisma` (`drug`, `facility_pharmacy_offering`, `price_book_entry`)
- `backend/src/lib/billing/price-resolver.js`, `clinical-request-billing.js`
- `backend/src/modules/pharmacy-order/services/pharmacy-order.service.js`
- `backend/src/modules/dashboard-widget/repositories/dashboard-widget.repository.js` (`aggregateMostSoldDrugs`, `sumDispenseSalesAmount`)
- `backend/src/lib/dashboard/summary.js`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`, `pharmacy_drug_edit_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart`, `pharmacy_access.dart`
- `frontend/lib/features/home/presentation/widgets/pharmacy_most_sold_charts.dart`
- Tests: drug/offering price schemas; walk-in billing entity; resolver cash vs insurance; most-sold amount/profit; unauthorized price UI absent

## Verification

- Unit/schema: buying + sell fields; price-book pharmacy/facility insurance entries; resolver returns correct unit by billing entity + payment mode.
- Integration: walk-in creates billing at pharmacy sell; facility order at facility sell; sales KPI / most-sold Amount match channel sell; Profit = (sell − buy) × qty when buy set.
- Auth: pricing read/write gates; unauthorized buy/sell controls absent.
- Manual: catalog edit three cash prices + insurance overlay; pharmacist dashboard Amount/Profit; light/dark; mobile/desktop without clip.
