# Patient List Table — Column Simplification

## Objective

Simplify **patient list/table rows** across HOSSPI HMS so each visible cell shows **one line of information**. Remove redundant identifiers and facility context from list views. Staff are already scoped to their logged-in facility, so facility names do not belong in patient list rows.

**Primary screen:** Patient registry (`/patients`) — see attached screenshot.

**Convention:** Apply the same single-line patient row rules to **every patient list** in the app (registry, OPD/IPD worklists, nursing, pharmacy, lab, emergency pickers, admission dialogs, etc.).

---

## Column Changes (Patient Registry)

| Column | Current | Target |
| ------ | ------- | ------ |
| **Patient no.** | MRN with copy-to-clipboard | Keep MRN text only — **remove copy action** |
| **Patient** | Name + facility subtitle (e.g. "DemoCare General Hospital") | Rename header to **"Patient name"**; show **name only** (single line) |
| **Age / sex** | `32 / Female` | **No change** |
| **Phone / ID** | Phone on line 1, MRN repeated on line 2 | Rename header to **"Phone"**; show **phone only** (fallback to email if no phone; do not repeat MRN) |
| **Alerts** | Status chips / "No alerts" | Keep; ensure alert chips do not force multi-line rows where avoidable |

### Rationale

- MRN appears once in **Patient no.** — repeating it under Phone is redundant.
- Facility is implicit from the user's session — do not show `facilityLabel` in list rows (including for super-admin list views).
- Copy-to-clipboard on every row adds noise; identifiers remain copyable in patient **detail** views where needed.

---

## Implementation Notes

### Registry (start here)

| Area | Location |
| ---- | -------- |
| Table columns & cells | `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` — `_PatientList`, `_PatientNumberCell`, `_PatientNameCell`, `_PatientContactIdentifierCell`, `_PatientMobileRow` |
| Facility subtitle toggle | `_showPatientFacilityInList` — remove facility from list rows entirely |
| Localization | `frontend/lib/l10n/app_en.arb` — update `patientsPatientColumnLabel`, `patientsPhoneIdentifierColumnLabel` (and regenerate l10n) |

**Concrete edits:**

1. `_PatientNumberCell` — render plain `Text` for `effectiveIdentifier ?? publicId`; drop `AppCopyableIdentifier`.
2. `_PatientNameCell` — single-line `Text` for `effectiveDisplayName`; remove `facilitySubtitle` and `showFacilityLabel` plumbing. Move "Registration incomplete" to **Alerts** column if not already there.
3. `_PatientContactIdentifierCell` — phone (or email) only; remove secondary identifier line.
4. Update column sort comparators to match new single-field semantics.

### Responsive layouts

| Breakpoint | Guidance |
| ---------- | -------- |
| **Desktop / wide** | Table columns as above; `maxLines: 1`, `TextOverflow.ellipsis` on all data cells |
| **Tablet** | Same columns where space allows; hide lowest-priority optional columns via existing `AppListTable` visibility controls |
| **Mobile** | `_PatientMobileRow` — title = patient name; subtitle = patient no. only (not facility); trailing = alerts/status. No duplicate MRN in subtitle + details |

### Cross-module patient lists

Audit and align any list/picker that shows patient name + facility + identifier in stacked lines. Prefer a shared compact row pattern (extract to `frontend/lib/shared/` only if 3+ call sites repeat the same layout).

Do **not** change patient **detail** panels, dialogs, or clinical context headers — facility and copyable identifiers remain appropriate there.

---

## Standards

- All user-visible labels via `app_en.arb` (no hardcoded strings).
- Follow `frontend/.cursor/design-system.mdc`, `ui-patterns.mdc`, `components.mdc`.
- No API or schema changes required.

---

## Acceptance Criteria

- [ ] Patient registry table: each data cell is a single line; no copy icon on Patient no.
- [ ] Column headers read **Patient no.**, **Patient name**, **Age / sex**, **Phone**, **Alerts** (plus existing optional columns).
- [ ] No facility name in any patient list row.
- [ ] MRN/identifier shown once per row (Patient no. column only).
- [ ] Mobile and tablet layouts follow the same rules without stacked duplicates.
- [ ] Other patient lists in the app match this convention where they show the same fields.
- [ ] `flutter analyze` and `flutter test` pass.

---

## Quality Gate

From `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```
