# Pharmacy tab — Catalog (+ nested catalog sub-tabs)

## 1. Tab strip (desk)

- Label: `pharmacyDeskCatalogLabel` (`Catalog and stock`)
- Icon: `Icons.inventory_2_outlined`
- Count source: **none** (`null` — management hub; `pharmacyTabItems` omits count)
- Count tone: `AppTabCountTone.info` (when count present; catalog omits count)
- Deep-link `section`: `catalog` (aliases `inventory` / `stock` / `catalog-and-stock` prepare Inventory sub-tab)
- Tab gate: `PharmacyCatalogAtomPermissions.tab` = `pharmacyCatalogBrowseRequirement` ∩ `pharmacy:read` + `pharmacy-dispensing`
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

Order: **Filters → Settings → Export → Print → Create / bulk?**

- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel`
- Settings: `commonTableSettings*`; Apply/Reset columns; Close; storage `pharmacy_catalog_drugs`
- Export / Print: omit without ∩ `evidence:export`; Print uses `commonPrintActionLabel` + preview-first (`printPharmacyWorkspaceList`)
- Trailing **Create** (`commonCreateActionLabel` / `pharmacyAddDrugAction`) when catalog write ∪ allows
- Bulk selection may replace Create (delete selected)

#### 3. Table

- Default columns (**5**): Selection / Code / Generic name / Brand name / Actions (always-visible keys as inventoried)
- Optional (`columnChoices`): Form / Strength / prices / Storage / Reorder / Stock status
- Row → drug details / edit

#### 5–9. Actions / dialogs / forms / print

| Dialog | Owner |
| --- | --- |
| Drug details | Pharmacy-owned `pharmacy_drug_details_dialog.dart` |
| Drug edit / add | Pharmacy-owned `pharmacy_drug_edit_dialog.dart` |
| Drug similarity | Pharmacy-owned |
| Pack scan | Pharmacy-owned `pharmacy_drug_pack_scan_dialog.dart` |
| Catalog dialog shell | `pharmacy_catalog_dialog.dart` |

- Pricing fields gated: pharmacy retail ∩ `pricing:pharmacy_write`; facility tariff ∩ `pricing:facility_write`
- Print: list Print gated as above; label helpers may appear from detail options

#### 11. RBAC

- Browse: catalog browse ∩; Add/Edit/Delete: catalog write ∪; pricing fields: pricing write ∩

### B. Formulary (`PharmacyCatalogTab.formulary`)

#### 2–5. Toolbar / table / actions

- Same Filters/Settings/Export/Print label + gate pattern; storage `pharmacy_catalog_formulary`
- Default columns (**5**): Selection / Drug name / Code / Active / Actions
- Optional: Form / Strength / Formulary id / Created / Updated
- Trailing Add formulary when write ∪
- Nested drug-picker tables keep `enableExport: false`

#### 11. RBAC

- Same catalog browse / write ∪ gates

### C. Inventory (`PharmacyCatalogTab.inventory`)

#### 2–5. Toolbar / table / actions

- Same Filters/Settings/Export/Print pattern; storage `pharmacy_catalog_inventory`
- Default columns (**5**): Selection / Item / Quantity / Stock status / Actions
- Optional: Reorder / Storage / Expiry / Batch / SKU / Unit / Facility / Room…
- Stock-alert desk sections land here with preset `PharmacyInventoryStockQuery`

#### 11. RBAC

- Browse ∩; mutations catalog write ∪

### D. Storage layout (`PharmacyCatalogTab.storageLayout`)

#### 2–5. Toolbar / table / actions

- Filters/Settings/Export/Print; storage `pharmacy_catalog_storage_rooms`
- Default columns (**5**): Name / Code / Shelves count / Status / Actions
- Optional: Created at
- Trailing Add storage room when write ∪

#### 11. RBAC

- Catalog write ∪ for create/update/delete rooms

### E. Shelves (`PharmacyCatalogTab.shelves`)

#### 2–5. Toolbar / table / actions

- Settings/Export/Print (no advanced Filters groups on this list); storage `pharmacy_catalog_shelves`
- Default columns (**5**): Shelf code / Label / Room / Status / Actions
- Trailing Add shelf when write ∪

#### 11. RBAC

- Catalog write ∪ for shelf CRUD

---

## Shared catalog sections (all sub-tabs)

### 6–8. Dialogs / nested / forms

- Edit dialogs host field groups for identity, packing, storage location, pricing
- Similarity dialogs: proceed / use existing / cancel
- Nested storage pickers from drug edit (`initialTab: PharmacyCatalogTab.storageLayout`)

### 9. Print / labels / preview

- Printable catalog tables: Export + Print gated by `canExportPharmacyWorkspace` / `canPrintPharmacyWorkspace`
- Nested formulary/selection / shelf-picker tables keep `enableExport: false`
- Trigger label `commonPrintActionLabel` (`Print`); preview-first helpers

### 10. Loading / empty / error / success

- Per-sub-tab loading/empty panels inside `PharmacyCatalogPanel`
- Mutation snackbars / dialog validation under write ∪

### Desk-level RBAC summary

| Atom | Gate |
| --- | --- |
| Catalog desk tab | ∩ `pharmacy:read` (`PharmacyCatalogAtomPermissions`) |
| Nested sub-tabs browse | catalog browse ∩ |
| Export / Print (printable tables) | ∩ `evidence:export` |
| Add / Edit / Delete / bulk | catalog write ∪ `pharmacy:write` \| `operations:write` |
| Pharmacy price fields | ∩ `pricing:pharmacy_write` |
| Facility price fields | ∩ `pricing:facility_write` (+ billing-payments on requirement) |
| Operations-only route entry | cannot see catalog (fallback strips catalog) |
