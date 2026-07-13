# Insurance & Claims Module — Implementation Prompt

## Objective

Complete the **Insurance and Claims Module** for HOSSPI HMS so insurance desk staff and billers can manage coverage end-to-end: verify patient coverage, create and track **pre-authorizations**, prepare and **submit claims**, record insurer responses (approval, rejection, partial approval), manage resubmission, and reconcile settlements — integrated with Billing and patient care flows (OPD, IPD, discharge).

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Insurance and claims module boundaries vs Billing
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §4 insurance authorization, deposit gates, discharge financial closure
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — consultation payment gate and payer context on OPD encounters
4. [prompts/09-billing-module-prompt.md](./09-billing-module-prompt.md) — shared claims/pre-auth work items in billing workspace

**Central rule:** coverage, pre-auth, and claims attach to **patient + payer + invoice/encounter** context. Claims module owns insurer workflow state — Billing owns invoice balances and cashier actions. Do not duplicate invoice line capture in Claims.

Deliver an **audit-ready insurance workspace** (standalone or integrated with Billing): clear claim lifecycle, pre-auth tracking, and linkage to IPD authorization gates.

---

## Global Implementation Standards

Mandatory platform rules for all work in this module.

| Area | Requirement |
| ---- | ----------- |
| Product scope | [app-write-up.mdc](../.cursor/app-write-up.mdc) — respect module boundaries; do not duplicate workflows owned elsewhere. |
| Patient flows | Align with [`.cursor/flows/`](../.cursor/flows/). Use [opd-flow.mdc](../.cursor/flows/opd-flow.mdc) and [ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) for journey touchpoints; read the module-specific flow file when one exists (lab, nursing, pharmacy, radiology, discharge, emergency, icu, theater). |
| Encounters | One active OPD encounter per outpatient visit; IPD admission as inpatient hub; overlays (ICU, Theater) and executing departments attach — never parallel admission records. |
| UI/UX | Modern, clean, minimal on-screen text; hospital workflow language (not enum names or UUIDs). Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`, `platform_guidelines.mdc`. Reuse `frontend/lib/shared/*` before creating new widgets. Responsive on Android, iOS, web, Windows, macOS, Linux. |
| Theming and i18n | Full theme support (light/dark/system). All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Modal-first workflows | **All create/edit/approve/complete/handoff actions** use **in-page dialogs, bottom sheets, or nested modals**. Do **not** navigate to new routes for within-module workflows. Shell entry routes (`/opd`, `/ipd`, etc.) and deep-link **pre-selection** of a patient/record are allowed; selecting a row opens the workspace detail panel — not a separate workflow page. |
| Realtime sync | Subscribe to relevant `RealtimeEventGroups` in workspace controllers. After mutations, refresh affected rows, detail panels, summary cards, and nav badges. Keep UI, frontend state, backend services, and database consistent. |
| Architecture | UI/controllers → repository → API (`frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`). Enforce RBAC + ABAC + tenant/facility scope + module entitlements (frontend `AccessGate` + backend authorization). |
| Database | Apply migrations for schema changes per backend standards; keep API contracts and schema aligned. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched modules. |

---


## Mandatory Reading (before any Claims change)

1. Re-read [app-write-up.mdc](../.cursor/app-write-up.mdc) — Claims owns coverage, pre-auth, submission, tracking.
2. Re-read [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §4 payment timing, insurance/credit paths, discharge settlement.
3. Re-read [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — payer on worklist, payment gate.
4. Re-read [prompts/09-billing-module-prompt.md](./09-billing-module-prompt.md) — §3 insurance claims gaps in billing workspace.

---

## Flow Integration Requirements

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Claims module responsibility |
| ----------- | ---------------------------- |
| §4 Before admission | Pre-auth for elective admission / packages |
| §4 During stay | Track approved amount, exclusions, consumed amount |
| §4 At discharge | Insurance closure alongside final bill |
| §7 Waiting Payment / Authorization | Orders blocked until pre-auth or deposit — show auth status |
| §13 Insurance desk role | Submit pre-auth, track approvals, manage claim documents |
| §16 Encounter hub | Claims reference IPD encounter and linked invoices |

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Claims module responsibility |
| ----------- | ---------------------------- |
| Payer on worklist | Coverage verification before or at consultation payment gate |
| `WAITING_CONSULTATION_PAYMENT` | Insured patients may proceed on authorization vs cash |
| Insured outpatient visits | Claims for consultation and outpatient services post-visit |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Claims implementation |
| ------------ | --------------------- |
| Insurance and claims row | Coverage plans, pre-auth, claim prep, submission, tracking |
| Billing boundary | Invoices and payments in Billing — claims link to invoices |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend workspace | `frontend/lib/features/claims/` | `claims_workspace_page`, controller, repository |
| Backend APIs | `/api/v1/insurance-claims`, `/pre-authorizations`, `/coverage-plans` | CRUD, submit, reconcile — **no** `claims-workspace` aggregator |
| Billing workspace | `CLAIMS_PENDING` queue, claim work items | Overlaps — invoice-centric detail in billing |
| Billing repository gaps | Partial claim/pre-auth mutations | See [prompts/09-billing-module-prompt.md](./09-billing-module-prompt.md) §3 |
| IPD references | Insurance desk role in ipd-flow §13 | Authorization gates not fully wired in IPD UI |

### Known gaps to close

- **Workspace orchestration** — frontend merges pre-auth + claim APIs client-side; no backend `claims-workspace` module.
- **Pre-auth lifecycle UI** — create, submit, approve/deny, link to encounter/admission.
- **Claim submission and tracking** — submit, record insurer response, resubmit, settlement.
- **IPD authorization panel** — approved amount, pending, consumed on admission detail.
- **OPD insured visit flow** — coverage check at registration or payment gate.
- **Integration with Billing** — `CLAIMS_PENDING` queue with non-invoice detail layouts (billing prompt).
- **Tests and localization** — full coverage for claim/pre-auth flows.
- **Pricing engine / insurer adapters** — multi-tier tariffs, enrollment verify, and stub payer connectors are specified in root [`prompt.md`](../prompt.md).

---

## Scope — Core Capabilities

### 1. Coverage and plan lookup

- Verify patient coverage plan, member ID, effective dates, exclusions.
- Link coverage to encounters and invoices.

### 2. Pre-authorization

- Create pre-auth for admission, procedure, or package (IPD flow §4).
- Track status: requested, approved, denied, partial, expired.
- Block or warn on orders when authorization insufficient.

### 3. Claim preparation and submission

- Build claim from invoice/encounter line items.
- Submit to insurer; record reference numbers and documents.
- Track pending, approved, rejected, paid, resubmitted.

### 4. Settlement and reconciliation

- Record settlement amount; reconcile with invoice balance in Billing.
- Handle partial approvals and patient co-pay.

### 5. Work queues

- Pending submission, pending insurer response, denied/resubmit, unsettled.
- Integrate with Billing `CLAIMS_PENDING` or standalone queue.

---

## UI / UX Requirements

This is an **insurance & claims workspace** — coverage, pre-authorizations, and claim-lifecycle tracking — not a patient clinical queue. Mirror the **Billing** financial workspace (`prompts/09-billing-module-prompt.md`), its closest peer, for layout consistency.

- **Layout:** `AppWorkspace` shell with `AppWorkspaceSummaryGrid` status cards, `AppSearchBar`, and `AppListTable` claim/pre-auth lists in `AppWorkspaceSplitContent` → `AppWorkspaceDetailPanel`; modal action dialogs (`AppActionPanel` + `showAppWorkspaceMutationDialog`).
- **Summary cards filter the claim list by status** (pending submission, awaiting insurer response, approved, partial, denied/resubmit, settled) — they must not open separate routes. Hide zero-value cards where the pattern expects it.
- **Status-pipeline framing:** show each claim/pre-auth's current state plus the **next required action** (submit, record response, resubmit, settle) and the **responsible role/payer** on list rows.
- **Modal-first / nested-modal actions:** create/submit pre-auth, build/submit claim, record insurer response, resubmit, and reconcile settlement run in dialogs or bottom sheets — never separate navigation routes; use nested modals for line-item or document sub-steps.
- Surface patient + payer context via `AppWorkspacePatientContextHeader`; use display IDs only — no raw UUIDs or enum codes.
- Full theme support (light/dark/system); all strings localized via `app_en.arb`; responsive on Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.

---


## Architecture and Conventions

| Rule | Requirement |
| ---- | ----------- |
| Layering | Widgets → Riverpod controllers → repository interface → impl → API client. No API calls from widgets. |
| State | `AsyncNotifier` + `Result<T>` / `AppFailure` for errors. |
| Permissions | `AccessGate` / `AppAccessActionGate`; backend auth mandatory even when UI hides actions. |
| File size | Extract reusable widgets to `presentation/widgets/`; shared components to `frontend/lib/shared/`. |
| Realtime | `frontend/.cursor/realtime_sync.mdc` — partial refresh after modal success when supported. |

---


## Module Boundaries (do not violate)

- Do not duplicate invoice creation — Billing owns invoice lifecycle.
- Do not mutate clinical orders or OPD/IPD stages from claims UI.
- Backend authorization mandatory for all claim/pre-auth mutations.

---

## Acceptance Criteria

- [ ] Pre-auth can be created and tracked for IPD admission and high-cost procedures.
- [ ] Claims can be submitted and status-updated with audit trail.
- [ ] IPD insurance gates show authorization state per ipd-flow §4.
- [ ] Billing workspace shows claim/pre-auth items with dedicated actions (or standalone module equivalent).
- [ ] OPD insured visits support coverage verification at payment gate.
- [ ] No raw UUIDs; permissions enforced; tests pass.

---

## Quality Gate

From `frontend/` when touching Flutter:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="<module>"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
backend/src/modules/insurance-claim/
backend/src/modules/pre-authorization/
backend/src/modules/coverage-plan/
frontend/lib/features/billing/

Related prompts: prompts/09-billing-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/12-opd-module-prompt.md
```
