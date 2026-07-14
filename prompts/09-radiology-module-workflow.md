# Radiology Module & Workflow — Implementation Prompt

## Objective

Deliver a dedicated Radiology executing-department module with full order-to-report workflow, role-appropriate workspaces, imaging assets/PACS integration where configured, versioned reports, and realtime reconciliation — without owning OPD/IPD stage transitions or Biomedical equipment lifecycle.

**Source requirement:** [prompt.md](../prompt.md) §5  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md)

---

## Mandatory reading

1. [`.cursor/flows/radiology-flow.mdc`](../.cursor/flows/radiology-flow.mdc)
2. [`.cursor/app-write-up.mdc`](../.cursor/app-write-up.mdc)
3. [`.cursor/flows/opd-flow.mdc`](../.cursor/flows/opd-flow.mdc) / [ipd-flow](../.cursor/flows/ipd-flow.mdc)
4. Shared prompts 03–07, 10, 11; Biomedical ownership in app-write-up

---

## Pre-implementation audit

- Inspect `frontend/lib/features/radiology/` and `backend/src/modules/radiology-workspace/` (and related modules).
- Confirm encounter linkage, queue intake, report versioning, asset storage, and entitlement checks.
- Implement only missing/non-compliant pieces; remove duplicates after cutover.

---

## Step-by-step instructions

### 1. Workflow states

Implement end-to-end:

1. Order received  
2. Billing gate when required (central billing engine)  
3. Scheduling and assignment  
4. Study started  
5. Study completed + imaging assets captured  
6. Report drafted  
7. Report finalized and attested  
8. Addendum or correction when required  

Expose states/capabilities to shared step progress (prompt 04).

### 2. Boundaries

- Every order links to originating clinical encounter.
- OPD/IPD orchestrators own patient-flow stages; Radiology UI must not perform those transitions.
- Radiology may schedule equipment; **Biomedical** owns equipment lifecycle and maintenance.
- Automatically add new authorized orders to the scoped Radiology work queue.

### 3. Role-appropriate workspaces

Provide workspaces for:

- Radiology clerks
- Radiographers
- Radiologists  

Reuse Patient Details, Clinical Request patterns, Step Progress, status, preview, and action components (prompts 03–07).

### 4. Studies, assets, PACS

- Modality/room/equipment assignment and scheduling
- Study execution and imaging-asset upload via controlled, access-checked storage
- PACS integration where configured (no unrestricted storage paths)
- Public IDs for orders/studies/assets in APIs and UI

### 5. Reporting & audit

- Draft, review, finalize/attest, correction, addenda
- Version history; finalized reports must not be silently overwritten
- Audit trails on all material transitions
- Compose previews/print with prompts 07 and 11

### 6. Database / migrations

- Schema for orders, studies, assets, report versions/addenda as needed
- Safe migrations; preserve finalized report versions; remove obsolete single-blob overwrite models after verified migration
- Idempotent billing hooks at configured billing points (prompt 10)

### 7. Authorization & sync

- Enforce Radiology module entitlement and action permissions on every order, study, asset, report, print, export endpoint
- Emit scoped domain events after committed changes
- Immediately patch acting user's worklist, details, summaries, and result previews
- Reconcile authorized clients through standard realtime pipeline
- Display current workflow state everywhere relevant

---

## Tests

- Full workflow including addendum/correction
- Finalized report immutability (no silent overwrite)
- Equipment scheduling does not mutate Biomedical master data incorrectly
- Role workspace visibility
- Unauthorized/cross-scope denial
- Multi-client reconciliation

## Related prompts

00, 04, 07, 08, 10, 11
