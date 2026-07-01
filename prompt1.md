# HR Schedule Templates — Flexible Weekly Patterns & Unified Schedule Editor

## Objective

Elevate **Schedule templates** from a flat list with a single start/end pair into a **first-class scheduling pattern** that matches the flexibility of **Record availability**. Unify both flows behind one reusable **weekly schedule editor**, improve the manage dialog UX (maximized by default, copyable IDs, icon actions, drill-in detail), and align naming so administrators see one coherent scheduling vocabulary across HR.

**Entry points:**
- `/hr` → toolbar **Schedule templates** (overflow or inline per [prompt.md](./prompt.md))
- `/hr` → staff detail → **Record availability**

**Screenshots (current UI):** manage list (`Biomedical | DAY | SHI0000001`), create/edit template form (name, shift type, department, single start/end), and record availability (Mon–Sun expansion tiles, multi-slot, duplicate-to).

**Parent context:** [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md); companion [prompt.md](./prompt.md) (toolbar IA). This prompt **supersedes** the “schedule-template CRUD out of scope” note in `prompt.md`.

---

## Problem Statement (from current UI)

| Area | Current behavior | Issue |
|------|------------------|-------|
| Manage dialog | Opens at default size (`maxWidth: 720`) | Hard to scan patterns; should open **maximized** like other HR workspace dialogs |
| Template row | `Biomedical \| DAY \| SHI0000001` as plain text | Template ID (`SHI0000001`) is not copyable; no row tap target |
| Row actions | Text buttons **Edit template** / **Delete template** | Verbose; inconsistent with icon-only patterns elsewhere (e.g. tenant facility rows) |
| Create/edit form | Single `default_start_time` / `default_end_time` pair | Cannot express split shifts, day-specific hours, or multi-slot days |
| Record availability | Full weekly editor (`_DayScheduleSection`, duplicate-to, add slot) | Rich UX isolated in `hr_record_availability_dialog.dart` |
| Naming | Toolbar label **Create schedule template** opens **Schedule templates** manage dialog; backend keys use `shift_template` | Confusing labels; two different forms for the same mental model (“when does this person/pattern work?”) |

A roster admin defining a **Biomedical day pattern** should use the same weekly schedule UI they already know from recording staff availability—not a reduced single-interval form.

---

## Current Implementation

| Area | Location |
|------|----------|
| Manage templates dialog | `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart` — `showHrManageScheduleTemplatesDialog` |
| Create/edit template dialog | Same file — `showHrShiftTemplateDialog` |
| Record availability dialog | `frontend/lib/features/hr/presentation/widgets/hr_record_availability_dialog.dart` — `showHrRecordAvailabilityDialog`, `_DayScheduleSection`, `_DayScheduleDraft` |
| Weekly day order / defaults | `kAvailabilityWeekDayOrder`, `kDefaultAvailabilityWeekdays`, default 08:00–17:00 |
| Toolbar entry | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — `scheduleTemplatesAction` |
| Copyable IDs (pattern) | `frontend/lib/shared/components/app_copyable_identifier.dart` — `AppCopyableIdentifier`; detail tiles via `AppInfoTileData(copyable: true)` in `hr_assignment_detail_dialog.dart` |
| Icon-only row actions (pattern) | `tenant_facility_setup_page.dart`, staff detail edit in `hr_workspace_page.dart` — `AppButton(iconOnly: true, …)` |
| Maximized dialogs (pattern) | `AppDialog.initialMaximized`, `showAppWorkspaceMutationDialog(initialMaximized: …)` — e.g. `hr_staff_onboarding_dialog.dart`, `hr_access_dialogs.dart` |
| Backend model | `shift_template` — `name`, `shift_type`, `facility_id`, `default_start_time`, `default_end_time` only (`backend/prisma/schema.prisma`) |
| API validation | `backend/src/modules/shift-template/schemas/shift-template.schema.js` |

**List row today:** `ListTile` with `title: template.label` (composite string) and trailing `AppButton.secondary` labels from `hrEditShiftTemplateAction` / `hrDeleteShiftTemplateAction`.

---

## Target UX

### 1. Manage dialog — layout & defaults

- Open with `initialMaximized: true` on `AppDialog`.
- Widen content area when maximized (recommend `maxWidth: 980`, matching work-queue / staff-directory dialogs).
- Keep description: *“Reusable shift patterns for roster generation and staff scheduling.”*

### 2. Template list rows

Each row shows:

