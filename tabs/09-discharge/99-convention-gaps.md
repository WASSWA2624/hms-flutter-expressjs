# Discharge inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after shared-chrome + cross-cutting remediation.

## Residual

none

## Justified product exceptions (tested / documented)

1. **No strip Plan/Clearance** — row next-action only (tests assert no Refresh / strip Plan tooltips; context actions stay off the toolbar). Documented in `00-shared-chrome.md`.
2. **`DischargeClearanceDialog` unused by workspace path** — thin wrapper; workspace uses `showDischargePlanningDialog` (section-scoped create/update). Documented in shared chrome.
3. **Open billing navigate-only** — no local cashier / invoice-create dialog; ownership handoff to `AppRoutes.billing?patient_id=…`. Documented in billing inventories + access map.

## Closed (2026-08-12)

1. Export gated ∩ `evidence:export` (`canExportDischargeWorkspace` / per-section `export` atoms); omitted when unauthorized.
2. Table Print after Export — preview-first `printDischargeWorkspaceList` / Follow-ups `_printDischargeFollowUpsList`; trigger label `Print`.
3. Empty unauthorized desk → `AppFailureStateView(forbidden)` (Reception pattern); not `SizedBox.shrink()`.
4. Route gate aligned — `AppRoutes.discharge` / catalog ∩ `discharge:read` + `inpatient-bed-management`.
5. Authoritative sibling counts — dedicated unfiltered `DischargeSectionCounts` (catalog `pageSize: 100`); active tab with search/filters → filtered section membership of `queue.items`.
6. Follow-ups Filters + date filter enabled on host `FollowUpWorklistPanel`.
7. Follow-ups strip label → `dischargeSectionFollowUps` (Discharge-owned key).
8. Date filter **on** for all queue tabs (`DischargeWorklistQuery.dateFrom` / `dateTo`).
9. Planning write atoms section-scoped (`DischargePlanned|Pending|Completed|All` create/update when opened from that tab).
10. Count tones — `warning` Planned + Pending clearance; `info` All / Completed / Follow-ups.
11. Toolbar order Filters → Settings → Export → Print; shared Filters / Settings / Export / Print labels + Clear/Apply/Close footers.
12. Default visible columns prefer **5** per queue tab (and Follow-ups panel defaults).
13. Detail / next-action Print label normalized to `Print` (`dischargePrintSummaryAction` / `commonPrintActionLabel`).
14. Follow-ups active badge falls back to `followUpTabCountProvider` when not narrowed.

Regression coverage: `frontend/test/features/discharge/`.
