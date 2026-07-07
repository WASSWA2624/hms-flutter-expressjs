# OPD Encounter Dialog — UI Refinement

## Objective

Redesign the **OPD encounter workflow dialog** (`FlowActionsDialog`) so staff can see at a glance *why the patient is in OPD*, *where they are in the journey*, and *what to do next* — without excessive vertical scrolling.

**Primary files:**

- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart` — dialog shell, clinical services panel, action grid
- `frontend/lib/shared/opd_actions/opd_action_context.dart` — encounter context section
- `frontend/lib/shared/components/app_copyable_identifier.dart` — inline copyable IDs (reuse app-wide)

**Reference:** [prompts/12-opd-module-prompt.md](prompts/12-opd-module-prompt.md), [`.cursor/flows/opd-flow.mdc`](.cursor/flows/opd-flow.mdc)

---

## Current Problems (from live UI)

| Area | Issue |
| ---- | ----- |
| Dialog title | Shows patient name (`flow.displayTitle`); should be encounter-focused |
| Context header | Patient identity, stage, billing, and journey are split across tiles and wraps — hard to scan |
| Copy actions | Separate "Copy patient ID" / "Copy encounter ID" buttons consume space |
| Clinical services | Lab/radiology orders render as stacked icon rows (e.g. LAB0000007) with duplicated title/subtitle — no status, timing, or location |
| Actions | Grid is stage-driven but not ordered chronologically; layout feels unstructured |
| Vertical space | Multiple sections and redundant summaries (vitals count, services count) add height without clarity |

---

## Required Changes

### 1. Dialog title

- Set dialog title to **"OPD Encounter"** (new `app_en.arb` key).
- Move **patient name** and **patient ID** into the context section immediately below the title — not in the dialog chrome.

### 2. Encounter context — single-line summary row

Replace the current multi-wrap / tile layout with a **compact, scannable header** that answers: *Who? Where are they? What's next? Who owns it?*

**Layout (one row where viewport allows; wrap only when unavoidable):**

```
Patient: Wilson Wasswa; Patient ID: [copyable PAT0000001]; Encounter ID: [copyable ENC…]; Current stage: In lab; Next: Process lab; Assigned: Dr Jordan Demo; Billing: Paid · $30,000.00
```

**Formatting rules:**

- Use **parameter : value** pairs.
- Separate pairs with **`; `** (semicolon + space).
- Within a pair, use normal spacing after the colon.
- Where a value is an ID, use `AppCopyableIdentifier` inline — **no separate copy buttons**.
- Show **current stage** and **next step** as distinct pairs (use existing `opdStatusDisplayLabel` / `opdNextStepDisplayLabel`).
- Include **assigned provider** and **billing state** when available.
- On narrow screens, allow the row to wrap to a second line; prefer horizontal density on tablet/desktop.

**Journey / completed steps:**

- Show a concise **visit journey** in the same row or directly beneath it (still ≤ 2 lines total): e.g. `Arrival → Vitals → Consultation → Lab`.
- Derive from `detail.timeline` (already used in `_completedActionSummary`); prefer stage/order labels over raw API action codes.
- **Remove** the separate "Completed" and "Services" info tiles that only repeat counts (e.g. "1 Vitals • 3 Services") — replace with the journey string and the clinical services table below.

**Remove:**

- Standalone copy-ID action buttons.
- Redundant vitals/resuscitation listing in the context panel (vitals belong in the services table or journey, not a duplicate count tile).

### 3. Clinical services — compact table

Replace `_OpdClinicalServicesPanel` icon list with a **dense data table** (reuse existing table/list patterns from `frontend/lib/shared/*`).

| Column | Content |
| ------ | ------- |
| Service | Type icon + display ID / name (lab, radiology, pharmacy, procedure, diagnosis) |
| Requested | Date/time (or "—" if unknown) |
| Status | Order/workflow status (pending, in progress, completed, cancelled) |
| Location / queue | Patient-facing location when relevant: *Waiting*, *In lab*, *In radiology*, *At pharmacy*, etc. |
| Result / value | Key result or value when completed; "—" while pending |

- Group or sort by service type only if it improves scanability; default sort: **chronological (requested date)**.
- Empty state: keep existing `opdClinicalServicesEmpty` message.
- Cap row height; truncate long values with tooltip on hover/long-press.
- Show the panel whenever `detail` has any clinical records — not only during doctor-review stages (labs visible while *In lab*, as in screenshot).

### 4. Actions — chronological organization

Reorganize `_actionGrid` so actions follow the **OPD visit timeline**, not arbitrary stage buckets:

1. Billing (pay / update consultation billing)
2. Vitals
3. Assign / change doctor
4. Doctor review
5. Clinical orders (lab, radiology, prescribe, procedure)
6. Disposition (admit, discharge, refer, follow-up)
7. Admin / utility (correct stage, print summary)

**Rules:**

- Highlight the **stage-appropriate primary action** (existing primary variant) — e.g. "Process lab" when stage is `IN_LAB` / `LAB_REQUESTED`.
- Hide or disable actions that are invalid for the current stage (keep existing RBAC + stage gates).
- Use a responsive grid: more columns on desktop, fewer on mobile; consistent icon + label buttons.

### 5. Information completeness

The dialog must answer for any staff role:

- Why is this patient in OPD? (visit type / arrival mode)
- What stage are they in and what happens next?
- Who is responsible (role + assigned provider)?
- What has already been done? (journey + services table)
- What can I do now? (chronological actions)

---

## Implementation Standards

| Area | Requirement |
| ---- | ----------- |
| UI/UX | Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`. Reuse shared widgets before creating new ones. |
| i18n | All new labels in `app_en.arb`; no hardcoded strings. |
| Responsive | Mobile, tablet, desktop — test at 520px, 768px, 1280px widths. |
| Scope | Limit changes to encounter dialog + `OpdActionContextPanel`; propagate `AppCopyableIdentifier` pattern elsewhere only where the same copy-button anti-pattern exists in OPD. |
| Quality | `dart format`, `flutter analyze`, add/adjust widget tests for context summary formatting and services table rendering. |

---

## Acceptance Criteria

- [ ] Dialog title reads **"OPD Encounter"**; patient name and ID appear in the context section.
- [ ] Patient ID and encounter ID are **inline copyable** (`AppCopyableIdentifier`); no standalone copy buttons.
- [ ] Current stage, next step, assigned provider, and billing appear in a **semicolon-separated parameter : value** summary (≤ 2 lines on desktop).
- [ ] Visit journey is visible without opening sub-panels.
- [ ] Clinical services render in a **table** with status, timing, location, and results — not stacked duplicate ID rows.
- [ ] Actions are ordered **chronologically**; primary next action is visually prominent.
- [ ] Layout uses materially less vertical space than the current design on the lab-in-progress scenario (screenshot reference).
- [ ] All strings localized; no analyzer warnings.

---

## Test Scenario

Use encounter **WILSON WASSWA** (`PAT0000001`), stage **In lab**, billing **Paid**, with lab orders `LAB0000007`, `LAB0000005`, `LAB0000004` — verify the table shows each order's status and that **Process lab** is the prominent action.
