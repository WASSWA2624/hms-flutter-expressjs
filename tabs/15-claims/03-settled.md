# Claims tab — Settled

## 1. Tab strip

- Label: `claimsSectionSettled`
- Icon: `Icons.task_alt_outlined`
- Count source: `state.paidClosedCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `settled`
- Tab gate: `ClaimsSettledAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**
- Strip primary: **absent** (review-only)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**

- Filters: **enabled** (only Settled among queue tabs)
- Settings: present
- Export / table Print: **absent**
- Context strip actions: none
- Date filter: **disabled**
- Summary chips: **absent**

## 3. Table

- Row model: `ClaimsQueueItem` (paid/cancelled closed)
- Row select: detail (read-only mutation surface)
- Default columns: Reference, Patient, Coverage, Settlement amount, Status
- Column choices: Invoice, Claim amount, Timeline
- Next action column: **never** (`claimsSectionShowsNextActionColumn` → false)

## 4. Advanced filters / search fields

- Group: Queue filter Paid / Cancelled (`_claimsFilterChoicesForSection`)
- No date filter

## 5. Primary / secondary / row actions

- Row select → detail only
- No Prepare / Request / Sync / Next

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Claims detail (review) | Claims-owned |

## 7. Nested / follow-on

Detail Print when nested export ∪ allowed. Sync explicitly gated off Settled.

## 8. Forms (summary)

- No mutation forms on Settled

## 9. Print / labels / preview

- Detail Print → `claimStatement`
- Gate: `ClaimsSettledAtomPermissions.export` (∪ `reports:read` \| `evidence:export` ∩ module)
- **Omitted when unauthorized** (even if detail open)

## 10. Loading / empty / error / success

- Empty queue copy; read-only refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / Filters / Settings / detail | read ∩ |
| Print statement | nested export ∪ |
| Write / approve / Sync / Next | **not mounted** |
