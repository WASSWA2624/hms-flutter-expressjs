# Clinical tab — Results ready

## 1. Tab strip

- Label: `clinicalSectionResultsReadyLabel` → **Results ready**
- Icon: `Icons.science_outlined`
- Count source: `state.resultsReadyCount` (facet total under shared filter/search; candidate load `AppPageRequest.maxPageSize`)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `results-ready` (aliases `results_ready`, `resultsready`, `results`)
- Tab gate: `ClinicalResultsReadyAtomPermissions.tab` = `clinicalWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print**

- Same shared worklist chrome as Pending
- Filters: `commonFiltersActionLabel` → Advanced filters; Clear / Apply / Close
- Export / Print: gated by ∩ `evidence:export`; Print label `Print`; preview-first via `printClinicalWorkspaceList`
- Date filter: **enabled** — `clinicalLastUpdatedLabel`
- Context strip actions: **none**

## 3. Table

- Scope: `ClinicalQueueScope.resultsReady` (non-terminal outpatient + `resultsReady`)
- Row select → `_ClinicalEncounterDialog`
- Row tint: `tertiaryContainer` alpha when `resultsReady`
- Status / detail chip: `clinicalResultsReadySummaryLabel` gated by `ClinicalResultsReadyAtomPermissions.resultsReadyChip`
- **Default columns (5, justified exception):** patient, **encounterType**, queue, status, nextAction (provider not in default set — review-by-type first; tested)
- Always-visible: status, nextAction
- Mobile meta: encounterType, queue
- Column choices: same full set as Pending
- Storage: `clinical_resultsReady` / `clinical_cw_resultsReady`

## 4. Advanced filters / search fields

- Same shared worklist filter model as table + active Results ready badge (shared filter context)
- Results-ready group especially relevant (`__RESULTS_READY__` / `__RESULTS_NOT_READY__`)
- Footer: **Clear filters** → **Apply filters** → **Close**

## 5. Primary / secondary / row actions

Same next-action / Open encounter / detail Quick Actions as Pending (Print gated by ∩ `evidence:export`). Lab/radiology review paths prominent in detail.

## 6. Dialogs from this tab

Same Clinical-owned encounter shell + **reused** clinical_actions / print / discharge (lab/radiology especially). Flows stay in-desk.

## 7. Nested / follow-on

- Same encounter detail panels and nested order/billing confirms
- Lab / radiology panels gated by `labResultsPanel` / `radiologyResultsPanel` (= clinical read; see convention gaps)

## 8. Forms (summary)

Same clinical action forms as Pending; lab/radiology cancel reasons and billing nested (shared field reuse; hide tenant/facility/session context).

## 9. Print / labels / preview

- Table Print: present after Export when export gate allows; preview-first
- Encounter Print: `showClinicalPrintSummaryDialog`; trigger label `Print`

## 10. Loading / empty / error / success

Shared clinical feedback (+ realtime lab result snackbars); mutations refresh worklist + all visible tab counts.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / pagination / empty / loading / retry / rowSelect / detail / nextActionReview / nestedRead / resultsReadyChip / labResultsPanel / radiologyResultsPanel | `clinicalWorkspaceReadRequirement` |
| export / listPrint / printSummary | `clinicalWorkspaceExportRequirement` (∩ `evidence:export`) |
| success / validation / create/update/delete/write / notes / vitals / diagnosis / procedure / refer / followUp / disposition / nestedWrite | `clinicalWorkspaceWriteRequirement` |
| requestLab / nestedLabWrite | lab order write ∪ |
| requestRadiology / nestedRadiologyWrite | radiology order write ∪ |
| prescribe / nestedPharmacyWrite | pharmacy order write ∪ |
| requestAdmission | admission write ∪ |
| dischargeFinancialRead | billing read ∩ |
| entry / routeEntry | catalog entry |
| followUpsTab | **n/a** on this atom class |
