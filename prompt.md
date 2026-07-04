# Refine laboratory print report — signature footer layout

## Context
Laboratory result reports (e.g. **Laboratory result report** for DemoCare General Hospital) use the shared print template in `frontend/lib/shared/printing/print_form_template.dart`. Header, patient metadata, results table, and footer note are acceptable — **do not change them**.

## Problem
The **Printed by** / **Verified by** signature block is not finalized. On the current output:

- **Printed by** may show a name (e.g. “Platform Demo”); **Verified by** may have no name.
- Because the name line is omitted when empty, the signature/stamp rule (the horizontal line above where someone signs) sits higher on the right than on the left.
- When the results table is short, the signature block and page footer float mid-page instead of anchoring to the bottom, leaving awkward empty space.

## Goal
Polish only the signature/footer region so the report looks balanced in print preview and on paper.

## Requirements

### 1. Horizontally aligned signature lines
- The **signature/stamp rule** under **Printed by** and **Verified by** must sit on the **same baseline**, left and right.
- Alignment must hold in all cases:
  - name present on one side only
  - names present on both sides
  - names absent on both sides
- Labels (“PRINTED BY”, “VERIFIED BY”) stay at the top of each column; optional names occupy a **fixed reserved area** above the rule so missing names do not shift the line.

### 2. Bottom-anchored footer block
- On the **last page**, treat **signatures + footer note** (“Generated from laboratory workflow data.”) as one footer unit.
- That unit should sit at the **bottom of the printable page area**, even when body content is short.
- Do not overlap or collide with the results table on longer reports; content may grow upward naturally when needed.

### 3. Scope and constraints
- Change layout/CSS (and minimal markup if needed) in the shared print template only.
- Preserve existing labels, copy, and data wiring (`PrintFormSignatures`, l10n keys).
- Apply consistently to all reports using the standard print layout, not only lab reports.
- Keep print-safe behavior: no broken page breaks, no clipped signature area.

## Acceptance criteria
- [ ] With **Printed by** filled and **Verified by** empty, both signature rules align on one horizontal line.
- [ ] With both names filled, both rules still align.
- [ ] With both names empty, both rules still align.
- [ ] Short-content report: signatures and footer note appear at the bottom of the page, not immediately under the table.
- [ ] Long-content report: layout remains readable; signatures stay on the last page only.
- [ ] Existing print template tests pass; add/update tests for signature alignment and bottom anchoring if practical.

## Reference
See attached lab report screenshots: misaligned **Verified by** stamp line vs **Printed by**, and unused vertical space above the signature block.
