# Billing tab — Open claims (`claimsPending` / `claims`)

## 1. Tab strip

- Label: `billingClaimsPending`
- Tooltip: `billingClaimsPendingTooltip`
- Icon: `Icons.health_and_safety_outlined`
- Count source: `summary.claimsPending`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `claims` (alias `claims-pending`)
- Tab gate: `BillingClaimsPendingAtomPermissions.tab` / `billingClaimsPendingTabRequirement` — needs `insurance-claims`
- **Omitted when unauthorized** (insurance module missing hides tab)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings** (no Charge / Issue all / Close trailing)

- Settings key: `billing_claims_v1`
- Export / table Print: **absent**
- Trailing context actions: **none** on this tab

## 3. Table

- Default columns: Patient / Invoice / Encounter / Status / Next action
- Next action column mounts only when `canMutateBillingClaims` (write alone without insurance must not show empty column)
- Column choices (claims-specific): Insurer, Scheme, Patient share, Insurer share
- Row select → detail

## 4. Advanced filters / search fields

- Groups: Source, Status (claims choices)
- Text filters + issued date
- No overdue/age groups here

## 5. Primary / secondary / row actions

- Next action: Submit claim / Record insurer response / Approve·Deny pre-auth when item allows + claims write ∩
- Detail mirrors those actions; Close shift/day **not mounted** (atom map documents write ∩ if reused)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail | Billing-owned |
| Submit claim / Reconcile / Pre-auth status | Billing-owned |
| Ledger (claims nested read) | Billing-owned |
| Claim/pre-auth print | Billing claim print helpers |

## 7. Nested / follow-on

Claim mutation forms → success refresh; print claim/pre-auth statement from detail when document read ∩.

## 8. Forms (summary)

- Claim submit / reconcile response fields; pre-auth approve/deny notes

## 9. Print / labels / preview

- Table Print: **absent**
- Detail: invoice PDF when invoice; claim/pre-auth statement print helpers

## 10. Loading / empty / error / success

- Empty: `billingEmptyClaimsPendingBody` (short title copy)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail | claims pending tab ∩ (+ insurance-claims) |
| Submit / Reconcile / Pre-auth | claims write ∩ |
| Next-action column mount | claims mutate allowed |
| Close shift/day | write ∩ documented — **not mounted** |
| Ledger | nested claims read ∩ |
| Print/Download | document read ∩ |
| Approve nested (other kinds) | approve ∩ |
| Route entry | billing read ∪ write |
