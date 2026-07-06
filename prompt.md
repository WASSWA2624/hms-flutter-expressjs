# Feature: Complete Pharmacy module (catalog, pricing, order queue UX)

## Goal

Finish the **Pharmacy workspace** so pharmacists can manage the full product catalog (drugs, vials, and other pharmacy items), track stock with multiple units of measure, apply correct **dual pricing** (pharmacy vs facility), and work orders from a scannable, Lab/Radiology-style queue—without a cluttered toolbar.

## Current state (screenshot + code)

The workspace at `/pharmacy` already has:

- **App bar:** `Pharmacy` title, primary **Dispense** action, and a busy overflow menu (Catalog and stock, Ready, Refresh, maintenance/fault globals, Notifications).
- **Order queue panel** with subtitle *Order queue* and description *System pharmacy orders with dispense and return actions.*
- **Search** (patient, order, encounter, medication, batch), a single **Queue filter** dropdown, and **Table settings**.
- **Default table columns:** Patient (name + stacked IDs/date), Order, Items, Dispense, Payment, Status.
- **Catalog dialog** with Drugs / Formulary / Inventory tabs (`pharmacy_catalog_panel.dart`).
- **Backend workbench** query supports `status`, `location`, `pending_payment`, `from`/`to`, `patient_id`, `encounter_id`, `search` (`pharmacy-workspace.schema.js`).
- **Drug model** has `unit_price` + `currency`; inventory items have `unit`; no separate facility offering table yet (unlike Lab/Radiology catalog offerings).

## Problems

1. **Catalog is incomplete for real pharmacy operations** — items cannot be fully defined with quantities, unit options, and dual prices; stock visibility is basic.
2. **Pricing model is wrong for hospital-embedded pharmacies** — one `unit_price` on `drug` does not distinguish pharmacy retail price from facility billing price.
3. **Order queue subtitle is noise** — the panel description under *Order queue* should be removed; the table should speak for itself.
4. **Filters are too narrow** — one queue-status dropdown; date range disabled; `partialStock` and `urgent` filters exist but are disabled.
5. **Table packs too much into cells** — Patient column stacks patient ID, encounter ID, and date; identifiers belong in optional columns or the detail dialog.
6. **Toolbar is overcrowded** — secondary actions duplicate overflow entries and crowd the header on smaller widths.

## Catalog, stock, and dual pricing

### Product management

Pharmacists (and users with `pharmacyWrite` or higher) must be able to **create and maintain pharmacy products**:

- Drugs and other pharmacy items (vials, consumables, etc.) with name, code, form, strength, SKU where applicable.
- **Quantity tracking** with visible on-hand stock, low/out-of-stock signals (reuse existing inventory stock workbench).
- **Multiple units of measure** — prescribe/dispense/stock in different units (e.g. tablets vs packs); surface `quantity_unit`, `dose_unit`, `duration_unit` consistently in catalog and dispense flows.

Extend the existing **Drugs / Formulary / Inventory** catalog panel rather than building a parallel UI.

### Dual price model

Each pharmacy product supports **two prices**:

| Price | Purpose | Default use |
|-------|---------|-------------|
| **Pharmacy price** | Retail / walk-in sales at the pharmacy counter | Direct pharmacy visits |
| **Facility price** | Hospital billing rate | Orders originating from clinical departments |

**Pricing rules at dispense/billing:**

- **Clinical-department orders** (OPD, IPD, theater, etc. — orders with an encounter / `orderSource` from clinical workflow): always use **facility price** for patient billing.
- **Walk-in / direct pharmacy orders** (no clinical encounter or explicit walk-in source): pharmacist **chooses** pharmacy price or facility price; the chosen price is **editable manually** before dispense/billing confirmation.

### Backend approach

Mirror the **facility catalog offering** pattern used by Lab and Radiology:

- `drug.unit_price` → treat as **pharmacy (retail) price**.
- Add **`facility_pharmacy_offering`** (or equivalent) keyed by `facility_id` + `drug_id` with `unit_price`, `currency`, `is_active` — same shape as `facility_radiology_test_offering` / `facility_lab_test_offering`.
- Expose CRUD + list endpoints; wire through `pharmacy-workspace` serializer and Flutter DTOs/entities.
- Persist the **selected price tier and overridden amount** on dispense / `billing_snapshot` when applicable.

**Primary references:**

- Backend: `backend/src/modules/facility-radiology-catalog/`, `backend/src/modules/facility-lab-catalog/`
- Frontend catalog: `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`
- Entities: `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`
- Billing: `frontend/lib/features/pharmacy/presentation/pharmacy_billing_helpers.dart`

## Order queue UX

### Remove panel subtitle

Drop `pharmacyQueuePanelDescription` from the queue `AppWorkspaceDetailPanel` — render the table directly under the workspace app bar (no *System pharmacy orders with dispense and return actions.* line). Keep the empty state copy.

### Toolbar / overflow

Reduce visible toolbar clutter:

