# Facility Lab Catalog Configuration — Implementation Prompt

## Objective

Refine **lab configuration** so each facility defines its own offered tests and panels (with prices), while the **platform catalog** remains the master source clinicians pick from during setup. Clinicians ordering labs must only see facility-offered items, with prices pre-filled and editable at order time.

**Related context:** [prompts/16-lab-module-prompt.md](./prompts/16-lab-module-prompt.md), [flows/lab-flow.mdc](./.cursor/flows/lab-flow.mdc)

---

## Catalog Model (two layers)

| Layer | Purpose | Who uses it |
| ----- | ------- | ----------- |
| **Platform catalog** | Master list of all lab tests and panels the system supports | Lab admins when configuring a facility — select from this list |
| **Facility offerings** | Tests/panels the facility actually performs, plus facility-specific price and overrides | Clinicians when requesting labs; lab staff for QC and workbench |

**Rule:** Clinical lab requests must query **facility offerings only** (`offered_only=true`), not the full platform catalog.

---

## Scope

### 1. Lab configuration UI (Lab workspace → Configurations dialog)

- Fix the configuration dialog so it loads reliably — no missing data, runtime errors, or broken nested dialogs.
- Open configuration modals **maximized by default** (full usable height/width per design-system dialog patterns).
- Keep forms fast and minimal: only fields needed to enable/configure an offering.
- When enabling a test or panel for the facility:
  - Select from the **platform catalog** (searchable).
  - Require a **unit price** on the facility offering.
  - Allow facility overrides (specimen, result kind, reference ranges, etc.) where supported.
- Configuration list should clearly distinguish platform defaults vs facility-customized offerings.

### 2. Facility offering price

- Every facility-offered test and panel must have a **unit price** stored on the offering.
- Price is the default billing amount — clinicians should not re-enter it on every order.

### 3. Clinical lab request dialog

- The lab request modal (`ClinicalLabOrderActionDialog`) must list **only tests and panels offered by the current facility**.
- When items are selected, **pre-fill billing line items** with the facility offering price.
- Price remains **editable during the order** (e.g. discounts, corrections) via the billing review step.
- Do not expose platform-only or inactive offerings to clinicians.

---

## Current State (read before changing code)

| Area | Location | Notes |
| ---- | -------- | ----- |
| Configuration dialog | `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` (`_LabConfigurationsDialog`) | Known loading/rendering issues |
| Test/panel edit dialogs | `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart` | Platform pick + facility offering toggle, price field |
| Clinical order dialog | `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart` | Billing pre-fill via `ClinicalRequestBillingLineItem` |
| Facility catalog API | `backend/src/modules/facility-lab-catalog/` | `offered_only`, `unit_price` on upsert schemas |
| Frontend repository | `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart` | `listFacilityLabTests`, `searchFacilityLabCatalog` |
| Entity | `frontend/lib/features/lab/domain/entities/lab_entities.dart` (`LabCatalogItem`) | `isOfferedAtFacility`, `unitPrice`, `usesPlatformDefaults` |

---

## Acceptance Criteria

- [ ] Lab configuration dialog opens without errors; all catalog data and actions load correctly.
- [ ] Configuration modals open maximized by default.
- [ ] Facility admins can enable platform tests/panels and set required unit prices.
- [ ] Clinical lab request picker shows **facility offerings only**.
- [ ] Selected tests/panels pre-fill billing with facility prices; price is editable before submit.
- [ ] Platform catalog remains available for configuration, not for clinical ordering.
- [ ] Permissions, tenant/facility scope, and i18n preserved; no regressions in analyze/test.

---

## Quality Gate

From `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API:

```sh
npm test -- --testPathPattern="facility-lab-catalog|lab-workspace"
```
