# Prescribe Dialog Medicine Card Layout

Simplify the shared Prescribe / Create order medicine cards so each line shows a clear drug identity, stays collapsed by default, and exposes only editable dosing fields—without changing catalog pick, billing, or submit pipelines.

## Context

**Current behavior**

- Clinical Prescribe and Pharmacy Create order both use `ClinicalPrescriptionActionDialog` with collapsible line cards (`_PrescriptionRxListTile` / `AppCollapsibleSection`).
- Screenshots show titles like `DRG-… · Oral · BID · Qty 1 tablet`: identity falls back to drug code/`displayTitle`, and compact meta (route · frequency · qty) is appended in the title.
- Card chrome: checkbox + title on the left; **Remove item** in `headerActions` (left of expand chevron). Chevron is already rightmost in `AppCollapsibleSection`.
- Expanded body field order today: Quantity | Quantity unit → Dose amount | Dose unit → Route | Frequency → Duration | Duration unit → Instructions. Quantity unit and dose unit are editable selects.
- New lines may open expanded (`line.expanded = true` on add). `expanded` defaults to `false`, but add-flow forces open.
- Helpers already exist: `clinicalPrescriptionDrugHeading`, `clinicalPrescriptionDrugGenericName`, `clinicalPrescriptionDrugStrength`, brand/generic/strength in catalog metadata (`pharmacy_drug_catalog_mapper` / clinical drug DTOs).
- Toolbar (search, filters, settings, export, Remove selected, Add medicine, Review billing) and footer (Cancel / Prescribe) stay as today unless noted below.

**Intended behavior**

- Each card title shows **drug code**, **generic name**, **brand in parentheses** (when present), and **strength**—not route/frequency/qty body text.
- Cards are **collapsed by default** (including after Add medicine). Expand via chevron only.
- Header actions: **Remove item** immediately left of the expand chevron; chevron remains rightmost.
- Expanded form is more compact and reordered: quantity pair → duration pair → dose pair → route/frequency → instructions.
- Catalog-fixed units (**quantity unit**, **dose unit**) are read-only/inactive; **quantity**, **dose amount**, **duration**, **duration unit**, **route**, **frequency**, and **instructions** remain editable.
- **Remove selected** stays enabled only when one or more line checkboxes are selected; per-line Remove still removes that line.

**Definitions**

- *Card title:* Collapsed header identity string for one medicine line.
- *Catalog-fixed unit:* Unit seeded from the selected drug (form → quantity unit; strength → dose unit) that must not be user-editable.
- *Body meta:* Route / frequency / qty summary previously appended after the drug name in the title.

## Requirements

1. Update card title to: `{code} {generic} ({brand}) {strength}` when those values exist; omit empty parts and parentheses when brand is missing. Prefer catalog `code` / `generic_name` / `brand_name` / `strength` (and existing display helpers). Do not fall back to a bare `DRG-…` id when a human name is available.
2. Remove body meta (route · frequency · qty) from the title. Keep the title compact (single primary line; ellipsis on overflow). Do not add a subtitle under the title for that meta unless an existing dense pattern already requires it—prefer omission.
3. Keep checkbox leading; keep **Remove item** in `headerActions` immediately left of the expand chevron; chevron remains the rightmost control. Per-line Remove deletes that line and updates selection state.
4. Default every new and existing line card to **collapsed**. Stop forcing `expanded = true` on add (or equivalent). Expanding one card must not expand others.
5. Reorder expanded fields to: **Quantity | Quantity unit** → **Duration | Duration unit** → **Dose amount | Dose unit** → **Route | Frequency** → **Instructions**. Tighten spacing/density so the expanded card is more compact than today without clipping on mobile/tablet/desktop.
6. Make **quantity unit** and **dose unit** inactive/read-only once seeded from the drug; keep **quantity**, **dose amount**, **duration**, **duration unit**, **route**, **frequency**, and **instructions** editable. Preserve dosing sync/validation that depends on those values.
7. Preserve dialog shell: search, filters, settings, export, Add medicine, Review billing (when billing enabled), Cancel, Prescribe/Create order submit, and shared use from Clinical and Pharmacy walk-in. **Remove selected** enables only when ≥1 checkbox is selected; unauthorized/disabled write states keep existing gates.
8. Cover loading/empty/error/success/validation feedback already used by this dialog; theme tokens; light/dark; no overflow of header actions on narrow widths.
9. Tests: title format (code + generic + brand + strength; no route/qty body); cards start collapsed after add; quantity/dose unit controls not editable; field order; Remove item and Remove selected behavior; existing dosing validation still passes.

## Constraints

- Reuse `ClinicalPrescriptionActionDialog`, `AppCollapsibleSection`, `clinical_prescription_display.dart` / dosing helpers, and catalog metadata—no second prescribe UI.
- Do not change pharmacy vs clinical create APIs, catalog picker, billing review payload shape, or anonymous/patient shell outside this card/title/form layout.
- Follow `.cursor/mandatories.mdc` and `prompts/.cursor/prompt.mdc`. Prefer extending display helpers over one-off string logic in the tile.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Card title shows code, generic, optional `(brand)`, and strength; no route/frequency/qty body in the title. | R1, R2 |
| A2 | Chevron is rightmost; Remove item sits immediately left of it; checkbox remains leading. | R3 |
| A3 | Cards are collapsed by default after add and on open; expand is user-driven. | R4 |
| A4 | Expanded field order is quantity → duration → dose → route/frequency → instructions; quantity unit and dose unit are inactive. | R5, R6 |
| A5 | Toolbar/footer and Clinical/Pharmacy shared dialog behavior unchanged aside from card layout; Remove selected requires a selection. | R7 |
| A6 | Tests/manual checks cover title, collapse, read-only units, order, remove actions, validation, viewports, and themes. | R8, R9 |

## Relevant Files

- `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/clinical_prescription_display.dart`
- `frontend/lib/shared/clinical_actions/clinical_prescription_dosing.dart`
- `frontend/lib/shared/components/app_collapsible_section.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_drug_catalog_mapper.dart`
- Tests: `frontend/test/shared/clinical_actions/clinical_prescription_action_dialog_test.dart`, display/dosing tests

## Verification

- FE: title identity; collapsed-by-default; field order; inactive units; Remove item / Remove selected; dosing validation still blocks bad submit.
- Manual: Clinical Prescribe and Pharmacy Create order—add medicine, expand one card, edit quantity/duration/dose/route/frequency, remove one vs selected, submit still succeeds.
- Responsive light/dark: header actions and title do not clip; expanded form usable on narrow width.
