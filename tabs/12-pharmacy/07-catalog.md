# Pharmacy tab — Catalog (+ nested catalog sub-tabs)

## 1. Tab strip (desk)

- Label: `pharmacyDeskCatalogLabel`
- Icon: `Icons.inventory_2_outlined`
- Count source: **none** (`null` — management hub)
- Count tone: `AppTabCountTone.info` (when count present; catalog omits count)
- Deep-link `section`: `catalog` (aliases `inventory` / `stock` prepare Inventory sub-tab)
- Tab gate: `pharmacyCatalogBrowseRequirement` = ∩ `pharmacy:read`
- **Omitted when unauthorized**
- Body: `PharmacyCatalogPanel` with nested `PharmacyCatalogTab`

## Nested catalog chrome (`PharmacyCatalogTab`)

| Sub-tab | Label key | Icon (descriptor) |
| --- | --- | --- |
| `drugs` | `pharmacyCatalogTabDrugs` | (drugs descriptor) |
| `formulary` | `pharmacyCatalogTabFormulary` | |
| `inventory` | `pharmacyCatalogTabInventory` | `Icons.inventory_2_outlined` |
| `storageLayout` | `pharmacyCatalogTabStorage` | |
| `shelves` | `pharmacyCatalogTabShelves` | |

Component: `PharmacyCatalogIconTabBar` / `pharmacyCatalogTabDescriptors`. Selection via `controller.setCatalogTab`.

---

## Catalog sub-tab checklists

### A. Drugs (`PharmacyCatalogTab.drugs`)

#### 2. Search / Filters / Settings / Export / Print / context

- Filters / Settings on drugs table; trailing **Add drug** (`pharmacyAddDrugAction`) when catalog write ∪ allows
- Bulk selection action may replace Add (destructive delete/selection label)
- Export: formulary-adjacent flows set `enableExport: false`; drugs table follows panel (no desk Export strip)

#### 3. Table

- Drug catalog rows; row → drug details / edit
- Filters include stock status / name / code / form / strength text filters (`_drug*` keys)

#### 5–9. Actions / dialogs / forms / print

| Dialog | Owner |
| --- | --- |
| Drug details | Pharmacy-owned `pharmacy_drug_details_dialog.dart` |
| Drug edit / add | Pharmacy-owned `pharmacy_drug_edit_dialog.dart` |
| Drug similarity | Pharmacy-owned |
| Pack scan | Pharmacy-owned `pharmacy_drug_pack_scan_dialog.dart` |
| Catalog dialog shell | `pharmacy_catalog_dialog.dart` |

- Pricing fields gated: pharmacy retail ∩ `pricing:pharmacy_write`; facility tariff ∩ `pricing:facility_write` (+ billing-payments module on facility pricing requirement)
- Print: not a primary drugs-list print; label/print helpers may appear from detail options

#### 11. RBAC

- Browse: catalog browse ∩; Add/Edit/Delete: catalog write ∪; pricing fields: pricing write ∩

### B. Formulary (`PharmacyCatalogTab.formulary`)

#### 2–5. Toolbar / table / actions

- Filters include active (`_formularyActiveFilterKey`)
- Trailing Add formulary (`pharmacyAddFormularyAction`) / add-selected formulary items when write
- `enableExport: false` on formulary selection tables
- Dialogs: add formulary (`pharmacyAddFormularyDialogTitle`), selection add (`pharmacyAddSelectedFormularyItemsAction`)

#### 11. RBAC

- Same catalog browse / write ∪ gates

### C. Inventory (`PharmacyCatalogTab.inventory`)

#### 2–5. Toolbar / table / actions

- Stock status / item name / SKU / facility / pending stock filters
- Trailing catalog write actions when authorized
- Stock-alert desk sections land here with preset `PharmacyInventoryStockQuery`
- Row actions open stock/drug surfaces (details/edit)

#### 11. RBAC

- Browse ∩; mutations catalog write ∪

### D. Storage layout (`PharmacyCatalogTab.storageLayout`)

#### 2–5. Toolbar / table / actions

- Room/shelf filter groups (`_storageRoomFilterKey` / `_storageShelfFilterKey`)
- Trailing Add storage room (`pharmacyAddStorageRoomAction`) when write
- Similarity: `pharmacy_storage_room_similarity_dialog.dart`
- Panel: `pharmacy_storage_panel.dart`

#### 11. RBAC

- Catalog write ∪ for create/update/delete rooms

### E. Shelves (`PharmacyCatalogTab.shelves`)

#### 2–5. Toolbar / table / actions

- Trailing Add shelf (`pharmacyAddStorageShelfAction`) when write
- Similarity: `pharmacy_storage_shelf_similarity_dialog.dart`
- Room-scoped shelf filters when a room selected

#### 11. RBAC

- Catalog write ∪ for shelf CRUD

---

## Shared catalog sections (all sub-tabs)

### 6–8. Dialogs / nested / forms

- Edit dialogs host field groups for identity, packing, storage location, pricing (summary level)
- Similarity dialogs: proceed / use existing / cancel
- Nested storage pickers from drug edit (`initialTab: PharmacyCatalogTab.storageLayout`)

### 9. Print / labels / preview

- Desk Export/Print generally **absent** / `enableExport: false` on catalog selection tables
- No registry list-print equivalent to Reception on catalog host

### 10. Loading / empty / error / success

- Per-sub-tab loading/empty panels inside `PharmacyCatalogPanel`
- Mutation snackbars / dialog validation under write ∪

### Desk-level RBAC summary

| Atom | Gate |
| --- | --- |
| Catalog desk tab | ∩ `pharmacy:read` |
| Nested sub-tabs browse | catalog browse ∩ |
| Add / Edit / Delete / bulk | catalog write ∪ `pharmacy:write` \| `operations:write` |
| Pharmacy price fields | ∩ `pricing:pharmacy_write` |
| Facility price fields | ∩ `pricing:facility_write` (+ billing-payments on requirement) |
| Operations-only route entry | cannot see catalog (fallback strips catalog) |
