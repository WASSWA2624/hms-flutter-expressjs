# Implementation prompt: Prescribe medication cards — Collapsible + smart dosing

## Goal

Replace each medication line card in the Prescribe dialog with the shared **`AppCollapsibleSection`** chrome, collapsed by default, with a patient-prescription-style header and an expanded inline dosing form that stays synchronized with the selected drug and interrelated fields (dose, frequency, duration, quantity). Block prescribe when lines are incomplete or internally inconsistent.

Primary surface: `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart` (`_PrescriptionRxListTile` / list mobile item builder). Supporting display helpers: `frontend/lib/shared/clinical_actions/clinical_prescription_display.dart`. Shared chrome: `frontend/lib/shared/components/app_collapsible_section.dart`.

## Current behavior (as implemented)

Screenshot / code status today:

| Area | Current |
| --- | --- |
| Card chrome | Custom `DecoratedBox` + padded column (`_PrescriptionRxListTile`), **not** `AppCollapsibleSection` |
| Expansion | Inline dosing fields are **always visible**; no collapse |
| Header | Checkbox + compact summary (`clinicalPrescriptionDrugHeading` + `clinicalPrescriptionCompactHeaderMeta`, e.g. `Acyclovir 400 mg · Oral · BID · Qty 1`) |
| Header actions | **Edit details** + **Remove item** as dense `AppButton`s (resting outline/fill chrome) |
| Expanded body title | Nested `AppFormSection` titled **Prescription details** (`clinicalPrescriptionInlineEditorsLabel`) |
| Field sync | Controllers are independent; adding a drug only sets `drugId` (qty defaults to `1`, route `ORAL`, frequency `BID`). Dose is **not** seeded from catalog strength |
| Submit gate | `_linesAreValid()` requires drug id, quantity &gt; 0, dose amount &gt; 0. Does **not** require dose unit, route, frequency, duration, or cross-field consistency |
| Dialog shell | Search, filters, settings/columns, export, remove selected, add medicine, review billing, Cancel / Prescribe — unchanged and out of redesign scope |

Related pieces that must keep working:

- Catalog multi-add (`showClinicalPrescriptionCatalogDialog`) and duplicate exclusion
- Bulk select + **Remove selected**
- Optional **Edit medicine** full-line dialog (`_openLineDialog` / `_PrescriptionLineCard`) for fields not on the card (drug swap, instructions) unless folded into the expanded body in the same change
- Billing review / submit payload keys (`drug_id`, `quantity`, `quantity_unit`, `dose_amount`, `dose_unit`, `route`, `frequency`, `duration_value`, `duration_unit`, `instructions`)
- Existing tests in `frontend/test/shared/clinical_actions/clinical_prescription_action_dialog_test.dart`

## Intended behavior

### 1. Card = `AppCollapsibleSection`

Replace the custom card shell with **`AppCollapsibleSection`** (prefer it directly over nesting a titled `AppFormSection` solely for chrome).

- **`initiallyExpanded: false`** (collapsed by default when a medicine is added).
- Tapping the **header** toggles expand/collapse (built-in `InkWell` on `AppCollapsibleSection`). Header actions must remain independently tappable without stealing the toggle (existing `headerActions` pattern).
- Preserve list selection: keep the **checkbox** for bulk remove (e.g. via `titleWidget` / leading content). Do not drop multi-select.

### 2. Collapsed header = patient-prescription summary

Header title content should read like the line on a patient prescription, driven by live form + catalog values, for example:

**`{generic name} {strength} · {route} · {frequency} · Qty {quantity}[{unit}]`**

Reuse / extend helpers in `clinical_prescription_display.dart` (`clinicalPrescriptionDrugHeading`, `clinicalPrescriptionCompactHeaderMeta`, paper summary helpers) so table cells and card headers stay consistent. Update the summary whenever related fields change.

Do **not** invent a second competing summary format if an existing helper already covers this; extend rather than duplicate.

### 3. Remove action placement and chrome

