# Claims tab — Active claims

## 1. Tab strip

- Label: `claimsSectionActiveClaims`
- Icon: `Icons.receipt_long_outlined`
- Count source: active claims scope (submitted/approved/partial/rejected membership totals)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `active-claims`
- Tab gate: `ClaimsActiveClaimsAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Settings** (+ strip primary Prepare claim)

- Filters: **intentionally omitted** (summary chips)
- Settings: present
- Export / table Print: **absent**
- Strip primary: `claimsPrepareClaimAction` — omitted without write ∩
- Date filter: **disabled**

## 3. Table

- Row model: `ClaimsQueueItem` (claim rows)
- Row select: detail
- Default columns: Reference, Patient, Coverage, Status, Next (when write ∪ financial:approve column chrome)
- Column choices: Invoice, Claim amount, Submitted at
- Next omitted without `claimsActiveClaimsNextActionColumnRequirement`

## 4. Advanced filters / search fields

- No advanced Filters sheet
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

Detail Sync insurer status (Active only). Print statement (read ∩). Collect navigates/opens Billing receive-payment.

## 8. Forms (summary)

- Prepare/submit/response: status, amounts, notes, insurer response fields
- Close as paid: locked PAID status path

## 9. Print / labels / preview

- Detail Print → `claimStatement` (claim statement title)
- Gate: document read ∩
- Table Print: absent

## 10. Loading / empty / error / success

- Same empty/error/snackbar patterns as Authorizations

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / Print | read ∩ |
| Prepare / Submit / Resubmit / Record / Sync | write ∩ |
| Close as paid / Next for APPROVED | financial:approve ∩ |
| Next column chrome | write ∪ financial:approve |
| Collect residual | billing write (via Billing) |
