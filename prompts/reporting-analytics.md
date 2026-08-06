# Pharmacy Reporting and Analytics Overview Layout

Redesign the pharmacist Reports Overview so pharmacy domain content is exactly two tabs—**Analytics** and **Reporting**—merging today’s overlapping Analysis and Analytics panels without changing dataset, permission, or reporting-pipeline behavior.

## Context

**Current behavior**

- Pharmacy desk exposes **Open reports** when `pharmacy:read` ∩ `reports:read` ∩ module `reporting-analytics`; deep-links to `/reports?dataset=pharmacy_drug_consumption`.
- Pharmacist domain pack (`ReportsDomainPack.pharmacy`) limits Reports panels to Overview, Catalog, Delivery and primary datasets: `pharmacy_drug_consumption`, `pharmacy_dispense_throughput`, `inventory_stock_risk`.
- `ReportsPharmacyDomainGroups` on Overview renders **three stacked panels**: Analysis (dataset chips), Analytics (insight chips that open the same datasets), Reporting (browse catalog / delivery / create-or-run when `reports:write`).
- Analysis and Analytics duplicate the same destinations; there is no tab strip—only stacked `AppSectionPanel`s.
- Backend builders already support consumption (incl. source mix + profit when `buy_unit_price` present), dispense throughput, and inventory stock/expiry risk.

**Intended behavior**

- Pharmacist Overview pharmacy chrome is a **two-tab** layout: **Analytics** | **Reporting** (not three sections; do not keep a separate **Analysis** tab or panel).
- **Analytics** holds interactive exploration and insights for the pharmacy datasets (former Analysis chips + Analytics insight chips in one place).
- **Reporting** holds shared report definition / run / schedule / download entry points (catalog, delivery, create-or-run when entitled).
- Preserve deep-link, RBAC, datasets, and non-pharmacy Overview behavior for other domain packs.

**Definitions**

- *Analytics tab:* In-period pharmacy insights and dataset shortcuts (consumption, throughput, stock/expiry risk, walk-in vs clinical mix, margin when buy cost exists).
- *Reporting tab:* Shared reporting pipeline surfaces (catalog, delivery, create/run) scoped by allowed panels and write permission.
- *Pharmacy domain groups:* Overview chrome shown when `reportsDomainPacks` includes `pharmacy` (and not admin-only overlay).

## Requirements

1. Replace the three stacked pharmacy Overview panels with an `AppTabStrip` (or equivalent design-system tabs) of exactly two tabs: **Analytics** and **Reporting**. Default to Analytics.
2. Move former Analysis dataset chips and Analytics insight chips into the **Analytics** tab only; remove the separate Analysis title/panel and unused Analysis-only copy if superseded. Keep insight labels (top consumed, stock-out risk, expiry risk, stocking focus, walk-in vs clinical mix, revenue/margin) and open the same dataset keys as today.
3. Keep the **Reporting** tab contents as today’s Reporting panel: Browse catalog, View delivery, and Create or run report only when `canWriteReports` and Catalog is allowed. Hide unauthorized chips entirely.
4. Preserve pharmacy Overview subtitle intent (analytics + reporting for the facility); update copy so it does not imply a third “Analysis” product area.
5. Do not change pharmacy desk **Open reports** gate or deep-link query, dataset builders, role-tailoring dataset lists, or non-pharmacy Overview layout.
6. Cover permission, loading, empty (no pharmacy datasets), error/success from existing Reports workspace flows, and visible feedback. Responsive; theme tokens; light/dark. Unauthorized pharmacy groups and write chips must not render.
7. Tests: two tabs only (no Analysis heading); Analytics actions open correct datasets; Reporting create chip absent without write; `shouldShow` unchanged for pharmacy vs non-pharmacy packs.

## Constraints

- Reuse `ReportsPharmacyDomainGroups`, Reports workspace controller (`openCatalogDataset` / `applyPanel`), role-tailoring, and existing pharmacy datasets—no parallel analytics API or pharmacy-only reports microservice.
- Do not broaden pharmacist panel set beyond Overview / Catalog / Delivery unless already granted by another pack.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Pharmacist Overview shows Analytics and Reporting tabs only; no Analysis panel/heading. | R1–R2, R4, R7 |
| A2 | Analytics tab exposes dataset/insight actions that open consumption, throughput, or stock-risk as today. | R2, R5 |
| A3 | Reporting tab shows catalog/delivery; create-or-run only with write + catalog panel. | R3, R6 |
| A4 | Non-pharmacy packs and pharmacy Open-reports deep-link unchanged. | R5 |
| A5 | Unauthorized groups/chips absent; light/dark and narrow viewport usable. | R6–R7 |

## Relevant Files

- `frontend/lib/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_overview_dashboard.dart`
- `frontend/lib/features/reports/presentation/reports_role_tailoring.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart` (`canOpenPharmacyReportsAnalytics`)
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (Open reports action)
- `frontend/lib/l10n/app_en.arb` (`reportsPharmacy*` keys)
- `frontend/test/features/reports/presentation/reports_pharmacy_domain_groups_test.dart`
- `backend/src/lib/reports/datasets.js` (pharmacy builders; no behavior change expected)

## Verification

- FE widget tests: Analytics + Reporting tabs present; Analysis absent; insight taps → dataset ids; read-only hides create; `shouldShow` true/false.
- Manual: pharmacist Overview → switch tabs → open insights and catalog/delivery; pharmacy desk Open reports still lands on consumption dataset; light/dark + narrow width.
- Confirm admin/finance/other Overviews unchanged.
