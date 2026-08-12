# Clinical tab — Assigned to me

## 1. Tab strip

- Label: `clinicalSectionAssignedToMeLabel` → **Assigned to me**
- Icon: `Icons.person_outline`
- Count source: `state.assignedToMeCount` (facet total under shared filter/search; candidate load `AppPageRequest.maxPageSize`)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `assigned-to-me` (aliases `assigned_to_me`, `assignedtome`, `mine`, `assigned`)
- Tab gate: `ClinicalAssignedToMeAtomPermissions.tab` = `clinicalWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print**

- Same shared worklist chrome as Pending
- Filters: `commonFiltersActionLabel` → Advanced filters; Clear / Apply / Close
- Export / Print: gated by ∩ `evidence:export`; Print label `Print`; preview-first via `printClinicalWorkspaceList`
- Date filter: **enabled** — `clinicalLastUpdatedLabel`
- Context strip actions: **none**

## 3. Table

- Scope: `ClinicalQueueScope.assignedToMe` (non-terminal outpatient + `providerUserId` == session user)
- Row select → `_ClinicalEncounterDialog`
- **Default columns (5):** patient, queue, provider (`Doctor`), status, nextAction
- Always-visible: status, nextAction
- Column choices: same full set as Pending
- Storage: `clinical_assignedToMe` / `clinical_cw_assignedToMe`

## 4. Advanced filters / search fields

- Same shared worklist filter model as table + active Assigned badge (shared filter context)
- Footer: **Clear filters** → **Apply filters** → **Close**

## 5. Primary / secondary / row actions

Same next-action / Open encounter / detail Quick Actions as Pending (Print gated by ∩ `evidence:export`).

## 6. Dialogs from this tab

Same Clinical-owned encounter shell + **reused** clinical_actions / print / discharge. Flows stay in-desk.

## 7. Nested / follow-on

Same encounter detail panels and nested order/billing confirms.

## 8. Forms (summary)

Same clinical action forms as Pending (shared field reuse; hide tenant/facility/session context).

## 9. Print / labels / preview

- Table Print: present after Export when export gate allows; preview-first
- Encounter Print: `showClinicalPrintSummaryDialog`; trigger label `Print`

## 10. Loading / empty / error / success

Shared clinical feedback; mutations refresh worklist + all visible tab counts.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / pagination / empty / loading / retry / rowSelect / detail / nextActionReview / nestedRead | `clinicalWorkspaceReadRequirement` |
| export / listPrint / printSummary | `clinicalWorkspaceExportRequirement` (∩ `evidence:export`) |
| success / validation / create/update/delete/write / notes / vitals / diagnosis / procedure / refer / followUp / disposition / nestedWrite | `clinicalWorkspaceWriteRequirement` |
| requestLab / nestedLabWrite | lab order write ∪ |
| requestRadiology / nestedRadiologyWrite | radiology order write ∪ |
| prescribe / nestedPharmacyWrite | pharmacy order write ∪ |
| requestAdmission | admission write ∪ |
| dischargeFinancialRead | billing read ∩ |
| entry / routeEntry | catalog entry |
| followUpsTab | **n/a** on this atom class |
