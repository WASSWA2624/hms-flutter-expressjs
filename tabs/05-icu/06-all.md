# ICU tab — All ICU

## 1. Tab strip

- Label: `icuAllIcuLabel`
- Icon: `Icons.inventory_2_outlined`
- Count source: `state.allCount` ← `scopeCounts.all` (server `totalItemCount` for `IcuBoardScope.all`); when this tab is selected and search/advanced filters narrow the list, badge uses filtered membership (search → board `totalItemCount`; option/date filters → client filter of current page)
- Sibling tabs: dedicated unfiltered `IcuScopeCounts`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all`
- Tab gate: `IcuAllAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (unauthorized Export/Print omitted)

- Search hint: `icuSearchHint` (submit/clear → `applySearch`)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close = Reset columns / Apply columns / Close
- Export: `commonTableExportActionLabel` gated by `canExportIcuWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintIcuWorkspace`; preview-first `printIcuWorkspaceList`
- Context strip actions: **none**
- Date filter: admitted-at (`ipdAdmittedAtColumnLabel`) — shared board filter chrome

## 3. Table

- Row model: `IcuPatientSummary` via `IcuBoardPanel`
- Scope: `IcuBoardScope.all`
- Row select → ICU stay detail (`openIcuDetailDialog`)
- Default columns (≤5): Patient, Bed, Source, Status, Next action (same shape as Active; Next action kept for readers — write kinds gate via `AppAccessActionGate`)
- Column choices (Settings): alert, icu_start, transfer, admitted, encounter (plus defaults when not already visible)
- Storage keys: `'icu_all'` / `'icu_cw_all'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Groups: alert / bed / source (`icuBoardFilterGroups`) + date range on `admittedAt`
- Client-side filter on current page for option/date groups; search reloads server scope
- All badge reflects filtered membership when narrowed (same filter model as table)

## 5. Primary / secondary / row actions

- Strip context: none
- Next-action cell: same cascade as Active (`_resolveIcuNextAction`); workflow `nextStep` wins when registered
- Row select → stay detail hub

## 6. Dialogs from this tab

Same stack as Active (ICU stay detail + mutation dialogs + **reused** clinical orders).

## 7. Nested / follow-on

Same as Active (IPD / billing / discharge clearance / clinical nested; Print `commonPrintActionLabel`).

## 8. Forms (summary)

Same ICU + clinical order forms as Active; no tenant/facility/session fields.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printIcuWorkspaceList`
- Stay detail Print: `commonPrintActionLabel` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Board empty: `icuNoPatientsTitle` / `icuNoPatientsBody`
- Workspace load/retry: `AsyncStateScaffold` + `IcuWorkspaceController.refresh`
- Mutations refresh board + sibling `scopeCounts` (incl. all badge)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / detail | `icuWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Mutations / next-action writes / panelDeepLink | `icuWorkspaceWriteRequirement` |
| Navigation / openIpd / openDischargeClearance | `icuNavigationRequirement` |
| openBilling / billingPanel | ∩ `billing:read` + `billing-payments` |
| Route entry | catalog ∩ `icu:read` + module |
