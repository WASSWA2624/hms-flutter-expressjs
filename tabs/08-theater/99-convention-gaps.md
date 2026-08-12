# Theater inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory (code-traced).

## Residual

none

## Closed (2026-08-12)

1. Table Print — `enablePrint` + preview-first `printTheaterWorkspaceList` / `PrintDocumentTemplates.registry`
2. Export gated — ∩ `evidence:export` via `canExportTheaterWorkspace`
3. Toolbar order — Filters → Settings → Export → Print → Schedule case (Follow-ups: no Schedule case)
4. Default columns — prefer **5** data columns (+ optional next-action on case boards)
5. Tab count authority — dedicated unfiltered `TheaterScopeCounts`; active narrowed → filtered total
6. Empty unauthorized workspace — `AppFailureStateView(forbidden)`
7. Recovery list vs count — `theaterRecoveryStageFilter` = `POST_OP,PACU_HANDOFF`
8. Follow-ups Filters/date — host enables advanced filters + date filter
9. Apply label — `theaterApplyFiltersAction`
10. Refresh retention — `keepPreviousDataDuringRefresh: true`
