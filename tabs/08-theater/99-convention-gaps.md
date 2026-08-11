# Theater inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory (code-traced; no UI changes in this pass).

## Residual

1. **No table Print** — `enablePrint` not set; no preview-first registry / Theater print path.
2. **Export ungated** — default AppListTable Export without ∩ `evidence:export` / `canExport`.
3. **Toolbar order** — Filters → Settings → Export → Schedule case (no Print slot).
4. **Default columns** — **4** data columns (+ optional next-action), not prefer-5.
5. **Tab count authority** — Scheduled / In theater / Recovery badges from **current page membership**, not dedicated unfiltered sibling totals.
6. **Empty unauthorized workspace** — `SizedBox.shrink()` instead of forbidden `AppFailureStateView`.
7. **Recovery list vs count** — tab applies `stage=POST_OP` only while `recoveryCount` includes `PACU_HANDOFF`.
8. **Follow-ups Filters/date off** — host disables advanced filters and date filter.
9. **`theaterApplyFiltersAction` unused** — Apply uses `opdApplyFiltersAction`.
10. **`keepPreviousDataDuringRefresh: false`** — unlike Reception `true`.
