# Clinical workspace worklist simplification

Simplify the Clinical (Doctors) worklist so tabs, counts, filters, table settings, and next-action cells match a doctor-facing outpatient queue—not a generic patient list.

## Context

- Screen: Clinical workspace (`/clinical`), feature `frontend/lib/features/clinical/`.
- Current tabs: All, Waiting review, Urgent, Results ready, In consultation, Completed, Follow-ups.
- Counts today are derived from the **active scoped page**, so switching tabs changes other tab badges.
- Worklist already excludes IPD/inpatient rows (`clinicalWorklistEntryIsOutpatient`); keep that invariant.
- Reuse design-system list table, advanced filters, column visibility, clinical access gates, and existing clinical actions. Follow `.cursor/locale-development.mdc` for English strings.
- Permission/billing inventories and `prompts/ui-permissions/clinical/*` for removed tabs must be retired or remapped with the strip change.

### Tab definitions

| Tab | Label | Membership |
| --- | --- | --- |
| Pending (rename of All) | Pending | Open outpatient encounters intended for doctors (sent / awaiting doctor work). Not a facility-wide patient census. Exclude IPD. |
| Assigned to me | Assigned to me | Open (non-terminal) outpatient encounters whose **assigned provider/clinician matches the logged-in user**. Empty when the session has no resolvable clinician identity. Exclude IPD and unassigned rows. |
| Urgent | Urgent | Pending set where `isUrgent` and not terminal. |
| Results ready | Results ready | Non-terminal outpatient encounters with lab/radiology (or equivalent) results ready that doctors have **not yet dispositioned**. |
| Completed today | Completed today | Terminal outpatient encounters completed **today** (calendar day in facility/local handling already used by completed scope). |
| Follow-ups | Follow-ups | Existing follow-ups worklist (unchanged behavior). |

**Remove:** Waiting review, In consultation (strip, scopes, deep links, dead inventories/tests). Map legacy URLs (`waiting-review`, `in-consultation`) to Pending (or nearest allowed tab) without breaking navigation.

## Requirements

1. Replace the tab strip with exactly: **Pending**, **Assigned to me**, **Urgent**, **Results ready**, **Completed today**, **Follow-ups** (order as listed), using localized labels; update enums, section query values, icons, tones, default columns, and access helpers accordingly.
2. Keep Pending membership outpatient-only open doctor work as defined above; do not show IPD admissions on this screen.
3. Implement **Assigned to me** by matching the encounter’s assigned provider/staff id (or equivalent stable key already on the worklist entry) to the authenticated user’s clinician identity from the existing session/access model—not by display-name string alone when an id is available.
4. Keep Urgent and Results ready semantics as defined; Results ready must mean results available and not yet dispositioned—not merely “any diagnostic ordered.”
5. Rename Completed → Completed today in UI; preserve today-bounded terminal membership already used by completed scope (adjust only if current behavior diverges).
6. Load and display **independent facet counts** for Pending, Assigned to me, Urgent, Results ready, and Completed today so changing the active tab (or its page) does **not** change other tab badges. Follow-ups may keep its existing count source if already independent.
7. Expand advanced Filters so every practical worklist field is filterable: at minimum patient name/id/phone, encounter id, queue/source queue, status, provider (including unassigned), encounter type, location, last-updated date range, urgency, and results-ready—plus any other fields already present on the row/entry. Filters must compose with the active tab scope (tab ∩ filters), clear/reset, and show active-filter state. On Assigned to me, do not require the user to re-select themselves as provider; the tab already scopes to self.
8. Make Table settings comprehensive: all available columns listed with clear labels, sensible defaults per tab, stable visibility/width persistence, and a tidy ordered layout in the settings dialog (easy scan/toggle/reorder if the shared component already supports order).
9. Enlarge and restyle **Next action** cells so labels and icons are readable and comfortably tappable on desktop and mobile—not compact/tiny chrome—while reusing existing clinical/workflow action wiring and permission gates.
10. Preserve authorized UI states: permission-filtered tabs, loading, empty, error/retry, success, validation, and visible feedback; synchronize lists/detail/counts after mutations (including after assign/reassign).
11. Update English l10n (`app_en.arb`), tests, and remove or remap obsolete waiting-review / in-consultation permission, billing-inventory, and section code so dead tabs do not remain reachable. Add section/query support for Assigned to me (e.g. `assigned-to-me`).

Optional enhancements: none.

## Constraints

- Reuse existing clinical controllers, repositories, design-system table/filter/settings components, routes, and `AppAccessPolicy` gates; no second permission vocabulary.
- Backend RBAC/ABAC remains authoritative; unauthorized tabs/actions/columns must not render.
- Theme tokens; responsive mobile/tablet/desktop; light and dark.
- No unrelated refactors outside Clinical worklist chrome, scopes, counts, filters, settings, and next-action presentation.
- Do not recreate removed `screens/` inventories.

## Acceptance Criteria

- AC1 (Req 1, 11): Tab strip shows only Pending, Assigned to me, Urgent, Results ready, Completed today, Follow-ups; Waiting review and In consultation are gone from UI and dead code paths are cleaned or remapped.
- AC2 (Req 2–5): Each tab’s list matches its definition (outpatient-only Pending; self-assigned open encounters; Urgent; results-ready-not-dispositioned; completed today; follow-ups unchanged).
- AC3 (Req 3): Assigned to me shows only encounters assigned to the logged-in doctor; unassigned and other clinicians’ patients are absent; empty state when none or identity cannot be resolved.
- AC4 (Req 6): Switching tabs leaves other tab counts unchanged for the same underlying data set; counts update only when data/mutations/refreshes change facets.
- AC5 (Req 7): Filters cover the listed fields, compose with tab scope, and clear/reset correctly.
- AC6 (Req 8): Table settings expose available columns in a clear ordered dialog with persistence.
- AC7 (Req 9): Next action controls are visually larger/clearer and remain permission-gated and actionable.
- AC8 (Req 10–11): Loading/empty/error/success states work; post-mutation sync includes list and independent counts; English strings and tests updated; unauthorized UI stays absent.

## Relevant Files

- `frontend/lib/features/clinical/` (page, controller, entities, access, billing inventories)
- `frontend/lib/shared/clinical_actions/`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/clinical/`
- `prompts/ui-permissions/clinical/`
- `.cursor/locale-development.mdc`
- `.cursor/access/permissions.mdc`
- `frontend/.cursor/permissions.mdc`
