# Patient Detail Dialog — UI/UX Refinement Prompt

## Objective

Refine the **Patient Detail** modal (`PatientDetailDialog`) so the summary header, contextual actions, and related-record sections are clearer, more compact, and workflow-aware. Prevent duplicate downstream actions by surfacing what is already in progress.

**Primary file:** `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` (`PatientDetailDialog`, `_PatientContextHeader`, `_QuickActions`)

**Shared building blocks:** `AppWorkspacePatientContextHeader`, `AppExpandableRecordSection`, `AppPatientDetailDialog`, dialogs under `frontend/lib/shared/components/` and `frontend/lib/shared/clinical_actions/`

**Reference:** [08-patients-module-prompt.md](prompts/08-patients-module-prompt.md) — modal-first, reuse shared components, RBAC + facility scope.

---

## Current Issues (from screenshots)

1. Summary card shows a generic avatar icon that adds no value.
2. MRN, type label, and value wrap onto separate lines instead of a single `Label: value` row.
3. Age shows as a bare number (`32`) without units; gender has no icon.
4. Facility is always shown even when the user has a single-facility scope.
5. Quick actions are incomplete, mislabeled, and include redundant **Copy patient ID**.
6. No section for **active** appointments, encounters, or pending requests — users can start duplicate workflows.
7. Record sections (Identifiers, Contacts, Guardians, etc.) stack label and value on two lines; add/edit/delete affordances are icon-only and not responsive.

---

## 1. Summary Header (`_PatientContextHeader`)

| Change | Requirement |
| ------ | ----------- |
| Remove avatar | Drop the person icon box from `AppWorkspacePatientContextHeader` identity row (or add a `showAvatar` flag defaulting to `false` for patient detail). |
| Patient ID | Display as **`{label}: {value}`** on one line (e.g. `MRN: DMO-PAT-001`). Keep the existing copy-to-clipboard control on the value. |
| Age | Format human-readably with localized units — e.g. `32 years, 10 months` (or `10 months` / `14 days` when under 1 year). Extract a shared formatter if needed. |
| Gender | Show a gender icon (`male` / `female` / neutral fallback) beside the localized gender label. |
| Facility | Show **only** when `PatientRegistrationScope.resolve(...).showFacilityPicker == true` (super admin, tenant admin, or tenant with multiple facilities). Hide for single-facility users. |
| Visit | Rename label from **Visit** to **Visit ID**; keep copyable `publicId`. |
| Status & alerts | Keep active/inactive badge and allergy/incomplete-registration alerts as today. |

Keep patient name in the dialog title bar only (`showPatientName: false` in the header — already set).

---

## 2. Active Work Section (new)

Add a section **above Quick actions** that lists in-progress or open items for this patient, sourced from `PatientDetail.workspace` and `patient.currentVisit`:

- Upcoming / in-progress **appointments**
- Open **OPD** or **Emergency** encounters
- Active **IPD admissions**
- Pending **lab**, **radiology**, **physiotherapy**, or **theater** requests (including walk-in requests not routed through OPD)

**Behavior:**

- Each row: status chip, human title, date/time, and a **View / Continue** action that opens the correct shared workspace dialog or deep-link — do not navigate to a new route.
- When an item exists, **suppress** the matching quick action (e.g. hide **Schedule appointment** if an open appointment exists; show **View active OPD encounter** instead of **Start OPD encounter** — partial logic exists in `_QuickActions`; extend consistently).
- Empty state: omit the section entirely (do not show “No active items”).

---

## 3. Quick Actions (`_QuickActions`)

### Rename / remove

| Current | Target |
| ------- | ------ |
| Appointment | **Schedule appointment** |
| Start / Check in OPD | **Start OPD encounter** |
| Copy patient ID | **Remove** (header already copies MRN / patient ID) |
| Patient report | Keep |

### Add (permission- and module-gated)

| Action | Shared dialog / entry point |
| ------ | --------------------------- |
| Request radiology | `clinical_radiology_order_action_dialog.dart` |
| Lab request | `clinical_lab_order_action_dialog.dart` |
| Theater procedure | Theater schedule-case form / dialog |
| Physiotherapy session | Physiotherapy referral / session dialog |
| Admit patient | `ipd_start_admission_dialog.dart` |

Wire every action through existing shared modals in `frontend/lib/shared/` — **no one-off forms** in the patients module.

Respect `AccessGate` / module entitlements; hide actions the user cannot perform.

---

## 4. Related-Record Sections

Applies to: Identifiers, Contacts, Guardians, Allergies, Medical history, Documents, Consents (and Timeline unchanged).

| Requirement | Detail |
| ----------- | ------ |
| Inline rows | Each item on **one line**: `{type label}: {value}` (e.g. `MRN: DMO-PAT-001`, `Phone: +15550000001`). Use `itemTitle` + `itemSubtitle` composition or a new `AppRecordInlineRow` helper in `app_record_section.dart`. |
| Collapsible | Sections use `ExpansionTile`; **`initiallyExpanded: true`** by default on patient detail. |
| CRUD affordances | Section header: **Add** (+). Each row: **Edit** and **Delete**. All three must remain permission-gated. |
| Responsive buttons | **≥ md breakpoint:** icon + text label, color-coded (add = primary, edit = secondary, delete = destructive). **< md:** icon-only with tooltip/semantic label. Update `AppExpandableRecordSection` / `_GuardedIconAction` accordingly. |

---

## 5. Localization & Theming

- Add or update keys in `app_en.arb` (and propagate to other locales) for new labels: visit ID, schedule appointment, start OPD encounter, active-work section title, new quick actions, formatted age strings.
- No hardcoded English in widgets.
- Full light/dark theme support; follow `frontend/.cursor/design-system.mdc`.

---

## 6. Architecture & Quality

| Rule | Requirement |
| ---- | ----------- |
| Layering | Keep API calls in `patientRegistryControllerProvider`; widgets dispatch actions only. |
| Reuse | Prefer extending `AppWorkspacePatientContextHeader`, `AppExpandableRecordSection`, and shared clinical/OPD/IPD dialogs over new bespoke widgets. |
| Extract | If `patient_registry_page.dart` grows further, move header, active-work panel, and quick actions into `frontend/lib/features/patients/presentation/widgets/`. |
| Tests | Update `patient_registry_page_test.dart` for: facility visibility, age formatting, inline record rows, active-work suppression of quick actions, responsive action buttons. |
| Quality gate | `dart format`, `flutter analyze`, `flutter test` from `frontend/`. |

---

## Acceptance Criteria

- [ ] No avatar in patient detail summary; MRN and demographics read clearly on one line.
- [ ] Age shows localized years/months; gender shows an icon.
- [ ] Facility hidden for single-facility users; visit field labeled **Visit ID**.
- [ ] Active appointments/encounters/requests appear in a dedicated section; duplicate quick actions are suppressed.
- [ ] Quick actions renamed, copy-patient-ID removed, and new clinical/IPD actions open shared modals.
- [ ] Record sections show `Label: value` on one line; expanded by default; responsive labeled/color-coded CRUD buttons.
- [ ] All strings localized; tests and analyzer pass.
