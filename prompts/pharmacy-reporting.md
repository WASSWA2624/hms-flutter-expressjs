# Pharmacy Reports Overview: In-Place Dialogs

Keep the pharmacist `/reports` Overview on Analytics | Reporting tabs, but remove tab instructional copy and open analytics/reporting actions in dialogs so the workspace stays on Overview instead of navigating to Catalog or Delivery panels.

## Context

**Current behavior (screenshots + code)**

- Pharmacist Overview shows subtitle *“Pharmacy analytics insights…”*, nested **Analytics** | **Reporting** tabs (`ReportsPharmacyDomainGroups`), then Overview **Create and run** (Browse catalog / Runs and delivery) plus metric cards (definitions, queued runs, due schedules, pinned widgets) and Attention queues.
- **Analytics** tab shows a long body (“Explore consumption…”) plus chips for datasets (`pharmacy_drug_consumption`, `pharmacy_dispense_throughput`, `inventory_stock_risk`) and insight shortcuts (top consumed, stock-out/expiry, stocking focus, walk-in vs clinical, revenue/margin). Chips call `openCatalogDataset` → switches panel to **Catalog** with dataset filter (leaves Overview).
- **Reporting** tab shows body (“Create, run, schedule…”) plus Browse catalog / Runs and delivery (and create-or-run when writable) via `applyPanel` → **Catalog** / **Delivery** (leaves Overview). Those actions duplicate Overview Create and run.
- Catalog/Delivery already expose definitions, runs, schedules, and detail/run/schedule via `AppDialog` / `showAppDialog` on the Reports workspace page. Overview itself is not dialog-hosted.

**Intended behavior**

- Drop the Analytics and Reporting **tab body descriptions** (the explore / create-run instructional paragraphs). Keep the Analytics | Reporting tab strip and action chips; keep page chrome (workspace title, search) unless a requirement below changes it.
- Every pharmacy Analytics / Reporting shortcut that today navigates away must instead open a **dialog** over Overview with the resources and actions needed for that task (dataset explore/run, catalog browse, delivery/runs)—user remains on Overview and the parent Analytics/Reporting tab.
- Prefer existing shared `AppDialog` / `showAppDialog` and Reports detail/run/schedule patterns; do not invent a parallel dialog system.
- Preserve dataset keys, RBAC (`reports:read`/`write`, pharmacy pack), deep-link `?dataset=`, and non-pharmacy Overview behavior.

**Definitions**

- *Parent tab:* Analytics or Reporting nested tab on Overview; must stay selected when a shortcut dialog opens/closes.
- *In-place dialog:* Modal over current Overview (not `applyPanel` / route change to Catalog or Delivery).
- *Analytics shortcut:* Dataset or insight chip under Analytics.
- *Reporting shortcut:* Browse catalog, Runs and delivery, Create or run (when entitled) under Reporting.

## Requirements

1. Remove Analytics and Reporting tab supporting body text from `ReportsPharmacyDomainGroups` (and unused l10n if superseded). Do not remove the tab labels or Overview pharmacy subtitle unless product copy is otherwise broken.
2. Wire Analytics shortcuts to open in-place dialogs that surface the selected pharmacy dataset (and insight intent) with entitled actions (view/run/export as already allowed)—do **not** call `openCatalogDataset` / `applyPanel` for those chips.
3. Wire Reporting shortcuts (Browse catalog, Runs and delivery, Create or run when `canWriteReports`) to in-place dialogs that expose the same entitled catalog/delivery capabilities without switching Overview → Catalog/Delivery panels.
4. When pharmacy domain groups are shown, stop Overview **Create and run** (and equivalent metric-card taps that only duplicate Reporting) from panel-navigating for the same targets; open the same dialogs or hide the duplicate Create and run row so Reporting is the single entry. Keep Attention queues / charts if they remain useful without forcing a panel leave for pharmacy shortcuts.
5. Reuse `AppDialog` / `showAppDialog` and existing Reports run/schedule/detail dialogs or extract shared content into dialog shells under reports presentation / shared components—no new reports microservice or route family.
6. Cover permission, loading, empty, error, success, validation, and visible feedback inside dialogs. Unauthorized chips/actions absent. Responsive; theme tokens; light/dark. Soft-refresh Overview after mutations without blank remount.
7. Tests: tab bodies absent; Analytics/Reporting chip taps do not change workspace panel away from Overview; dialogs open with correct dataset/panel intent; write-gated create absent without write; non-pharmacy Overview unchanged.

## Constraints

- Do not remove Catalog/Delivery panels or deep-link dataset handling for non-Overview entry points (e.g. pharmacy desk Open reports may still land on a dataset); Overview pharmacy shortcuts must stay in-place.
- Do not broaden pharmacist panel entitlements.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Analytics/Reporting tabs have no explore/create instructional body under the strip. | R1 |
| A2 | Analytics chips open dialogs; Overview panel stays selected. | R2, R5–R7 |
| A3 | Reporting shortcuts open dialogs (catalog/delivery/create) without leaving Overview. | R3–R5, R7 |
| A4 | No duplicate panel-navigate Create and run for pharmacy Overview when Reporting covers those actions. | R4 |
| A5 | Unauthorized actions absent; light/dark + narrow usable; non-pharmacy Overview unchanged. | R5–R7 |

## Relevant Files

- `frontend/lib/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_overview_dashboard.dart`
- `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart` (existing `AppDialog` run/schedule/detail)
- `frontend/lib/features/reports/presentation/controllers/reports_workspace_controller.dart` (`openCatalogDataset`, `applyPanel`)
- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/l10n/app_en.arb` (`reportsPharmacyAnalyticsBody`, `reportsPharmacyReportingBody`, …)
- `frontend/test/features/reports/presentation/reports_pharmacy_domain_groups_test.dart`

## Verification

- Widget/integration: body copy gone; chip → dialog; panel remains Overview; read-only hides create; reception/admin Overview unchanged.
- Manual: Analytics chip → dialog dismiss → still on Analytics; Reporting Browse/Runs → dialog; no Catalog/Delivery tab switch from those shortcuts; light/dark + narrow width.
