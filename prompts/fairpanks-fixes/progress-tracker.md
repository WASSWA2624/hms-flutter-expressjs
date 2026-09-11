# Fairpanks Fixes — Progress Tracker

Implementation prompts for [fairpanks-fixes.md](../fairpanks-fixes.md). Work the steps in
numeric order; each prompt lists its own dependencies.

**Every step is done only when it is live and verified in both environments.** A step stays
`In progress` while it passes in development but not yet in production.

| Environment     | Backend | Frontend |
| --------------- | ------- | -------- |
| **Development** | `NODE_ENV=development`, `.env.development`, `npm run dev` | `env/development.json`, `flutter run` |
| **Production**  | `NODE_ENV=production`, `.env.production`, `https://api.hosspi.com` | `env/production.json.example`, `https://app.hosspi.com`, release APK |

Status values: `Not started` · `In progress` · `Dev done` · `Prod done` · `Blocked`

## Gates

| Gate | Owning step | Rule | Status |
| ---- | ----------- | ---- | ------ |
| Tenant isolation confirmed | 07 | No step past Phase 2 is done until 07 passes in both environments | Not started |
| Reporting scope enforced | 31 | No reporting step is done until 31 passes | Not started |
| Backend authorization proven | 48 | Release blocked while any sensitive route is unproven | Not started |
| Audit trails complete | 49 | Release blocked while a listed action writes no audit entry | Not started |
| Final release gate | 50 | Correctness, data isolation, authorization, workflow integrity, reporting accuracy, performance, security, regression | Not started |

## Phase 1 — Authentication, Registration and Session Stability

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 01 | [Login password field](01-login-password-field.md) | — | Not started | ☐ | ☐ | |
| 02 | [Registration error truthfulness](02-registration-error-truthfulness.md) | 01 | Not started | ☐ | ☐ | |
| 03 | [Persistent authentication](03-persistent-authentication.md) | 01, 02 | Not started | ☐ | ☐ | |

## Phase 2 — Tenant Architecture and Data Isolation

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 04 | [Tenant seed audit](04-tenant-seed-audit.md) | 02 | Not started | ☐ | ☐ | Read-only against production |
| 05 | [Remove tenant operational seed](05-remove-tenant-operational-seed.md) | 04 | Not started | ☐ | ☐ | Cleanup needs backup and dry run |
| 06 | [Platform presets model](06-platform-presets-model.md) | 04, 05 | Not started | ☐ | ☐ | |
| 07 | [Tenant isolation verification](07-tenant-isolation-verification.md) | 04, 05, 06 | Not started | ☐ | ☐ | **Gate** |

## Phase 3 — Users, Roles and Permissions

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 08 | [User creation stability](08-user-creation-stability.md) | 03, 07 | Not started | ☐ | ☐ | |
| 09 | [Global default roles](09-global-default-roles.md) | 06, 08 | Not started | ☐ | ☐ | |
| 10 | [Custom role creation](10-custom-role-creation.md) | 09 | Not started | ☐ | ☐ | |
| 11 | [Role hierarchy and privilege guard](11-role-hierarchy-privilege-guard.md) | 09, 10 | Not started | ☐ | ☐ | |
| 12 | [Scope-based access control](12-scope-based-access-control.md) | 11 | Not started | ☐ | ☐ | Foundation for Phases 4 and 9 |

## Phase 4 — Billing, Payments, Waivers and Refunds

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 13 | [Remove pending-payment blocking](13-remove-pending-payment-blocking.md) | 12 | Not started | ☐ | ☐ | |
| 14 | [Payment waivers](14-payment-waivers.md) | 12, 13 | Not started | ☐ | ☐ | |
| 15 | [Staff payment collection](15-staff-payment-collection.md) | 12, 13, 14 | Not started | ☐ | ☐ | |
| 16 | [Refund approval](16-refund-approval.md) | 14, 15 | Not started | ☐ | ☐ | |

## Phase 5 — Clinical Workflow Flexibility

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 17 | [Remove clinical blocking](17-remove-clinical-blocking.md) | 13 | Not started | ☐ | ☐ | Keep safety controls |

## Phase 6 — Facility and Staff Management

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 18 | [Facility and tenant relationship](18-facility-tenant-relationship.md) | 07 | Not started | ☐ | ☐ | |
| 19 | [Facility logo rendering](19-facility-logo-rendering.md) | 18 | Not started | ☐ | ☐ | Production uploads permissions |
| 20 | [Facility create staff](20-facility-create-staff.md) | 08, 18 | Not started | ☐ | ☐ | |
| 21 | [Staff list and details](21-staff-list-and-details.md) | 20 | Not started | ☐ | ☐ | |

## Phase 7 — Shared UI Components

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 22 | [Phone input speech duplication](22-phone-input-stt-duplication.md) | — | Not started | ☐ | ☐ | |
| 23 | [Shared country selector](23-shared-country-selector.md) | 22 | Not started | ☐ | ☐ | |
| 24 | [Facility active checkbox](24-facility-active-checkbox.md) | 18 | Not started | ☐ | ☐ | |

