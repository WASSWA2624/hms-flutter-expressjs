# Clarify Active Visits and Reception Patient Count

Update `/reception?section=active` so Active visits lists in-facility patients with open OPD encounters, and the Reception menu badge counts unique patients across reception sections.

## Context

Active visits may omit open visits via a stage subset. The Reception menu badge reuses OPD workload instead of reception patient load. Follow `prompts/.cursor/prompt.mdc`.

## Requirements

1. On Active visits, show synchronized non-terminal OPD flows for today with open encounters for patients still in the facility. Exclude closed, completed, discharged, and cancelled encounters.
2. Keep Current step and Next action as read-only flow labels. Do not invent stages or add clinical controls beyond authorized row hubs.
3. Apply the same membership rules to search, filters, sorting, settings, tab counts, and mobile cards.
4. Set the Reception shell menu badge to unique patients across Appointments, Desk queue, Active visits, and Payment gate—patients, not encounters or duplicates.
5. Keep tab badges as section row counts; only the shell Reception badge uses the unique-patient total.

## Constraints

- Reuse OPD sync, terminal helpers, authorization, localization, shell badges, and design-system components.
- Do not change backend contracts, clinical transitions, or unrelated tabs beyond badge math.
- Support loading, empty, error, themes, and responsive states.

## Acceptance Criteria

- R1–R3: Active visits shows today’s open in-facility patients with correct labels, search, filters, and counts.
- R4–R5: Reception menu badge equals unique patients across four sections; tab badges stay section-local.
- Add/update reception and shell-badge tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/app/router/shell_badge_counts.dart`
- `frontend/lib/app/router/app_router.dart`
- `frontend/test/features/reception/presentation/`
