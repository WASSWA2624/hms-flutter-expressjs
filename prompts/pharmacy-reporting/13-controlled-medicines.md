# Pharmacy Reporting: Controlled Medicines — Accurate Balance Log

Implement controlled-drug balance reports only after a **durable controlled marker** exists; balances must reconcile from movements + dispenses.

## Context

**Gap:** No `drug.is_controlled` (or equivalent). Only weak signals: seed Morphine/Tramadol keys; `custody_snapshot.controlled_items_json`; `pharmacy_dispense_attestation`.

**Stock/dispense truth:** `inventory_stock`/`drug_batch.quantity`, `stock_movement`, `dispense_log.quantity_dispensed`, batch refs on dispense.

**All 12 controlled ids unavailable.**

## Data contract

| Report id | Formula |
| --- | --- |
| Identify controlled set | **Required:** boolean on `drug` (preferred) or versioned allow-list constant shared by seed+dataset—document choice |
| `controlled_medicine_stock` | on-hand qty for controlled drugs | `drug`, `quantity`, `batch_number` |
| `opening_balance` | on-hand at `from` − 1 tick: stock − movements after from + dispenses after from (state formula in code comments) |
| `quantity_received` | INBOUND/PURCHASE qty in range for controlled |
| `quantity_dispensed` | DISPENSED log qty in range |
| `closing_balance` | opening + received − dispensed − wastage ± adjustments |
| `batch_numbers` | batches for controlled drugs |
| `controlled_prescriber` / `controlled_patient` / `dispensing_staff` | from order encounter/patient + attestation user |
| `controlled_adjustments` | ADJUSTMENT movements |
| `wastage` | EXPIRY/DAMAGE qty |
| `regulatory_log` | chronological union of receive/dispense/adjust/waste with actor+batch |

**Invariant (test):** `closing = opening + received − dispensed − wastage + adjustments_net` for each drug/batch grain you choose (document grain: drug vs batch).

## Requirements

1. Migrate `is_controlled` (or equivalent) + mark Morphine/Tramadol (and peers) in seed **before** claiming ready.
2. Implement balance grain consistently; refuse silent drift.
3. Permission-tighten regulatory_log. Seed volume: ≥1,000 controlled-related dispense/movement/attestation events so balances and regulatory log are dense—not a single Morphine sample (`index.md` rule 9).
4. Reuse shared dialog; quantity units throughout.
5. Tests: golden balance fixture; unauthorized log absent; volume floor asserted.

## Constraints

- Permissions + pharmacy-flow; `index.md` gap rule; migrations mandatory.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Controlled set is explicit in DB or shared allow-list. | contract |
| A2 | Balance invariant holds in tests. | contract |
| A3 | ≥1,000 controlled events; open→receive→dispense→close demonstrable. | R3 |

## Relevant Files

- Prisma drug (+ migration), dispense_log, stock_movement, attestation; clinical catalog seeder; datasets; provider

## Verification

- Manual ledger vs dialog balances for Morphine seed.
- Manual: Controlled → opening/closing, regulatory log.
