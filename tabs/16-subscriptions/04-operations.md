# Subscriptions panel — Operations

## 1. Tab strip

- Label: `Subscriptions`
- Icon: `Icons.verified_user_outlined`
- Deep-link `panel`: `operations`
- Nested resources: `subscriptions` (default), `module-subscriptions`
- Tab gate: `SubscriptionsAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → New subscription** (subscriptions resource only)

- Nested resource tab bar when both resources available
- New subscription omitted without write ∩ or when tenants lookup empty
- Module-subscriptions: no create primary from `_worklistCreateAction`
- Export / Print: **absent**

## 3. Table

### Resource `subscriptions`

- Default: Tenant, Plan, Status, Amount, Expiry date
- Choices: Subscription ID, Billing cycle, Fit status, Start date, Change status, Tenant ID, …

### Resource `module-subscriptions`

- Default: Module, Tenant, Status, Plan, Expiry date
- Choices: Record ID, Eligibility, …

- Row select → detail (gated by `SubscriptionsAtomPermissions.rowSelect`)

## 4. Advanced filters / search fields

- Status, tier, billing cycle, plan, module, fit, date preset as applicable
- Pending-changes queue chip may prefilter

## 5. Primary / secondary / row actions

- New subscription (strip)
- Detail: Edit / Renew / Change plan / Activate / Cancel (status→CANCELLED via PUT) / Assign module / Enable·Disable module — all write ∩
- HTTP delete: **not mounted**
- Upgrade path via upgrade dialog when offered

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Subscription / module-subscription detail | Subscriptions-owned |
| New / Edit / Renew / Change plan | Subscriptions-owned |
| Assign / toggle module | Subscriptions-owned |
| Upgrade | Subscriptions-owned `subscription_upgrade_dialog.dart` |
| Report admins (when surfaced) | Subscriptions-owned |

## 7. Nested / follow-on

Upgrade → plan selector + payment method / mobile money selectors. Cancel via update form status.

## 8. Forms (summary)

- Subscription: tenant, plan, cycle, dates, status, amounts
- Module assign/toggle: module + tenant linkage
- Upgrade: plan comparison, billing cycle, payment method

## 9. Print / labels / preview

- **Absent**

## 10. Loading / empty / error / success

- Standard worklist; `savedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / nested resources / list / detail | read ∩ |
| New / Assign / Edit / Renew / Change plan / Activate / Cancel / Toggle | write ∩ |
| Delete | delete ∩ — **not mounted** |
