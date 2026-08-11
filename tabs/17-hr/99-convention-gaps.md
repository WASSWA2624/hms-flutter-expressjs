# HR inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after code-traced inventory (2026-08-11).

## Residual

| Gap | Evidence |
| --- | --- |
| No list **Print** on any desk `AppListTable` | `enablePrint` default false; print only in detail dialogs |
| **Export** ungated (no `evidence:export`) | work queues, positions, ManageUsers, Access rely on default `enableExport: true` |
| Work-queue **date filter** shown but not applied | `enableDateFilter` default true; `applyWorkItemsScope` keeps prior `from`/`to` only |
| Positions date filter likely shown, unused | no `enableDateFilter: false` |
| Next-action **disabled** not omitted | `_workItemNextActionColumn` sets `hideWhenDenied: false` |
| Access tab **count always 0** | `_sectionCount` → `0` |
| Staff directory count from **HR staff page**, not ManageUsers | mismatch risk vs visible CRUD table |
| Access Filters label `hrFiltersLabel` vs `commonFiltersActionLabel` | |
| ManageUsers Filters `commonFilterActionLabel` (singular) | |
| Access tables missing column storage keys / column ids | |
| Roster list has no next-action Publish (detail-only) | atom docs vs table |
| Route catalog ∩ `hr:read` vs `AppRoutes.hr` ∪ read\|write | noted in permission tests |
| Forbidden empty workspace = shrink, not `AppFailureStateView` | differs from Reception |
