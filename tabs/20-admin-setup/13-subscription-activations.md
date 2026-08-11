# Admin setup tab — Subscription activations

## 1. Tab strip

- Label: `tenantFacilitySetupTabSubscriptionActivations`
- Icon: `Icons.payments_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link `section`: `subscription-activations` (aliases `subscription_activations`, `activations`, `payment-activations`)
- Tab gate: **`isElevated` only**
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search: `tenantFacilitySubscriptionActivationsSearchHint`
- Intro text; no Filters/Settings/Export/Print/Add

## 3. Table

- Query `AccessAdminPanel.payments` / `subscriptionPaymentRequests`
- Columns: tenant, plan, amount (`positionTitle`), email, Activate + Reject actions

## 4. Advanced filters / search fields

- Search only

## 5. Primary / secondary / row actions

- Activate / Reject (`tenantFacilitySubscriptionActivationsActivateAction` / `…RejectAction`)
- Confirm + success keys

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Activate/reject confirms | Setup-owned |
| Data | **reused** access-admin repository |

## 7. Nested / follow-on

- Nested confirm only

## 8. Forms (summary)

- None

## 9. Print / labels / preview

- None

## 10. Loading / empty / error / success

- Empty/error parallel to approvals

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab | `isElevated` |
| No AccessRequirement atom | compare platform admin patterns |
| Export/Print/Filters | absent |
