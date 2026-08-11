# Subscriptions panel — Billing (Invoices)

## 1. Tab strip

- Label: `Invoices`
- Icon: `Icons.receipt_long_outlined`
- Deep-link `panel`: `billing` / resource `subscription-invoices`
- Tab gate: `SubscriptionsInvoicesAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**

- Create primary: **intentionally omitted**
- Export / Print: **absent**
- Past due invoices queue chip (shared) may land here

## 3. Table

- Row model: invoice `SubscriptionItem`
- Row select: detail when invoices rowSelect allowed
- Default columns: Invoice, Tenant, Status, Amount, Issued at
- Column choices: Invoice ID, Billing status, Due date, Payment method, …

## 4. Advanced filters / search fields

- Invoice status / date preset / related groups from `_filterGroups`

## 5. Primary / secondary / row actions

- Detail: Collect invoice, Retry invoice (write ∩)
- No create; no delete/void mounted

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Invoice detail | Subscriptions-owned |
| Collect / Retry | Subscriptions-owned |

## 7. Nested / follow-on

Collect/Retry → payment method / confirmation fields

## 8. Forms (summary)

- Collect/retry: amount, method, notes/status adjustment groups

## 9. Print / labels / preview

- **Absent**

## 10. Loading / empty / error / success

- Standard worklist feedback

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | read ∩ |
| Collect / Retry | write ∩ |
| Create / Delete | mapped but **not mounted** |
