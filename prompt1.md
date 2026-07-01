# Subscription Upgrade CTA & Payment Dialog — Implementation Prompt

## Objective

Add a **persistent, state-aware subscription button** to the authenticated app header and a **modal upgrade/activation flow** so tenants can discover plans, submit payment, and notify platform admins without leaving their current workspace.

**Parent prompts:** [prompts/02-subscriptions-module-prompt.md](./prompts/02-subscriptions-module-prompt.md), [prompt.md](./prompt.md)

---

## Header Subscription Button

Place a prominent **Upgrade / Subscription** control in the **app shell header** (visible on all authenticated routes), with both an **icon** and a **text label**.

| Subscription state | Visual treatment | Label (i18n) |
|------------------|------------------|--------------|
| **Active** (paid or trial, healthy) | Theme success color (green/blue per theme); optional check/tick affordance | e.g. “Subscribed” / “Active” |
| **Expiring soon** (within configurable threshold, e.g. 14 days) | Warning color (orange) | e.g. “Renew soon” / “Expires in {n} days” |
| **Expired / past due** | Error color (red) | e.g. “Subscription expired” / “Upgrade required” |

- Derive state from tenant subscription (`status`, `ends_at` / trial end) in session or workspace data — do not hardcode thresholds in UI widgets.
- **Tap** opens the subscription upgrade/activation dialog (modal; no route navigation).
- Compact breakpoints may collapse to icon + tooltip; full label remains on larger layouts.

---

## Upgrade / Activation Dialog

Single in-page dialog (or bottom sheet on narrow viewports) opened from the header button or subscription workspace.

### Plan selection

- List available plans (Basic, Pro, Advanced, Custom, trial → paid) with clear tier comparison.
- Default selection should reflect current plan or recommended upgrade.
- Initiation and plan discovery must be **one or two steps** — no buried navigation.

### Payment methods

Support multiple paths in the same dialog:

| Method | Behavior |
|--------|----------|
| **Manual / bank transfer** | Tenant uploads **proof of payment** (image/PDF); optional reference number and amount fields. |
| **Mobile money** | Provider selection + payment instructions or deep link where integrated. |
| **Card (Visa, etc.)** | Checkout or collect flow when payment provider is configured. |
| **Other** | Extensible list driven by backend-supported methods. |

### Platform admin contact & notification

- Show **platform admin contact details** in the dialog (email, phone with `mailto:` / `tel:` links) so tenants can call or email after paying.
- On proof-of-payment submit (and other payment initiation where applicable):
  - **Send email** to platform admin(s) with tenant name, plan, amount, and payment reference.
  - Create or update a **pending payment / subscription request** record visible in platform admin workspace.
- Platform admin reviews the request and **activates** or approves the subscription (existing admin activation flow).

---

## Acceptance Criteria

- [ ] Header button is visible on authenticated shell; icon + label; state-driven color and copy.
- [ ] Active, expiring-soon, and expired states render correctly from live subscription data.
- [ ] Dialog opens from header button; plan selection and payment method choice are straightforward.
- [ ] Manual payment supports proof upload; submission notifies platform admin (email + admin queue).
- [ ] Admin contact info (email, phone) is shown in the payment section.
- [ ] All strings in `app_en.arb`; follows design system and modal-first patterns.
- [ ] Quality gate: `flutter analyze`, `flutter test`, targeted backend tests for payment-notification endpoints.

---

## Key References

```
frontend/lib/app/router/app_router.dart          — _AppShell / ResponsiveAppShell
frontend/lib/shared/layout/responsive_shell_scaffold.dart
frontend/lib/features/subscriptions/
frontend/lib/core/security/auth_session.dart     — entitlements / subscription in session
backend/src/modules/subscription/
backend/src/modules/subscriptions-workspace/
backend/src/config/env.js                        — admin contact / notification config
```
