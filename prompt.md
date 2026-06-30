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

1. **Extract** staff onboarding into a shared widget/dialog (e.g. `showHrStaffOnboardingDialog`) callable from `/hr` and any other module that may onboard staff.
2. **Hide scope fields** — `tenant_id`, `facility_id`, and `branch_id` (when applicable) are injected server-side from the authenticated session; remove them from the form UI.
3. **Restructure the form** into logical sections:

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

4. **Default maximize** the dialog using shared `AppDialog` viewport maximize behavior.
5. **RBAC** — only users with staff-create permission (e.g. HR manager, administrator) see **+ Add staff** and can open the global dialog.
6. **Backend** — ensure create/link/compensation/role assignment works in one coordinated action or a clear transactional sequence; validate scope server-side.

### Out of scope

- Editing the Access Admin permission matrix (HR may preview only).
- Patient, OPD, or billing workflows.
- Payroll run processing (compensation capture only).

---

## Implementation targets

| Layer | Location |
| ----- | -------- |
| Current form | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — `_StaffProfileFields` |
| Create-user nested dialog | `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart` — `showHrCreateUserDialog` |
| Controller / API | `hr_workspace_controller.dart`, `hr_repository_impl.dart`, `backend/src/modules/hr-workspace/` |
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
- [ ] Dialog is extracted as a reusable entry point, permission-gated, and renders well on all breakpoints.
- [ ] `flutter analyze` and targeted `flutter test` pass; backend tests cover scoped create + compensation.

---

## Quality bar

- Hospital workflow language — no enum names or UUIDs in labels.
- Light/dark themes; all strings in `app_en.arb`.
- Modal-first: no new sub-routes for this flow.
- Realtime refresh of staff directory and nav badges after successful create.
