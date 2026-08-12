# Clinical tab — Completed

## 1. Tab strip

- Label: `clinicalSectionCompletedLabel` → **Completed** (not `clinicalSectionCompletedTodayLabel`)
- Icon: `Icons.task_alt_outlined`
- Count source: `state.completedCount` (facet total under shared filter/search; candidate load `AppPageRequest.maxPageSize`)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `completed` (aliases `completed-today`, `completed_today`, `closed`, `done`)
- Tab gate: `ClinicalCompletedAtomPermissions.tab` = `clinicalWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print**

- Same shared worklist chrome as Pending
- Filters: `commonFiltersActionLabel` → Advanced filters; Clear / Apply / Close
- Export / Print: gated by ∩ `evidence:export`; Print label `Print`; preview-first via `printClinicalWorkspaceList`
- Date filter: **enabled** — `clinicalLastUpdatedLabel`
- Context strip actions: **none**

## 3. Table

- Scope: `ClinicalQueueScope.completed` (terminal outpatient + same calendar day via `updatedAt` / `startedAt`)
- Row select → `_ClinicalEncounterDialog`
- **Default columns (5, justified exception):** patient, queue, **encounterType**, status, nextAction (provider not in default set; tested)
- Always-visible: status, nextAction
- Mobile meta: queue, encounterType
- Column choices: same full set as Pending
- Storage: `clinical_completed` / `clinical_cw_completed`

## 4. Advanced filters / search fields

- Same shared worklist filter model as table + active Completed badge (shared filter context)
- Footer: **Clear filters** → **Apply filters** → **Close**

## 5. Primary / secondary / row actions

- Vitals / disposition actions hidden when `entry.isTerminal`
- Open encounter still available; post-completion writes use write atoms (`reopen` maps write)
- Detail Print gated by ∩ `evidence:export`

## 6. Dialogs from this tab

Same Clinical-owned encounter shell + **reused** clinical_actions when still eligible; print / discharge. Flows stay in-desk.

## 7. Nested / follow-on

Same encounter detail panels; terminal entries suppress some mutation entry points in UI.

## 8. Forms (summary)

Same clinical forms when write actions remain mounted (shared field reuse; hide tenant/facility/session context).

## 9. Print / labels / preview

- Table Print: present after Export when export gate allows; preview-first
- Encounter Print: `showClinicalPrintSummaryDialog`; trigger label `Print`

## 10. Loading / empty / error / success

Shared clinical feedback; mutations refresh worklist + all visible tab counts.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / pagination / empty / loading / retry / rowSelect / detail / openEncounter / nextActionReview / nestedRead / completedChip | `clinicalWorkspaceReadRequirement` |
| export / listPrint / printSummary | `clinicalWorkspaceExportRequirement` (∩ `evidence:export`) |
| success / validation / create/update/delete/write / reopen / notes / vitals / diagnosis / procedure / refer / followUp / disposition / nestedWrite | `clinicalWorkspaceWriteRequirement` |
| requestLab / nestedLabWrite | lab order write ∪ |
| requestRadiology / nestedRadiologyWrite | radiology order write ∪ |
| prescribe / nestedPharmacyWrite | pharmacy order write ∪ |
| requestAdmission | admission write ∪ |
| dischargeFinancialRead | billing read ∩ |
| entry / routeEntry | catalog entry |
| followUpsTab | **n/a** on this atom class |
