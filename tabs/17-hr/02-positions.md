# HR tab — Positions

## 1. Tab strip

- Label: `hrPositionsTabLabel`
- Icon: `Icons.work_outline`
- Count source: `state.positionsTotalCount` (authoritative when unfiltered; else refresh)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `positions` (aliases `staff-positions`, `position`)
- Tab gate: `HrHumanResourcesAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search: `hrPositionsSearchHint`
- Clear: `hrClearFiltersAction`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`
- Settings: yes
- Export: default on, no evidence gate (columns have `exportValue`)
- Print (toolbar): off
- Context: `hrCreatePositionAction` — omitted without `HrHumanResourcesAtomPermissions.write`
- Date filter UI: default true on search — **not wired** into reload

## 3. Table

- Row model: `HrStaffPosition`
- Row select → `showHrStaffPositionDetailDialog`
- Default: name, id, description, scope, status; actions if write
- Storage: `hr.positions.table.v2` / widths `.widths.v2`

## 4. Advanced filters / search fields

- Search fields: name / id / description
- Text: name, description
- Groups: status active/inactive (`hrPositionActiveStatus` / `Inactive`), record state current/deleted/all, scope facility/shared
- Date: UI may appear; not applied

## 5. Primary / secondary / row actions

- Create / Edit / Soft delete / Restore / Permanent delete (facility-owned only; shared read-only)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Position create/edit (`showHrCreateStaffPositionDialog`) | HR-owned |
| Position detail + Print | HR-owned |

## 7. Nested / follow-on

- Detail Print → `showHrPositionPrintPreview` (`hrPositionPrintDocumentSubtitle`, sections details/staff)

## 8. Forms (summary)

- Position name / description / active

## 9. Print / labels / preview

- Detail Print only (preview-first); not list toolbar

## 10. Loading / empty / error / success

- Empty: `hrNoPositionsTitle` / `Body`
- Loading flag; failure via table `error`
- Success: `hrSavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings | ∩ `hr:read` |
| Create / actions column | ∩ `hr:write` (`HrHumanResourcesAtomPermissions.write`) |
| Export | ungated |
| Print (list) | absent |
