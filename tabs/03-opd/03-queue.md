# OPD tab — Queue

## 1. Tab strip

- Label: `opdSectionQueueLabel`
- Icon: `Icons.queue_outlined`
- Count source: `state.queueCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `queue` (aliases `desk-queue`, `desk_queue`)
- Tab gate: `OpdQueueAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

**Filters → Settings → Export → Start OPD**; table Print **absent**.

## 3. Table

- Row model: queue-category `_OpdTableItem`
- Row select → Queue Actions (`actionRequirement: OpdQueueAtomPermissions.write`) — **sole hub entry**
- Default columns coded as Patient, Provider, Waiting time, Status, Next action — but `opdBoardShowsNextActionColumn` is **false** for Queue → Next action column **not mounted** (4 data columns shown)
- Column choices: Visit type, Arrival time, Arrival mode, Encounter

## 4. Advanced filters / search fields

Shared OPD filters + arrival date.

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

- Table Print: **absent**
- No Flow Actions print path from queue hub

## 10. Loading / empty / error / success

Shared board feedback; success `opdSavedMessage` after hub mutations.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Start OPD | encounter source |
| Prioritize / Move / Assign doctor | front-desk write |
| Next-action column | absent (inventory) |
| Nested billing/admission | _(n/a)_ |
