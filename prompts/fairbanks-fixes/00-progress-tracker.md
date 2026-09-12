<h1 align="center">Fairbanks Fixes</h1>

<p align="center">
<code>▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱</code><br>
<b>6%</b> &nbsp;·&nbsp; 3 / 50 shipped &nbsp;·&nbsp; 0 / 5 gates
</p>

<p align="center">
🟩 Prod &nbsp; 🟨 Dev &nbsp; 🟦 WIP &nbsp; 🟥 Blocked &nbsp; ⬜ Todo &nbsp; 🚩 Gate
</p>

| Phase | # | Step | Deps | ● |
| :--- | :-: | :--- | :-: | :-: |
| **1 · Auth & Sessions**<br>`▰▱▱` 1/3 | 01 | [Login password field](01-login-password-field.md) | — | 🟩 |
| | 02 | [Registration error truthfulness](02-registration-error-truthfulness.md) | 01 | 🟨 |
| | 03 | [Persistent authentication](03-persistent-authentication.md) | 01, 02 | 🟨 |
| **2 · Tenancy & Isolation**<br>`▰▰▱▱` 2/4 | 04 | [Tenant seed audit](04-tenant-seed-audit.md) | 02 | 🟩 |
| | 05 | [Remove tenant operational seed](05-remove-tenant-operational-seed.md) | 04 | 🟩 |
| | 06 | [Platform presets model](06-platform-presets-model.md) | 04, 05 | ⬜ |
| | 07 | [Tenant isolation verification](07-tenant-isolation-verification.md) 🚩 | 04-06 | ⬜ |
| **3 · Users & Roles**<br>`▱▱▱▱▱` 0/5 | 08 | [User creation stability](08-user-creation-stability.md) | 03, 07 | ⬜ |
| | 09 | [Global default roles](09-global-default-roles.md) | 06, 08 | ⬜ |
| | 10 | [Custom role creation](10-custom-role-creation.md) | 09 | ⬜ |
| | 11 | [Role hierarchy & privilege guard](11-role-hierarchy-privilege-guard.md) | 09, 10 | ⬜ |
| | 12 | [Scope-based access control](12-scope-based-access-control.md) | 11 | ⬜ |
| **4 · Billing & Payments**<br>`▱▱▱▱` 0/4 | 13 | [Remove pending-payment blocking](13-remove-pending-payment-blocking.md) | 12 | ⬜ |
| | 14 | [Payment waivers](14-payment-waivers.md) | 12, 13 | ⬜ |
| | 15 | [Staff payment collection](15-staff-payment-collection.md) | 12-14 | ⬜ |
| | 16 | [Refund approval](16-refund-approval.md) | 14, 15 | ⬜ |
| **5 · Clinical Flow**<br>`▱` 0/1 | 17 | [Remove clinical blocking](17-remove-clinical-blocking.md) | 13 | ⬜ |
| **6 · Facilities & Staff**<br>`▱▱▱▱` 0/4 | 18 | [Facility & tenant relationship](18-facility-tenant-relationship.md) | 07 | ⬜ |
| | 19 | [Facility logo rendering](19-facility-logo-rendering.md) | 18 | ⬜ |
| | 20 | [Facility create staff](20-facility-create-staff.md) | 08, 18 | ⬜ |
| | 21 | [Staff list & details](21-staff-list-and-details.md) | 20 | ⬜ |
| **7 · Shared UI**<br>`▱▱▱` 0/3 | 22 | [Phone input speech duplication](22-phone-input-stt-duplication.md) | — | ⬜ |
| | 23 | [Shared country selector](23-shared-country-selector.md) | 22 | ⬜ |
| | 24 | [Facility active checkbox](24-facility-active-checkbox.md) | 18 | ⬜ |
| **8 · Pharmacy**<br>`▱▱▱` 0/3 | 25 | [Pharmacy journey simplification](25-pharmacy-journey-simplification.md) | 13-15 | ⬜ |
| | 26 | [Flexible drug strength](26-flexible-drug-strength.md) | 06 | ⬜ |
| | 27 | [Pharmacy analytics](27-pharmacy-analytics.md) | 12, 14, 16, 25, 26 | ⬜ |
| **9 · Reporting**<br>`▱▱▱▱▱▱▱` 0/7 | 28 | [Permission-based reporting](28-permission-based-reporting.md) | 12, 27 | ⬜ |
| | 29 | [Analytics default tab](29-analytics-default-tab.md) | 28 | ⬜ |
| | 30 | [Collapsible report sections](30-collapsible-report-sections.md) | 28, 29 | ⬜ |
| | 31 | [Reporting scope security](31-reporting-scope-security.md) 🚩 | 12, 28 | ⬜ |
| | 32 | [Standard report filters](32-standard-report-filters.md) | 30, 31 | ⬜ |
| | 33 | [Cross-system analytics](33-cross-system-analytics.md) | 27, 28, 31, 32 | ⬜ |
| | 34 | [Report export & print](34-report-export-and-print.md) | 31-33 | ⬜ |
| **10 · Excel**<br>`▱▱▱▱` 0/4 | 35 | [Excel data model](35-excel-data-model.md) | 06, 12 | ⬜ |
| | 36 | [Excel templates](36-excel-templates.md) | 35 | ⬜ |
| | 37 | [Import validation & preview](37-import-validation-preview.md) | 36 | ⬜ |
| | 38 | [Import upsert](38-import-upsert.md) | 37 | ⬜ |
| **11 · Printouts & PDF**<br>`▱▱▱` 0/3 | 39 | [Printout internal fields](39-printout-internal-fields.md) | — | ⬜ |
| | 40 | [Logo print padding](40-logo-print-padding.md) | 19 | ⬜ |
| | 41 | [PDF file naming](41-pdf-file-naming.md) | 39, 40 | ⬜ |
| **12 · Client Comms**<br>`▱` 0/1 | 42 | [Appreciation messaging](42-appreciation-messaging.md) | 12, 17 | ⬜ |
| **13 · Performance**<br>`▱▱▱▱` 0/4 | 43 | [Performance profiling](43-performance-profiling.md) | 42 | ⬜ |
| | 44 | [Backend & API optimization](44-backend-api-optimization.md) | 43 | ⬜ |
| | 45 | [Frontend optimization](45-frontend-optimization.md) | 43, 44 | ⬜ |
| | 46 | [Performance re-test](46-performance-retest.md) | 43-45 | ⬜ |
| **14 · E2E Testing**<br>`▱` 0/1 | 47 | [End-to-end journeys](47-end-to-end-journeys.md) | 01-46 | ⬜ |
| **15 · Security & Audit**<br>`▱▱▱` 0/3 | 48 | [Backend authorization audit](48-backend-authorization-audit.md) 🚩 | 11, 12, 31, 47 | ⬜ |
| | 49 | [Audit trail verification](49-audit-trail-verification.md) 🚩 | 48 | ⬜ |
| | 50 | [Full regression & release gate](50-full-regression.md) 🚩 | 01-49 | ⬜ |
