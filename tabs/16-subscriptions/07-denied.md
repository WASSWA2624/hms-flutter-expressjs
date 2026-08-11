# Subscriptions panel — Denied modules

## 1. Tab strip

- Label: `Denied modules`
- Icon: `Icons.block_outlined`
- Count: `deniedModulesCount` when > 0
- Deep-link `panel`: `denied` (aliases `denied-modules`); sets `queue=MODULE_BLOCKED`
- Resource: `module-subscriptions`
- Tab gate: `SubscriptionsAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**

- Create primary: **intentionally omitted**
- Export / Print: **absent**
- Selecting tab resets filters and applies denied queue

## 3. Table

- Same module-subscription column model as Operations nested resource
- Default: Module, Tenant, Status, Plan, Expiry date
- Row select gated by `SubscriptionsAtomPermissions.rowSelect`

## 4. Advanced filters / search fields

- Present; queue already scopes to blocked modules
- Eligibility / status groups as applicable

## 5. Primary / secondary / row actions

- No New subscription / Add license here
- Detail may still offer write actions when policy allows (shared operations atom map) — create strip remains omitted

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Module subscription detail | Subscriptions-owned |

## 7. Nested / follow-on

Detail enable/disable / assign patterns shared with operations when mounted on item

## 8. Forms (summary)

- Same as module-subscription mutation forms when actions present

## 9. Print / labels / preview

- **Absent**

## 10. Loading / empty / error / success

- Empty when no denied modules; chip/count drive attention

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | read ∩ |
| Create strip | **not mounted** |
| Item update toggles | write ∩ when detail actions mount |
| Delete | **not mounted** |
