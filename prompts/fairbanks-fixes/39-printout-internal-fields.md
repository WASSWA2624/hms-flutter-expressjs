# 39 — Uncheck Internal Information From Default Printouts

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 11, Step 39
**Depends on:** none
**Applies to:** development and production

## Context

Printouts include internal administrative fields by default — facility identifier, facility type, tenant and internal identifiers, and similar. These must stay available as options but be unchecked by default, so a user enables them deliberately. The print option surfaces are the `*_print_options.dart` widgets and the shared print preview.

## Requirements

1. Inventory every print option across features and classify each as patient- or document-facing versus internal administrative.
2. Set every internal administrative option to unchecked by default, while keeping it visible and selectable in the print options UI.
3. Keep document-facing options at their current defaults so existing printouts do not lose required content.
4. Apply the default consistently across every print surface, including receipts, invoices, clinical documents, reports, and workspace printouts, using the shared print options model rather than per-screen defaults.
5. Persist a user manual selection for the current session only, and return to the defaults on a new session unless a documented preference feature already exists.
6. Ensure the printed layout remains correct when internal fields are hidden, with no empty blocks, stray labels, or broken alignment.
7. Add tests asserting internal options default to unchecked and that enabling one renders the field.
8. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not remove any option; only change its default.
- Do not hide a field that is legally or clinically required on a document.
- Reuse the shared print options components; follow `prompts/.cursor/printing.mdc` and `localization.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1, R2)** The option inventory is recorded, and every internal administrative option is unchecked by default in every print surface.
- [ ] **AC2 (R3)** Document-facing content is unchanged by default.
- [ ] **AC3 (R4)** The default is applied through the shared model, with no per-screen override remaining.
- [ ] **AC4 (R5)** A manual selection applies for the session and resets afterwards.
- [ ] **AC5 (R6)** Printed output with internal fields hidden has no empty blocks or layout breaks.
- [ ] **AC6 (R7)** New tests pass.
- [ ] **AC7 (R8)** Defaults are identical in development and production.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: print preview and physical or PDF print of at least six document types in each environment, in both themes.

## Rollout — Development and Production

- Defaults must be identical under both Flutter define files; no environment-specific print defaults.
- Config: mirror any print-related define in `frontend/env/development.json.example` and `frontend/env/production.json.example`.
- Schema/data: none expected.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, then re-check print defaults in production.

## Relevant Files

- `frontend/lib/shared/printing/`, `frontend/lib/shared/printing/templates/`, `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/features/**/presentation/**/*_print_options.dart`
- `frontend/lib/features/**/presentation/**/*_print_helpers.dart`
- `frontend/lib/app/printing/print_form_template_context.dart`
