# Reception tab — High priority

## 1. Tab strip

- Label: `receptionSectionHighPriority`
- Icon: `Icons.priority_high_outlined`
- Count source: authoritative prioritized non-terminal queue scope total; when this tab is active and search/advanced filters/date narrow the list, badge uses the filtered membership total
- Sibling tabs: dedicated unfiltered scope totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.warning` (attention queue)
- Deep-link `section`: `high-priority` (aliases `high_priority`, `priority`)
- Tab gate: `ReceptionHighPriorityAtomPermissions.tab` = ∩ `patient:read` (+ modules) — **same as desk queue read**, not emergency read
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule → Register**

- Search hint: `receptionSearchHint`
- Filters / Settings: shared labels (`commonFiltersActionLabel`, `commonTableSettings*`)
- Export: gated by `ReceptionHighPriorityAtomPermissions.export` / `receptionDeskExportRequirement` (∩ `evidence:export`); omitted when denied
- Print (toolbar): `commonPrintActionLabel` → preview-first `printReceptionDeskList` / `PrintDocumentTemplates.registry`; omitted without export/print gate
- Schedule / Register: ∩ `patient:write`
- Date filter: **enabled** — `receptionQueuedAtLabel`

## 3. Table

- Row model: prioritized non-terminal queue rows (`_ReceptionDeskRow.queue`)
- Row select:
  - Linked **emergency** flow + ∪ `emergency:read` → Flow Actions (emergency nested chrome; `printActionLabel: Print`)
  - Linked flow without emergency grant → fall through to Queue Actions (emergency Flow Actions not mounted)
  - No linked flow → Queue Actions (`ReceptionHighPriorityAtomPermissions.frontDesk`)
- Default columns (prefer **5** data columns; next-action is read-only guidance):
  1. Patient (alwaysVisible) — name + identifier subtitle only (atomic)
  2. Priority flag (`receptionHighPriorityBadgeLabel`) — single atomic badge: Emergency when nested emergency read + `isReceptionEmergencyFlow`, otherwise High priority when prioritized
  3. Phone
  4. Queued at (`receptionQueuedAtLabel`)
  5. Current step (`receptionCurrentStepLabel`)
  6. Next action label — if allowed (`nextActionLabel`); **read-only text**
- Mobile compact row may still show emergency / priority meta chips when nested emergency read allows
- Column choices (Settings): Provider / Doctor, Patient ID, Queue ID, Payment status, Reason
- Reset restores the five defaults (+ next-action when readable)

## 4. Advanced filters / search fields

Same as Desk queue (shared filter model with table + active count): Current step, Next action, Provider, Payment status; date on queued-at; search fields patient/record/staff/reason/status

## 5. Primary / secondary / row actions

- Strip: Schedule, Register
- Row: Queue Actions and/or Flow Actions as above
- Next-action column: read-only guidance

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Queue Actions | Reception → **reused** `QueueActionsDialog` |
| Flow Actions (esp. emergency-linked) | **reused** |
| Schedule / Register | shared |

## 7. Nested / follow-on

- Queue hub: Prioritize, Move/change status, Assign/Change doctor (same as Desk queue)
- Flow Actions: front-desk subset; clinical/vitals/billing off; Print trigger `Print`
- Emergency nested read gate: `receptionHighPriorityEmergencyNestedReadRequirement` = ∪ `emergency:read` + `scheduling-queue`
- Does **not** grant `/emergency` shell entry
- Hard-delete **not mounted**

## 8. Forms (summary)

- Same nested form groups as Desk queue hubs + shared Schedule/Register

## 9. Print / labels / preview

- Table Print: present when authorized; preview before device print
- Flow Actions Print when that hub opens: label `Print` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Empty: `receptionHighPriorityEmptyTitle` / `receptionHighPriorityEmptyBody`
- Success / loading / error: shared workspace patterns + `opdSavedMessage`
- After mutations: refresh table + all visible tab counts

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / next-action label | ∩ `patient:read` |
| Export / Print | ∩ `evidence:export` |
| Register / Schedule | ∩ `patient:write` |
| Hub prioritize / status / assign | source front-desk |
| Emergency Flow Actions / emergency badge | ∪ `emergency:read` (nested; does **not** unlock tab) |
| Hard delete | not mounted |
| Nested write matrix | n/a — front-desk hub only |
| Deep-link workspace entry | ∪ `patient:read` \| `last_office:read` |
