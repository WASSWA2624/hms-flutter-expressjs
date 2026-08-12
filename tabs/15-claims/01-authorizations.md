# Claims tab — Authorizations

## 1. Tab strip

- Label: `claimsSectionAuthorizations`
- Icon: `Icons.verified_user_outlined`
- Count source: authorization-scope summary total; active + narrowed → `queue.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `authorizations`
- Tab gate: `ClaimsAuthorizationsAtomPermissions.tab` = ∩ `billing:read` + `insurance-claims`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (+ strip primary Request authorization)

- Search: claims search hint
- Filters: present (status groups; summary chips remain shortcuts)
- Settings: present
- Export / table Print: ∩ `evidence:export` — omit when unauthorized
- Strip primary: `claimsRequestAuthorizationAction` — omitted without ∩ `billing:write`
- Date filter: **disabled** (API/query have no date range)

## 3. Table

- Row model: `ClaimsQueueItem` (authorization rows)
- Row select: claims detail
- Default columns (5): Reference, Patient, Coverage, Status, Next (when write ∩) **or** Amount/Approved amount when Next is omitted
- Column choices: Approved amount (when not already default), Requested at
- Next column omitted without write ∩
- Mobile: trailing next when shown

## 4. Advanced filters / search fields

- Advanced Filters: authorization status choices (Pending / Approved / Denied / Expired)
- Footer: Clear filters → Apply filters → Close
- Summary chips (when count > 0): Auth pending / approved / Denied / Expired → apply queue filter

## 5. Primary / secondary / row actions

- Strip: Request authorization
- Next: Update status (write)
- Deep-link `action=preauth`: create dialog when write

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Claims detail | Claims-owned |
| Request authorization | Claims-owned |
| Update authorization / status | Claims-owned |

## 7. Nested / follow-on

Detail Print when document read ∩. No Sync on this tab. No Settled nested export ∪.

## 8. Forms (summary)

- Request/update authorization: patient/coverage/status/amount/notes groups

## 9. Print / labels / preview

- Detail: label `Print` → `PrintDocumentTemplates.claimStatement`
- Gate: `ClaimsAuthorizationsAtomPermissions.document` (read ∩)
- Table Print: preview-first `printClaimsListTable`; gate ∩ `evidence:export`

## 10. Loading / empty / error / success

- Empty: claims empty queue copy
- Error/success: snackbars + refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / chips / detail | read ∩ |
| Request / Update / Next column | write ∩ |
| Detail Print | document read ∩ |
| Table Export / Print | ∩ `evidence:export` |
| Approve / Sync / Settled nested export | **absent** on this tab |
