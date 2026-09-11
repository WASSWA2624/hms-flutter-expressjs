# 40 — Fix the Logo Print Layout

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 11, Step 40
**Depends on:** 19
**Applies to:** development and production

## Context

On printouts the facility logo sits too close to its surrounding border and can overflow or distort depending on its dimensions. Padding between logo and border must increase, and containment must hold for any aspect ratio.

## Requirements

1. Increase the padding between the logo and its border in the shared print header so the gap is visually balanced at the printed size, not only on screen.
2. Contain the logo within its box for any aspect ratio and resolution, scaling proportionally without cropping, stretching, or overflowing the border.
3. Define a maximum printed logo height and width so an unusually large image cannot dominate or break the header.
4. Keep header alignment with facility name and document title intact for wide, tall, and square logos.
5. Apply the fix in the shared print header used by every printable document, rather than per template.
6. Handle the missing-logo case so the header keeps its layout without an empty bordered box.
7. Verify the result in generated PDF output as well as the browser print path, since rendering differs.
8. Add a test or golden check covering at least a wide, a tall, and a square logo in the print header.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the shared print header component; follow `prompts/.cursor/printing.mdc`.
- Do not change the logo source, storage, or URL handling from step 19.
- Keep paper-size assumptions consistent with existing templates.

## Acceptance Criteria

- [ ] **AC1 (R1)** The printed gap between logo and border is visibly increased and consistent across documents.
- [ ] **AC2 (R2, R3)** Wide, tall, square, small, and oversized logos remain contained, proportional, and within the maximum bounds.
- [ ] **AC3 (R4)** Header alignment holds for every tested logo shape.
- [ ] **AC4 (R5)** The change lives in the shared header and applies to every printable document.
- [ ] **AC5 (R6)** A facility without a logo prints a clean header with no empty bordered box.
- [ ] **AC6 (R7)** PDF and browser print output both render correctly.
- [ ] **AC7 (R8)** The new test or golden check passes.
- [ ] **AC8 (R9)** Output is identical in development and production.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: print or export at least five documents with different logo shapes in each environment.

## Rollout — Development and Production

- Output must be identical under both Flutter define files.
- Config: none expected.
- Schema/data: none.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, then compare printed output from `https://app.hosspi.com` against the local build.

## Relevant Files

- `frontend/lib/shared/printing/`, `frontend/lib/shared/printing/templates/`
- `frontend/lib/shared/printing/app_print_preview.dart`
- `frontend/lib/core/platform/app_print.dart`, `app_print_web.dart`
- `frontend/test/shared/printing/`
