# Action inventory — `/nursing`

Primary surface: `NursingWorkspacePage` (`frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`).

Write gate: `nursingWriteRequirement` / `NursingPatientDetailDialog.writeRequirement` (`clinicalWrite` | `patientWrite` | `lastOfficeWrite` + nurse/manager/admin roles + `inpatient-bed-management`). Matrix All / Assigned ward create/update/delete lists ∩ `clinical:write` alone — keep this source ∪; mapping noted in `NursingAllAtomPermissions` / `NursingAssignedWardAtomPermissions` / tests. Transfer / Discharge pending stage writes prefer matrix ∩ `clinical:write` (`nursingClinicalWriteRequirement` / tab `*AtomPermissions.write`). Open ICU navigation remains without write. Unauthorized write controls do not render.

Read chrome (All / Assigned ward): ∪ `clinical:read` | `patient:read` + `inpatient-bed-management` (`nursingWorkspaceReadRequirement` / `NursingAllAtomPermissions.tab` / `NursingAssignedWardAtomPermissions.tab`). Route entry ∪ also allows `last_office:read` | `operations:read` (`RouteAccessCatalog.nursingEntry` / `AppRoutes.nursing`); those alone do not unlock All / Assigned ward chrome or writes.

Medication panel: ∩ `pharmacy:read`. Administer / medication next-action: `pharmacy:read` ∩ (`clinical:write` | `pharmacy:write`) + write roles + module. Shift context: roster/hr/operations/unit read ∪ + `hr-rosters`.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload worklist | **Removed** — list syncs after mutations / scaffold **Try again** |
| Tab-strip primary (Record vitals / Administer medication / …) depends on prior selection | Same stage write as row | **Removed** — row **Next action** is the labeled minimal path |
| Tab-strip **Add note** (no patient selected) | Add nursing note | **Removed** — sole entry is detail **Add note** after row select |
| Detail Quick Action matching row next-action (vitals / medication / handover / transfer / discharge / escalate) | Same write | **Omitted** from detail via `omitNextActionKind` — next-action is the sole primary for that goal |
| Detail actions shown disabled when ineligible (transfer / discharge) | No-op chrome | **Removed** — ineligible writes omitted; `permissionActions` hide when denied |
| Deep link `panel=` opened detail shell then required hunting for the action | Intermediate shell | **Removed** — panel deep links open the focused mutation dialog directly |
| Mobile list without next-action trailing | Same stage write as desktop column | **Fixed** — compact `NursingNextActionCell` on `AppListTableMobileItem.trailing` (tooltip + semantic label) |
| Dead tab-strip `nursingPrimaryActionLabel` / `Icon` helpers | Parallel primary write API with no UI | **Removed** — row next-action is the sole primary |

---

## Nursing workspace screen

### Tab strip

- **All / Assigned ward / Urgent / Medication due / Handover pending / Transfer pending / Discharge pending**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_scope`, updates URL `?scope=…`, reloads worklist.
  - Condition: Always when workspace loads.
  - Counts: From workspace state; Urgent danger tone; Medication / Transfer warning tone.

- **Shift context** (secondary)
  - Location: Tab-strip toolbar.
  - Opens modal: Yes — roster + pending handovers overview.
  - Immediate result: Read-only shift context (progressive disclosure).
  - Condition: Always when workspace loads.

Tab-strip primary write, **Add note**, and **Refresh** were removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads nursing workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings dialog.
  - Immediate result: Search / filters / column visibility for the active scope.
  - Condition: Always when worklist loads.

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Patient detail dialog (context, checklist, complementary writes, records).
  - Immediate result: Loads detail; omits the stage next-action from Quick Actions.
  - Condition: Always when rows exist.

- **Next action** (stage label)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing`.
  - Opens modal: Matching mutation dialog (vitals / medication / handover / transfer / discharge / escalate).
  - Immediate result: Persists via controller; snackbar; worklist refresh. No empty detail shell.
  - Condition: Write gate; unauthorized next-action absent. All / Assigned ward use task-type cascade; Urgent critical → Escalate; scoped tabs force that scope’s action.

### Detail dialog

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (add note, prescribe, lab/radiology, escalate when not next-action, accept handover, print, and stage actions when not the row next-action)
  - Location: Detail `AppQuickActions` (`permissionActions`).
  - Opens modal: Matching action dialog (or navigates for Open ICU).
  - Immediate result: Mutates selected admission; snackbar; refresh where needed.
  - Condition: Write gate; action omitted when it equals `omitNextActionKind`; transfer only with active transfer; discharge only when pending; unauthorized / ineligible writes absent.

- **Admission checklist**
  - Location: Detail checklist panel.
  - Opens modal: Checklist step dialogs (identity / vitals / allergies / belongings / care plan / notify / handover / clearance).
  - Immediate result: Progressive disclosure for admission checklist steps.
  - Condition: Always when detail is open.

### Deep links

- **`?id=` / `?admissionId=`** — opens patient detail (next-action omitted).
- **`?id=&panel=vitals|medication|handover|discharge`** — opens the focused mutation dialog directly (no empty detail shell).
- **`?id=&panel=checklist`** — opens patient detail (checklist on detail).
- **`?scope=` / `?search=`** — selects tab / pre-fills search.

### Manual checks (Req 7)

- [x] Unauthorized user: next-action writes and detail write actions absent; Open ICU still available when ICU active. *(widget: `unauthorized policy hides next-action writes`)*
- [x] All-tab routine patient: only **Record vitals** next-action; detail has no Record vitals duplicate. *(widget)*
- [x] Medication-due patient: only **Administer medication** next-action; detail omits Administer medication. *(widget)*
- [x] Urgent critical patient: only **Escalate** next-action; detail omits Escalate. *(widget)*
- [x] Deep link `/nursing?id=…&panel=vitals` opens vitals dialog without an empty detail first. *(widget)*
- [x] No Refresh, Add note, or primary write control on the tab strip; worklist still updates after a successful mutation. *(widget; dead `nursingPrimaryAction*` helpers removed)*
- [x] Mobile list shows next-action trailing; tapping it completes the same write as desktop. *(widget)*
- [x] All-tab permission scan: ∩ denial / ∪ allowance / subscription strip / meds panel / shift context / viewports / themes. *(widget: `nursing_all_permissions_test.dart`)*
- [x] Urgent-tab permission scan: ∩ denial / ∪ allowance / subscription strip / Escalate next-action / meds panel / shift context / viewports / themes. *(widget: `nursing_urgent_permissions_test.dart`)*
- [x] Discharge-pending permission scan: ∩ `clinical:write` for discharge CTA; ∪ read; nested billing/pharmacy; subscription strip; complementary source ∪; viewports / themes. *(widget: `nursing_discharge_pending_permissions_test.dart`)*
- [x] Medication-due permission scan: ∩ `pharmacy:read` (+ clinical|pharmacy write) for Administer / med panel; ∪ `clinical:read` \| `patient:read` for tab; matrix View ∩ / create∩ mapping noted; subscription strip; shift context; viewports / themes. *(widget: `nursing_medication_due_permissions_test.dart`)*
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths. *(manual — dialog validation / snackbars reuse shared nursing helpers)*
