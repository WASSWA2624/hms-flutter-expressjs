# HR Staff Detail Dialog — UX & Workforce Lifecycle Improvements

## Objective

Refine the **Staff detail** dialog in the HR workspace (`/hr`) so HR managers can understand, act on, and close out a staff member's employment without guessing what raw IDs mean or which action to take. Replace cryptic list rows with human-readable summaries, drill-down detail modals, calendar-based scheduling views, production-grade compensation and payroll flows, and an integrated **staff separation** (offboarding) workflow.

**Parent context:** [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md)

**Primary touchpoints:**

| Area | File |
|------|------|
| Staff detail layout & record sections | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` |
| Action toolbar (Compensation, Payroll, etc.) | `frontend/lib/features/hr/presentation/widgets/hr_staff_detail_actions.dart` |
| Assignment / mutation dialogs | `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart` |
| Onboarding compensation reference | `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart` |
| Domain entities | `frontend/lib/features/hr/domain/entities/hr_entities.dart` |
| Backend models | `backend/prisma/schema.prisma` (`staff_profile`, `staff_assignment`, `staff_compensation`, `payroll_item`) |

---

## Problem Statement (from current UI)

The staff detail dialog for **Wilson Wasswa** (`STF0000001`) exposes several usability gaps:

1. **Assignments are unclear** — rows render as `Biomedical | <uuid>` with a date range. The UUID is not meaningful to users; it is unclear whether the row is department, unit, or room assignment; duplicate rows appear with no distinction; and there is no way to open a detail view or edit an assignment beyond "End assignment".
2. **Availability is a flat, repetitive list** — each weekday shows `08:00–17:00, 08:00–17:00 | Available` with no visual calendar; users cannot quickly see which days someone works or tap a day for slot detail.
3. **Shifts and compensation are empty or opaque** — shifts show raw `shiftId` when present; compensation section has no records and no inline guidance on how to add them.
4. **Compensation and Run payroll actions appear inactive** — users do not understand why (permission gating vs missing prerequisites) or when each action applies.
5. **No staff separation flow** — there is no UI to record resignation, termination, retirement, or end of contract; ending individual assignments is not the same as offboarding the employee.

---

## Global Standards

Follow the same rules as the HR module prompt:

- Hospital workflow language — **never show raw UUIDs** in primary UI; use display IDs, names, and localized labels.
- Modal-first: all create/edit/detail flows use `AppDialog` / `showAppWorkspaceMutationDialog`.
- Reuse `frontend/lib/shared/*` components; follow `frontend/.cursor/design-system.mdc` and `ui-patterns.mdc`.
- All new strings in `frontend/lib/l10n/app_en.arb`.
- Permission-gate actions with clear disabled tooltips (not silent grey buttons).
- Refresh staff detail via `HrWorkspaceController` after every mutation; respect realtime events.

---

## 1. Assignment List & Detail Modal

### 1.1 Fix assignment row display

**Current (bug):** `_RecordLine.title` joins `departmentName`, `departmentId` (UUID), and primary label.

**Required row summary (one line each):**

| Field | Display |
|-------|---------|
| Title | `{Department name}` — or `{Department} › {Unit}` / `{Department} › {Room}` when unit/room set |
| Badge | `Primary` chip when `isPrimary`; `Active` / `Ended` status chip from `isActive` + `endDate` |
| Subtitle | `{startDate} – {endDate or "Ongoing"}` |
| Trailing | `End assignment` only when active |

- Resolve unit and room names via existing HR reference data or extend `HrStaffAssignment` DTO/entity if only IDs are returned today.
- Deduplicate or explain duplicate rows: if backend returns overlapping assignments, show assignment `displayId` in subtitle (not title) and flag overlaps in the detail modal.

### 1.2 Assignment detail modal (new)

**Trigger:** tap anywhere on an assignment row (not only the trailing action).

**Modal content:**

- Assignment ID (display ID, copyable)
- Staff member name + staff number
- Department, unit, room (resolved names)
- Primary flag, active status
- Start date, end date (editable when active)
- Created / last updated timestamps if available from API
- Notes field (add to schema/API if missing — optional stretch)

**Actions:**

- **Edit** — change department/unit/room, dates, primary flag (reuse or extend assign-department / assign-position flows)
- **End assignment** — existing `showHrEndAssignmentDialog` with confirmation + end-date picker (default today)
- **Close**

Wire through `HrWorkspaceController` with existing `endAssignment` and any new `updateAssignment` repository method.

---

## 2. Availability Calendar View

Replace the flat `_SmallRecordSection` list with a **week/month calendar panel** inside staff detail.

### 2.1 Visual design

- Default: **week view** (Mon–Sun) with color shading:
  - **Available** — light green fill
  - **Unavailable / blocked** — grey or hatched
  - **Leave (approved)** — amber overlay (cross-reference `detail.leaves` for the visible range)
- Toggle to **month view** for longer-range planning.
- Legend below the calendar explaining colors.

### 2.2 Day interaction

**On day tap:** open a bottom sheet or nested modal showing:

- Day name and date
- All time slots (`HrAvailabilitySlot` / `startTime`–`endTime`)
- Status / preference label (localized)
- Effective-from / effective-to if set
- **Edit** → opens existing `showHrRecordAvailabilityDialog` pre-filled for that day
- **Add slot** when none exist

### 2.3 Data mapping

- Map `HrStaffAvailability.dayOfWeek` (1–7) onto calendar cells for recurring weekly patterns.
- Fix duplicate slot display: dedupe identical `startTime`/`endTime` pairs before render; if duplicates come from API, log and collapse in UI.
- Empty state: illustrated placeholder + **Record availability** CTA linking to the existing action.

Reuse or extract a shared `HrAvailabilityCalendar` widget if roster module has similar patterns.

---

## 3. Shifts Section Improvements

### 3.1 Row display

Replace raw `shiftId` with:

- Shift name and type (fetch shift definition or include in `HrShiftAssignment` DTO)
- Assigned date/time
- Roster period if linked
- Status chip (scheduled, completed, swapped)

### 3.2 Shift detail modal

On row tap: show full shift details, assigned roster, swap history, and actions (**Swap shift**, **Remove assignment**) permission-gated.

### 3.3 Empty state

When no shifts: short explanation + **Assign shift** button (existing `_showShiftAssignmentDialog`).

---

## 4. Compensation — Comprehensive Modal

### 4.1 Clarify Compensation vs Payroll

| Concept | When to use | Who can act |
|---------|-------------|-------------|
| **Compensation** | Define or update pay structure (salary, hourly, per-procedure, allowances, effective dates) | `hrWrite` |
| **Run payroll** | Calculate and process pay for a **pay period** based on recorded compensation, attendance, and approved leave | `hrWrite` + `financialApprove` |

Update disabled action buttons to show a **tooltip or subtitle** explaining the missing permission or prerequisite (e.g. "Requires Financial Approve permission" or "Add compensation before running payroll").

Relax or split `_payrollRequirement` in `hr_staff_detail_actions.dart` so **Compensation** only requires `hrWrite`; keep **Run payroll** behind `financialApprove`.

### 4.2 Compensation modal (replace minimal `_CompensationFields`)

Model after `hr_staff_onboarding_dialog.dart` compensation section and international HR practice:

**Sections:**

1. **Pay structure**
   - Pay type: monthly salary, hourly, daily, per-consultation, per-procedure
   - Base rate + currency (use facility default currency)
   - Pay frequency: monthly, bi-weekly, weekly
2. **Allowances & deductions** (repeatable rows)
   - Type (housing, transport, on-call, tax, pension, etc.)
   - Amount or percentage
   - Taxable flag
3. **Effective period**
   - Effective from (required)
   - Effective to (optional — auto-close prior record when new one starts)
4. **History tab**
   - List past compensation records from `detail.compensations` with view-only detail

**Submit:** `HrWorkspaceController.updateSelectedStaffProfile` or dedicated compensation endpoint; append to history rather than silently overwriting.

**Empty section in staff detail:** each compensation row shows pay type, rate, currency, date range; row tap opens read-only detail with **Edit** / **Add new rate**.

---

## 5. Payroll — International-Standard Flow

Upgrade `_PayrollRunFields` and `createPayrollRun` into a guided payroll run dialog:

### 5.1 Wizard steps

1. **Period selection** — pay period start/end; default to current month; validate period overlaps.
2. **Preview** — line items per staff (base pay, allowances, deductions, leave without pay, net pay); support dry-run (`HrPayrollPreview` entity if available).
3. **Review & approve** — summary totals, staff count, exceptions (missing compensation, unapproved leave).
4. **Process** — create payroll run in `DRAFT` → `APPROVED` → `PAID` lifecycle.

### 5.2 Staff-scoped entry point

From staff detail, pre-select the current staff member in the payroll preview; from HR toolbar, allow facility-wide runs.

### 5.3 Compliance labels

Use internationally recognized terms in UI copy: *gross pay*, *net pay*, *deductions*, *pay period*, *payslip* — all localized via ARB keys.

---

## 6. Staff Separation (Offboarding)

Add workforce exit handling — distinct from ending a single department assignment.

### 6.1 UI placement

- New action in `HrStaffDetailActions`: **End employment** (or **Offboard staff**)
- Visible when staff profile is active; permission: `hrWrite`

### 6.2 Offboarding modal fields

| Field | Notes |
|-------|-------|
| Separation type | Resignation, termination, retirement, contract end, deceased |
| Last working day | Required |
| Reason / notes | Optional text |
| End all active assignments | Checkbox, default on |
| Revoke system access | Checkbox, default on — triggers user deactivation via Users/Roles integration |
| Final payroll | Checkbox + link to payroll run for final period |

### 6.3 Backend

- Use `staff_profile.deleted_at` for soft-delete **or** add `employment_status` + `separation_date` fields if product prefers active archive over delete.
- End all active `staff_assignment` rows with `end_date = last_working_day`.
- Cancel future shift assignments and pending leave requests (or flag for HR review).

### 6.4 Staff detail status banner

When separated, show a prominent banner: `{Separation type} · Last day {date}` and hide/disable onboarding actions except view-only history.

---

## 7. Overall Staff Detail Polish

### 7.1 Information hierarchy

1. Header — name, staff number, edit profile, employment status chip
2. Overview cards — position, department, hire date, linked user (unchanged)
3. **Staff actions** grid — with disabled-state explanations
4. **Timeline sections** — Assignments, Leave, Availability (calendar), Shifts, Compensation

### 7.2 Interaction patterns

- All list rows are tappable with chevron affordance
- Consistent empty states: icon + message + primary CTA
- Section collapse/expand for long histories
- Copy-to-clipboard only on display IDs, not internal UUIDs

### 7.3 Leave section (minor)

- Row tap → leave detail modal (type, status, dates, covering staff, handover notes)
- Calendar should reflect approved leave dates (see §2.1)

---

## Acceptance Criteria

- [ ] Assignment rows show department/unit/room **names only** — no UUIDs in title or subtitle.
- [ ] Tapping an assignment opens a detail modal with edit and end actions.
- [ ] Availability renders as a shaded calendar; day tap shows time slots and edit entry point.
- [ ] Duplicate availability slots are not shown twice.
- [ ] Shift rows show human-readable shift names; tap opens shift detail.
- [ ] Compensation action is enabled for `hrWrite`; payroll explains `financialApprove` when disabled.
- [ ] Compensation modal supports pay types, allowances/deductions, effective dates, and history.
- [ ] Payroll run follows period → preview → approve → process steps.
- [ ] **End employment** offboarding flow exists and ends assignments + optional access revocation.
- [ ] Separated staff show a status banner; inactive actions are hidden or disabled with reason.
- [ ] All new copy is localized; `flutter analyze` passes; HR widget tests updated.

---

## Suggested Implementation Order

1. Fix assignment row labels + assignment detail modal (highest confusion in screenshots).
2. Permission tooltips + split compensation vs payroll gating.
3. Compensation modal upgrade + compensation row detail.
4. Availability calendar component.
5. Shifts display + detail modal.
6. Payroll wizard upgrade.
7. Staff separation / offboarding end-to-end.

---

## Quality Gate

```bash
cd frontend && flutter analyze && flutter test test/features/hr/
cd backend && npm test -- --testPathPattern=staff
```

Manually verify on `/hr` with demo staff `STF0000001`: assignments readable, calendar interactive, compensation and payroll flows completable, and offboarding removes staff from active directory.
