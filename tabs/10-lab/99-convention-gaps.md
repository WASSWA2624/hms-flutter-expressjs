# Lab inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory (code-traced; no UI changes in this pass).

## Residual

1. **Collect / Receive / Reject / Reverse** — controller + billing inventories + atoms; **UI unmounted** (`labCollectSampleAction` absent).
2. **Open billing** — Await payment text only; no Billing handoff CTA despite `labOpenBillingRequirement`.
3. **Lab Configurations / Orders view / Refresh toolbar** — removed from UI; atoms/`applyView`/`configure` residual.
4. **Create additional / Edit order** helpers on page — **dead** (no entry from result dialog).
5. **Table Export ungated** — no ∩ `evidence:export` / `canExport`.
6. **Table Print not mounted** — Reception has preview-first registry print; Lab report print only from result preview.
7. **Follow-ups Settings mismatch** — opens Lab desk column prefs, not follow-up columns; dual storage (`lab_followUps` vs `lab_follow_ups_cols`).
8. **No forbidden failure view** when zero tabs — empty `labNoOrders*` instead of Reception-style forbidden.
9. **`keepPreviousDataDuringRefresh: false`** vs Reception `true`.
10. **Critical notify** documented — no acknowledge chrome.
11. **Delete order/panel/test** atoms — explicitly not mounted.
12. **`LabWorkbenchView.orders`** still in domain/controller — UI patients-only.
