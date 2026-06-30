# Record availability — weekly schedule builder

## Context

From **Staff detail → Record availability** (`hrRecordAvailabilityAction`), HR records when a staff member is available to work. Availability informs roster generation (see [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md) §4).

**Entry point:** `HrStaffDetailActions` → `_showAvailabilityDialog` in `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`.

**API:** `POST /staff-availabilities` — one record per `day_of_week` (0–6), each with optional `time_slots[]`, `preference`/`status`, and `effective_from` / `effective_to`.

---

## Current behaviour (screenshots)

The dialog title is **Record availability**. Fields today:

| Field | Notes |
| ----- | ----- |
| Day of week * | Single dropdown — only one day per save (e.g. Monday) |
| Start time * / End time * | One pair; **+ Add slot** adds more slots for that same day |
| Availability (optional) | Preferred / Available / Unavailable |
| Effective from * / Effective to (optional) | Date range for the schedule |

**Limitations:**

1. Only one day can be configured per submission — building a full week requires many separate saves.
2. No way to copy a day's slots to other days.
3. No way to copy an existing schedule from another staff member.
4. When the form is short, the dialog footer (Cancel / Record availability) does not sit at the bottom — empty space appears between content and actions. This affects this dialog and other mutation dialogs using `showAppWorkspaceMutationDialog`.

---

## Desired behaviour

### 1. Weekly schedule builder (replace single-day picker)

Replace the single **Day of week** dropdown with a **week view** listing all seven days (Monday–Sunday).

For **each day**:

- Show the day label as a section header or expandable row.
- Allow **zero or more time slots** per day (start time, end time).
- **+ Add slot** is scoped to that day (not global).
- A day with no slots = not scheduled / unavailable for that day.
- Slots on the same day must not overlap; end time must be after start time (match backend `availabilitySlotSchema`).

**Examples the UI must support:**

- **Monday:** 08:00–10:00 and 14:00–16:00 (split shift with a break).
- **Tuesday:** 22:00–06:00 (night shift — validate overnight spans if product allows, or document constraint).
- **Wednesday–Friday:** no slots (off days).

Keep **Availability (optional)**, **Effective from**, and **Effective to** as shared fields applying to the whole submission (same effective period for all days saved in one action).

### 2. Duplicate day schedule

Per day, provide a **Duplicate to…** action (or equivalent) that copies that day's slot list to one or more other days.

- User selects target day(s) — e.g. copy Monday's slots to Tuesday and Wednesday.
- Target days are replaced (or merged — prefer **replace** for predictability; confirm in UI copy).
- Do not duplicate effective dates or availability preference — only time slots.

### 3. Copy schedule from another staff member

Add a **Copy from staff** control (toolbar action, link, or secondary button in the dialog).

- Opens a staff picker (searchable directory subset or compact select).
- Loads that staff member's current availability (active `effective_from` / `effective_to` window).
- Pre-fills the week builder; user can edit before saving.
- Saving applies the schedule to the **currently selected** staff profile (detail context), not the source staff.
- Respect tenant/facility scope and `hrWrite` permission.

### 4. Submit semantics

On **Record availability**:

- Validate all days and slots.
- Create or update one `staff-availability` record per day that has at least one slot (batch or sequential API calls — prefer a single batch endpoint if added; otherwise multiple `POST`s with shared effective dates).
- Refresh the staff detail **Availability** section and summary counts after success.
- Show standard mutation snackbar via `_showMutationResult` / `showHrMutationSnackBar`.

Extract `_AvailabilityFields` into a dedicated widget file (e.g. `hr_record_availability_dialog.dart`) following `hr_assign_department_dialog.dart` and `hr_assign_position_dialog.dart`.

---

## Global dialog footer layout

**Problem:** In `showAppWorkspaceMutationDialog` / `AppDialog`, when form content is shorter than the dialog body, action buttons float immediately below the fields instead of anchoring to the bottom.

**Requirement:** Footer actions (Cancel, primary submit, and any extra actions) must **always align to the bottom** of the dialog content area, with the form fields scrollable above when needed.

**Scope:** Fix in shared layout — `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart` and/or `frontend/lib/shared/components/app_dialog.dart` — so every consumer benefits (HR mutations, assign department/position, onboarding, etc.).

**Acceptance:**

- Short form: footer pinned to bottom; no large empty gap *between* fields and footer (whitespace may appear *above* fields if vertically centered is undesirable — prefer top-aligned scrollable content + bottom-pinned footer).
- Long form: fields scroll; footer remains visible/fixed at bottom.
- Works in default and maximized dialog modes.

---

## UI / engineering standards

| Area | Requirement |
| ---- | ----------- |
| i18n | All new strings in `frontend/lib/l10n/app_en.arb` |
| Components | Reuse `AppSelectField`, `AppDateField`, `AppButton`, `AppFormSection`, time inputs consistent with existing `_AvailabilitySlotFields` |
| Backend | Extend only if needed — `time_slots` array already supported per day; add batch create or copy-from-staff endpoint if multiple round-trips are unacceptable |
| Tests | Widget tests for week builder, duplicate-day, and copy-from-staff flows; backend tests if API changes |
| Quality | `flutter analyze`, `flutter test` for touched paths |

---

## Acceptance checklist

- [ ] Week view shows Mon–Sun; each day supports multiple add/remove slots.
- [ ] Split shifts (e.g. morning + afternoon) work on one day.
- [ ] Different patterns per day (e.g. night shift Tuesday only) in one save.
- [ ] Duplicate day → copy slots to selected other day(s).
- [ ] Copy from staff → pick colleague → pre-fill → save to current staff.
- [ ] Effective from/to and availability preference apply to the whole submission.
- [ ] Detail availability section refreshes after save.
- [ ] Dialog footer pinned to bottom globally for mutation dialogs.
- [ ] No regressions to leave, shift assignment, or other HR dialogs.
