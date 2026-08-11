# Clinical tab — Results ready

## 1. Tab strip

- Label: `clinicalSectionResultsReadyLabel`
- Icon: `Icons.science_outlined`
- Count source: `state.resultsReadyCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `results-ready` (aliases `results_ready`, `resultsready`, `results`)
- Tab gate: `ClinicalResultsReadyAtomPermissions.tab` = `clinicalWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same as Pending; Export / Print absent; date enabled.

## 3. Table

- Scope: results-ready non-terminal
- **Default columns differ:** patient, **encounterType**, queue, status, nextAction (no default provider)
- Mobile meta: encounterType, queue
- Status chip: `clinicalResultsReadySummaryLabel` → `resultsReadyChip`
- Row tint for results-ready
- Storage: `clinical_resultsReady` / `clinical_cw_resultsReady`

## 4. Advanced filters / search fields

Shared filters; results-ready option group especially relevant.

## 5. Primary / secondary / row actions

Same next-action / Open encounter / Quick Actions; lab/radiology review paths prominent in detail.

## 6. Dialogs from this tab

Same Clinical + **reused** clinical_actions (lab/radiology especially).

## 7. Nested / follow-on

- Lab / radiology detail panels gated by `labResultsPanel` / `radiologyResultsPanel` (= clinical read)
- Nested order update / cancel / billing confirms

## 8. Forms (summary)

Same clinical forms; lab/radiology cancel reasons and billing nested.

## 9. Print / labels / preview

Encounter print summary only.

## 10. Loading / empty / error / success

Shared clinical feedback (+ realtime lab result snackbars).

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / printSummary / resultsReadyChip / labResultsPanel / radiologyResultsPanel | read ∩ |
| Mutations / clinical writes | write ∪ |
| requestLab / requestRadiology / nested order writes | lab/radiology write ∪ |
| routeEntry | catalog entry |
