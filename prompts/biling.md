**Verdict:** Don’t invent two new finance “jobs” as the primary fix. The app already models two prices; what’s missing is **who is allowed to set each one**. Prefer **fine-grained pricing permissions** (and optional role packs), not a second accountant identity.

## What you already have

Pricing is already split at the data layer for pharmacy drugs:

| Concept | Storage | Meaning |
|---|---|---|
| Pharmacy retail | `drug.unit_price` → `pharmacy_unit_price` | Walk-in / OTC / pharmacy counter |
| Facility billing | `facility_pharmacy_offering.unit_price` → `facility_unit_price` | In-hospital / clinical encounter charging |

Order-time selection already exists (`PharmacyItemPriceSource.pharmacy` vs `.facility`): clinical/OPD/IPD/etc. default to **facility**; walk-in defaults to **pharmacy**. Price books and invoice lines also carry `billing_entity: FACILITY | PHARMACY`.

So the mix risk is mostly **authorization and UI**, not missing price fields.

## Where mixing still happens

1. **One dialog, one gate** — `pharmacy_drug_edit_dialog` edits pharmacy + facility price together; catalog write is effectively `pharmacy:write` ∪ `operations:write`.
2. **Coarse finance roles** — `BILLING` owns invoice/claims/`financial:approve`; `ACCOUNTANT` is only an alias of `BILLING`. Neither owns “set pharmacy retail” vs “set facility tariff.”
3. **Price book** — `billing:write` can write either `billing_entity` with no split.
4. **No cost floor** — there’s no purchase/cost price, so nothing stops retail or facility tariff going below cost.

## Recommended approach: permissions first, roles as packs

### 1. Add pricing permissions (primary lever)

Keep existing `billing:*` / `pharmacy:*` for operations (dispense, collect payment). Add pricing-specific atoms, for example:

- `pricing:pharmacy_read` / `pricing:pharmacy_write` — pharmacy retail on `drug`
- `pricing:facility_read` / `pricing:facility_write` — facility tariffs (pharmacy offerings, lab/radiology offerings, clinical catalog)
- Optionally later: `pricing:price_book_write` scoped by `billing_entity`, or `pricing:approve` for dual-control

Wire them so:

- Updating `drug.unit_price` requires **pharmacy pricing write**
- Updating `facility_pharmacy_offering.unit_price` requires **facility pricing write**
- UI disables the other field if the user lacks that permission
- Backend enforces the same split (UI alone is not enough)

That stops one person quietly overwriting the other ledger’s price.

### 2. Optional roles (convenience only)

Only add roles if staffing is literally two people:

| Role pack | Permissions | Owns |
|---|---|---|
| **Pharmacy pricing** (or extend Pharmacist / Pharmacy manager) | `pricing:pharmacy_*` (+ existing `pharmacy:*` as needed) | Retail / OTC |
| **Facility billing / tariff** (or keep Billing/Accountant) | `pricing:facility_*`, `billing:*` | Encounter / facility tariffs, invoices, claims |

Do **not** make `ACCOUNTANT` a second full clone of `BILLING` unless you also split permissions. Today `ACCOUNTANT → BILLING` means they are the same capability set.

Prefer: **one Billing Officer for facility tariffs + cash office**, and **pharmacy manager/pharmacist for retail**, both composed from permissions. Custom roles in Access Admin already fit this.

### 3. What not to do

- Don’t create parallel invoice engines or parallel catalogs — you already have one billing pipeline with `billing_entity` / `price_source`.
- Don’t rely on “two accountants” without permission atoms — they’ll still share `billing:write` and mix prices.
- Don’t give both people `pharmacy:write` and expect process discipline to protect margins.

### 4. Loss-prevention add-ons (after the split)

- Optional **cost / acquisition price** with “selling &lt; cost needs `pricing:approve`”
- Audit on price changes (who changed which tier)
- Keep runtime defaults as today (clinical → facility, walk-in → pharmacy); restrict **manual override** of `price_source` to billing/pricing write, not every dispenser

## Practical target model

```text
Pharmacist / Pharmacy tech     → dispense, stock, (optional) pharmacy retail price
Facility billing / accountant  → facility tariffs, invoices, claims, payments
Facility admin                 → both pricing writes (exception / setup)
```

**Bottom line:** Separate **permissions** for pharmacy vs facility price writes; use **roles only as packs** of those permissions. That matches the current dual-price model and closes the real gap (same write path editing both prices).

---
Rules: `user_rules` (ask mode, concise communication, cite code, append rules/model)  
Model: Composer (Auto / agent router)