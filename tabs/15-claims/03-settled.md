# Claims tab — Settled

## 1. Tab strip

- Label: `claimsSectionSettled`
- Icon: `Icons.task_alt_outlined`
- Count source: `state.paidClosedCount`; active + narrowed → `queue.totalItemCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `settled`
- Tab gate: `ClaimsSettledAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**
- Strip primary: **absent** (review-only)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print**

- Filters: enabled (Paid / Cancelled)
- Settings: present
- Export / table Print: ∩ `evidence:export` — omit when unauthorized
- Context strip actions: none
- Date filter: **disabled** (API/query have no date range)
- Summary chips: **absent**

## 3. Table

- Row model: `ClaimsQueueItem` (paid/cancelled closed)
- Row select: detail (read-only mutation surface)
- Default columns: Reference, Patient, Coverage, Settlement amount, Status — **5**
- Column choices: Invoice, Claim amount, Timeline
- Next action column: **never** (`claimsSectionShowsNextActionColumn` → false)

## 4. Advanced filters / search fields

- Group: Queue filter Paid / Cancelled (`_claimsFilterChoicesForSection`)
- Footer: Clear filters → Apply filters → Close
- No date filter

## 5. Primary / secondary / row actions

- Row select → detail only
- No Prepare / Request / Sync / Next

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Claims detail (review) | Claims-owned |

## 7. Nested / follow-on

Detail Print when ∩ `evidence:export` allowed (same desk gate as table Print). Sync explicitly gated off Settled.

## 8. Forms (summary)

- No mutation forms on Settled

## 9. Print / labels / preview

- Detail Print: label `Print` → `claimStatement`
- Gate: `claimsDetailPrintRequirement(settled)` = ∩ `evidence:export` (same as table Print)
- Nested ∪ `ClaimsSettledAtomPermissions.export` remains for matrix completeness (platform auto-injects `reports:read`)
- Table Print: preview-first; gate `ClaimsSettledAtomPermissions.tableExport` / `print` (∩ `evidence:export`)
- **Omitted when unauthorized**

## 10. Loading / empty / error / success

- Empty queue copy; read-only refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / Filters / Settings / detail | read ∩ |
| Detail Print / Table Export / Print | ∩ `evidence:export` |
| Nested export atom (matrix) | ∪ `reports:read` \| `evidence:export` |
| Write / approve / Sync / Next | **not mounted** |
