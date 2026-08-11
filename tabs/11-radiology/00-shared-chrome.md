# Radiology — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.radiology` under app `ShellRoute`
- Workspace route gate: `radiologyWorkspaceRouteEntryRequirement` — ∪ `radiology:read` | `radiology:write` | `clinical:read` | `clinical:write` | `billing:read` + module `radiology-workflows`
- Catalog entry: `RouteAccessCatalog.radiologyEntry` / `radiologyWorkspaceCatalogEntryRequirement` (∩ `radiology:read`)
- Tab chrome read: ∩ `radiology:read` + `radiology-workflows` (Follow-ups same read ∩)
- Route-only clinical/billing readers without `radiology:read`: fallback keeps worklist/reporting/allOrders chrome; Follow-ups omitted
- If no desk tabs allowed: empty `AppWorkspaceStatePanel` (`radiologyNoOrdersTitle` / `radiologyNoOrdersBody`) — no disabled tab placeholders

## Page chrome

- `AsyncStateScaffold<RadiologyWorkspaceState>` over `radiologyWorkspaceControllerProvider`
  - Loading: `radiologyLoadingTitle` / `radiologyLoadingBody`
  - Retry → controller `refresh()`
  - `keepPreviousDataDuringRefresh: true`
- Body: `ResponsivePage` + `AppTabStrip` + order board `AppListTable<RadiologyOrder>` (or **reused** `FollowUpWorklistPanel`)
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>`
- Deep-link: section (+ order/patient deep-open handled in page content)

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard variant)
- Tabs omitted when unauthorized (`radiologySectionTabRequirement` / `radiologyAllowedSections`) — not disabled
- Counts:
  - Active non–follow-ups tab: `state.orders.totalItemCount` (table footer mirror)
  - Sibling worklist / reporting / all: `workloadCount` / `reportingCount` / `historyCount`
  - Follow-ups: `followUpTabCountProvider(FollowUpWorklistScope())`
- Count tones (`AppTabCountTone`): `warning` for Worklist + Reporting; `info` for All orders + Follow-ups
- Icons: pending_actions / edit_note / assignment / phone_callback

## Table toolbar (order-board pattern)

Order on search bar: **Filters → Settings → (no Export/Print on table) → Request imaging**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `radiologySearchLabel` / `radiologySearchHint` | mic via `AppSearchBar` default |
| Clear / reset filters | `radiologyClearFiltersAction` | advanced filter reset |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction` |
| Settings | `commonTableSettings*` | Apply `radiologyApplyColumnsAction`, Reset `radiologyResetColumnsAction` |
| Export | **absent** on desk `AppListTable` | not mounted (`enableExport` unused) |
| Print (table) | **absent** on desk table | print lives on detail / reported shortcut |
| Request imaging | `radiologyRequestImagingAction` | omitted without strip create ∩ `radiology:write`; **not mounted** on Follow-ups |

Column visibility storage: `radiology_${section.name}_${view.name}` / widths `radiology_cw_…`.  
Default view query: `RadiologyWorkbenchView.patients` (orders view columns exist; **no strip toggle currently mounted** — see convention gaps).

## Shared strip / dialogs

### Request imaging — **reused** clinical shell

- Entry: `_showCreateOrderDialog` → **reused** `ClinicalRadiologyOrderActionDialog` / clinical request flow dialogs
- Gate: `radiologyStripCreateRequirement(section)` = ∩ `radiology:write`
- Nested request-from-clinical ∪ documented as `radiologyRequestFromClinicalWriteRequirement` (not strip)

### Configurations — Radiology-owned (not strip)

- `_showRadiologyConfigurationsDialog` / `_RadiologyConfigurationsDialog` still in code
- Strip chrome **no longer mounts** Configurations (comment in page); enable/edit/delete facility offerings + **reused** `LabDeleteReasonDialog` / radiology catalog dialogs when opened from remaining call sites
- Gate: ∩ `radiology:write` (`radiologyConfigurationsWriteRequirement`)

### Order detail hub — Radiology-owned

- `_openRadiologyDetailDialog` → `AppDialog` (`radiologyDetailTitle`) + `_RadiologyOrderDetail`
- Shortcuts: reported → print dialog; waiting-for-report + write → report composer
- Procedure workbench: Mark done / Report / Print / Undo / Cancel (Assign + Start imaging **intentionally omitted**)
- Billing gate column/filter/payment: ∩ `billing:read` (`radiologyBillingHoldReadRequirement`)

### Print report — Radiology-owned

- `_showRadiologyPrintDialog` / `_RadiologyPrintDialog` → `PrintDocumentTemplates.clinicalResult`
- Gate: ∩ `radiology:read` (`radiologyPrintReportRequirement`)

### Follow-ups — **reused**

- `FollowUpWorklistPanel` with `storageKeyPrefix: 'radiology_follow_ups'`
- Read/write: `RadiologyFollowUpsAtomPermissions`

## Feedback patterns (cross-tab)

- Mutation failures: snackbars via `_showMutationResult` / `showAppFailureSnackBar`; page-level failure banner cleared (dialogs own errors)
- Empty: `radiologyNoOrdersTitle` / `radiologyNoOrdersBody` (patients-view variants when `view == patients`)
- Detail loading: `radiologyDetailLoadingTitle` / `radiologyDetailLoadingBody`
- Success paths write-gated per atom maps
