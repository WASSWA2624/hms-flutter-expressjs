# 41 — Implement Consistent PDF Naming

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 11, Step 41
**Depends on:** 39, 40
**Applies to:** development and production

## Context

Generated PDFs need predictable filenames. For an existing patient the default is `[patient-first-name]-[patient-id]-[order-or-encounter-id].pdf`, for example `John-PAT00125-ORD00452.pdf`, with a defined fallback when parts are missing.

## Requirements

1. Implement a shared filename builder that composes patient first name, patient identifier, and order or encounter identifier in that order, separated by hyphens, with a `.pdf` extension.
2. Define the fallback order when a component is missing: omit the missing part and use the best available combination, ending with a document-type and timestamp form when no patient context exists.
3. Sanitize the filename: strip or transliterate characters unsupported by common filesystems and browsers, collapse whitespace and repeated separators, and cap total length while keeping the identifiers intact.
4. Prevent collisions where the same name would otherwise be produced in one session, using a deterministic suffix rather than a random string.
5. Use the builder from every PDF generation and download path, including reports, receipts, invoices, clinical documents, and workspace printouts.
6. Preserve the name through the browser download path and the mobile share or save path.
7. Keep non-patient documents (reports, administrative exports) on their own documented naming rule using the same builder.
8. Add tests covering the full name, each fallback, sanitization of unsupported characters, non-Latin names, length capping, and collision suffixing.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the shared printing and export paths; do not set filenames ad hoc per screen.
- Do not include tenant-internal identifiers in filenames unless the document already displays them.
- Follow `prompts/.cursor/printing.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1)** A complete patient document downloads as `John-PAT00125-ORD00452.pdf` for the worked example.
- [ ] **AC2 (R2)** Each missing-component case produces the documented fallback name.
- [ ] **AC3 (R3)** Unsupported characters, non-Latin names, and long names produce valid, readable filenames.
- [ ] **AC4 (R4)** Two documents that would collide receive distinct deterministic names.
- [ ] **AC5 (R5, R6, R7)** Every PDF path uses the builder, and names survive browser download and mobile save or share.
- [ ] **AC6 (R8)** New tests pass.
- [ ] **AC7 (R9)** Filenames are identical in development and production.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: download at least six document types in each environment, on web and Android.

## Rollout — Development and Production

- Naming must be identical under both Flutter define files.
- Config: none expected.
- Schema/data: none.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, then confirm downloaded filenames from `https://app.hosspi.com` and the release APK.

## Relevant Files

- `frontend/lib/shared/printing/`, `frontend/lib/core/platform/app_print*.dart`
- `frontend/lib/core/utils/`
- `frontend/lib/features/**/presentation/**/*_print_helpers.dart`
- `frontend/test/shared/printing/`
