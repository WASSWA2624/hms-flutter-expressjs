# OPD tab — Queue

## 1. Tab strip

- Label: `opdSectionQueueLabel`
- Icon: `Icons.queue_outlined`
- Count source: `queueEntries.totalItemCount` (fallback `queueCount`); filtered when active + narrowed
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `queue` (aliases `desk-queue`, `desk_queue`)
- Tab gate: `OpdQueueAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Start OPD**

- Filters: `commonFiltersActionLabel` + date `opdArrivalDateFilterLabel` + Close `commonCloseActionLabel`
- Start OPD omitted without `OpdQueueAtomPermissions.startEncounter`
- Export/Print gated by ∩ `evidence:export`

## 3. Table

- Row model: queue-category `_OpdTableItem`
- Row select → Queue Actions (`actionRequirement: OpdQueueAtomPermissions.write`) — **sole hub entry**
- Default columns (5): Patient name, Doctor (provider), Wait time, Status, Visit type
- Next action column **not mounted** (`opdBoardShowsNextActionColumn` is false for Queue — row select is the sole hub entry)
- Column choices: Arrival time, Arrival mode, OPD encounter
- Mobile: arrival mode, waiting time, status; no next-action trailing

## 4. Advanced filters / search fields

Shared OPD filters + arrival date. Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Start OPD (search bar) when encounter gate allows
- No next-action mutation column
- Row → Queue Actions only

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Queue Actions | **reused** `showQueueActionsDialog` |
| Start encounter | **reused** |

## 7. Nested / follow-on (Queue Actions)

Front-desk (`OpdQueueAtomPermissions.frontDesk`):

1. Prioritize
2. Change status / Move
3. Assign / Change doctor

Hard-delete not mounted. Nested billing/admission panels not reachable from this tab.

## 8. Forms (summary)

Prioritize optional reason; queue status; provider select; encounter form from Start OPD.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printOpdWorkspaceList`
- No Flow Actions print path from queue hub

## 10. Loading / empty / error / success

Shared board feedback; success `opdSavedMessage` after hub mutations. Forbidden: `routeForbiddenTitle` when board read denied.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Export / Print | ∩ `evidence:export` |
| Start OPD | encounter source |
| Prioritize / Move / Assign doctor | front-desk write |
| Next-action column | absent (inventory) |
| Nested billing/admission | _(n/a)_ |
| Route entry | catalog ∩ `opd:read` |
