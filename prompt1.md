# Task: Reorganize and refine the HMS side navigation

## Goal

Improve the left sidebar and mobile navigation drawer so menu items are grouped by real hospital workflows, consistently named, and easy to scan. Users should find the right module quickly without reading a long, flat list.

## Context

The app shell renders navigation from `ResponsiveShellDestination` entries built in `frontend/lib/app/router/app_router.dart` (`_shellDestinations`). Groups are assigned via `groupLabel` and rendered in `frontend/lib/shared/layout/responsive_shell_scaffold.dart` (`SideNavigation`, `_MobileShellDrawer`).

Current groups (from `app_en.arb`):

| Group | Example destinations |
|---|---|
| Overview | Dashboard |
| Patient access | Patients, OPD, Emergency |
| Inpatient care | IPD, Rooms & beds, ICU, Nursing, Discharge |
| Clinical services | Clinical, Physiotherapy, Theater |
| Diagnostics and medication | Lab, Radiology, Pharmacy |
| Revenue cycle | Billing, Claims, Subscriptions |
| Facility operations | Operations, Housekeeping, Biomedical, Mortuary |
| Administration | HR, Communications, Integrations, Reports, Settings, Setup |

Navigation labels live in `frontend/lib/l10n/app_en.arb`. On desktop/tablet, the sidebar supports expand/collapse and search. On mobile (`AppBreakpoint.isMobile`), navigation moves into a drawer opened from the app menu bar; the main content area has no persistent sidebar.

## Problem

- Grouping does not always match how staff think about their work (e.g. related clinical actions are scattered or mis-grouped).
- Some labels are inconsistent in length or style (abbreviations vs full words, title casing, domain jargon).
- On narrow/mobile layouts, long labels truncate or crowd the drawer, making items hard to distinguish.

## Requirements

### 1. Use-case-driven grouping

- Audit every shell destination and regroup items by primary user workflow, not by backend module name alone.
- Keep related clinical workflows together (e.g. clinical documentation, theatre, physiotherapy, discharge planning) where that improves discoverability.
- Prefer fewer, clearer group headings over many thin groups.
- Preserve route paths and access-policy filtering; only change navigation metadata (group, labels, order), not authorization.

### 2. Consistent naming

- Standardize nav item labels: concise, action- or domain-oriented, parallel structure within each group.
- Use established hospital abbreviations where appropriate (OPD, IPD, ICU, HR) and spell out terms where clarity matters.
- Align sidebar labels with page titles where reasonable; note intentional differences.
- Update all affected strings in `app_en.arb` (and regenerate l10n if needed).

### 3. Short labels for constrained layouts

- Add a `shortLabel` (or equivalent) to `ResponsiveShellDestination` for compact display.
- Use **short labels** on mobile drawer items and anywhere horizontal space is limited.
- Use **full labels** on expanded desktop sidebar.
- Short labels must remain unambiguous within their group (e.g. "Physio" vs "Physiotherapy", "Tenant setup" vs "Setup").
- Collapsed desktop sidebar may continue to show icons only; tooltips should use the full label.

### 4. Visual polish (minimal)

- Ensure group headers, spacing, and item order feel intentional after regrouping.
- Avoid truncation where a better short label solves the problem.
- Do not redesign the shell layout or theme tokens unless required for the above.

## Out of scope

- Adding or removing routes/modules.
- Changing RBAC / `appAccessPolicy` rules.
- Home-page shortcuts (`home_page.dart`) unless needed to stay consistent with nav labels.
- New navigation patterns (bottom tabs, flyout menus, etc.).

## Key files

- `frontend/lib/app/router/app_router.dart` — destination list, group assignment, order
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart` — sidebar, drawer, menu item rendering
- `frontend/lib/l10n/app_en.arb` — navigation and group labels
- `frontend/test/shared/layout/responsive_shell_scaffold_test.dart` — shell/nav widget tests

## Acceptance criteria

- [ ] Every shell destination sits in a workflow-oriented group with a documented rationale (brief comment or PR note).
- [ ] Navigation item order within each group follows a logical task flow (e.g. register → treat → discharge).
- [ ] All nav labels follow a consistent naming convention; no awkward truncation on desktop expanded sidebar.
- [ ] Mobile drawer shows short labels; desktop expanded sidebar shows full labels.
- [ ] Search still matches both full and short labels.
- [ ] Existing nav/shell tests pass; add or update tests for short-label behavior and any regrouped structure.
- [ ] `flutter analyze` and relevant tests pass.

## Suggested approach

1. Propose a revised grouping + label table (full + short) for review before coding.
2. Implement model change (`shortLabel`), l10n keys, and router updates.
3. Wire short labels into `_MobileShellDrawer` and any narrow-layout nav surfaces.
4. Run widget tests and manually verify at mobile and desktop breakpoints (`.\tool\run_web_5201.ps1`).

## Deliverable

A focused PR that improves navigation IA and labeling, with a short summary of grouping decisions and before/after label changes.
