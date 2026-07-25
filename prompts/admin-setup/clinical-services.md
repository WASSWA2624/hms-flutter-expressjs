# Clinical Services — Lab test create/edit (parity with radiology)

Scope for now: **lab tests only** (panels later). Apply the same create/edit robustness pattern used for radiology procedures under Clinical Services (`/admin/setup?section=clinical-services` → Lab nested tab).

Primary surfaces:
- `LabCatalogItemMutationDialog` / shared `LabTestDefinitionForm`
- Sources: `frontend/lib/shared/lab_catalog/`, `clinical_catalog_admin_dialogs.dart`
- Screen map: `screens/admin-setup/clinical-services.md`
- Radiology reference: similarity guard + dialogs in radiology catalog mutation flow

Enforce `.cursor/mandatories.mdc` (loading feedback, responsive UI, realtime sync, migrations if needed, role- and action-based access).

---

## 1. Pre-save similarity check (required)

Before creating or updating a lab test in the database:

1. Run a **comprehensive similarity check** against existing catalog tests (tenant + standard, same spirit as radiology).
2. **Show similarity results** to the user (matches, field-level similarity %, exact conflicts).
3. Only commit after the user proceeds (or chooses use-existing when that path applies).
4. Exact name/code conflicts must **block** save with clear field errors — no proceed path.
5. Near-matches: show a similarity dialog (Cancel / Use existing / Proceed), mirror radiology UX.
6. Create path: if no similar matches, keep a clear “no similar” confirmation before first save (edit may skip when radiology does).
7. When the user accepts a similar match, send `confirm_similar: true` (or equivalent) on submit; clearing name/code must reset acceptance state.
8. Show in-button / action loading while the similarity scan runs (`AppButton.isLoading`), not a full-page logo loader.

Respect all **role-based and action-based** gates for create, edit, delete, and configure — UI and backend.

---

## 2. Create/edit lab test form — look & feel

Polish `LabTestDefinitionForm` so it feels intentional and consistent with radiology mutation dialogs and shared form patterns (`AppFormSection`, `AppResponsiveFieldRow`, `AppSelectField`).

### Layout / styling fixes (from current UI)

| Area | Problem | Direction |
| ---- | ------- | --------- |
| **Category** | Searchable field in a two-column row next to code; visually uneven vs **Result kind** | Match select styling; ensure equal column width/height with code; full-width behavior should match sibling select fields (not a cramped half-width oddity). |
| **Result kind** | Looks fine | Keep as the visual reference for selects. |
| **Unit options** | Add-row / chip footer looks awkward | Restyle the option list (search + add + chips) so spacing, alignment, and trailing add control feel finished. |
| **Reference ranges** | Fields packed too tightly | Increase vertical/horizontal rhythm; consistent gaps; cards should breathe. |
| **Add reference range** | Button sits below the range cards | Move **+ Add reference range** to the **top** of the reference-ranges block (with range count), above the cards. |

Overall: cleaner section hierarchy (Test identity → Result configuration → Reference ranges), no cramped grids, responsive from `xs`/`sm` through `xxl`.

---

## 3. Reference-range intelligence

Make reference ranges smart and non-duplicative:

- Prevent **duplicate ranges** for the same applicability key (e.g. label “Adult” + same gender + same age band/unit must not be addable twice).
- When adding a range, disable or block duplicates and surface a clear validation message.
- Prefer curated labels (Adult, Pediatric, Neonate, etc.) via select / picker where it fits — avoid free-text-only where a closed set is safer.
- Validate age min/max, normal min/max, critical min/max (numeric, min ≤ max where both set; age min < age max).
- Critical bounds should not contradict normal bounds when both are present.
- Empty optional ranges should not fail save; incomplete/invalid filled ranges must.

---

## 4. Prefer modal pickers over plain text where appropriate

Replace free-text fields with searchable selects or small modal dialogs when values come from catalogs or closed sets, for example:

- Category (known categories + values from loaded rows)
- Specimen type
- Default unit / unit options (suggestions + add)
- Reference range label presets
- Gender / age unit (already selects — keep consistency)

Do not invent new dialog chrome; reuse `AppDialog` / shared select patterns. Keep create/edit and facility configure forms sharing `LabTestDefinitionForm` where possible.

---

## 5. Validation & robustness

- Required: test name, result kind.
- Optional: code, category, specimen, units, description, ranges — but validate format when provided.
- Code uniqueness / exact conflicts via similarity guard + field errors.
- Disable Save while saving or while similarity check is in progress; keep Cancel available when safe.
- Localized strings for all new copy (no hard-coded user-facing English).
- After successful save: immediate UI sync for the acting user; respect realtime rules for shared catalog data.

---

## 6. Out of scope (for this pass)

- Lab **panels** create/edit parity (note for a follow-up).
- Redesigning the whole Clinical Services desk chrome beyond the lab test mutation form and its save guard.

---

## Acceptance checklist

- [ ] Create and edit lab test run similarity before DB write; exact conflicts block; near-matches show dialog; proceed requires confirmation.
- [ ] Role/action permissions respected on UI and API.
- [ ] Category / unit options / reference-range layout look polished and evenly spaced; Add range is at the top.
- [ ] Duplicate reference ranges (same Adult/gender/age applicability) cannot be saved.
- [ ] Catalog-backed fields use select/modal patterns instead of bare text where appropriate.
- [ ] Form works across breakpoints; loading feedback on Save/similarity; l10n complete.
