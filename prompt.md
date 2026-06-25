# Task: Refine HR Staff Detail, Access Control & Dialog Standards

Act as an expert HR product engineer. Refine the existing HR module (it is mostly built),
keeping the **frontend, backend, and database fully synchronized** for every change.

Read first: `prompts/24-hr-module-prompt.md` (boundaries, architecture, quality gates).

**Primary code areas**

- Frontend HR: `frontend/lib/features/hr/` (`presentation/pages/hr_workspace_page.dart`,
  `presentation/controllers/hr_workspace_controller.dart`,
  `domain/entities/hr_entities.dart`, `domain/repositories/hr_repository.dart`,
  `data/repositories/hr_repository_impl.dart`, `data/dtos/hr_dtos.dart`)
- Shared dialogs/buttons: `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart`,
  `frontend/lib/shared/components/app_dialog.dart`,
  `frontend/lib/shared/components/app_button.dart`
- Backend: `backend/src/modules/{hr-workspace,staff-profile,staff-assignment,staff-leave,shift-assignment,roster,payroll-run}/`
- Strings: `frontend/lib/l10n/app_en.arb`

**Definition of done for every change:** UI ↔ controller ↔ repository ↔ API ↔ DB are
consistent; new strings localized; `dart format --set-exit-if-changed .`, `flutter analyze`,
`flutter test` pass from `frontend/`; targeted `npm test` passes for touched backend modules;
migrations applied for schema changes.

---

## 0. Global dialog standard (applies to ALL modal dialogs in this task)

**Action buttons (Save/Assign/Run/Cancel/etc.) must be non-scrollable and pinned to the
bottom of the dialog.** Only the form content above them may scroll.

- Migrate every HR action dialog in `hr_workspace_page.dart` (currently built with raw
  `showAppDialog` + `AppDialog(scrollable: true, actions: [...])`) to use
  **`showAppWorkspaceMutationDialog`** from `app_workspace_mutation_dialog.dart`, which already
  renders scrollable fields with a fixed footer via `AppDialog`'s `_DialogActions`.
- Confirm content lives in the scrollable region and actions in the footer (never inside the
  scroll view). This is the fix for the **Record availability "BOTTOM OVERFLOWED BY 18px"**.
- Verify no overflow at compact (<600px), tablet, and desktop widths, in light and dark themes.

---

## 1. Staff Detail modal — overview section

- Redesign the header info block (staff number, name, position, department, practitioner type,
  hire date) into a clean, well-spaced summary that reads well in light and dark themes.
- **Remove/relocate the misplaced "Reports" area** in the staff detail — it does not belong there.
- Keep the read-only **Assignments** and **Availability** summary sections, updated to reflect
  the richer data added below.

---

## 2. Staff action dialogs

### 2.1 Assign department (multi-department + units)
- Support a staff member assigned to **multiple departments**; list current department
  assignments in the detail panel with start/end dates, plus edit/end actions.
- Support hierarchy **Department → Unit → Room**: dialog selects a department and optionally a
  unit/room. Extend entities/DTOs, `staff-assignment` schema/service, and a migration.

### 2.2 Assign position (searchable + add-new)
- Replace the plain text field with a **searchable select** of existing positions; if missing,
  the user can **type and add a new position**. Persist new positions appropriately.

### 2.3 Record availability (calendar-style, multi-slot) — also fixes the overflow
- Model availability as **day + one or more time ranges** per day (e.g. Mon 08:00–10:00 AND
  14:00–17:00); a staff member can have **multiple availabilities** with status and effective
  date range.
- Implement a **work/scheduling calendar** view: visualize the week, add/edit/remove slots, and
  **copy/duplicate** availability across days. Update entities/DTOs, backend schema/service,
  and a migration.

### 2.4 Request leave (flexible)
- Keep current design but make it flexible: entering **start date + number of days**
  auto-computes the **end date** (and keep the inverse in sync).

### 2.5 Assign shift (make it meaningful)
- Replace the raw "Shift ID" text field with a **search/select of existing shifts** (by
  name/time/department) sourced from `shift-assignment`/roster reference data.

### 2.6 Swap shift (searchable)
- Allow **searching shifts** and selecting a target staff member; clean, clear interface.

### 2.7 Run payroll + compensation (NEW capability)
- Add **compensation** to the staff profile: flexible pay structures — **per procedure**,
  **per hour**, **per month** (combinations where sensible) with rate, currency, effective
  dates. Extend `staff-profile` schema/service + migration; surface a "Compensation" action in
  the detail panel.
- Make **Run payroll** compute pay for the period from compensation data (`payroll-run`
  module), producing a preview/run with an audit trail.

---

## 3. RBAC / ABAC — deeper and app-wide

- Include **availability, departments, and positions** in the access model.
- A staff member can hold **multiple roles simultaneously** (e.g. Doctor + Surgeon; Biomedical +
  Cleaner); some roles carry **default access**.
- Roles must drive permissions **across the whole app** (OPD, IPD, Theater, …), consistently
  answering "does my role permit X here?".
- Enforce on the **backend** (mandatory) and reflect in the frontend via `AccessGate` /
  `AppAccessActionGate`. Add backend tests for multi-role resolution.

---

## 4. Global "Add" button styling fix

- Primary **Add** buttons (e.g. **Add staff**) are poorly styled across screens: invisible-ish
  white on light theme, dark/invisible on dark theme.
- Fix the shared primary button styling (`app_button.dart` / theme) so **Add** buttons are
  clearly visible and consistent in **both themes** everywhere they appear.

---

## 5. Suggested order of work

1. Section 0 — migrate HR dialogs to `showAppWorkspaceMutationDialog` (pinned footer, fix overflow).
2. Section 4 — global Add button fix (quick, high visibility).
3. Section 1 — staff detail overview cleanup.
4. Section 2 dialogs in order 2.2 → 2.4 → 2.6 → 2.5 → 2.1 → 2.3 → 2.7 (simple → schema-heavy).
5. Section 3 — RBAC/ABAC depth and app-wide enforcement.
6. Run the full quality gate; apply migrations; update `app_en.arb`.

---

## 6. Acceptance checklist

- [ ] All HR modal action buttons are pinned to a non-scrolling footer; only content scrolls.
- [ ] No dialog overflow (incl. Record availability) at compact/tablet/desktop, light + dark.
- [ ] Staff detail overview redesigned; misplaced Reports area removed.
- [ ] Multi-department + Department→Unit→Room assignment works end-to-end.
- [ ] Position select is searchable with add-new; persists correctly.
- [ ] Calendar-style multi-slot availability with duplicate works end-to-end.
- [ ] Leave auto-calculates end date from start + days.
- [ ] Shift assign/swap use search/select, not raw IDs.
- [ ] Compensation (per procedure/hour/month) captured and drives payroll runs with audit trail.
- [ ] Multi-role RBAC/ABAC enforced backend + frontend and honored in OPD/IPD/Theater.
- [ ] Add buttons visible in light and dark themes everywhere.
- [ ] Quality gate green; migrations applied; strings localized.