| Element | Spec |
|---------|------|
| Primary title | Template **name** (e.g. `Biomedical`) |
| Subtitle | Shift type + department when present (e.g. `DAY · Biomedical dept`) |
| Identifier | `AppCopyableIdentifier` for `human_friendly_id` / `SHI…` (hide when empty/placeholder per `isCopyableIdentifierValue`) |
| Row tap | Opens **template detail** dialog (see §3) |
| Trailing actions | Icon-only **Edit** (`Icons.edit_outlined`) and **Delete** (`Icons.delete_outline`, destructive color)—**no “template” in labels**; use `semanticLabel` + `tooltip` from l10n (`commonEditAction` / `commonDeleteAction` or HR-specific short keys) |

Stop opening the edit mutation dialog directly from the list edit icon if detail becomes the primary surface; edit icon may either open detail in edit mode or open the mutation dialog—pick one path and use detail for row tap.

### 3. Template detail dialog (new)

Follow `showHrAssignmentDetailDialog` / `AppInfoTileGrid` patterns:

- Title: template name; icon: `Icons.view_week_outlined`.
- Read-only tiles: Template ID (copyable), shift type, department, active status, created/updated if available from API.
- **Weekly schedule summary** — human-readable per-day slot list (same formatting as availability expansion subtitles, e.g. `08:00-17:00`).
- Footer / inline actions: **Edit**, **Delete**, and (when backend supports it) **Duplicate** / slot management.
- Detail dialog may also open maximized when the weekly grid is shown inline.

### 4. Flexible weekly schedule (shared editor)

Extract a reusable widget from `hr_record_availability_dialog.dart`, e.g. `HrWeeklyScheduleEditor` (name negotiable), containing:

- Monday-first `ExpansionTile` per day (`_DayScheduleSection` behavior).
- Per-day multi-slot fields (`AppTimeField` with 12H/24H toggle).
- **Duplicate to…**, **Add slot**, overlap / end-after-start validation.
- Configurable props: which days to show, whether copy-from-staff is visible, read-only mode for detail view.

**Consumers:**

| Consumer | Editor mode | Extra fields |
|----------|-------------|--------------|
| Record availability | Editable; copy-from-staff | Preference, effective from/to, staff context |
| Schedule template create/edit | Editable | Name, shift type, department (optional) |
| Template detail | Read-only summary + actions | — |

Record availability and schedule templates must **not** duplicate `_DayScheduleSection` / draft logic in separate files after this task.

### 5. Create/edit template mutation dialog

- Replace single `AppTimeField` start/end pair with `HrWeeklyScheduleEditor`.
- Open with `initialMaximized: true` on `showAppWorkspaceMutationDialog` (weekly grid needs vertical space).
- Submit still calls `createShiftTemplate` / `updateShiftTemplate` on `HrWorkspaceController`.

### 6. Naming consistency (l10n)

Align user-facing strings around **schedule** / **pattern**, not mixed “shift template” vs “schedule template”:

| Key / surface | Current | Target |
|---------------|---------|--------|
| Toolbar / overflow | `hrShiftTemplateAction` → “Create schedule template” | **Schedule templates** (opens manage dialog) |
| Manage dialog title | `hrManageScheduleTemplatesTitle` → “Schedule templates” | Keep |
| Create action | `hrCreateShiftTemplateAction` → “Create template” | **Create schedule** or **Add pattern** (short, no redundant “template”) |
| Edit / delete (list icons) | “Edit template” / “Delete template” | **Edit** / **Delete** (icon-only; tooltips only) |
| Mutation dialog title | `hrShiftTemplateDialogTitle` → “Schedule template” | **Schedule pattern** (create) / **Edit schedule pattern** (edit)—or keep “Schedule template” if preferred; **must match** manage dialog vocabulary |
| Record availability | `hrAvailabilityDialogTitle` → “Record availability” | Keep action label; shared section title **`hrWeeklyScheduleSectionTitle`** → “Weekly schedule” (reuse `hrAvailabilityWeekScheduleTitle` value, deprecate duplicate key) |
| Shared editor a11y | — | One l10n prefix family for slot actions (`hrAddScheduleSlotAction`, `hrDuplicateScheduleToAction`, …) used by **both** flows |

Rename arb keys only when necessary; prefer retargeting existing strings before adding parallel keys.

---

## Backend Dependency (weekly slots on templates)

`shift_template` today stores only `default_start_time` / `default_end_time`. Staff availability already supports `time_slots_json` per day.

**Required for full parity:**

1. Extend `shift_template` with `weekly_schedule_json` (or `time_slots_json` mirroring availability shape), **or** add a `shift_template_slot` child table.
2. Update Zod schemas and Flutter DTOs / controller payloads.
3. Migration + backward compatibility: existing templates map to a single weekday slot (e.g. Mon–Fri 08:00–17:00 or infer from `default_start_time`/`default_end_time` on read).

