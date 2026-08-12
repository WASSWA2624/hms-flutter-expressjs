# Claims tab — Active claims

## 1. Tab strip

- Label: `claimsSectionActiveClaims`
- Icon: `Icons.receipt_long_outlined`
- Count source: active claims scope summary; active + narrowed → `queue.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `active-claims`
- Tab gate: `ClaimsActiveClaimsAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (+ strip primary Prepare claim)

- Filters: present (status groups; summary chips remain shortcuts)
- Settings: present
- Export / table Print: ∩ `evidence:export` — omit when unauthorized
- Strip primary: `claimsPrepareClaimAction` — omitted without write ∩
- Date filter: **disabled** (API/query have no date range)

## 3. Table

- Row model: `ClaimsQueueItem` (claim rows)
- Row select: detail
- Default columns (5): Reference, Patient, Coverage, Status, Next (when write ∪ financial:approve column chrome) **or** Invoice when Next is omitted
- Column choices: Invoice (when not already default), Claim amount, Submitted at
- Next omitted without `claimsActiveClaimsNextActionColumnRequirement`

## 4. Advanced filters / search fields

- Advanced Filters: Submitted / Approved / Partial / Rejected
- Footer: Clear filters → Apply filters → Close
- Summary chips: Submitted / Approved / Partial / Rejected → filter

## 5. Primary / secondary / row actions

- Strip: Prepare claim
- Next: Submit / Resubmit / Record response (write); Close as paid (financial:approve)
- Detail Sync (write); Collect patient share → Billing when residual

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Claims detail | Claims-owned |
| Prepare / Submit / Record response | Claims-owned |
| Close as paid | Claims-owned |
| Collect patient share | **reused** Billing |

## 7. Nested / follow-on

Detail Sync insurer status (Active only). Detail Print (read ∩). Collect navigates/opens Billing receive-payment.

## 8. Forms (summary)

- Prepare/submit/response: status, amounts, notes, insurer response fields
- Close as paid: locked PAID status path

## 9. Print / labels / preview

- Detail Print: label `Print` → `claimStatement`
- Gate: document read ∩
- Table Print: preview-first `printClaimsListTable`; gate ∩ `evidence:export`

## 10. Loading / empty / error / success

- Same empty/error/snackbar patterns as Authorizations

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / settings / detail / Detail Print | read ∩ |
| Table Export / Print | ∩ `evidence:export` |
| Prepare / Submit / Resubmit / Record / Sync | write ∩ |
| Close as paid / Next for APPROVED | financial:approve ∩ |
| Next column chrome | write ∪ financial:approve |
| Collect residual | billing write (via Billing) |
