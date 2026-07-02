# OPD Flow Worklist — UI Refinement Prompt

## Objective

Refine the **OPD flow** worklist (`/opd`) so reception and clinical staff can scan active outpatient visits at a glance: one fact per column, no duplicated status text, and billing details only inside the encounter workspace — not on the main table.

**Keep unchanged:** page title **“OPD flow”** (`opdTitle`) and the **+ Start OPD encounter** primary action.

**Source of truth:** [`.cursor/flows/opd-flow.mdc`](.cursor/flows/opd-flow.mdc) §4 (worklist contract), §6 (UI rules), §8 (completion rules). Reuse patterns from [Patient Registry](frontend/lib/features/patients/presentation/pages/patient_registry_page.dart) for the patient-number column.

---

## Layout changes

| Area | Action |
| ---- | ------ |
| Page header | Keep `opdTitle` (“OPD flow”) only. |
| Table panel | **Remove** nested `AppWorkspaceDetailPanel` title (“OPD encounters”) and description (“Track arrivals, queue status…”). Render **search bar + table** directly under the workspace toolbar. |
| Worklist scope | Show **active outpatient encounters only** — exclude terminal stages (`DISCHARGED`, `ADMITTED`, cancelled, no-show, closed). Completed visits belong in filters/history, not the default queue. |

---

## Table column contract

Split overloaded cells into dedicated columns. Each column shows **one** value — no stacked subtitles in default columns.

| Column | Label (i18n) | Content | Notes |
| ------ | -------------- | ------- | ----- |
| Patient number | `patientsPatientNumberColumnLabel` | `patientIdentifier` / `effectiveIdentifier` | Mirror registry `_PatientNumberCell` pattern. |
| Patient name | Rename from “Patient” → “Patient name” | Display name only | Remove ID, arrival mode, and wait time from this cell. |
| Arrival mode | New — e.g. `opdArrivalModeColumnLabel` | Walk-in, Appointment, Emergency (from `arrival_mode` / visit type) | Hospital language; map backend enums in `opd_status_display.dart`. |
| Waiting time | `opdWaitingTimeColumnLabel` | Elapsed time since queue/arrival (`Xh Ym`) | Use existing `_formatShortDuration`; dedicated column, not patient subtitle. |
| Queue status | Rename from “Queue / status” → **“Queue status”** | **Single** canonical stage label | Fix duplication: do not show the same text twice (e.g. “With doctor” + “With doctor”). Use backend stage → one user-facing label via `opdStageDisplayLabel`. |
| Next step | `opdNextStepColumnLabel` | Distinct actionable step | Must differ from queue status (e.g. status “Lab pending” → next step “Lab handoff”). Derive from `displayNextStep` / stage owner role — never repeat the status string. |
| Assigned staff | `opdProviderColumnLabel` | Doctor/nurse/reception assignee only | **Omit facility/hospital name** from the worklist cell. |
| OPD encounter | New — e.g. `opdEncounterColumnLabel` | Active encounter display ID | Friendly ID for the current open OPD visit; copy action optional. |
| ~~Payer / billing~~ | **Remove from worklist** | — | Payment state belongs in the **encounter detail/actions dialog** and Billing module, not the default table. |

### Column visibility defaults

- **Default visible (5):** Patient number, Patient name, Queue status, Next step, Assigned staff.
- **Available via table settings:** Arrival mode, Waiting time, OPD encounter, Arrival time, Visit type (if kept), and any legacy columns.
- Enforce `_maxOpdTableColumns = 5` default cap; user can toggle additional columns in table settings (`AppListTable` column chooser).

---

## Data & behavior rules

1. **One row per active OPD encounter** — dedupe triage queue, flow, and queue-entry sources; prefer the active `OpdFlowSummary` when multiple representations exist.
2. **Queue status vs next step** — status = where the patient is in the workflow; next step = what staff should do next. Both map to [opd-flow.mdc §3](.cursor/flows/opd-flow.mdc) stages without repeating the same string.
3. **Arrival mode** — derive from entry path: walk-in, appointment check-in, emergency handoff, follow-up/review where applicable.
4. **Billing** — remove `_OpdTableColumnId.payerBilling` from default and available worklist columns; retain billing in `_OpdPatientActionsDialog` / encounter panel via `opd_billing_state.dart`.
5. **Search** — keep existing search fields; ensure patient number and encounter ID are searchable.
6. **i18n** — all new/changed labels in `frontend/lib/l10n/app_en.arb`; no hardcoded strings.
7. **Mobile rows** — update `_OpdTableMobileRow` to match the new column split.

---

## Implementation pointers

| Area | Location |
| ---- | -------- |
| Worklist UI | `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart` |
| Stage / status labels | `frontend/lib/shared/opd_actions/opd_status_display.dart` |
| Encounter dialog / billing | `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`, `opd_billing_state.dart` |
| DTO fields | `frontend/lib/features/opd/data/dtos/opd_dtos.dart` (`arrival_mode`, encounter IDs) |
| Registry column reference | `patient_registry_page.dart` — `_PatientNumberCell`, split name column |

---

## Acceptance criteria

- [ ] Page shows **“OPD flow”** only — no “OPD encounters” subtitle or tracking description above the table.
- [ ] Patient name column shows **name only**; patient number, arrival mode, and wait time each have **dedicated columns**.
- [ ] **Queue status** and **Next step** never display duplicate text on the same row.
- [ ] **Assigned staff** omits facility name; **billing/payer** is absent from the worklist but visible when opening an encounter.
- [ ] Only **active, non-terminal** OPD encounters appear in the default worklist.
- [ ] Default view shows **5 columns**; additional columns available in table settings.
- [ ] `flutter analyze` and OPD workspace tests pass.

---

## Quality gate

From `frontend/`: `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test test/features/opd/`.
