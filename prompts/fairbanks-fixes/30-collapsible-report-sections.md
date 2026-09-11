# 30 — Implement Searchable, Collapsible Reporting Sections

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 9, Step 30
**Depends on:** 28, 29
**Applies to:** development and production

## Context

Each analytics tab must organize its reports into logical, collapsible, searchable sections so a user finds a report without scrolling a long flat list. For example Finance contains Revenue, Payments, Outstanding Balances, Refunds, Waivers, Expenses, and Financial Performance.

## Requirements

1. Add a section dimension to the report registry from step 28 so every report declares its tab, section, display name, and ordering.
2. Render sections as collapsible groups with a consistent expand and collapse control, remembering expansion state within the session.
3. Provide a search box per tab that filters across section names and report names, showing matching reports with their section context and clearing cleanly.
4. Apply permission-based visibility at section level: a section with no authorized report does not render, and no unauthorized report name appears in search results.
5. Expose the relevant filters for each report at the point of use, without forcing the user through unrelated filters.
6. Keep naming consistent across tabs and sections, localized, and aligned with the shared metric vocabulary.
7. Present sections responsively, including a usable layout on mobile widths, in both themes.
8. Add frontend tests for section rendering, expansion state, search matching, permission-filtered sections, and empty search results.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the shared reporting and layout components; do not build a bespoke accordion.
- Search must run against the authorized catalog only, never against a full registry.
- Follow `prompts/.cursor/tabs.mdc`, `tables.mdc`, `responsiveness.mdc`, and `localization.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** Every report appears under its declared section, and sections expand and collapse with state retained within the session.
- [ ] **AC2 (R3)** Search finds a report by report name or section name and shows its section context; clearing search restores the full view.
- [ ] **AC3 (R4)** Sections and search results contain no unauthorized report, and empty sections do not render.
- [ ] **AC4 (R5)** Each report exposes only its relevant filters.
- [ ] **AC5 (R6, R7)** Naming is consistent and localized, and layouts work at mobile, tablet, and desktop widths in both themes.
- [ ] **AC6 (R8)** New tests pass.
- [ ] **AC7 (R9)** Behavior is identical in development and production.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: browse and search every tab as at least two differently scoped users in each environment.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`.
- Config: none expected beyond the registry metadata.
- Schema/data: apply report registry metadata changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host when the registry is persisted.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, plus `python deploy/deploy-backend.py` when the registry changes, then repeat the browsing checks in production.

## Relevant Files

- `frontend/lib/features/reports/presentation/widgets/reports_domain_reporting_groups.dart`, `reports_pharmacy_domain_groups.dart`
- `frontend/lib/features/reports/presentation/domain_reporting_catalogs.dart`, `domain_reporting_labels.dart`
- `frontend/lib/shared/reporting/`, `frontend/lib/shared/layout/`
- `backend/src/modules/report-definition/`, `reports-workspace/`
