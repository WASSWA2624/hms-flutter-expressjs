# Settings section — Administrative setup workspace

## 1. Section chrome

- Label: `settingsWorkspaceSectionTitle` / body `settingsWorkspaceSectionBody`
- Icon: `build_outlined`
- Deep-link `tab`: `workspace`
- Visibility: `settingsWorkspaceAdminRequirement` ∨ `settingsWorkspaceHrRequirement`
  - Admin: `profile:read` ∩ admin ∪ + admin roles + tenant ctx
  - HR: `profile:read` ∩ (`hr:read` ∪ `hr:write`) + HR role + tenant/facility ctx
- Nested `AppAccessGate` admin then HR
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Context panel (`settingsWorkspaceTenantSelectorLabel`): tenant / facility selects
- Filters panel titled `settingsWorkspaceSearchLabel`:
  - Search field + hint (`settingsWorkspaceSearchHint`) — submit on field submit
  - Group / State selects
  - `settingsWorkspaceActionableOnlyLabel` checkbox
- **No** Export / Print / Table Settings
- Controller: `SettingsWorkspaceController` + `SettingsWorkspaceQuery` (`tenantId`, `facilityId`, `group`, `state`, `search`, `actionableOnly`)
- Realtime: `RealtimeEventGroups.settings`

## 3. Inner surfaces

- Rendered: context → filters → module groups/rows
- **Not rendered** (parsed from API, tested absent): summary cards, setup checklist, quick actions, context summary chrome
- Module row: label, `settingsWorkspaceRecordsLabel` + state, attention reason, Open/Create
- Open routes → tenant/facility setup **or** access-admin with resource/panel query map
- Security routes (API key / MFA / OAuth / sessions): `_mappedSettingsRoute` → `null` → Open omitted

## 4. Advanced filters / search fields

- Inline filter panel (not Filters dialog); server-driven via `_applyQuery`

## 5. Primary / secondary / row actions

- Open: `settingsWorkspaceOpenAction` when `canRead` + mapped route
- Create: `settingsWorkspaceCreateAction` when `canCreate` + mapped create route + (`settingsWorkspaceCreateRequirement` ∪ `settingsWorkspaceHrCreateRequirement`)
- Update/delete: not mounted

## 6. Dialogs from this section

| Dialog | Owner |
| --- | --- |
| — | none (navigates away) |

## 7. Nested / follow-on

- Opens Admin setup or Access Admin workspaces

## 8. Forms (summary)

- Context/filter selects and search only

## 9. Print / labels / preview

- Absent

## 10. Loading / empty / error / success

- Loading: `settingsWorkspaceLoadingTitle`/`Body`
- Error: `settingsWorkspaceErrorTitle` + retry
- Empty modules: `settingsWorkspaceEmptyTitle`/`Body` + `commonRefreshActionLabel`
- Tenant required: `settingsWorkspaceTenantContextRequiredTitle`/`Body` + selectors
- Filtered-empty groups copy: `settingsWorkspaceNoModulesBody`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Strip visibility | admin ∨ HR **source** gates |
| Search / filters / modules / Open | read chrome / backend `can_read` |
| Create | ∩ `facility:admin` ∪ (`hr:write` ∪ `unit:manage` + facility ABAC) + `can_create` |
