# Pharmacy Suppliers: Catalog CRUD and Product Attachment

Add pharmacy-facing supplier management (name, location, email, phone) and optional supplier attachment when saving catalog products, so pharmacy knows which supplier a product was bought from—without replacing existing dispense, inventory, or procurement flows.

## Context

**Current behavior (codebase; no screenshots attached)**

- Backend already ships full supplier CRUD at `/api/v1/suppliers` (`supplier` module: list/get/create/update/soft-delete, tenant scope, audit). Model fields: `name`, `contact_email`, `phone`. No location column on `supplier`; location is modeled via related `address` (`address.supplier_id`). Extra contacts via `contact.supplier_id`. Module entitlement for the route is `inventory-procurement-lite`.
- `purchase_order.supplier_id` already links suppliers to procurement orders. `drug` / `inventory_item` have **no** `supplier_id`. Drug create/update accepts pricing (including `buy_unit_price` / pharmacy buy / COGS) but not a supplier.
- Frontend registers `HmsApiEndpoint.suppliers` only. There is no pharmacy supplier repository, entity, list, or form. Pharmacy Catalog nested tabs are Drugs | Formulary | Inventory | Storage layout | Shelves (`PharmacyCatalogTab`); Catalog CRUD is gated ∪ `pharmacy:write` | `operations:write` under `pharmacy-dispensing`.

**Intended behavior**

- Pharmacists manage suppliers inside Pharmacy Catalog (same workspace family as drugs/inventory/storage): create, read, update, soft-delete; fields **name**, **location**, **email**, **phone**.
- When creating or editing a pharmacy **product** (catalog drug save flow), optionally attach a supplier so the saved product records who it was bought from. Attachment is optional; existing products without a supplier remain valid.
- Reuse the existing suppliers API and catalog UX patterns (dialogs, list/search, soft-refresh). Do not build a separate procurement workspace or purchase-order UI in this scope.

**Definitions**

- *Supplier:* Tenant-scoped vendor of pharmacy medicines/products (`supplier` entity).
- *Location:* Supplier physical/business location shown and edited in the supplier form; persist via the existing `address` ↔ `supplier` relation (primary address), not a parallel location microservice.
- *Product:* Pharmacy catalog drug created/updated through the existing drug edit/create dialog (`PharmacyDrugEditDialog` / catalog Drugs tab).
- *Attach supplier:* Optional preferred `supplier_id` on the product (drug) persisted on save and shown on edit/detail when present.

## Requirements

1. Expose a **Suppliers** nested Catalog tab (or equivalent Catalog subsection) in Pharmacy, listing tenant suppliers with search/pagination consistent with other catalog tabs. Unauthorized users must not see the tab or write actions.
2. Implement create / view / edit / soft-delete supplier dialogs or panels with required **name** and optional **location**, **email**, **phone**. Validate email/phone formats; show loading, empty, error, success, and field validation feedback. Soft-refresh the list after mutations.
3. Persist suppliers through existing `GET/POST/PUT/DELETE /api/v1/suppliers`. Persist location via existing address APIs/relations keyed by `supplier_id` (create/update primary address with the supplier). Keep `contact_email` / `phone` on the supplier record as today; do not invent a second suppliers backend.
4. If pharmacy-dispensing tenants cannot call `/suppliers` because only `inventory-procurement-lite` is entitled, extend module entitlement (or plan coverage) so catalog-entitled pharmacy users can use suppliers **without** a duplicate suppliers route family. Keep backend RBAC/ABAC authoritative.
5. Add optional product→supplier attachment: extend `drug` (schema + create/update validation + service) with nullable `supplier_id`; surface a supplier picker on drug create/edit; persist and reload the selection. Clearing the picker clears the attachment. Do not require a supplier to save a drug.
6. Show the attached supplier name on drug detail (and list columns only if it fits existing density without clutter). Buy/COGS price behavior stays unchanged.
7. Gate browse with catalog browse (∩ `pharmacy:read` + pharmacy module) and mutations with catalog write (∪ `pharmacy:write` | `operations:write`). Unauthorized controls absent (not merely disabled). Theme tokens; light/dark; responsive; no clipping of primary actions.
8. Tests: supplier tab absent without permission; CRUD happy path + validation; location round-trips via address relation; drug save with/without `supplier_id`; list refresh after mutation; unauthorized write UI absent; existing catalog tabs and dispense flows unchanged.

## Constraints

- Do not replace purchase-order / goods-receipt procurement; do not require PO creation to attach a supplier to a product.
- Do not remove or rewrite Drugs / Formulary / Inventory / Storage / Shelves behavior except to add the supplier picker and Suppliers tab.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`. Soft deletes only.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Catalog shows Suppliers for entitled users; absent when unauthorized. | R1, R7 |
| A2 | Create/edit/delete supplier with name + optional location/email/phone; list updates after save/delete. | R2, R3 |
| A3 | Location stored/retrieved via supplier-linked address; email/phone on supplier. | R3 |
| A4 | Pharmacy-entitled clients can call suppliers without a parallel API. | R4 |
| A5 | Drug create/edit can set/clear optional supplier; value persists on reload; save works with none. | R5, R6 |
| A6 | Unauthorized supplier/product-supplier actions absent; light/dark + narrow usable; other catalog/dispense unchanged. | R7, R8 |

## Relevant Files

- `backend/src/modules/supplier/**`, `backend/prisma/schema.prisma` (`supplier`, `address`, `drug`)
- `backend/src/modules/drug/schemas/drug.schema.js`, `backend/src/modules/drug/services/drug.service.js`
- `backend/src/middlewares/module-entitlement.middleware.js` (`suppliers` → `inventory-procurement-lite`)
- `frontend/lib/core/network/api_endpoints.dart` (`suppliers`)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`, `pharmacy_catalog_tabs.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart`, `pharmacy_drug_details_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`, `domain/entities/pharmacy_entities.dart`
- `frontend/lib/l10n/app_en.arb`

## Verification

- Backend: supplier CRUD + drug `supplier_id` schema/service tests; entitlement allows pharmacy catalog path.
- Widget/integration: Suppliers tab visibility; form validation; drug picker attach/clear; soft-refresh; write-gated actions absent without write.
- Manual: create supplier with location → appear in list → select on new drug → reopen drug shows supplier; delete/soft-delete supplier behavior consistent with FK rules; light/dark + narrow width; dispense queues untouched.
