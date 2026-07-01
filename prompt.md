# Subscription Upgrade Dialog — UX Refinement Prompt

## Objective

Refine the **subscription upgrade / renewal dialog** so it is compact, maximized by default, and guides tenants through payment with method-specific inline fields, proof upload with preview, and **read-only plan amounts** converted to the selected currency in real time.

**Parent prompts:** [prompt1.md](./prompt1.md), [prompts/02-subscriptions-module-prompt.md](./prompts/02-subscriptions-module-prompt.md)

**Primary file:** `frontend/lib/features/subscriptions/presentation/widgets/subscription_upgrade_dialog.dart`

---

## Dialog Shell

- Open **maximized by default** (`AppDialog.initialMaximized: true`).
- Tighten vertical spacing; remove redundant copy where the title already conveys intent.
- **Remove** the upgrade intent banner (`_IntentBanner` / `subscriptionUpgradeIntentBanner` — “You are upgrading to a higher plan.”). Keep the renewal banner if useful, or remove both for consistency.
- Retain plan selector, payment method selector, payment details, amount/currency, proof upload, admin contact, and submit actions.

---

## Payment Method Selector

Keep the existing top-level method cards (`SubscriptionPaymentMethodSelector`): Mobile Money, Bank Transfer, Credit Card, Debit Card, Cash, Other.

When a method is selected, show **inline detail fields** below (no nested modal).

| Method | Inline fields |
|--------|---------------|
| **Mobile Money** | Provider chips (see below) + payer phone number |
| **Bank Transfer** | Platform bank account details (account name, bank, branch, account number, SWIFT/IBAN where applicable) + optional payer bank name |
| **Credit Card** | Cardholder name + last 4 digits |
| **Debit Card** | Cardholder name + last 4 digits |
| **Cash** | **Amount paid only** — remove reference / transaction ID fields |
| **Other** | Notes only (unchanged) |

### Mobile Money providers

Replace the dropdown with a **horizontal, scrollable row** of selectable chips/buttons (radio semantics, single selection):

MTN Mobile Money, Airtel Money, M-Pesa, Vodacom, Tigo, Orange, Zamtel, Government — per `MobileMoneyProviderId`.

- Each chip shows the **provider logo** (add assets under `frontend/assets/…`) **and** localized name.
- Single tap selects; compact layout with horizontal overflow scroll on narrow widths.
- Reuse existing `subscriptionPaymentMethodRequiresProof` rules.

### Bank Transfer details

Display **recipient bank instructions** (read-only) when Bank Transfer is selected. Source from platform admin / env config or a small backend endpoint if not yet available. Research standard fields for East/Southern African bank transfers.

---

## Proof of Payment

Required for: **Bank Transfer**, **Mobile Money**, **Cash** (per `subscriptionPaymentMethodRequiresProof`).

- Support image and PDF upload (existing file picker flow).
- After upload, show an **inline preview**:
  - Thumbnail for images
  - File name + icon for PDFs
- Keep attach / remove actions; preview sits beside or below the file name.

---

## Amount & Currency

- Plan prices are stored in **USD** (base currency).
- **Amount is read-only** for subscribers — they cannot edit the numeric value.
- **Currency is selectable** via `AppCurrencyAmountField` (or equivalent); only the currency control is interactive.
- On **plan change**: set amount from the selected plan’s USD price.
- On **currency change**: convert USD → selected currency using **[Frankfurter](https://frankfurter.dev)** (open source, no API key, self-hostable — [GitHub: lineofflight/frankfurter](https://github.com/lineofflight/frankfurter)).

### FX API — Frankfurter (chosen)

| | |
|---|---|
| **Why** | Open source (MIT), free, no signup/key, official central-bank rates, 200+ currencies in v2, suitable for billing |
| **Update cadence** | Latest official rates (working-day refresh, not intraday ticks — acceptable for subscription amounts) |
| **Public base URL** | `https://api.frankfurter.dev` |

**Primary call (v1 — simple, stable):**

```
GET https://api.frankfurter.dev/v1/latest?base=USD&symbols=UGX
```

```json
{ "amount": 1, "base": "USD", "date": "2026-07-01", "rates": { "UGX": 3701.23 } }
```

**Conversion:** `convertedAmount = usdPrice * rates[TARGET]` (round per currency rules below).

**Fallback for unsupported pairs (v2):**

```
GET https://api.frankfurter.dev/v2/rate/USD/UGX
```

**Implementation notes:**

- Add a small `FxRateService` (frontend or thin backend proxy) that fetches on currency change.
- Cache the full USD→symbols map in memory for **1 hour** (or until dialog closes) to avoid repeat calls.
- Show a brief loading indicator on the amount field while fetching; on failure, keep USD amount and show a non-blocking error (“Could not load exchange rate — amount shown in USD”).
- Round converted amounts sensibly (0 decimals for UGX/TZS/KES/ZMW; 2 for USD/EUR).
- Persist submitted `amount` + `currency` as today; backend may normalize to USD if needed later.

---

## Acceptance Criteria

- [ ] Dialog opens maximized; layout uses less vertical space than current build.
- [ ] Upgrade intent banner is removed.
- [ ] Mobile money providers render as logo + label chips in a horizontal row; no nested dialog.
- [ ] Bank transfer shows platform recipient details inline.
- [ ] Credit/debit card collect holder name + last 4 digits only.
- [ ] Cash collects amount only (no reference / transaction ID).
- [ ] Proof upload shows image/PDF preview before submit.
- [ ] Amount field is disabled/read-only; currency change triggers live FX conversion from USD plan price.
- [ ] All new strings in `app_en.arb`; new logos added to `pubspec.yaml` assets.
- [ ] Quality gate: `flutter analyze`, `flutter test` (including dialog/widget tests where applicable).

---

## Key References

```
frontend/lib/features/subscriptions/presentation/widgets/subscription_upgrade_dialog.dart
frontend/lib/features/subscriptions/presentation/widgets/subscription_payment_method_selector.dart
frontend/lib/features/subscriptions/presentation/widgets/subscription_payment_methods.dart
frontend/lib/shared/components/app_dialog.dart                    — initialMaximized
frontend/lib/shared/forms/app_currency_amount_field.dart
backend/src/config/env.js                                         — admin / bank details config
https://frankfurter.dev                                           — FX API docs
https://github.com/lineofflight/frankfurter                       — open-source server (self-host option)
```
