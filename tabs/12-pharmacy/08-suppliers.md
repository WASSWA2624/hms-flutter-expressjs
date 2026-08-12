# Pharmacy tab — Suppliers

## 1. Tab strip

- Label: `pharmacyDeskSuppliersLabel` (`Suppliers`)
- Icon: `Icons.local_shipping_outlined`
- Count source: `state.suppliers.totalItemCount` (filtered query total via `pharmacySectionTabCount`)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `suppliers` (prepares suppliers via `controller.prepareSuppliers`)
- Tab gate: `PharmacySuppliersAtomPermissions.tab` = `pharmacyCatalogBrowseRequirement` ∩ `pharmacy:read` + `pharmacy-dispensing`
- **Omitted when unauthorized**
- Body: `PharmacySuppliersCatalogTab` / `pharmacy_suppliers_panel.dart` (not nested under Catalog icon bar)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Create?**

- Search: `pharmacySupplierSearchHint`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`
- Settings: `commonTableSettings*`; Apply/Reset columns; Close; storage `pharmacy_catalog_suppliers`
- Export: `commonTableExportActionLabel` — omit without ∩ `evidence:export`
- Print: `commonPrintActionLabel` — preview-first (`printPharmacyWorkspaceList`); same export gate
- Trailing **Create** (`commonCreateActionLabel` / `pharmacyAddSupplierAction`) when catalog write ∪ — omitted when denied

## 3. Table

- Row model: `PharmacySupplier`
- Default columns (**5**):
  1. Name (always visible)
  2. Location (always visible)
  3. Email (always visible)
  4. Phone (always visible)
  5. Actions (always visible)
- Row select → supplier details / edit dialogs
- Mobile meta uses contact chips

## 4. Advanced filters / search fields

Text filters: Name / Location / Email / Phone (same search model as table + active count).  
Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Strip Create (write ∪)
- Row Edit / Delete when write ∪ (omitted when denied)
- Unauthorized actions omitted

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Supplier details | Pharmacy-owned `pharmacy_supplier_details_dialog.dart` (`pharmacySupplierDetailsTitle`) |
| Add / edit supplier | Pharmacy-owned (`pharmacyAddSupplierAction` / `pharmacyEditSupplierAction`) |
| Supplier similarity | Pharmacy-owned `pharmacy_supplier_similarity_dialog.dart` |

## 7. Nested / follow-on

Similarity → proceed / use existing; details may nest edit form.

## 8. Forms (summary)

- Supplier identity, contacts (email/phone), location — no tenant/facility fields

## 9. Print / labels / preview

- Table Export + Print gated by `canExportPharmacyWorkspace` / `canPrintPharmacyWorkspace`
- Trigger label `Print`; preview-first helpers

## 10. Loading / empty / error / success

- Panel empty/loading; mutation snackbars under write ∪

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list | `PharmacySuppliersAtomPermissions` browse ∩ `pharmacy:read` |
| Export / Print | ∩ `evidence:export` |
| Add / Edit / Delete | catalog write ∪ |
| Operations-only entry | suppliers omitted in fallback |
