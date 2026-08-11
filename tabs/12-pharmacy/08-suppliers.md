# Pharmacy tab — Suppliers

## 1. Tab strip

- Label: `pharmacyDeskSuppliersLabel`
- Icon: `Icons.local_shipping_outlined`
- Count source: `state.suppliers.totalItemCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `suppliers` (prepares suppliers via `controller.prepareSuppliers`)
- Tab gate: `pharmacyCatalogBrowseRequirement` = ∩ `pharmacy:read`
- **Omitted when unauthorized**
- Body: `PharmacySuppliersCatalogTab` / `pharmacy_suppliers_panel.dart` (not nested under Catalog icon bar)

## 2. Search / Filters / Settings / Export / Print / context

- Search on suppliers table
- Trailing **Add supplier** (`pharmacyAddSupplierAction`) when catalog write ∪ allows — omitted when denied
- Export / Print: not a primary suppliers strip feature (panel-owned if any)

## 3. Table

- Row model: `PharmacySupplier`
- Default columns (panel): name / contact / phone / status / related fields as defined in `pharmacy_suppliers_panel.dart` (name, code, contact, phone, status family)
- Row select → supplier details / edit dialogs
- Mobile meta uses contact/status chips

## 4. Advanced filters / search fields

- Panel search matcher; advanced groups if mounted on suppliers panel (name/status style) — browse chrome under catalog browse ∩

## 5. Primary / secondary / row actions

- Strip Add supplier (write ∪)
- Row → details / edit / deactivate paths when authorized

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Supplier details | Pharmacy-owned `pharmacy_supplier_details_dialog.dart` |
| Add / edit supplier | Pharmacy-owned (panel dialogs; title uses Add/Edit supplier keys) |
| Supplier similarity | Pharmacy-owned `pharmacy_supplier_similarity_dialog.dart` |

## 7. Nested / follow-on

Similarity → proceed / use existing; details may nest edit form.

## 8. Forms (summary)

- Supplier identity, contacts, notes, active flag (summary)

## 9. Print / labels / preview

- Absent as desk table Print/Export for suppliers

## 10. Loading / empty / error / success

- Panel empty/loading; mutation snackbars under write ∪

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list | catalog browse ∩ `pharmacy:read` |
| Add / Edit / Delete | catalog write ∪ |
| Operations-only entry | suppliers omitted in fallback |
