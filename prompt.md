# HR — Redesign “Add staff profile” onboarding dialog

## Objective

Replace the current **Add staff profile** modal (`/hr` → **+ Add staff**) with a user-friendly, permission-gated, globally reusable onboarding flow that captures everything HR needs in one place — without exposing internal IDs or confusing account-linking steps.

**Current pain points (from `/hr` UI):**

| Issue | Today | Expected |
| ----- | ----- | -------- |
| Tenant ID | Required manual text field | Auto-derived from the signed-in user’s tenant/facility/branch scope — never shown to HR |
| Link user account | Required dropdown listing unrelated accounts (e.g. “Patient demo”) | Clear “staff identity” section: create new person **or** link an existing internal user — filtered to facility scope, labeled with name + role hint |
| Identity fields | Missing (only email/password in nested “Create user account”) | First name, last name, sign-in email, phone, optional address — required where appropriate |
| Position / department | Free text + basic selects | Searchable selects backed by reference data; allow inline “add new” when missing |
| Roles & permissions | Not on create form | Assign roles (and show effective permissions preview) during onboarding; if skipped, show a visible “No roles assigned yet” warning |
| Consultation fee | Always visible | Show **only** for clinical roles (doctor, specialist, practitioner types that bill consultations) |
| Compensation | Not on create form | Dynamic pay model: monthly salary, daily rate, hourly rate, etc. — wired end-to-end to `staff-compensation` |
| Dialog UX | Small default modal | Open **maximized by default**; responsive on mobile, tablet, and desktop |

---

## Scope

### In scope

1. **Extract** staff onboarding into the **single canonical** shared dialog — `showHrStaffOnboardingDialog` — in a dedicated file (e.g. `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart`), exported from the HR feature for app-wide use.
2. **Consolidate and remove duplicates** — audit the repo for overlapping staff/user onboarding UI and backend paths; **replace every call site** with `showHrStaffOnboardingDialog` (or the shared coordinated API it uses), then **delete** the superseded widgets, nested dialogs, and dead code. Do not leave parallel implementations.
3. **Hide scope fields** — `tenant_id`, `facility_id`, and `branch_id` (when applicable) are injected server-side from the authenticated session; remove them from the form UI.
4. **Restructure the form** into logical sections:

   **A. Person & access**
   - Toggle or tabs: *Create new user* | *Link existing user*
   - New user: first name, last name, email (sign-in), phone, optional address, initial password (or “send invite” if supported)
   - Link existing: searchable select of users **without** a staff profile, scoped to the current facility/tenant — display `full name · email`, never raw UUIDs

   **B. Employment**
   - Staff number (optional, auto-generate if empty)
   - Position — searchable select + “add position” when not in list
   - Department — searchable select from `referenceData.departments`
   - Practitioner type (when clinically relevant)
   - Hire date

   **C. Access & roles**
   - Role multi-select from reference data
   - Read-only permissions preview (matrix editing stays in Access Admin)
   - Inline warning if no roles selected

   **D. Compensation** (conditional)
   - Pay type selector: monthly / daily / hourly / per-visit (extensible)
   - Rate + currency + effective-from date
   - Consultation fee + currency — **only** when role or practitioner type indicates a billing provider

5. **Default maximize** the dialog using shared `AppDialog` viewport maximize behavior.
6. **RBAC** — only users with staff-create permission (e.g. HR manager, administrator) see **+ Add staff** and can open the global dialog.
7. **Backend** — ensure create/link/compensation/role assignment works in one coordinated action or a clear transactional sequence; validate scope server-side. Retire or delegate duplicate create paths (e.g. doctor module inline `createStaffProfile`) to this coordinated endpoint.

### Out of scope

- Editing the Access Admin permission matrix (HR may preview only).
- Patient, OPD, or billing workflows.
- Payroll run processing (compensation capture only).

---

## Consolidation — replace, don’t duplicate

**Rule:** one onboarding dialog, one coordinated create API. Any similar flow found during implementation must be **migrated to the canonical dialog** and the old code **removed**.

### Known duplicates to replace (audit for others)

