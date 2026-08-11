# Claims tab — Authorizations

## 1. Tab strip

- Label: `claimsSectionAuthorizations`
- Icon: `Icons.verified_user_outlined`
- Count source: authorization-scope count from workspace state
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `authorizations`
- Tab gate: `ClaimsAuthorizationsAtomPermissions.tab` = ∩ `billing:read` + `insurance-claims`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Settings** (+ strip primary Request authorization)

- Search: claims search hint
- Filters: **intentionally omitted** (summary chips act as status shortcuts)
- Settings: present
- Export / table Print: **absent**
- Strip primary: `claimsRequestAuthorizationAction` — omitted without ∩ `billing:write`
- Date filter: **disabled**

## 3. Table

- Row model: `ClaimsQueueItem` (authorization rows)
- Row select: claims detail
- Default columns: Reference, Patient, Coverage, Status, Next (when write)
- Column choices: Approved amount, Requested at
- Next column omitted without write ∩
- Mobile: trailing next when shown

## 4. Advanced filters / search fields

- No advanced Filters sheet
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

Detail Print statement when document read ∩. No Sync on this tab. No Settled export ∪.

## 8. Forms (summary)

- Request/update authorization: patient/coverage/status/amount/notes groups

## 9. Print / labels / preview

- Detail: `claimsPrintStatementAction` → `PrintDocumentTemplates.claimStatement` (authorization statement title)
- Gate: `ClaimsAuthorizationsAtomPermissions.document` (read ∩)
- Table Print: absent

## 10. Loading / empty / error / success

- Empty: claims empty queue copy
- Error/success: snackbars + refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / settings / chips / detail | read ∩ |
| Request / Update / Next column | write ∩ |
| Print statement | document read ∩ |
| Approve / Sync / Settled export | **absent** on this tab |
