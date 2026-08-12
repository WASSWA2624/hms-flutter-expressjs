# OPD inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after shared-chrome and per-tab remediation.

## Residual

None — desk remediations through 2026-08-12:

- Shared chrome: table Print (preview-first), Export RBAC (`evidence:export`), board membership counts (not raw API totals) + tones, forbidden empty workspace, Flow Actions Print label, main-tab viewport (`scrollable: false` + `Expanded`, no shrinkWrap), Settings Apply/Reset l10n
- Board Export/Print use **full filtered membership** (not current page only)
- Prefer-5: when Next action is unauthorized, promote from column choices so defaults stay at 5
- Section empty copy: Arrivals / Queue / Triage / Active / All each use dedicated strings
- `panel=` multi-status filters preserved across Advanced filters open/apply unless a single status is chosen
- Print chrome strings via commonPrint* l10n; patient cells are name-only (atomic)
- Follow-ups: Filters/date/Close parity, Export/Print gated, prefer-5 columns, narrowed badge, bounded height
- Per-tab inventories refreshed: All, Arrivals, Queue, Triage, Active, Follow-ups
