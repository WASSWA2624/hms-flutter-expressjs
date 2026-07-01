# Refine subscription upgrade dialog UI

Improve the subscription upgrade / payment form in `frontend/lib/features/subscriptions/presentation/widgets/subscription_upgrade_dialog.dart` and related widgets.

## 1. Plan selection → toggle buttons

Replace `AppSelectField` for plan selection with **toggle buttons** (segmented control or equivalent). The current dropdown is hard to see or clipped; toggles should make plan switching obvious and keep all options visible without opening a menu.

**Files:** `subscription_upgrade_dialog.dart` (and a small shared widget if needed).

## 2. Payment method selector — compact single-line chips

Redesign `SubscriptionPaymentMethodSelector` so each method is a **compact horizontal chip**:

- **Layout:** icon on the left, label on the right (one line per method).
- **Style:** remove card border and filled background; use minimal styling with a clear selected state only.
- **Density:** all methods should fit on **one row** on typical widths (wrap only on very narrow screens if unavoidable).

**Files:** `subscription_payment_method_selector.dart`.

## 3. Mobile money provider logos

In `MobileMoneyProviderSelector`, replace placeholder or incorrect logos with **official brand assets** for:

MTN, Airtel Money, M-Pesa, Tigo, Orange, Zamtel, Government Payment.

- Source logos from each provider’s official site or brand kit.
- Add assets under the frontend repo (e.g. `frontend/assets/images/payment_providers/`) and wire them in the selector.
- MTN is acceptable as-is; prioritize fixing Airtel, M-Pesa, and the rest.

**Files:** `mobile_money_provider_selector.dart`, new asset files, `pubspec.yaml` if needed.

## 4. Payment details layout & amount formatting

- On **large screens**, place **mobile money number** and **amount paid** on the **same row** (responsive: stack on small screens).
- Format **amount paid** with **thousands separators** (comma-separated) for readability. Reuse or extend `AppCurrencyAmountField` / `fx_currency_utils` if appropriate.

**Files:** `subscription_upgrade_dialog.dart`, `app_currency_amount_field.dart` (if formatting lives there).

## 5. Proof of payment

No change — file picker and preview behavior are fine.

## 6. Platform billing contact — clearer post-payment guidance

Expand `_AdminContactSection` copy so users know what to do **after paying**, e.g.:

- If the account is not activated after payment, contact platform administrators using the shown email/phone.
- State that support is available **at any time**.

Update `app_en.arb` (and regenerate l10n) with clear, actionable wording; show email and phone prominently.

**Files:** `subscription_upgrade_dialog.dart`, `app_en.arb`.

## Acceptance criteria

- [ ] Plan selection uses toggles, not a dropdown; all plans visible at a glance.
- [ ] Payment methods are compact, icon-left / label-right, no heavy borders or backgrounds.
- [ ] Mobile money logos are official assets committed to the repo.
- [ ] Phone + amount share a row on wide layouts; amount displays with comma separators.
- [ ] Admin contact section explains post-payment activation help and 24/7 availability.
- [ ] Existing form validation and submit flow unchanged.
- [ ] Widget tests updated or added where behavior changed.
