# Simplify the Shared Start OPD Encounter Dialog

Use one focused, reusable dialog for every Start OPD encounter entry point. Follow `prompts/.cursor/prompt.mdc`, `.cursor/flows/opd-flow.mdc`, and `frontend/.cursor/index.mdc`.

## Context

The dialog has competing loaders, excessive grouping, and payment controls outside Reception’s responsibility.

## Requirements

1. Route every authorized start action through shared `OpdEncounterDialog`; remove compatible duplicates without changing workflow contracts.
2. While initial data loads, show one centered branded `AppLoadingIndicator` overlay. Block dialog interactions and remove simultaneous inline initial loaders.
3. In appointment/patient-pinned mode, show one flat responsive form: searchable doctor, editable consultation fee and currency, and Payment required.
4. Default Payment required to false. Selecting a doctor populates any configured fee and currency, which remain editable.
5. Remove Payment received, payment method, transaction reference, and payment posting. Billing owns collection and settlement.
6. Preserve active-encounter protection, authorization, validation, localized feedback, recoverable input, and targeted post-success synchronization.

## Constraints

- Do not invent routes, permissions, contracts, transitions, or billing mutations.
- Use shared components and tokens; support accessibility, both themes, and all viewports without overflow.

## Acceptance Criteria

- R1–R5: Every entry point opens the simplified form with one loader; defaults remain editable and payment cannot be recorded.
- R6: Loading, error, retry, validation, cancel, and success remain correct.
- Test reuse, defaults, removed controls, permissions, widths, and themes; run localization generation, Flutter analysis, and relevant tests.

## Relevant Files

- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_encounter_flow.dart`
- `frontend/lib/features/reception/presentation/`
- `frontend/test/shared/`
