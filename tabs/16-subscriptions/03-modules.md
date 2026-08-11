# Subscriptions panel — Modules

## 1. Tab strip

- Label: `Modules`
- Icon: `Icons.view_module_outlined`
- Deep-link `panel`: `modules` / resource `modules`
- Tab gate: `SubscriptionsPlansAtomPermissions.tab` (same plans atom map)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings**

- Create primary: **intentionally omitted** (`_worklistCreateAction` returns null for modules)
- Export / Print: **absent**
- Pack membership edited via Manage modules on a **plan** (catalog), not here

## 3. Table

- Row model: `SubscriptionItem` (`modules`) — read-only catalog
- Row select: detail when rowSelect allowed; **update writes false** for modules resource
- Default columns: Module, Status, Tier, Amount limit, Renewal / expiry
- Column choices: Module ID, Is add-on, …

## 4. Advanced filters / search fields

- Module-oriented filter groups (status / tier / eligibility as provided)

## 5. Primary / secondary / row actions

- No create
- Detail is read-focused; no module write primary on this panel

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Module detail (read) | Subscriptions-owned |

## 7. Nested / follow-on

None for mutations on this panel; manage packs from Catalog plan detail.

## 8. Forms (summary)

- None for create/update on Modules panel

## 9. Print / labels / preview

- **Absent**

## 10. Loading / empty / error / success

- Standard empty/loading worklist

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | read ∩ |
| Create / update on this panel | **not mounted** (write used on Catalog Manage modules) |