| Current implementation | Location | Action |
| ---------------------- | -------- | ------ |
| `_StaffProfileFields` + `_showStaffProfileDialog` | `hr_workspace_page.dart` | Replace with `showHrStaffOnboardingDialog`; delete private widget |
| Nested `showHrCreateUserDialog` | `hr_enhanced_dialogs.dart` | Fold into onboarding dialog; delete function |
| `showHrCreateStandaloneUserDialog` (user + roles, no staff link) | `hr_access_dialogs.dart` | Replace “create user” entry with onboarding dialog in *link-existing* or *create-new* mode; delete if fully superseded |
| Home quick actions `add_staff_profile` / `staff_profile` | `home_page.dart` + `dashboard-workspace.service.js` | Open `showHrStaffOnboardingDialog` directly (permission-gated) instead of only navigating to `/hr` |
| Doctor inline staff creation | `backend/.../doctor.service.js` → `doctorRepository.createStaffProfile` | Delegate to shared HR staff-onboarding service / coordinated endpoint |
| Edit-staff reuse | `_showStaffProfileDialog` edit path | Reuse same dialog in **edit mode** with shared field components — do not fork a second edit form |

### Consolidation workflow

1. **Search** the codebase for: `createStaffProfile`, `createUserAndLinkStaff`, `showHrCreateUserDialog`, `StaffProfileFields`, `add_staff_profile`, `tenant_id` on staff-create forms.
2. **Implement** `showHrStaffOnboardingDialog` + shared field widgets + coordinated backend action.
3. **Rewire** every entry point (HR toolbar, home dashboard, access workspace, future modules) to call the canonical dialog.
4. **Delete** superseded private widgets, nested dialogs, and unused l10n keys.
5. **Update tests** — migrate existing HR dialog tests to the new widget; add regression test that no duplicate create-staff dialog remains.

Follow the same shared-dialog pattern already used for `showHrStaffDirectoryDialog` and `showHrWorkQueueDialog` in `hr_workspace_dialog_actions.dart`.

---

## Implementation targets

| Layer | Location |
| ----- | -------- |
| **New canonical dialog** | `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart` (create) |
| Superseded form (remove) | `hr_workspace_page.dart` — `_StaffProfileFields`, `_showStaffProfileDialog` |
| Superseded nested dialog (remove) | `hr_enhanced_dialogs.dart` — `showHrCreateUserDialog` |
| Overlapping access dialog (migrate/remove) | `hr_access_dialogs.dart` — `showHrCreateStandaloneUserDialog` |
| Shared dialog pattern | `hr_workspace_dialog_actions.dart` |
| Home entry points | `home_page.dart`; `backend/.../dashboard-workspace.service.js` (`add_staff_profile`) |
| Controller / API | `hr_workspace_controller.dart`, `hr_repository_impl.dart`, `backend/src/modules/hr-workspace/` |
| Backend duplicate | `backend/src/modules/doctor/services/doctor.service.js` |
| Compensation model | `HrStaffCompensation` in `hr_entities.dart`; `staff-compensation` API |
| Design system | `frontend/.cursor/design-system.mdc`, `ui-patterns.mdc`, `app_en.arb` for all labels |
| Parent context | Align with `prompts/24-hr-module-prompt.md` global HR standards |

---

## Acceptance criteria

- [ ] HR user never sees or enters tenant, facility, or branch IDs.
- [ ] “Link user account” is replaced with clear copy and facility-scoped options; no patient/demo accounts appear.
- [ ] New staff can be created with full identity fields in a single maximized dialog (no confusing nested pop).
- [ ] Position and department use searchable selects with predefined values; missing values can be added inline.
- [ ] Roles can be assigned on create; skipped roles show a visible warning on the profile.
- [ ] Consultation fee fields appear only for applicable clinical roles.
- [ ] Compensation type (monthly/daily/hourly/etc.) saves correctly and appears on staff detail.
- [ ] `showHrStaffOnboardingDialog` is the **only** staff-create UI in the frontend; all known duplicates are removed.
- [ ] Home dashboard and HR workspace both open the same dialog (not separate forms or route-only navigation).
- [ ] `showHrCreateUserDialog` and `_StaffProfileFields` no longer exist in the codebase.
- [ ] Backend doctor onboarding delegates to the shared HR create path (no parallel `createStaffProfile` logic).
- [ ] Dialog is permission-gated, opens maximized by default, and renders well on all breakpoints.
- [ ] `flutter analyze` and targeted `flutter test` pass; backend tests cover scoped create + compensation.

---

## Quality bar

- Hospital workflow language — no enum names or UUIDs in labels.
- Light/dark themes; all strings in `app_en.arb`.
- Modal-first: no new sub-routes for this flow.
- Realtime refresh of staff directory and nav badges after successful create.
