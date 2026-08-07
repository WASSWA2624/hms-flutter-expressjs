# Pharmacy Reporting: Category Sections, Report Buttons, and In-Place Dialogs

Build the pharmacy **Reporting** tab as a data-driven catalog of report categories and subcategory buttons that open reusable in-place report dialogs (period presets, custom range, table→Excel / chart→PDF export), filtered by the existing search bar—without changing Analytics or non-pharmacy Overview.

## Context

**Current behavior (codebase; no screenshots attached)**

- Pharmacist Reports Overview nests **Analytics** | **Reporting** in `ReportsPharmacyDomainGroups`. Analytics keeps dataset/insight chips that open overview shortcut dialogs. Reporting shows only `AppSearchBar` + Filters; overview metrics/queues/charts/timeline are hidden while Reporting is selected.
- Filters already expose the 17 category keys from `.cursor/reporting-analytics.md/pharmacy-reporting.md` (sales, inventory, medicines, … management), plus date range. Search/filter state is local and does **not** yet drive a section list—there are no category sections, subcategory buttons, or report dialogs under the bar.
- Shared reports workspace already uses `AppDialog` / `showAppDialog`, run/export patterns, and pharmacy pack gating (`reportsDomainPacks` + `pharmacyRead` / `reports:read`). Catalog/Delivery panels and Analytics shortcuts remain separate entry points.

**Intended behavior**

- Under the Reporting search bar, render every catalog **category** as a section; under each section, every listed **subcategory** is a button. Tapping a button opens an in-place dialog for that report (user stays on Reporting).
- Each dialog supports period presets (today, last week, last month, last 3/6/12/24 months, and similar) **and** a custom date range; shows loading/empty/error/success; exports **Excel** when the primary view is tabular and **PDF** when the primary view is a chart/graph.
- UI is driven by a reusable catalog model (loop sections → buttons → dialog shell). Search + advanced filters comprehensively narrow by category, subcategory (and related text/date criteria already on the bar).

**Definitions**

- *Category:* Top-level group from the pharmacy reporting catalog (e.g. Sales & Revenue).
- *Subcategory / report entity:* One reportable metric or slice under a category (e.g. Total sales)—one button → one dialog.
- *Report dialog:* `AppDialog` over Reporting with period controls, content (table and/or chart), and entitled export actions.
- *Catalog model:* Declarative list of categories → subcategories (ids, labels, icons, content kind) used to build sections, filters, and dialogs without hard-coding each widget tree.

## Requirements

1. Define a pharmacy reporting **catalog model** that mirrors `.cursor/reporting-analytics.md/pharmacy-reporting.md` (all 17 categories and their subcategory bullets). Localize labels; keep stable ids for filters and dialogs.
2. Below the Reporting search bar, render reusable **category sections** and **subcategory buttons** by looping the catalog. Empty/filtered-out states use localized empty copy. Keep Overview chrome and Analytics chips unchanged.
3. Wire search text and advanced filters so users can filter by **category**, **subcategory**, and date criteria already on the bar; extend filter groups as needed so filters are comprehensive for this catalog (not category-only). Applying filters updates the visible sections/buttons without leaving Reporting.
4. On subcategory press, open a reusable **report dialog** via `AppDialog` / `showAppDialog`. Shell includes title, period presets, custom from/to dates, validation for inverted ranges, loading/empty/error, and close. Stay on Reporting; do not `applyPanel` to Catalog/Delivery for these opens.
5. Export: entitled users get **Excel** when the report’s primary surface is a table and **PDF** when it is a chart/graph; unauthorized export controls absent. Reuse existing reports/export helpers where possible.
6. Prefer existing pharmacy/report data for dialogs that already map to datasets or APIs; for catalog entries without a backend yet, show the shell with an honest empty/unavailable state—do not invent parallel report microservices in this slice. Soft-refresh content after period changes.
7. Gate Reporting with existing pharmacy + reports read access; hide write/export actions without entitlement. Theme tokens; light/dark; responsive sections/buttons/dialogs without clipped primary actions.
8. Tests: all categories render as sections; filter by category/subcategory hides others; button opens dialog; Analytics and non-pharmacy Overview unchanged; unauthorized export absent; empty/loading/error paths covered for the dialog shell.

## Constraints

- Do not remove or rewrite Analytics chips, Catalog/Delivery panels, or non-pharmacy Overview except where Reporting already hides dashboard chrome.
- Do not require a new reports route family for subcategory dialogs; stay in-place on Overview Reporting.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`. Source of category/subcategory lists: `.cursor/reporting-analytics.md/pharmacy-reporting.md`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Reporting lists every catalog category as a section with subcategory buttons. | R1, R2 |
| A2 | Search/filters by category and subcategory (plus bar date/text) update the list in place. | R3 |
| A3 | Subcategory opens an in-place dialog with presets + custom range; panel stays Reporting. | R4 |
| A4 | Table reports offer Excel export; chart reports offer PDF when entitled; otherwise export absent. | R5, R7 |
| A5 | Missing-backend reports show empty/unavailable in the shell; no fake microservice. | R6 |
| A6 | Analytics + non-pharmacy Overview unchanged; unauthorized UI absent; light/dark + narrow usable. | R7, R8 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` (category/subcategory catalog)
- `frontend/lib/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_overview_dashboard.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_overview_shortcut_dialogs.dart`
- `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart`
- `frontend/lib/features/reports/presentation/reports_access.dart`, `reports_role_tailoring.dart`
- `frontend/lib/shared/components/app_dialog.dart`, `app_search_bar.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/reports/presentation/reports_pharmacy_domain_groups_test.dart`

## Verification

- Widget: catalog sections/buttons from model; filter category/subcategory; dialog open stays on Reporting; Analytics untouched.
- Dialog: period presets + custom range validation; loading/empty/error; Excel vs PDF by content kind; export gated.
- Manual: Reporting → filter Sales → Total sales → dialog periods → export; switch Analytics still shows chips; light/dark + narrow width.
