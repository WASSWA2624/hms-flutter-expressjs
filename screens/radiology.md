# Action inventory — `/radiology`

Primary surface: `RadiologyWorkspacePage` (`frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`).

Write gates: request imaging uses `clinicalWrite` / `radiologyWrite` (`_requestRequirement`); work / configurations use `radiologyWrite` (`_workRequirement`); workflow stepper mutations also require active module `radiology-workflows`. Unauthorized write controls do not render (`AppAccessActionGate`). Backend auth remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** (primary when read-only; secondary when write) | Reload worklist | **Removed** — mutations / realtime / adaptive poll / scaffold **Try again** |
| **Configurations** only on Worklist / All orders | Open catalog / equipment | **Merged** — stable **Configurations** secondary on every non–Follow-ups tab |
| Row **WorkflowActionButton** (route-only back to `/radiology`) | Select order without opening work | **Removed** — stage-labeled **Next action** opens detail dialog directly |
| Deep link `orderId` / `encounterId` only selected order | Intermediate shell; hunt for row | **Removed** — deep link opens detail dialog |
| Detail header **Assign** / **Start** / **Perform study** / **Draft** / **Release** + section / stepper copies | Same writes | **Removed** from header — stepper owns assign/start; Studies / Report sections own study & report writes; header keeps **Cancel** only |
| Start imaging **notes** dialog | Optional notes; no required input | **Removed** — mutate directly with empty payload |
| Disabled **billing gate** stepper / header action | No-op chrome | **Removed** — step help already states await payment |
| Empty studies **Upload images** disabled CTA | Dead chrome | **Removed** — upload lives on study blocks after perform |
| Doctor review **Acknowledge** that only scrolled | Fake attest | **Removed** — attest stays on Report section; **Open report** scrolls for progressive disclosure |
| Order metadata **Payment** restating patient-context payment | Same info | **Removed** from metadata panel |
| Report panel **Draft** + empty-state **Draft** / inline save | Same draft write | **Merged** — empty CTA when no report; inline save when editing draft; panel Draft only when neither applies |
| Mobile list without next-action trailing | Same stage open as desktop column | **Fixed** — compact `RadiologyNextActionCell` on `AppListTableMobileItem.trailing` |

---

## Radiology workspace screen

### Tab strip

- **Worklist / Reporting / Released / All orders / Follow-ups**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies stage filter (non–Follow-ups). Follow-ups shows `FollowUpWorklistPanel`.
  - Condition: Always when workspace loads.
  - Counts: Summary counts per section / Follow-ups from `followUpTabCountProvider`.

- **Request imaging** (primary)
  - Location: Tab-strip primary on every non–Follow-ups tab.
  - Opens modal: Yes — create radiology order dialog.
  - Immediate result: Creates order; worklist refresh.
  - Condition: Request write; unauthorized control absent; Follow-ups has no strip primary.

- **Orders view / Patients view** (secondary)
  - Location: Tab-strip secondary.
  - Opens modal: No.
  - Immediate result: Toggles `RadiologyWorkbenchView`.
  - Condition: Non–Follow-ups tabs.

- **Configurations** (secondary)
  - Location: Tab-strip secondary on every non–Follow-ups tab.
  - Opens modal: Yes — facility radiology catalog / equipment dialog.
  - Immediate result: Browse/enable catalog procedures; manage equipment.
  - Condition: Radiology write; unauthorized control absent.

Tab-strip **Refresh** was removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads radiology workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (stage / status / modality / priority / payment / date), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Client/server filters / search / column visibility for the active tab.
  - Condition: Worklist sections (not Follow-ups).

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; **Request imaging** remains when authorized.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Radiology order detail dialog.
  - Immediate result: Loads workflow; complementary writes + imaging/reporting sections.
  - Condition: Always when rows exist.

- **Next action** (status-aware label)
  - Location: `next_action` column (always visible) and mobile list `trailing`.
  - Opens modal: Same detail dialog (no empty intermediate shell / no route-only loop).
  - Immediate result: Sole labeled row path into assign / start / study / report work.
  - Condition: Activatable except **Cancelled** (text only).

### Order detail dialog

- **Close**
  - Location: Dialog chrome.
  - Opens modal: No.
  - Immediate result: Dismisses detail.

- **Cancel order**
  - Location: Patient-context header only.
  - Opens modal: Cancel reason dialog.
  - Immediate result: Cancels order when eligible.
  - Condition: Write + `canCancel`.

- **Imaging floor / Reporting** view mode
  - Location: Detail body radios.
  - Opens modal: No.
  - Immediate result: Reorders sections / reveals report vs study primary CTAs.
  - Condition: Always in detail.

- **Workflow stepper** (Assign / Start imaging)
  - Location: `RadiologyWorkflowProgressSection`.
  - Opens modal: Assign collects schedule/assignee/equipment; Start mutates directly.
  - Immediate result: Advances imaging workflow; snackbar on failure.
  - Condition: Write + backend `nextActions`; unauthorized / unavailable actions absent; billing-blocked steps show help only.

- **Request details Edit**
  - Location: Request section panel action.
  - Opens modal: Edit request form.
  - Immediate result: Updates clinical request fields.
  - Condition: Write.

- **Perform study** / upload / PACS sync / remove asset
  - Location: Studies section (empty CTA or panel action when studies exist) + study blocks.
  - Opens modal: Study form / PACS sync notes when required.
  - Immediate result: Creates study, uploads assets, syncs PACS.
  - Condition: Write + capabilities.

- **Draft / release / request finalize / attest / addendum / print**
  - Location: Report section — empty CTA (first draft), inline save (editing draft), or panel Draft when neither; other actions on the panel.
  - Opens modal: Report / finalize / note dialogs as required.
  - Immediate result: Persists report workflow; validation banners; sync after mutations.
  - Condition: Write + capabilities; view mode may hide report CTAs on imaging floor.

- **Doctor review Open report**
  - Location: Doctor review panel when finalization capabilities apply.
  - Opens modal: No.
  - Immediate result: Scrolls to report section; version list for progressive disclosure.
  - Condition: When panel is shown.

### Deep links

- **`?orderId=` / `?encounterId=`** — opens detail for the matching row (no select-only shell).
- **`?section=` / `?search=`** — selects tab / pre-fills search.

### Manual checks (Req 7)

- [x] Unauthorized user: Request imaging, Configurations absent; view toggle remains; no Refresh. *(widget)*
- [x] Every worklist tab: one **Request imaging** primary and one **Configurations** secondary; no Refresh. *(widget)*
- [x] Ordered row **Next action** opens detail (no WorkflowActionButton route loop). *(widget)*
- [x] Deep link `/radiology?orderId=…` opens detail without hunting the row. *(widget)*
- [ ] Single-order detail: Assign/Start once (stepper); study/report CTAs once in their sections; Cancel once in header; Start imaging has no notes shell.
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths.
- [ ] Mobile list shows trailing next-action and opens the same detail dialog.
