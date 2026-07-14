# Patient Reporting & Printing — Implementation Prompt

## Objective

Implement a unified reporting and printing solution reused across departments via the shared report template and configurable sections — with backend authorization, PHI audit, controlled storage, and printer-optimized output.

**Source requirement:** [prompt.md](../prompt.md) §7  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md), [07-clinical-results-preview.md](./07-clinical-results-preview.md)

---

## Mandatory reading

1. [`frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc)
2. [`backend/.cursor/storage.mdc`](../backend/.cursor/storage.mdc)
3. [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc)
4. Department flows as needed (OPD, IPD, lab, radiology, theatre, ICU, pharmacy, billing)

---

## Pre-implementation audit

- Locate existing shared report template and any department-specific document frameworks.
- Extend the shared template; delete duplicate department document stacks after migration.

---

## Step-by-step instructions

### 1. Shared template only

- Reuse and extend the existing shared report template for all printable reports.
- Do **not** create department-specific document frameworks.
- Compose reports from shared, configurable sections/components.
- Each fact renders from its authoritative module — avoid duplicate information.

### 2. Configurable sections

Support authorized, selectable sections such as:

- Patient information, Encounter details, Vitals, Clinical notes, Diagnoses, Findings  
- Laboratory results, Radiology reports, Procedures  
- Prescriptions, Medications, Doctor's notes, Billing information  
- Other clinical records as authorized  

UI rules:

- Users select authorized sections to print
- Sections without data are unselected and **disabled** by default
- Print only selected sections
- Chronological display; locale-aware dates/times; clear headings

### 3. Output quality

- Printer-optimized, high-quality layout
- Stable page breaks; repeated headers where needed
- No clipped content; no interactive-only controls in print output

### 4. Backend authorization & privacy

- Apply RBAC, ABAC, subscription, tenant, facility, and patient/encounter scope to generation, preview, export, and printing
- Audit PHI report access, generation, export, and printing (actor, scope, report type, timestamp)
- Prevent hidden/unauthorized fields from entering generated output, API payloads, local caches, or realtime events
- Retrieve documents only through controlled, access-checked storage
- Large reports may use async jobs with authoritative status metadata (non-blocking)

### 5. Database / migrations

- Persist job/status metadata and section selection audit as needed
- Do not store unrestricted filesystem paths in public APIs
- Remove obsolete per-department report generators after verified cutover

### 6. Frontend integration

- Shared section pickers and preview chrome under `frontend/lib/shared/`
- Instant status updates for async generation; reconcile via realtime where applicable
- Localize all labels; design tokens only

---

## Tests

- Empty, partial, long, multi-page, localized output
- Revoked-access denial mid-job
- Unauthorized section exclusion
- Disabled empty sections default
- Async job status lifecycle

## Related prompts

03, 07, 08, 09, 10, 13