**If backend work is deferred:** ship the shared UI component and detail/list UX first; serialize the weekly editor to the legacy pair (e.g. first filled slot of first filled day) with a visible banner: *“Full weekly patterns will apply after server update.”* Do **not** silently drop extra slots.

---

## Implementation Requirements

### 1. Shared weekly schedule module

- New file under `frontend/lib/features/hr/presentation/widgets/` (e.g. `hr_weekly_schedule_editor.dart`).
- Move `_DayScheduleSection`, `_DayScheduleDraft`, `_AvailabilitySlotDraft`, validation helpers, and `kAvailabilityWeekDayOrder` (or rename to `kHrWeekDayOrder`) into shared module.
- Export a single public widget + draft-to-payload mapper(s) for availability batch API vs template API.

### 2. Manage templates dialog

- `initialMaximized: true`, `maxWidth: 980`.
- Refactor list to structured row (title, subtitle, `AppCopyableIdentifier`, icon actions).
- `onTap` → `showHrScheduleTemplateDetailDialog` (new).
- Delete retains confirmation pattern if one exists elsewhere; show snackbar via `showHrMutationSnackBar`.

### 3. Template detail dialog

- New `hr_schedule_template_detail_dialog.dart` (or colocate in enhanced dialogs if small).
- Use `AppInfoTileGrid` + read-only `HrWeeklyScheduleEditor`.
- Actions: Edit (opens mutation dialog), Delete (with confirm).

### 4. Record availability refactor

- Replace inlined `_DayScheduleSection` usage with `HrWeeklyScheduleEditor`.
- **No behavior regression** on copy-from-staff, duplicate-to, validation messages, or `createAvailabilitySchedule` payload.

### 5. Shift template mutation dialog

- Integrate `HrWeeklyScheduleEditor`; remove standalone start/end `AppTimeField`s.
- `initialMaximized: true`.
- Map weekly draft ↔ API payload per backend contract (§ Backend Dependency).

### 6. Toolbar label fix

- Update `hrShiftTemplateAction` (and generated l10n) to **Schedule templates** so the button matches the manage dialog it opens.

### 7. Tests

- Widget test: manage dialog opens maximized (`find.byType` / dialog size flag if exposed).
- Widget test: list row shows `AppCopyableIdentifier` when ID present.
- Widget test: icon-only edit/delete buttons with correct `semanticLabel`s.
- Widget test: `HrWeeklyScheduleEditor` — add slot, duplicate-to, validation errors (extract from or extend `hr_record_availability` tests if any).
- Regression: existing availability dialog tests still pass after refactor.

### 8. Quality gate

- `flutter analyze` clean on touched files.
- `flutter test` for new/changed test files.
- Manual QA: `.\tool\run_web_5201.ps1` → `/hr` → **Schedule templates** → verify maximize, copy ID, row detail, create/edit weekly pattern → **Record availability** on a staff profile → confirm identical weekly schedule UX.

---

## Global Standards

- Reuse `AppDialog`, `AppButton` (`iconOnly`), `AppCopyableIdentifier`, `AppInfoTileGrid`, `AppTimeField`, theme spacing.
- Icons: outlined Material set (`view_week_outlined`, `edit_outlined`, `delete_outline`, `content_copy_outlined`).
- All new/changed strings in `frontend/lib/l10n/app_en.arb`.
- Permission gates unchanged (`hrRead` / `hrWrite`).
- Hospital workflow language—no raw enum names in labels (`DAY` → “Day shift” if not already localized).

---

## Acceptance Criteria

- [ ] **Schedule templates** manage dialog opens **maximized** by default.
- [ ] Each template row shows a **copyable** template ID via `AppCopyableIdentifier`.
- [ ] List **Edit** and **Delete** are **icon-only** (no “template” in visible text).
- [ ] Tapping a template row opens a **detail** dialog with metadata, weekly schedule summary, and edit/delete actions.
- [ ] Create/edit template uses the **same weekly schedule editor** as Record availability (multi-day, multi-slot, duplicate-to).
- [ ] Weekly schedule UI lives in **one shared component**—no duplicated `_DayScheduleSection` in availability vs template files.
- [ ] Toolbar action label matches manage dialog (**Schedule templates**).
- [ ] l10n uses consistent **schedule / weekly schedule** vocabulary across both flows.
- [ ] Backend stores and returns full weekly pattern **or** interim mapping is documented and non-destructive.
- [ ] Widget tests cover list/detail/editor behaviors; manual QA checklist passes.

---

## Out of Scope

- Roster generation logic that consumes templates (separate scheduling prompt).
- Work-queue or toolbar overflow IA ([prompt.md](./prompt.md)).
- Staff detail action grid reordering.
- Applying a template to a staff member in one click (“Assign template to staff”)—future enhancement.
