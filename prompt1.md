# Feature: Refine Radiology workspace worklist (patients & orders views)

## Goal

Improve the **main Radiology workspace** so the worklist is scannable, radiology-focused, and consistent with the Lab workbench pattern. Each table column must represent **one parameter**; secondary identifiers and metadata move to optional columns or the order/patient detail dialog.

## Current state (keep)

The following already work well—do not regress:

- **Page title:** `Radiology` in the app bar.
- **Toolbar summary chips** (green/warning/info tones): e.g. *Radiology patients*, *Patients waiting imaging*, *Reporting*, *Released*—clickable to apply stage filters.
- **Worklist section header:** *Radiology patients* with description *Patients grouped by active imaging orders, reporting status, and next action.*
- **Primary action:** `+ Request imaging`.
- **Search bar**, **Radiology filters**, and **Table settings** affordances.
- **Patients ↔ Orders** view toggle and **Configurations** entry (separate feature).

## Problem

The worklist table packs multiple values into single cells (see screenshot):

| Column | Current content | Issue |
|--------|-----------------|-------|
| **Patient** | Name + patient ID + order ID | Three parameters in one column |
| **Study** | Procedure name + modality / body region / laterality | Radiology anatomy split across subtitle |
| **Next action** | Hidden behind Table settings | Core workflow signal not visible by default |

Radiology staff need a fast queue view: **who**, **what study**, **how urgent**, **what to do next**—not administrative IDs.

## Reference implementation

Mirror the Lab workbench column model in `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`:

- **One column = one field** (`_patientNameWorklistColumn`, `_patientIdWorklistColumn`, `_orderWorklistColumn`, etc.).
- **Default columns** show actionable worklist data; identifiers and context fields are **optional** via Table settings.
- **Single-line text cells** for scalar values; status uses `AppWorkspaceStatusBadge`.
- **Detail dialog** holds full order/patient context (encounter, billing, PACS, results, studies).

**Primary references:**

- Radiology: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`, `radiology_workspace_page.detail_cells.dart`
- Entities: `frontend/lib/features/radiology/domain/entities/radiology_entities.dart` (`RadiologyOrder`, `RadiologyWorkspaceQuery`)
- Shared UI: `frontend/lib/shared/components/app_list_table.dart`, `app_search_bar.dart`, `frontend/lib/shared/layout/app_workspace.dart`, `app_workspace_summary_notification.dart`

## Table columns

### Patients view — default (visible without Table settings)

| Column | Source field | Notes |
|--------|--------------|-------|
| **Patient** | `patientDisplayName` | Name only—no subtitle IDs |
| **Study** | `testDisplayName` / `testsSummary` | Procedure name only |
| **Priority** | `priority` | Use `_radiologyPriorityDisplayLabel`; badge or plain text |
| **Next action** | derived via `_nextActionLabel` | **Promote to default column** |
| **Status** | `status` | `AppWorkspaceStatusBadge` via `_orderStatus` |

### Orders view — default

| Column | Source field |
|--------|--------------|
| **Order** | `effectiveDisplayId` (or active-order count for patient groups) |
| **Patient** | `patientDisplayName` |
| **Study** | `testDisplayName` / `testsSummary` |
| **Priority** | `priority` |
| **Next action** | `_nextActionLabel` |
| **Status** | `status` badge |

### Optional columns (Table settings only)

Expose as separate togglable columns—never as subtitles in default cells:

- Patient ID (`patientId`)
- Order ID / Order(s) (`effectiveDisplayId`, `orderDisplayIds`)
- Modality (`modality`)
- Body region (`bodyRegion`)
- Laterality (`laterality`)
- Encounter (`encounterId`)
- Payment / authorization (`paymentStatus`, `authorizationStatus` → `_billingGateLabel`)
- Ordered at (`orderedAt`)

Refactor `_radiologyPatientColumn` and the Study column to remove `_TwoLineCell` stacking for default columns. Reuse Lab’s `_labWorklistTextCell` pattern or extract a shared single-line worklist cell helper under `frontend/lib/shared/` if duplication would otherwise grow.

## Detail dialog

Row click opens the existing radiology detail dialog. Ensure it surfaces everything removed from the table:

- Patient ID, encounter, order ID(s)
- Modality, body region, laterality, clinical note
- Billing / authorization gate
- Studies, results, PACS links, workflow actions

Do not duplicate table defaults in the dialog header; keep the dialog as the deep-dive surface.

## Filters

Expand **Radiology filters** to cover all radiology-relevant query dimensions. Minimum set:

| Filter | Query param | Notes |
|--------|-------------|-------|
| Stage | `stage` | Already wired to summary chips |
| Order status | `status` | ORDERED, IN_PROCESS, COMPLETED, CANCELLED |
| Modality | `modality` | Existing enum |
| Order date | `from` / `to` | Existing date filter |
| Priority | `priority` | STAT, URGENT, ROUTINE, etc.—add to schema/controller if missing |
| Payment / billing gate | new or mapped | Filter orders awaiting billing confirmation |

Wire new filters through `RadiologyWorkspaceQuery`, `radiology_workspace_controller.dart`, and backend `getRadiologyWorkbenchQuerySchema` / repository queries. Search placeholder already mentions patient, order, encounter, study, report, PACS—ensure server-side search matches.

## Mobile list tile

Update `_RadiologyOrderListTile` to reflect the same information hierarchy: name, study, priority, next action, status badge—no ID stacking in the subtitle.

## Implementation rules

- **Reuse shared components** from `frontend/lib/shared/` (`AppListTable`, `AppSearchBar`, `AppWorkspaceDetailPanel`, `AppWorkspaceStatusBadge`, layout/toolbar primitives). Extract shared worklist column builders only when Lab and Radiology would duplicate identical patterns.
- **No new visual language**—match Lab spacing, typography, and Table settings behavior.
- **Localization:** add/adjust keys in `frontend/lib/l10n/app_en.arb` for any new column or filter labels.
- **Backend parity:** any new filter must be enforced server-side; do not client-filter paginated results.
- **Scope:** this task is the worklist UX only; facility catalog configuration is out of scope.

## Acceptance criteria

- [ ] Default patients-view columns: Patient (name only), Study (name only), Priority, Next action, Status—no multi-value cells.
- [ ] Default orders-view columns follow the orders table above.
- [ ] Patient ID, order ID, modality, body region, laterality, encounter, billing, and ordered-at are optional columns only.
- [ ] Next action is visible by default without opening Table settings.
- [ ] Row click detail dialog shows full radiology context removed from the table.
- [ ] Filters cover stage, status, modality, order date, and priority (plus billing gate if applicable).
- [ ] Mobile list tile matches desktop information hierarchy.
- [ ] Lab worklist patterns and `frontend/lib/shared/` components are reused—not forked markup.
- [ ] New filters work with pagination via backend query params.
