# Nursing inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after shared-chrome + cross-cutting remediation.

## Residual

none

## Closed (2026-08-12)

1. Route entry comments/tests aligned to ∩ `nursing:read` + module (`AppRoutes.nursing` / `RouteAccessCatalog.nursingEntry`); atom-map docs no longer describe ∪ clinical|patient|last_office|operations:read for route entry.
2. Dual read vocabulary closed — tab/list chrome uses the same ∩ `nursing:read` + module as shell/catalog.
3. Worklist Print mounted after Export (`printNursingWorkspaceList` / preview-first); detail Print label `Print`.
4. No dedicated Handover strip toolbar — justified: tab + next-action + detail + Shift context (documented in shared chrome).
5. Export gated via `canExportNursingWorkspace` ∩ `evidence:export`.
6. `assignedWard` `matchesScope` = `hasActiveBed` (ward-bed membership).
7. Handover tab count uses worklist-scoped `NursingScopeCounts.handoverPending` (not global pending list alone).
8. Urgent / Medication due / Transfer pending atom maps include `billingPanel` / `openBilling`.
9. `panel=transfer` deep link wired (`NursingDetailPanel.transfer`).
10. `openIcu` / `navigation` = `RouteAccessCatalog.icuEntry` (omit when ICU entry denied).
11. Responsible nurse column — justified synthetic summary (no assignee field); documented in code/tests.
12. Count badges show explicit `0` (sibling `NursingScopeCounts` + active filtered total).
13. Authoritative sibling counts + filtered active-tab badge; urgency tones applied.
14. Toolbar order Filters → Settings → Export → Print → Shift context; shared filter/settings footer labels.

Regression coverage: `frontend/test/features/nursing/` (per-tab chrome/export/print omit gates, count tones, filtered active badges, `matchesScope`, route-entry ∩).