- Place **Remove** in `headerActions` (immediately **left of the chevron**).
- Style: icon + label only — **no resting fill, no border** (use `AppCollapsibleSection`’s plain header action chrome / `AppActionLabelScope(plainChrome: true)` already applied to `headerActions`).
- Keep confirm-before-delete behavior consistent with today’s remove flow.
- **Remove “Edit details” from the always-visible card header.** Expansion replaces that affordance for the inline dosing fields. Keep the full-line **Edit medicine** dialog only if instructions / drug change still need a separate surface; otherwise move those fields into the expanded body and retire the redundant CTA.

### 4. Expanded body = dosing form without section title

When expanded, show the existing inline editors (quantity, quantity unit, dose amount, dose unit, route, frequency, duration, duration unit) **without** the **Prescription details** / `clinicalPrescriptionInlineEditorsLabel` section title.

- Prefer untitled / unframed field layout inside the collapsible body (compact density, same `AppResponsiveFieldRow` patterns).
- Do not nest a second collapsible titled “Prescription details”.

### 5. Form synchronized with drug catalog

When a medicine is added (or drug id changes), seed and bind from the selected `ClinicalActionCatalogOption`:

| Form concern | Source |
| --- | --- |
| Display name / heading | Generic name + strength (`clinicalPrescriptionDrugHeading` / metadata) |
| Default dose amount / unit | Parsed from catalog **strength** when present and parseable |
| Sensible defaults already in use | Keep route / frequency defaults unless catalog metadata supplies better defaults |

The form must “know” which drug it is editing: changing catalog-derived strength context should refresh defaults **only when the user has not already customized** that field (or when the drug id itself changes). Do not wipe user edits on every rebuild.

### 6. Intelligent field interconnection

Implement a deterministic dosing consistency model so related numeric fields stay coherent for common solid/oral prescribe paths. Minimum expected behavior:

1. **Frequency → doses/day** map (e.g. OD=1, BID=2, TID=3, QID=4, Q6H≈4, Q8H≈3, Q12H=2, ONCE/STAT=1; PRN does not auto-drive quantity).
2. When **dose amount**, **dose unit**, **strength**, **frequency**, and **duration** are known and units are compatible, **derive / update quantity** (ceiling to whole dispense units when quantity is integer).
3. When the user edits **quantity** (or duration) with enough other fields known, **recompute the dependent field** that was not the last edited control (last-edited wins; avoid feedback loops).
4. If the user enters a combination that **cannot tally** (e.g. dose unit incompatible with strength unit, or quantity that cannot cover frequency × duration at the stated dose), surface a clear **inline validation** error on the offending field(s) and treat the line as invalid for submit.
5. Changing dose amount should refresh dependent derived values when the previous values were auto-derived or still match the prior derivation; do not fight an explicit user override of quantity/duration until inputs become inconsistent again.

Document the formula in code comments briefly (e.g. `quantity ≈ dosesPerDay × durationInDays × (doseAmount / strengthAmount)` when units match). Prefer a small pure helper (testable) over ad-hoc `setState` math scattered in the widget.

Out of scope for v1 unless already available in catalog metadata: complex liquid reconstitutions, tapering schedules, multi-ingredient strengths.

### 7. Do not allow prescribe with errors or insufficient entries

Tighten `_linesAreValid()` / submit gating (and mirror rules in the edit-line dialog if it remains):

**Required per line (minimum):**

- Drug selected
- Quantity &gt; 0
- Dose amount &gt; 0
- Dose unit
- Route
- Frequency
- Duration value &gt; 0 and duration unit (unless frequency is STAT/ONCE where product rules already allow omitting duration — if so, encode that exception explicitly)

**Also block when:**

- Cross-field consistency validation fails (from §6)
- Any visible field validator fails

On block: keep the existing validation failure banner pattern; prefer expanding / focusing the first invalid line so the user can fix it. Do not submit partial or silently coerced payloads.

## Gap to close

| Area | Gap |
| --- | --- |
| Card chrome | Custom tile vs `AppCollapsibleSection` |
| Default state | Always expanded vs collapsed by default |
| Header actions | Edit + bordered Remove vs plain Remove left of chevron |
| Body title | “Prescription details” still shown |
| Drug seeding | `drugId` only; strength not applied to dose |
| Field linkage | No dose ↔ frequency ↔ duration ↔ quantity sync |
| Validation | Incomplete required set; no consistency checks |
| Tests | Assert always-open “Prescription details” / Edit details; need collapse + sync + stricter submit coverage |

