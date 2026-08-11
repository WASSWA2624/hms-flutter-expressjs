# Subscriptions panel — Governance (Licenses)

## 1. Tab strip

- Label: `Licenses`
- Icon: `Icons.key_outlined`
- Deep-link `panel`: `governance` / resource `licenses`
- Tab gate: `SubscriptionsLicensesAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Add license**

- Add license omitted without write ∩ or empty tenants
- Export / Print: **absent**
- Expiring licenses queue chip may land here

## 3. Table

- Row model: license `SubscriptionItem`
- Row select: detail
- Default columns: License type, Tenant, Status, Amount, Expires at
- Column choices: License ID, End date, …

## 4. Advanced filters / search fields

- License type / status / date preset groups as provided

## 5. Primary / secondary / row actions

- Strip: Add license
- Detail: Update license (incl. status→CANCELLED soft revoke), Revoke (delete ∩)
- Revoke omitted without delete ∩

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| License detail | Subscriptions-owned |
| Add / Update license | Subscriptions-owned |
| Revoke confirm | Subscriptions-owned |

## 7. Nested / follow-on

Update → status CANCELLED soft path. Revoke → HTTP delete confirm.

## 8. Forms (summary)

- License: tenant, type, dates, amount, status

## 9. Print / labels / preview

- **Absent**

## 10. Loading / empty / error / success

- Standard worklist; saved snackbar

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | read ∩ |
| Add / Update | write ∩ |
| Revoke | delete ∩ |
