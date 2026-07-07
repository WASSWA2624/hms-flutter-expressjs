# Pharmacy Prescription Detail Dialog — UI Refinement

## Objective

Refine the **Prescription Detail** dialog in the Pharmacy workbench so patient context, order metadata, actions, and medication lines are compact, scannable, and workflow-ready. Fix layout issues visible in the current dialog (patient header, metadata grid, action bar, medicines table).

**Primary file:** `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (`_PharmacyDetailPanel`, `_PharmacyActionPanel`, `_MedicationItemsPanel`).

**Reuse before creating:** `AppWorkspacePatientContextHeader`, `AppActionPanel`, `AppListTable`, `AppWorkspaceDetailPanel` from `frontend/lib/shared/`.

---

## Scope

### In scope

- Prescription Detail dialog layout and styling only.
- Per-line medication pricing display and price-source selection UI.
- Per-line medication actions (replace Stock column).
- Wire existing order-level actions so enabled/disabled states and handlers work correctly.

### Out of scope

- Pharmacy workflow readiness panel.
- Dispense history / timeline panel.
- Backend schema changes unless required to expose line-level prices or price-source overrides already supported by the API.

---

## 1. Patient & order context header

Replace the current avatar + tile grid with a **compact label:value layout**.

| Change | Requirement |
| ------ | ----------- |
| Avatar | **Remove** patient avatar from this dialog. |
| Patient identity | Show inline pairs on one flowing row (wrap to next row when width is exhausted): **Patient name:** `{name}`, **Patient ID:** `{id}` (copyable when available). |
| Status & alerts | Render order status and alerts as the same label:value pattern — e.g. **Status:** Dispensed, **Payment clearance:** Unavailable — not standalone chips floating beside the name. |
| Order metadata | Convert all metadata (Order, Encounter, Source, Care location, Priority, Ordered, Payment status/amount when present) to **label:value** pairs using the same inline, left-to-right, wrap-on-overflow layout. |
| Copy actions | Keep copy-to-clipboard on Order ID and Encounter ID. |

**Implementation hint:** Use `AppWorkspacePatientContextHeader` with `showAvatar: false`, `fieldStyle: AppWorkspacePatientContextFieldStyle.inline`, and `mergeFieldsIntoMetaLine: true` where appropriate. Move status/alerts into `AppWorkspacePatientContextField` entries with tone when needed.

---

## 2. Actions panel

| Change | Requirement |
| ------ | ----------- |
| Density | Reduce vertical footprint; avoid oversized action chrome. |
| Header | Show a compact **Actions** title with a leading icon (match other workspace panels). |
| Buttons | Keep existing actions: Record payment (when gated), Dispense, Attest, Return, Cancel order, Print instructions. |
| Functionality | Ensure each action respects `workflow.nextActions` / `order.can*` flags, RBAC (`AppAccessActionGate`), and payment-block tooltips. Disabled actions must explain why (tooltip or inline hint). |

---

## 3. Medicines table

### Layout & alignment

- Fix row/cell vertical alignment so `#`, Medication, Dose, Quantity, and action columns line up on one baseline.
- Long medication names and instructions may wrap; dose and quantity cells stay top-aligned with the medication name.

### Columns

| Column | Requirement |
| ------ | ----------- |
| `#` | Row index (existing `AppListTable` index). |
| Medication | Drug name + instructions (current `_MedicationCell`). |
| Dose | Dose, route, frequency, duration (current `doseLine`). |
| Quantity | Prescribed / dispensed / pending / returned (current `quantityLine`). |
| **Price** | **New.** Unit price and line total for the row. |
| **Actions** | **Replace Stock column.** Per-line icon+label actions driven by item state. |

### Remove Stock column

The Stock column duplicates the medication name and adds no workflow value in this view. Stock mapping readiness remains in **Pharmacy workflow readiness** below the table.

### Per-line actions

Show contextual actions when a line is blocked, rejected, cancelled, or needs pharmacist intervention — e.g. resolve stock mapping, override price source, retry dispense. Use compact icon+label buttons (not icon-only). Hide actions that do not apply to the current line status.

### Pricing rules

| Rule | Behavior |
| ---- | -------- |
| Default | Use **pharmacy unit price** for display and billing. |
| Order source | When the order originates from a clinical/facility context, default to **facility unit price** if configured. |
| Override | Pharmacist may switch the active price source (pharmacy vs facility) per line; persist via existing pharmacy billing/price APIs where available. |
| Display | Show unit price, optional source badge, and line total (`unit × quantity prescribed`). Format with existing `clinicalRequestPriceLabel` / catalog price helpers. |

---

## 4. Unchanged sections

Leave as-is unless a shared spacing tweak is needed for visual consistency:

- Pharmacy workflow readiness
- Dispense history / timeline

---

## Standards

| Area | Requirement |
| ---- | ----------- |
| UI/UX | Follow `frontend/.cursor/design-system.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`. Responsive on mobile, tablet, and desktop. |
| i18n | All new labels and tooltips in `frontend/lib/l10n/app_en.arb`. |
| Theming | Light/dark/system; use theme tokens, not hardcoded colors. |
| Tests | Update/add widget tests for header layout, table columns, and price-source action visibility. |

---

## Acceptance criteria

- [ ] No patient avatar in Prescription Detail dialog.
- [ ] Patient name, patient ID, status, payment clearance, and all order metadata render as inline **label:value** pairs that wrap left-to-right across rows.
- [ ] Actions panel is compact, titled with icon, and all buttons honor workflow/RBAC/payment gates.
- [ ] Medicines table rows are visually aligned; Stock column removed.
- [ ] Price column shows unit and line total; pharmacist can choose pharmacy vs facility price per line when both exist.
- [ ] Per-line Actions column shows relevant icon+label controls for blocked/rejected/cancelled lines.
- [ ] Workflow readiness and dispense history sections unchanged in behavior.
- [ ] `flutter analyze` and affected tests pass.