## Requirements

### UI (`clinical_prescription_action_dialog.dart`)

1. Rebuild `_PrescriptionRxListTile` (or replace it) on **`AppCollapsibleSection`** with collapsed default, live prescription-style title, checkbox preserved, Remove in `headerActions`.
2. Expanded child = inline dosing fields **without** “Prescription details” title.
3. Wire `onChanged` so header summary and derived fields update immediately.
4. Preserve dialog toolbar, catalog add, bulk remove, billing review, and submit payload shape unless a field becomes newly required (still send the same keys; requiredness is client-side gate).
5. Do **not** redesign the Prescribe dialog shell, search bar, or catalog picker in this ticket.

### Display helpers (`clinical_prescription_display.dart`)

- Prefer extending existing summary helpers for the collapsible title.
- Add pure helpers for strength parsing / doses-per-day / quantity derivation as needed; keep them unit-testable without Flutter where practical.

### Localization

- Reuse existing remove / field labels.
- Do not hard-code new user-facing English in widgets; add `app_en.arb` keys only for new validation messages (e.g. inconsistent quantity vs duration).
- “Prescription details” title should no longer appear on the card; unused key can remain until a cleanup pass.

### Tests

Update `clinical_prescription_action_dialog_test.dart`:

- Added medicine card is **collapsed** by default (inline dose labels hidden until expand).
- Header shows prescription-style summary; Remove is available; **Edit details** is not in the card header (unless explicitly kept for the full dialog — assert the chosen behavior).
- Expanding reveals dose/route/frequency fields **without** “Prescription details”.
- Catalog strength seeds dose when applicable.
- Changing frequency/duration updates quantity (or shows inconsistency) per the sync rules.
- Prescribe remains blocked on incomplete **and** inconsistent lines; succeeds on a coherent complete line.
- Existing catalog add / remove-selected / billing-disabled-when-empty behaviors still pass.

## Non-goals / preserve

- Do not change backend prescribe APIs or billing resolve beyond client validation.
- Do not remove search, filters, column settings, export, add medicine, or review billing.
- Do not force-expand all cards; default remains collapsed.
- Do not redesign `AppCollapsibleSection` itself unless a missing affordance (e.g. leading checkbox slot) truly cannot be done via `titleWidget` / `headerActions`.
- Do not invent a full clinical decision-support / interaction-checking system; scope is dosing arithmetic + required fields only.

## Acceptance criteria

- [ ] Each medicine line uses `AppCollapsibleSection`, **collapsed by default**.
- [ ] Header shows live generic + strength + route + frequency + quantity summary; tapping header toggles expand/collapse.
- [ ] Remove sits left of the chevron with plain icon+label chrome (no fill/border).
- [ ] Expanded form has **no** “Prescription details” title; fields remain editable inline.
- [ ] Form seeds from drug catalog (name/strength) and keeps dose/frequency/duration/quantity interconnected with last-edit-safe updates.
- [ ] Prescribe is blocked for missing required fields or inconsistent dosing; allowed only for complete, consistent lines.
- [ ] Checkbox multi-select + dialog shell + submit payload shape preserved.
- [ ] Widget tests updated for collapse, header, sync, and stricter validation.

## Implementation notes

- `AppCollapsibleSection.headerActions` already applies plain chrome and stops toggle when those actions are pressed — use that for Remove.
- Selection highlight: if the old selected fill on the custom `DecoratedBox` is still desired, pass `backgroundColor` / `borderColor` on the section when selected rather than wrapping another card.
- Prefer one small `_PrescriptionDosingSync` (or similar) helper with an explicit `lastEditedField` enum to prevent oscillation.
- When seeding from strength strings like `400 mg`, parse amount + unit defensively; if unparsable, leave dose blank and rely on required-field validation.
- Match existing `AppButton` / l10n / form field patterns; no new visual language.
