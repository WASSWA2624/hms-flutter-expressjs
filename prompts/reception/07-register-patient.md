# Reusable Patient Registration with Duplicate Review

Implement one safe registration flow that returns an existing or created patient to its caller. Follow `prompts/.cursor/prompt.mdc`.

## Context

Registration entry points need consistent duplicate review and caller-aware handoff.

## Requirements

1. Use the shared dialog from every authorized Reception, registry, appointment, and intake entry point.
2. Before creation, compare normalized name, birth date/age, gender, phone, email, and identifiers within authorized scope. Return ranked candidates with a documented 0–100 score, classification, and matched/conflicting fields; weight exact identifiers highest.
3. Show **Use existing patient**, **Register anyway**, and **Cancel** in a focused comparison step. Require confirmation before creating a likely duplicate.
4. Block dismissal and repeat submission while busy. Editing compared fields requires rechecking.
5. Return the existing or created `Patient` to the caller. Continue appointment scheduling; for standalone Reception, show patient details, then return.
6. Synchronize affected lists, counts, searches, and caller state.

## Constraints

- Keep backend RBAC/ABAC authoritative; omit unauthorized data and actions.
- Reuse contracts, validation, localization, and design-system components.
- Support loading, no-match, duplicate, validation, error, cancel, success, themes, and responsive layouts.

## Acceptance Criteria

- R1–R4: Every entry point uses one explainable, guarded review flow.
- R5–R6: Each outcome resumes the correct caller with synchronized state.
- Add scoring, scope, dialog, handoff, authorization, theme, and viewport tests; run backend tests and Flutter analysis.

## Relevant Files

- `frontend/lib/shared/patient_actions/`
- `frontend/lib/features/reception/`
- `frontend/lib/features/patients/`
- `backend/src/modules/patient/`
