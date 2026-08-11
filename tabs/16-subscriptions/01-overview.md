# Subscriptions panel — Overview

## 1. Tab strip

- Label: `Overview`
- Icon: `Icons.dashboard_customize_outlined`
- Count: none (unless shared denied badge on other tab)
- Deep-link `panel`: `overview`
- Tab gate: `SubscriptionsOverviewAtomPermissions.tab` = ∩ `subscriptions:read` + module
- **Omitted when unauthorized**
- No worklist create primary

## 2. Search / Filters / Settings / Export / Print / context

- **No** worklist search/filters/settings/export/print on Overview
- Shared queue chips may appear above overview content

## 3. Table / panel surface

- `_SubscriptionOverviewPanel` — KPI / cohort cards, attention charts, usage limits, recommendations
- Cohorts: Active plans / Not subscribed / Closed subscriptions (and related summary IDs)
- Not a columnar `AppListTable`

## 4. Advanced filters / search fields

- **Absent** on Overview body (chips may navigate filtered panels)

## 5. Primary / secondary / row actions

- Cohort dialogs: New subscription / Edit subscription when write ∩
- No tab-strip create
- Destructive delete: **not mounted**

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Cohort accounts list | Subscriptions-owned |
| New / Edit subscription (from cohort) | Subscriptions-owned |

## 7. Nested / follow-on

Cohort → create/edit subscription forms; may open upgrade flows when surfaced from recommendations

## 8. Forms (summary)

- Subscription create/edit: tenant, plan, billing cycle, dates, status groups

## 9. Print / labels / preview

- **Absent**

## 10. Loading / empty / error / success

- Chart empty copy when no attention/cohort data
- Success snackbar after nested mutations

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / KPIs / usage / recommendations / cohort dialog | read ∩ |
| Cohort New / Edit | write ∩ |
| Delete / void | delete ∩ — **not mounted** |
| Route entry | ∪ `platform:admin` |
