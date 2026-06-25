# Patient Registry Module — Implementation Prompt

## Objective

Complete the **Patient Registry Module** for HOSSPI HMS so registration staff and clinicians can manage patients end-to-end: search and register, maintain demographics and identifiers, contacts and guardians, allergies and medical history, documents and consent, duplicate detection/merge, and **launch** OPD/IPD/Emergency workflows without duplicating patient master records.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Patient registry boundaries vs OPD, Clinical, IPD, Emergency, Billing
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §2 entry paths (search patient first, register if needed)
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §2 admission paths, step 3 registration, §16 encounter links to patient

**Central rule:** one **patient master record** per person per tenant scope. OPD encounters, IPD admissions, and emergency cases reference `patient_id` — the registry does not own clinical queues or bed assignment.

Deliver a **search-first registry workspace**: fast lookup, safe registration, rich patient detail, and contextual quick actions to start downstream flows.

---

## Global Implementation Standards

Mandatory platform rules for all work in this module.

| Area | Requirement |
| ---- | ----------- |
| Product scope | [app-write-up.mdc](../.cursor/app-write-up.mdc) — respect module boundaries; do not duplicate workflows owned elsewhere. |
| Patient flows | Align with [`.cursor/flows/`](../.cursor/flows/). Use [opd-flow.mdc](../.cursor/flows/opd-flow.mdc) and [ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) for journey touchpoints; read the module-specific flow file when one exists (lab, nursing, pharmacy, radiology, discharge, emergency, icu, theater). |
| Encounters | One active OPD encounter per outpatient visit; IPD admission as inpatient hub; overlays (ICU, Theater) and executing departments attach — never parallel admission records. |
| UI/UX | Modern, clean, minimal on-screen text; hospital workflow language (not enum names or UUIDs). Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`, `platform_guidelines.mdc`. Reuse `frontend/lib/shared/*` before creating new widgets. Responsive on Android, iOS, web, Windows, macOS, Linux. |
| Theming and i18n | Full theme support (light/dark/system). All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Modal-first workflows | **All create/edit/approve/complete/handoff actions** use **in-page dialogs, bottom sheets, or nested modals**. Do **not** navigate to new routes for within-module workflows. Shell entry routes (`/opd`, `/ipd`, etc.) and deep-link **pre-selection** of a patient/record are allowed; selecting a row opens the workspace detail panel — not a separate workflow page. |
| Realtime sync | Subscribe to relevant `RealtimeEventGroups` in workspace controllers. After mutations, refresh affected rows, detail panels, summary cards, and nav badges. Keep UI, frontend state, backend services, and database consistent. |
| Architecture | UI/controllers → repository → API (`frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`). Enforce RBAC + ABAC + tenant/facility scope + module entitlements (frontend `AccessGate` + backend authorization). |
| Database | Apply migrations for schema changes per backend standards; keep API contracts and schema aligned. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched modules. |

---


## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Patient registry responsibility |
| ----------- | ----------------------------- |
| §2 Walk-in / new patient | Search existing patient first; register only when no match |
| §2 Appointment check-in | Verify patient identity before check-in handoff to OPD |
| Start OPD encounter | Quick action → `startOpdFlow` / bootstrap with `patient_id` — registry does not own OPD stages |
| Triage vitals | Optional quick triage dialog routes to OPD/triage APIs on same patient |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Patient registry responsibility |
| ----------- | ----------------------------- |
| Step 3 Registration | Complete demographics for `Pending Registration` admissions |
| §2.1 Emergency | Support minimal/temporary registration; complete later |
| Admit from registry | Link to IPD `startAdmission` with verified `patient_id` |
| §16 Encounter hub | Patient is parent of encounter — show read-only clinical summary links |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Patient registry implementation |
| ------------ | ------------------------------- |
| Patient registry row | Demographics, identifiers, contacts, guardians, allergies, documents, consent, lookup |
| OPD/IPD boundary | Registry launches flows; does not replace OPD/IPD workspaces |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/patients/` | `patient_registry_page.dart`, controller, repository |
| Backend | `backend/src/modules/patient/` + related resources | CRUD, workspace overview, duplicates, merge |
| Key APIs | `GET/POST/PUT /patients`, `/patients/workspace/overview`, `/patients/duplicates`, `/merge`, `/:id/workspace` | Aggregate and granular |
| Quick actions | OPD start, vitals/triage, IPD disposition hooks | Embedded in registry page |
| Localization | `app_en.arb` | Patient strings substantial |

### Known gaps

- Monolithic registry page (~7k lines) — extract panels/widgets
- Per-patient workspace API underused vs client-side composition
- Emergency minimal registration path incomplete vs full demographics
- Deep links from OPD/IPD/Emergency to patient detail with context
- Frontend tests limited

---

## Scope — Core Capabilities

1. **Search and register** — fast search; create with required identifiers and consent flags.
2. **Patient detail** — contacts, guardians, allergies, history, documents; edit with permission gates.
3. **Duplicates and merge** — preview and merge with audit trail.
4. **Quick actions** — start OPD, triage vitals, open clinical context — without duplicating flow UIs.
5. **Cross-navigation** — links to active OPD encounter, IPD admission, billing ledger when permitted.

---

## UI / UX Requirements

- **Patient registry workspace** — `AppWorkspace` list+detail: a searchable patient list/table beside a patient profile/detail panel. Search-first: a prominent search bar drives lookup; selecting a patient opens the detail panel (not a separate route).
- **Modal CRUD** for demographics, identifiers, contacts, guardians, allergies, documents, and consent via `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart` / `app_dialog.dart`. Contextual quick actions (start OPD, triage vitals, IPD disposition) run as modals or deep-links — never duplicating downstream flow UIs.
- Optional summary cards (e.g. recently registered, incomplete registration) **filter** the registry list — they must not open separate list routes; hide zero-value cards.
- Reuse shared components: `frontend/lib/shared/layout/app_workspace.dart`, `components/app_search_bar.dart`, `app_list_table.dart`, `app_file_upload_panel.dart`, `app_copyable_identifier.dart`, and field widgets.
- Full theming (light/dark/system), all strings localized via `app_en.arb`, responsive across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Pattern peers: other registry/list workspaces, not clinical worklists.

---


## Architecture and Conventions

| Rule | Requirement |
| ---- | ----------- |
| Layering | Widgets → Riverpod controllers → repository interface → impl → API client. No API calls from widgets. |
| State | `AsyncNotifier` + `Result<T>` / `AppFailure` for errors. |
| Permissions | `AccessGate` / `AppAccessActionGate`; backend auth mandatory even when UI hides actions. |
| File size | Extract reusable widgets to `presentation/widgets/`; shared components to `frontend/lib/shared/`. |
| Realtime | `frontend/.cursor/realtime_sync.mdc` — partial refresh after modal success when supported. |

---


## Module Boundaries

- Do not own OPD queues, IPD bed board, or clinical documentation depth (Clinical module).
- Do not post charges — Billing owns financial records.

---

## Acceptance Criteria

- [ ] Staff can search, register, and maintain patient records end-to-end.
- [ ] OPD/IPD quick actions use correct patient and do not duplicate encounters/admissions.
- [ ] Duplicate merge works with confirmation and audit.
- [ ] No raw UUIDs in UI; permissions enforced.

---

## Quality Gate

From `frontend/` when touching Flutter:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="<module>"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
frontend/lib/features/patients/
backend/src/modules/patient/

Related prompts: prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/13-emergency-module-prompt.md, prompts/11-triage-module-prompt.md
```
