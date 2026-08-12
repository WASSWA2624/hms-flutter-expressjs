# Lab inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after remediation (2026-08-12).

## Residual

None required.

## Justified product exceptions (tested)

1. **Collect / Receive / Reject / Reverse** — controller + billing inventories + atoms remain; UI stays unmounted. Operator path is Enter result on the worklist. Tests assert `labCollectSampleAction` / Collect tooltip absent.
2. **Open billing CTA** — Await payment text only; settle owned by Billing desk (`labOpenBillingRequirement` kept for inventory/atom maps). Billing inventories mark `openBilling.mounted = false`.
3. **Lab Configurations / Orders view / Refresh toolbar** — intentionally removed; tests assert tooltips absent. Controller `applyView` / configure atoms residual only.
4. **Create additional / Edit order** — dead page helpers removed; billing inventory atoms remain with `mounted: false`. Mutation paths stay Create Lab Order + Enter result.
5. **Critical notify acknowledge chrome** — atom `labCriticalNotifyRequirement` documented; no dedicated acknowledge control on Critical tab (`criticalNotify` / `acknowledge` mounted false).
6. **Delete order/panel/test** atoms — explicitly not mounted (`deleteOrder.mounted = false`).
7. **`LabWorkbenchView.orders`** — domain/controller residual; UI patients-only (tested: Orders view absent).

## Closed in this remediation

- Table Export gated with ∩ `evidence:export` / `canExportLabWorkspace` / per-tab `.export` atoms
- Table Print mounted after Export (preview-first `printLabWorkspaceList`; label `Print`)
- Follow-ups Settings uses panel column prefs (`lab_follow_ups_cols`) — not Lab desk settings override
- Zero-tabs → `AppFailureStateView` forbidden
- `keepPreviousDataDuringRefresh: true`
- Authoritative sibling counts + filtered active-tab badge (`labSectionTabCount`)
- Count tones via `labSectionCountTone` (Critical danger; Pending warning; others info)
- Toolbar order Filters → Settings → Export → Print → Create; Close labels on Advanced filters / Settings
- Dead `_openAdditionalLabOrderDialog` / `_openEditLabOrderDialog` removed
- Billing inventory `mounted` flags aligned with unmounted Open billing / create-additional / edit-order
