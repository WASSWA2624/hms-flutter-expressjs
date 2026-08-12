# Clinical inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after remediation (2026-08-12).

## Residual

None.

### Justified product exceptions (tested / documented in code)

1. **Lab/radiology results panel read** stays ∩ `clinical:read` (matrix nested cross-module read _(n/a)_; not separate `lab:read` / `radiology:read`) — see `ClinicalResultsReadyAtomPermissions.labResultsPanel` / `radiologyResultsPanel`.
2. **Write gates** keep source ∪ `clinical:write` \| `platform:admin` rather than matrix ∩ write alone — see `clinicalWorkspaceWriteRequirement`.
3. **Results ready default columns** use patient / encounterType / queue / status / nextAction (still 5; provider omitted so type is visible for results review) — `_clinicalDefaultColumnsForSection` + `results-ready tab shows encounter type column by default`.
4. **Completed default columns** use patient / queue / encounterType / status / nextAction (still 5; provider omitted for completed review) — `_clinicalDefaultColumnsForSection` + `Completed tab shows encounter type column by default`.
