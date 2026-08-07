# Role-Scoped Reporting & Analytics (Pharmacy Pattern Parity)

Give every **staff** demo account a Reports Overview with pharmacy’s flow—Reporting / Analytics tabs, domain sections, and in-section report buttons—scoped to that user’s job, while preserving the workspace, pharmacy catalog, and permissions.

## Context

**Current behavior (codebase; no screenshots attached)**

- **Shared kit:** `frontend/lib/shared/reporting/` (`ModuleReportingShell`, domain tabs, catalog, report dialog, filters, viz, print/export).
- **Pharmacy reference (done):** `ReportsPharmacyDomainGroups` mounts Reporting + Analytics; `pharmacyReportingCatalog` (~17 categories); dialogs via `PharmacyReportingDataProvider` + `REPORT_DATASET_MAP`. Category prompts: `prompts/pharmacy-reporting/`.
- **Other roles today:** `reports_role_tailoring.dart` only curates workspace **panels** and Overview **dataset shortcuts**. Non-pharmacy users get generic Overview KPIs—**no** domain Reporting sections or role-specific buttons.
- **Access:** Entry = `reports:read` ∪ `compliance:read` (or admin). Most seeded staff roles have `reports:read`; `PATIENT` (`patient.portal@hosspi.com`) does **not**—exclude portal from staff `/reports`.
- **Pack gap:** `ReportsDomainPack` from effective permissions. Cross-domain embed reads (e.g. doctor `pharmacy:read`) can mount **pharmacy** Reporting for non-pharmacists—too broad.

**Intended behavior**

- Reuse pharmacy’s **chrome** (tabs → sections → buttons → shared dialog), not pharmacy sales/stock metrics, per staff domain.
- Sections/buttons match that account’s job (reception ≠ billing ≠ lab ≠ HR).
- Multi-pack users see a **union of owned domain catalogs** (or domain switcher)—never another role’s full catalog via embed-only grants.
- Preserve pharmacy. Admins keep infra panels (catalog/delivery/dashboards/monitor/activity) plus admin cross-domain access.

**Definitions**

- *Domain Reporting chrome:* Overview Reporting/Analytics on `ModuleReporting*` + per-pack catalog (section + report ids), like `ReportsPharmacyDomainGroups`.
- *Owned pack:* Domain the role’s primary job owns (focused-shell / allow-list)—not every module `:read` used for embeds.
- *Demo staff accounts:* `seed-catalog.js` / `demo_credentials.dart` (password via demo setup docs—never hardcode in product). Include `radiology@hosspi.com`. Exclude patient portal.

**Account → owned pack**

| Demo account | Primary pack(s) |
| --- | --- |
| `super/tenant/facility.admin@…` | `admin` |
| `pharmacy@…` | `pharmacy` (preserve) |
| `billing@…` | `finance` |
| `reception@…` | `reception` |
| `doctor@…` / `nurse@…` | `clinical` (not pharmacy catalog) |
| `lab@…` / `radiology@…` | `lab` / `radiology` |
| `hr@…` / `biomed@…` | `hr` / `biomedical` |
| `operations@…` / `housekeeping@…` | `operations` (+ housekeeping sections when schema allows) |
| `ambulance@…` | emergency/operations-lean catalog under owned grants |

## Requirements

1. **Generalize pharmacy chrome:** Mirror `ReportsPharmacyDomainGroups` so Overview mounts domain Reporting for each owned pack (finance, reception, clinical, lab, radiology, hr, biomedical, operations, communications as applicable). Reuse `ModuleReporting*`—do not fork dialog math.
2. **Owned-pack selection:** Embed-only cross-reads must **not** show that domain’s Reporting. Prefer focused-shell / primary-role rules; keep permission union for true multi-role staff. Unauthorized packs/export absent (not disabled stubs).
3. **Per-pack catalogs:** Add stable category + report ids, l10n labels, and domain-specific buttons. Wire `datasetKey`s to existing `REPORT_DATASETS` where possible; honest “unavailable” on schema gaps—never invent columns or money math. Prefer extending runners.
4. **Pharmacy freeze:** Do not break `pharmacyReportingCatalog`, provider, or `prompts/pharmacy-reporting/*`. Keep pharmacist Reporting-only Overview and admin infra panels.
5. **Program structure:** This file is the **index**. Add per-domain prompt folders (e.g. `prompts/billing-reporting/`) modeled on `prompts/pharmacy-reporting/index.md` before deep subcategory work. Ship chrome + first dense sections first.
6. **Seed & density:** Runnable reports must meet demo fact-table volume floors (pharmacy index rule 9 / `.cursor/access/demo-data.mdc`). No production seeding.
7. **States:** Loading, empty, error, success, validation on catalog/dialogs; soft-refresh after runs that change Overview signals. Theme tokens; light/dark; responsive without clipped actions.
8. **Tests:** Pack matrix per demo role (doctor ≠ pharmacy catalog; pharmacist keeps pharmacy; billing → finance; patient has no reports entry); unauthorized atoms absent; pharmacy regression; ≥1 runnable dialog per new pack when a dataset exists.

## Constraints

- Reuse reports workspace, RBAC/ABAC, and shared kit. Do not rebuild `/reports` panels or clone pharmacy metrics into other domains.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.
- Optional deeper per-domain Analytics chips beyond pharmacy’s Analytics tab—out of scope unless a child prompt requires it.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Each staff owned pack with `reports:read` shows Reporting sections + buttons on Overview (pharmacy pattern). | R1, R3 |
| A2 | Demo roles mount only owned packs; clinical users do not get full pharmacy Reporting via embed `pharmacy:read`. | R2 |
| A3 | Labels/datasets match the domain; gaps unavailable, not fabricated. | R3 |
| A4 | Pharmacy catalog/dialogs and admin infra panels unchanged. | R4 |
| A5 | Child domain prompt indexes exist (or stubbed with first sections) before claiming pack complete. | R5 |
| A6 | Unauthorized UI/export absent; themes/viewports usable; patient portal lacks staff reports. | R2, R7, R8 |

## Relevant Files

- `frontend/lib/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart`, `reports_overview_dashboard.dart`, `reports_workspace_page.dart`
- `frontend/lib/features/reports/presentation/reports_role_tailoring.dart`, `reports_access.dart`, `pharmacy_reporting_catalog.dart`
- `frontend/lib/shared/reporting/*`
- `backend/src/lib/reports/constants.js`, `datasets.js`
- `prompts/pharmacy-reporting/index.md` (+ `01`–`17`), `.cursor/reporting-analytics.md/pharmacy-reporting.md`
- `frontend/patrol_test/helpers/demo_credentials.dart`, `backend/scripts/seeders/seed-catalog.js`
- Tests: `reports_access_test.dart`, `reports_pharmacy_domain_groups_test.dart`, role-tailoring / Overview tests

## Verification

- Unit/widget: owned-pack matrix for listed demo roles; pharmacy regression; one dialog path per new pack with a live dataset.
- Manual: pharmacy / billing / reception / doctor / lab / admin (demo password from setup docs)—Reporting matches the job; doctor ≠ pharmacist sales catalog; `patient.portal` cannot open staff reports.
- After seed: wired reports stay dense for default period presets.
