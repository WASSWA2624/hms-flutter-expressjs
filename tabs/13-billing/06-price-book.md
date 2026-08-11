# Billing tab — Price book

## 1. Tab strip

- Label: `billingPriceBookTab`
- Tooltip: `billingPriceBookTooltip`
- Icon: `Icons.menu_book_outlined`
- Count source: `billingPriceBookActiveCountProvider`
- Count tone: default (not queue `billingQueueCountTone`)
- Deep-link / selection: price-book URL flag / tab id `prices` (not a `BillingQueueType`)
- Tab gate: `BillingPriceBookAtomPermissions.tab` = ∩ `billing:read` + `billing-payments`
- **Omitted when unauthorized**
- Body: `BillingPriceBookPanel` (replaces queue table)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Print → Add?**

- Filters: `commonFiltersActionLabel` → advanced filters; reset `billingClearFilters`
- Text filters for price-book fields (panel-owned)
- Trailing: Print list (`billingPriceBookPrintAction`); Add (`commonAddActionLabel`) when price-book write ∪ allows
- Queue Charge / Issue all / Close: **not mounted**

## 3. Table

- Row model: `BillingPriceBookEntry`
- Default columns: Item, Mode, Price, Status (+ Actions when write)
- Row select / edit opens create-or-edit dialog when authorized
- Export values wired on columns for print/export helpers

## 4. Advanced filters / search fields

- Panel filter value (`_filterValue`) drives reload; mode/status/item style filters per price-book panel

## 5. Primary / secondary / row actions

- Strip: Print list; Add
- Row: Edit / Deactivate (write ∪) — omitted when unauthorized

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Create / edit price book entry | Billing-owned `billing_price_book_dialogs.dart` |
| Similarity | Billing-owned `billing_price_book_similarity_dialog.dart` |

## 7. Nested / follow-on

Similarity → proceed / use existing / cancel; edit form submit → refresh count/list.

## 8. Forms (summary)

- Item / payment mode / unit price / currency / active flag (summary)

## 9. Print / labels / preview

- List Print: `billingPriceBookPrintAction` → price-book print helpers / options
- No queue invoice/receipt print on this tab

## 10. Loading / empty / error / success

- Panel loading/empty/retry under price-book tab read ∩
- Mutation feedback under write ∪

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / search / filters | price-book tab read ∩ |
| Add / Edit / Deactivate | price-book write ∪ (`pricing:facility_write` \| `pricing:pharmacy_write` \| tenant/facility admin) ∩ `billing-payments` |
| Print list | available with panel (read chrome) |
| Route entry | billing read ∪ write |