- Keep **Dispense** as the sole primary action.
- Move **Catalog and stock**, **Ready** (and other queue shortcuts already on summary chips) into **`overflowSections`** via `appWorkspaceToolbarWithLabels` — follow `maxVisibleScreenActions` and `AppToolbarOverflowSection` patterns in `app_workspace_toolbar.dart`.
- Do not duplicate the same action in both `secondary` and overflow.
- Preserve global actions (Refresh, maintenance, fault report, Notifications) in overflow only when width-constrained.

### Filters

Expand **Queue filter** to a multi-group advanced filter panel matching Radiology (`radiology_workspace_page.dart`):

| Filter | Query param | Notes |
|--------|-------------|-------|
| Queue status | `status` | ORDERED, PARTIALLY_DISPENSED, DISPENSED, CANCELLED |
| Location | `location` | OUTPATIENT, INPATIENT, DISCHARGE |
| Pending payment | `pending_payment` | Billing gate |
| Order date | `from` / `to` | Enable date filter (currently `enableDateFilter: false`) |
| Priority | new if needed | STAT, URGENT, ROUTINE — wire if `PharmacyOrder.priority` is populated |
| Partial stock | new | Enable `PharmacyOrderFilter.partialStock` server-side |
| Urgent | new | Enable `PharmacyOrderFilter.urgent` server-side |

Wire all filters through `PharmacyWorkbenchQuery`, `pharmacy_workspace_controller.dart`, and `getPharmacyWorkbenchQuerySchema` / repository queries. **Do not client-filter paginated results.**

### Table columns

Follow the **one column = one field** Lab/Radiology worklist model (`lab_workspace_page.dart`, `radiology_workspace_page.dart`):

#### Default columns (visible without Table settings)

| Column | Source field | Notes |
|--------|--------------|-------|
| **Patient** | `patientDisplayName` | Name only — no stacked IDs |
| **Order** | `displayId` | `AppCopyableIdentifier` |
| **Location** | `location` / `encounterType` | OUTPATIENT / INPATIENT / DISCHARGE label |
| **Items** | `itemCount` | Numeric |
| **Dispense** | `quantityDispensedTotal` / `quantityPrescribedTotal` | Progress label (existing helper) |
| **Payment** | `effectivePaymentStatus` | Billing gate label |
| **Status** | `status` | `AppWorkspaceStatusBadge` |

#### Optional columns (Table settings only)

- Patient ID (`patientId`)
- Encounter (`encounterId`)
- Ordered at (`orderedAt`)
- Priority (`priority`)
- Prescriber (`prescriberDisplayName`)
- Order source (`orderSource`)
- Pending attestation (`hasPendingAttestation` / batch ref)
- Remaining qty (`quantityRemainingTotal`)

Refactor `_PharmacyOrderPatientCell` to a single-line name cell for the default Patient column. Add `columnChoices` to `AppListTable` (currently missing).

### Detail dialog

Row click opens the existing prescription detail dialog. It must surface everything removed from default table cells: IDs, encounter, prescriber, source, full item list with stock mapping, **price tier selection** for walk-in orders, billing gate, and dispense/return history.

### Mobile

Update the mobile list tile to match desktop hierarchy: patient name, location, dispense progress, payment gate, status badge — no ID stacking in subtitles.

## Implementation rules

- **Reuse shared components** from `frontend/lib/shared/` (`AppListTable`, `AppSearchBar`, `AppWorkspaceDetailPanel`, `AppWorkspaceStatusBadge`, `app_workspace_toolbar.dart`). Extract a shared single-line worklist text cell only if Lab/Radiology/Pharmacy would otherwise duplicate identical patterns.
- **No new visual language** — match Lab/Radiology spacing, typography, Table settings, and filter sheet behavior.
- **Localization:** add/adjust keys in `frontend/lib/l10n/app_en.arb` for new columns, filters, and pricing labels.
- **Backend parity:** new filters and pricing fields must be enforced server-side.
- **Responsive:** verify queue, catalog dialog, and dispense flows on narrow/mobile widths.
- **Permissions:** catalog write actions remain gated by `pharmacyWrite` / `operationsWrite`.

## Acceptance criteria

- [ ] Pharmacists can add/edit pharmacy products with stock quantities and unit-of-measure fields visible in catalog and inventory tabs.
- [ ] Each product has **pharmacy price** and **facility price**; facility offerings follow the Lab/Radiology catalog pattern.
- [ ] Clinical-department orders bill at facility price; walk-in orders let the pharmacist pick price tier and override amount manually.
- [ ] Order queue panel has **no** subtitle/description under the table.
- [ ] Toolbar shows only **Dispense** prominently; Catalog/Ready and other shortcuts live in overflow or summary chips without duplication.
- [ ] Filters cover status, location, pending payment, order date, priority, partial stock, and urgent — all backend-backed with pagination.
- [ ] Default columns are single-field cells; IDs, encounter, prescriber, source, and dates are optional via Table settings.
- [ ] Detail dialog shows full context and walk-in price selection.
- [ ] Mobile list tile matches desktop information hierarchy.
- [ ] Shared workspace components and Lab/Radiology patterns are reused — not forked markup.
