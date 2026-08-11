# Subscriptions panel — Catalog (Plans)

## 1. Tab strip

- Label: `Plans`
- Icon: `Icons.workspace_premium_outlined`
- Deep-link `panel`: `catalog` / resource `subscription-plans`
- Tab gate: `SubscriptionsPlansAtomPermissions.tab` = read ∩
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Create plan**

- Search / Filters / Settings: present
- Export / Print: **absent**
- Create plan: omitted without write ∩
- Date filter control: off; may include date_preset group depending on resource filters

## 3. Table

- Row model: `SubscriptionItem` (`subscriptionPlans`)
- Row select: plan detail (read ∩)
- Default columns: Plan, Monthly price USD, Annual price USD, Tier, Modules
- Column choices: Plan ID, Billing cycle, Max users/facilities/storage/modules, Updated, Description
- Row tint by plan theme
- Initial sort: monthly price

## 4. Advanced filters / search fields

- Groups from `_filterGroups` for plans (status / tier / billing cycle / … as applicable)
- Date preset optional

## 5. Primary / secondary / row actions

- Strip: Create plan
- Detail: Edit plan, Manage modules (write ∩)
- Delete: **not mounted**

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Plan detail | Subscriptions-owned |
| Create / Edit plan | Subscriptions-owned |
| Manage modules | Subscriptions-owned |

## 7. Nested / follow-on

Manage modules → module pack checkbox form. Edit → plan form fields.

## 8. Forms (summary)

- Plan: name/code/tier/prices/billing limits/description/included modules

## 9. Print / labels / preview

- **Absent**

## 10. Loading / empty / error / success

- Empty worklist copy; `savedMessage` on mutate

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / row select / detail | read ∩ |
| Create / Edit / Manage modules | write ∩ |
| Delete | delete ∩ — **not mounted** |
