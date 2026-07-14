# Laboratory Module Improvements — Implementation Prompt

## Objective

Close laboratory gaps so Lab remains an executing department with a complete, auditable order-to-result flow, configurable reference ranges, critical-result notifications, print eligibility, and entitlement-enforced endpoints — without duplicating OPD/IPD orchestration.

**Source requirement:** [prompt.md](../prompt.md) §4  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md)

---

## Mandatory reading

1. [`.cursor/flows/lab-flow.mdc`](../.cursor/flows/lab-flow.mdc)
2. [`.cursor/app-write-up.mdc`](../.cursor/app-write-up.mdc) — Laboratory boundaries
3. [`.cursor/flows/opd-flow.mdc`](../.cursor/flows/opd-flow.mdc) — lab stages
4. [`.cursor/flows/ipd-flow.mdc`](../.cursor/flows/ipd-flow.mdc) — lab route / critical results
5. Shared: prompts 04, 05, 06, 07, 10, 11

---

## Pre-implementation audit

- Inspect `frontend/lib/features/lab/` and `backend/src/modules/lab-workspace/` (and related lab catalog modules).
- Verify encounter linkage, billing gate, sample/result pipeline, range persistence, print eligibility, and realtime patches.
- Change only gaps and non-compliant areas.

---

## Step-by-step instructions

### 1. Module boundary

- Every order links to originating clinical encounter (`encounter_id` / public encounter ID).
- Lab executes and reports; OPD/IPD orchestrators own patient-flow stage changes.
- Do not create parallel encounters or mutate OPD/IPD stages from Lab UI.

### 2. Canonical order-to-result flow

Support and persist:

1. Order received  
2. Billing gate (when required) via centralized billing engine (prompt 10)  
3. Sample collection  
4. Sample receipt / rejection with reason  
5. Processing  
6. Result entry  
7. Verification/release or rejection  
8. Authorized reversal  

Reuse shared step progress (prompt 04) with backend-provided capabilities.

### 3. Reference ranges (database + backend)

- Determine ranges from effective-dated, configurable laboratory rules using patient age, sex/gender as clinically configured, test method, units, and other configured factors.
- **Do not hardcode ranges in UI or feature logic.**
- On release, persist the **exact** reference range and units applied so historical reports remain reproducible after catalog changes.
- Migrations: versioned range rules; backfill strategy for historical results if missing applied-range snapshots; never overwrite released snapshots when catalogs change.
- Remove obsolete hardcoded range constants/code after cutover.

### 4. Display & clinical safety

- Previews and printed reports show only the applicable (persisted) range.
- Flag abnormal and critical values with non-color cues.
- Verification + audit for release, correction, rejection, reversal.
- Critical results notify responsible clinician/ward via shared notification pipeline.

### 5. Print Report eligibility

- Enable **Print Report** by default when user is authorized and ≥1 printable released result exists.
- Selection reset or unrelated UI actions must not control eligibility.
- Align with prompts 07 and 11.

### 6. Worklists & sync

- Scoped pagination/filtering.
- Immediate Riverpod patches after successful actions.
- Realtime reconciliation for other authorized clients.
- Reuse workspace stack (prompt 03).

### 7. Authorization

- Enforce Laboratory module entitlement and action permissions on every order, result, report, print, and export endpoint (backend + mirrored UI).

---

## Tests

- Full pipeline including reject/reverse paths
- Range snapshot reproducibility after catalog change
- Critical notification emission
- Print eligibility independent of selection chrome
- Cross-scope and unauthorized access
- Multi-client worklist reconciliation

## Related prompts

00, 04, 07, 09, 10, 11
