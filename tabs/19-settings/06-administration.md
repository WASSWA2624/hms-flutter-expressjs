# Settings section — Administration boundaries

## 1. Section chrome

- Label: `settingsAdministrationSectionTitle` / body `settingsAdministrationSectionBody`
- Icon: `admin_panel_settings_outlined`
- Deep-link `tab`: `administration`
- Gate: `settingsAdministrationReadRequirement` = `profile:read` ∩ (`facility:admin` ∪ `tenant:admin` ∪ `platform:admin`)
- Visible only if that gate **and** ≥1 navigate destination allowed
- When workspace visible: destinations = **subscriptions only** (setup + access-admin owned by workspace)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Absent

## 3. Inner surfaces

- Navigate tiles (`InkWell` list), unauthorized destinations **filtered out**
- Full mode tiles:
  1. Tenant/facility setup — `settingsTenantFacilitySetupActionTitle`/`Body` → `AppRoutes.tenantFacilitySetup` — `setupEntry` (`setup:read` ∩ facility)
  2. Subscriptions — `navigationSubscriptionsLabel` + `settingsSubscriptionsActionBody` → `subscriptionsEntry` (platform admin/owner)
  3. Users and access — `settingsAccessAdminActionTitle`/`Body` → `accessAdminEntry` (`access_admin:read` ∩ tenant)
- Empty destinations → `SizedBox.shrink` (section body); strip already hidden via visibility helper

## 4. Advanced filters / search fields

- Absent

## 5. Primary / secondary / row actions

- Actions are navigations only
- Create/update/delete matrix keys — **not mounted**

## 6. Dialogs from this section

| Dialog | Owner |
| --- | --- |
| — | none (handoffs to other workspaces) |

## 7. Nested / follow-on

- None in Settings; destinations open Admin setup / Subscriptions / Access Admin

## 8. Forms (summary)

- None

## 9. Print / labels / preview

- Absent

## 10. Loading / empty / error / success

- N/A mutations; no loading on section itself

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | `settingsAdministrationReadRequirement` |
| Tenant/facility tile | `RouteAccessCatalog.setupEntry` |
| Subscriptions tile | `RouteAccessCatalog.subscriptionsEntry` |
| Access admin tile | `RouteAccessCatalog.accessAdminEntry` |
| Create / update / delete | matrix ∩ — not mounted |
