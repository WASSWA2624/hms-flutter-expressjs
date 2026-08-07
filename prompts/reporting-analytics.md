# Role-Scoped Reporting & Analytics (Pharmacy Pattern Parity)

Give every **staff** demo account a Reports Overview with pharmacy’s flow—Reporting / Analytics tabs, domain sections, and in-section report buttons—scoped to that user’s job, while preserving the workspace, pharmacy catalog, and permissions.

## Context

**Current behavior (shipped chrome; no screenshots attached)**

- **Shared kit:** `frontend/lib/shared/reporting/` (`ModuleReportingShell`, domain tabs, catalog, report dialog, filters, viz, print/export).
- **Pharmacy (done):** `ReportsPharmacyDomainGroups` + `pharmacyReportingCatalog` (~17 categories) + `PharmacyReportingDataProvider`. Category prompts: `prompts/pharmacy-reporting/`.
- **Owned packs (done):** `reportsDomainPacks` in `reports_role_tailoring.dart` uses focused-shell / primary **roles**, not embed-only `:read` grants. Doctors with `pharmacy:read` do **not** mount pharmacy Reporting. Patient portal gets no owned staff packs.
- **Non-pharmacy chrome (done):** `ReportsDomainReportingGroups` / `ReportsOwnedDomainReportingHost` mount Reporting + Analytics on Overview for finance, reception, clinical, lab, radiology, hr, biomedical, operations, emergency, communications, and admin. Catalogs live in `domain_reporting_catalogs.dart`; dialogs use `DomainReportingDataProvider` (pass-through dataset preview).
- **Wired datasets today:** Existing `REPORT_DATASETS` only—e.g. billing collections/claims, registrations, appointment throughput, HR leave, biomed incidents, pharmacy snapshots (admin), stock risk (ops). Many subcategory buttons are honest **unavailable**.
- **Program stubs (done):** `prompts/{billing,reception,clinical,lab,radiology,hr,biomedical,operations,emergency}-reporting/index.md`.
- **Finance + reception category Data contracts (done):** `prompts/billing-reporting/01`–`03`, `prompts/reception-reporting/01`–`03` (wiring/seed still remaining).
- **Tests:** `reports_owned_domain_packs_test.dart` covers pack matrix (pharmacist / doctor / billing / reception / patient / admin / ambulance).

**Intended behavior (remaining)**

- Implement finance then reception category prompts (runners, projections, seed floors, dialog tests); then deepen other domain packs the same way.
- Keep chrome/ids stable; prefer extending `REPORT_DATASET_MAP` builders over parallel math. Never invent columns.
- Multi-pack users keep the domain switcher; pharmacy and admin infra panels stay unchanged.

**Definitions**

- *Domain Reporting chrome:* Overview Reporting/Analytics on `ModuleReporting*` + per-pack catalog.
- *Owned pack:* Domain the role’s primary job owns (not every module `:read` used for embeds).
- *Demo staff accounts:* `seed-catalog.js` / `demo_credentials.dart` (password via demo setup docs). Include `radiology@hosspi.com`. Exclude patient portal from staff Reporting chrome.

**Account → owned pack**

| Demo account | Primary pack(s) |
| --- | --- |
| `super/tenant/facility.admin@…` | `admin` |
| `pharmacy@…` | `pharmacy` (preserve) |
| `billing@…` | `finance` |
| `reception@…` | `reception` |
| `doctor@…` / `nurse@…` | `clinical` |
| `lab@…` / `radiology@…` | `lab` / `radiology` |
| `hr@…` / `biomed@…` | `hr` / `biomedical` |
| `operations@…` / `housekeeping@…` | `operations` |
| `ambulance@…` | `emergency` |

## Requirements

1. **Do not regress chrome:** Keep owned-pack selection, Overview mounting, pharmacy freeze, and domain switcher. Unauthorized packs/export remain absent.
2. **Child domain prompts own depth:** For each pack folder under `prompts/*-reporting/`, add category files (pharmacy `01`–`17` pattern) with Data contracts, `datasetKey` wiring, seed floors, and tests. Finance + reception category prompts exist; other packs still need category files before deep completeness.
3. **Wire or gap honestly:** Implement finance `01`–`03` then reception `01`–`03` next. Map report ids to existing runners when possible; otherwise migrate + join real tables or leave unavailable—never fabricate client values. Prefer extending `datasets.js` / constants registration.
4. **Seed density:** When a report becomes runnable, applicable fact tables must meet ≥1,000 demo rows after `db:seed:demo` (pharmacy index rule 9 / `.cursor/access/demo-data.mdc`). No production seeding.
5. **States & UX:** Loading, empty, error, success, validation on catalog/dialogs; soft-refresh after runs that change Overview signals. Theme tokens; light/dark; responsive.
6. **Tests:** Keep pack matrix green; add ≥1 dialog/widget path per pack with a live dataset; unauthorized atoms absent; pharmacy regression.

## Constraints

- Reuse reports workspace, RBAC/ABAC, and shared kit. Do not rebuild `/reports` panels or clone pharmacy metrics into other domains.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.
- Optional deeper Analytics chips beyond current dataset/insight chips—out of scope unless a child prompt requires it.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Owned-pack Overview chrome remains for each staff demo role; doctor ≠ pharmacy catalog; patient has no staff domain chrome. | R1 |
| A2 | Child domain indexes gain category Data-contract prompts before claiming deep completeness. | R2 |
| A3 | Newly wired reports use real runners/seed; gaps stay unavailable, not fabricated. | R3, R4 |
| A4 | Pharmacy catalog/dialogs and admin infra panels unchanged. | R1 |
| A5 | Pack matrix + dialog tests pass; unauthorized export absent; themes/viewports usable. | R5, R6 |

## Relevant Files

- `frontend/lib/features/reports/presentation/reports_role_tailoring.dart`, `domain_reporting_catalogs.dart`, `domain_reporting_labels.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_domain_reporting_groups.dart`, `domain_reporting_data_provider.dart`, `reports_pharmacy_domain_groups.dart`, `reports_overview_dashboard.dart`
- `backend/src/lib/reports/constants.js`, `datasets.js`
- `prompts/reporting-analytics.md` (this index), `prompts/*-reporting/`, `prompts/pharmacy-reporting/`
- Tests: `reports_owned_domain_packs_test.dart`, `reports_access_test.dart`, `reports_pharmacy_domain_groups_test.dart`

## Verification

- Unit: owned-pack matrix for listed demo roles; pharmacy regression.
- Per child prompt: dialog totals match dataset summary for same from/to/scope; seed floors where newly wired.
- Manual: pharmacy / billing / reception / doctor / lab / admin—Reporting matches the job; doctor ≠ pharmacist sales catalog.
