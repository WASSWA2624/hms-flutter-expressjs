# Clinical Results Preview — Implementation Prompt

## Objective

Deliver reusable clinical-results preview components for laboratory, radiology, procedures, clinical assessments, and other clinical modules — consistent chronology, status clarity, authorization, and print eligibility.

**Source requirement:** [prompt.md](../prompt.md) §3 — Clinical Results Preview  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md), [03-shared-reusable-components.md](./03-shared-reusable-components.md)

---

## Mandatory reading

1. [`frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc)
2. [`frontend/.cursor/date_time_formatting.mdc`](../frontend/.cursor/date_time_formatting.mdc)
3. Domain flows: [lab-flow](../.cursor/flows/lab-flow.mdc), [radiology-flow](../.cursor/flows/radiology-flow.mdc)
4. Reporting prompt: [11-patient-reporting-printing.md](./11-patient-reporting-printing.md)

---

## Pre-implementation audit

- Find existing result/report preview dialogs in lab, radiology, clinical, and shared folders.
- Consolidate into shared preview shells with module-specific content adapters.

---

## Step-by-step instructions

### 1. Shared preview shell

Support presentation modes:

- Inline
- Modal
- Full-screen

Shared behaviors:

- Chronological display across modules
- Locale-aware timestamps via shared formatters
- Loading, empty, error, permission-denied, retry
- Encounter scope enforced from authorized API data

### 2. Result status vocabulary

Clearly distinguish (localized labels + non-color cues):

- Preliminary
- Verified / final
- Corrected
- Unavailable

Never rely on color alone for abnormal/critical/unavailable states.

### 3. Module content adapters (no duplicate shells)

Typed content builders for:

- Laboratory results (ranges, abnormal/critical flags — see prompt 08)
- Radiology reports
- Procedures
- Clinical assessments
- Other clinical modules as needed

Adapters supply data + callbacks; shared shell owns layout and chrome.

### 4. Authorization & print

- Enforce encounter scope and effective permissions from backend.
- Print eligibility comes from backend/capabilities (authorized + printable released content exists) — not from transient UI selection state.
- Compose with shared report sections (prompt 11) for print/export paths.

### 5. Backend

- Preview endpoints return only authorized, scoped fields.
- Public IDs only; audit PHI access where required for full report retrieval.
- Controlled storage for any generated preview documents.

### 6. Instant UI

- After result release/correction in owning modules, patch previews, timelines, and worklists immediately for the acting user; reconcile peers via realtime.

---

## Tests

- Inline/modal/full-screen layouts on mobile, tablet, desktop
- Status distinctions without color-only cues
- Unauthorized/revoked access
- Empty and partial result sets
- Print eligibility independent of unrelated UI selection resets

## Related prompts

03, 05, 08, 09, 11
