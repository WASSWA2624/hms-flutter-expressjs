# Admin setup tab — Subscription approvals

## 1. Tab strip

- Label: `tenantFacilitySetupTabSubscriptionApprovals`
- Icon: `Icons.verified_user_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `subscription-approvals` (aliases `subscription_approvals`, `approvals`, `account-approvals`, `registration-approvals`)
- Tab gate: **`isElevated` only** (platform-admin / owner roles)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Standalone `AppSearchBar` hint `tenantFacilitySubscriptionApprovalsSearchHint`
- Intro: `tenantFacilitySubscriptionApprovalsIntro`
- **No** Filters/Settings/Export/Print/Add

## 3. Table

- `AppListTable<AccessAdminItem>` via access-admin workspace query `AccessAdminPanel.registrations` / `registrationFollowUps`, `allTenants/allFacilities: true`
- Columns: admin, facility, email, phone, actions
- Storage: `setup_subscription_approvals_columns_v1`

## 4. Advanced filters / search fields

- Search only

## 5. Primary / secondary / row actions

- Approve `accessAdminApproveRegistrationAction`
- Detail also Reject
- Confirm titles `tenantFacilitySubscriptionApprovalsApproveTitle` / success snackbar key `…ApproveSuccess`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail `_SubscriptionApprovalDetailDialog` | Setup-owned |
| Approve/reject confirm (`app_action_dialogs`) | Setup-owned |
| Data repository | **reused** `AccessAdminRepository` |

## 7. Nested / follow-on

- Approve/reject confirm dialogs

## 8. Forms (summary)

- No create forms

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Empty: `tenantFacilitySubscriptionApprovalsEmptyTitle` / `…Empty`
- Failure banner + retry; mutating disables actions

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | `isElevated` (role, not AccessRequirement key) |
| Compare | access-admin registrations ∩ `platform:admin` |
| Export/Print | absent |
| Filters/Settings | absent |
