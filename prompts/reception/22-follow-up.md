# Generate Ten Compact Mobile List Sample Photos

Produce 10 unique sample photos of compact Follow-ups list layouts for phones. Do not modify any code.

## Context

Reception `AppListTable` keeps a table on large screens and a list on phones. Follow-ups mobile rows are stacked and tall. Desktop table is out of scope.

**Sample photo:** phone-frame mockup of several Follow-ups rows for later layout selection.

**Fields to show:** patient name, patient ID, phone, follow-up date, follow-up time.

## Requirements

1. Generate exactly **10** distinct sample photos of compact mobile Follow-ups list items.
2. Each photo must show multiple rows with the listed fields; prefer low height over card-heavy chrome.
3. Make each sample visually unique: vary density, alignment, meta placement, dividers, trailing time, initials, accent bars, or contact-first emphasis—not near-duplicates.
4. Label samples 1–10 in-frame or by filename for comparison.
5. Do not change Flutter, backend, tests, or any repository code.

## Constraints

- Design-only; no implementation or UI wiring.
- Realistic clinical reception worklist; light theme; readable type.
- Do not invent clinical actions or fields beyond the listed columns.

## Acceptance Criteria

- R1–R4: Ten distinct, labeled compact Follow-ups mobile-list photos delivered.
- R5: No code or app files modified.
- Manual check: each photo shows name, ID, phone, date, and time on dense rows.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` (Follow-ups columns and `_ReceptionDeskMobileRow`; reference only)
- `frontend/lib/shared/components/app_list_table.dart` (table vs mobile; reference only)