## Phase 8 — Pharmacy Workflow and Data Model

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 25 | [Pharmacy journey simplification](25-pharmacy-journey-simplification.md) | 13, 14, 15 | Not started | ☐ | ☐ | Record interaction baseline |
| 26 | [Flexible drug strength](26-flexible-drug-strength.md) | 06 | Not started | ☐ | ☐ | Migration review list per environment |
| 27 | [Pharmacy analytics](27-pharmacy-analytics.md) | 12, 14, 16, 25, 26 | Not started | ☐ | ☐ | |

## Phase 9 — Reporting and Analytics Framework

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 28 | [Permission-based reporting](28-permission-based-reporting.md) | 12, 27 | Not started | ☐ | ☐ | |
| 29 | [Analytics default tab](29-analytics-default-tab.md) | 28 | Not started | ☐ | ☐ | |
| 30 | [Collapsible report sections](30-collapsible-report-sections.md) | 28, 29 | Not started | ☐ | ☐ | |
| 31 | [Reporting scope security](31-reporting-scope-security.md) | 12, 28 | Not started | ☐ | ☐ | **Gate** |
| 32 | [Standard report filters](32-standard-report-filters.md) | 30, 31 | Not started | ☐ | ☐ | Timezone rule identical in both |
| 33 | [Cross-system analytics](33-cross-system-analytics.md) | 27, 28, 31, 32 | Not started | ☐ | ☐ | Scheduler must run in production |
| 34 | [Report export and print](34-report-export-and-print.md) | 31, 32, 33 | Not started | ☐ | ☐ | |

## Phase 10 — Excel Data Exchange

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 35 | [Excel data model](35-excel-data-model.md) | 06, 12 | Not started | ☐ | ☐ | Specification only |
| 36 | [Excel templates](36-excel-templates.md) | 35 | Not started | ☐ | ☐ | Identical templates per version |
| 37 | [Import validation and preview](37-import-validation-preview.md) | 36 | Not started | ☐ | ☐ | Never write before confirmation |
| 38 | [Import upsert](38-import-upsert.md) | 37 | Not started | ☐ | ☐ | |

## Phase 11 — Printouts and PDF

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 39 | [Printout internal fields](39-printout-internal-fields.md) | — | Not started | ☐ | ☐ | |
| 40 | [Logo print padding](40-logo-print-padding.md) | 19 | Not started | ☐ | ☐ | |
| 41 | [PDF file naming](41-pdf-file-naming.md) | 39, 40 | Not started | ☐ | ☐ | |

## Phase 12 — Client Communication

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 42 | [Appreciation messaging](42-appreciation-messaging.md) | 12, 17 | Not started | ☐ | ☐ | Sandbox credentials in development |

## Phase 13 — Performance Optimization

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 43 | [Performance profiling](43-performance-profiling.md) | 42 | Not started | ☐ | ☐ | Measure only |
| 44 | [Backend and API optimization](44-backend-api-optimization.md) | 43 | Not started | ☐ | ☐ | |
| 45 | [Frontend optimization](45-frontend-optimization.md) | 43, 44 | Not started | ☐ | ☐ | |
| 46 | [Performance re-test](46-performance-retest.md) | 43, 44, 45 | Not started | ☐ | ☐ | Production numbers gate release |

## Phase 14 — End-to-End Integration Testing

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 47 | [End-to-end journeys](47-end-to-end-journeys.md) | 01-46 | Not started | ☐ | ☐ | Clean up production test data |

## Phase 15 — Security, Audit and Regression

| # | Prompt | Depends on | Status | Dev | Prod | Notes |
| - | ------ | ---------- | ------ | --- | ---- | ----- |
| 48 | [Backend authorization audit](48-backend-authorization-audit.md) | 11, 12, 31, 47 | Not started | ☐ | ☐ | **Gate** |
| 49 | [Audit trail verification](49-audit-trail-verification.md) | 48 | Not started | ☐ | ☐ | **Gate** |
| 50 | [Full regression and release gate](50-full-regression.md) | 01-49 | Not started | ☐ | ☐ | **Gate** |

## Per-step completion checklist

Copy into the pull request for each step:

- [ ] Requirements implemented and every acceptance criterion met
- [ ] Backend: `npm run lint`, `npm run test:backend`, `npm run openapi:validate`
- [ ] Frontend: `flutter analyze`, `flutter test` (or `pwsh scripts/delivery-gate.ps1`)
- [ ] New backend keys documented in `backend/env.template.txt` and set in `.env.development` **and** `.env.production`
- [ ] New frontend defines mirrored in `env/development.json.example` **and** `env/production.json.example`
- [ ] Migrations run: `npm run prisma:migrate` (development) **and** `npm run prisma:migrate:deploy` (production host)
- [ ] Backfills idempotent, run in both databases, counts logged, production backed up first
- [ ] Deployed with `deploy/deploy-backend.py`, `deploy/deploy-frontend.py`, `deploy/deploy-android.py` as applicable
- [ ] Acceptance checks repeated against `https://api.hosspi.com` and `https://app.hosspi.com`
- [ ] No behavior gated on `NODE_ENV` or on a development-only flag, seed, or account
- [ ] Tenant isolation, scope, authorization, and audit behavior unchanged or improved
- [ ] Tracker row updated with Status, Dev, Prod, and notes

## Change log

| Date | Step | Change | By |
| ---- | ---- | ------ | -- |
| 2026-09-11 | — | Prompts generated from `fairpanks-fixes.md` | — |
