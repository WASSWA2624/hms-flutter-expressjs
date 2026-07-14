# HOSSPI HMS Application Improvement Requirements

Improve the existing HOSSPI HMS application without duplicating compliant functionality. Before implementing any requirement, inspect the current frontend, backend, database schema, shared components, and tests; preserve correct behavior and change only missing, obsolete, or non-compliant areas.

These requirements are ordered from cross-cutting foundations through module workflows. Sections may be delivered independently only when their cross-stack dependencies and the global requirements below remain satisfied.

## 0. Global Delivery & Acceptance Requirements

- Follow every applicable rule under [HMS rules](.cursor/), [Backend rules](backend/.cursor/), and [Frontend rules](frontend/.cursor/), including their documented conflict precedence.
- Treat security, privacy, clinical safety, and compliance as higher priority than convenience or visual behavior.
- Keep module boundaries intact. Reuse existing services, repositories, controllers, providers, design-system primitives, and shared components before creating new implementations.
- Preserve the documented stack architecture: feature-first `data/domain/presentation` boundaries in Flutter and the backend module/layer boundaries defined under `backend/.cursor/`. Widgets must not call APIs, databases, or synchronization services directly.
- Implement each feature end-to-end where applicable: database, migration/backfill, backend authorization and API, audit and domain events, frontend state and UI, localization, automated tests, and documentation.
- For schema changes, provide safe migrations, preserve valid data, remove obsolete data/code only after replacement is verified, and define rollback or recovery handling.
- Public APIs, routes, UI state, deep links, and real-time events must reference entities by `human_friendly_id` or approved domain display IDs. Backend repositories map these to internal IDs. Never expose raw database primary keys.
- Follow the shared API contract: versioned `/api/v1/*` business routes, lowercase `snake_case` payloads/query parameters, normalized success/error envelopes, safe pagination, and UTC ISO-8601 timestamps.
- Validate path parameters, queries, and request bodies at the API boundary; reject unknown or unsafe fields without exposing PHI, secrets, internal errors, or record existence.
- Every shared-data mutation must:
  1. persist through HTTP;
  2. update all affected Riverpod state immediately after successful persistence;
  3. avoid UI changes on cancellation or failure;
  4. emit a scoped backend domain event after persistence and audit; and
  5. reconcile authorized clients through WebSocket events and the smallest targeted refresh.
- Do not use WebSockets as a mutation transport. Do not promise fixed delivery latency; HTTP persistence is authoritative and reconnect reconciliation must recover missed events.
- Scope all data, caches, events, reports, and navigation to the authenticated user, tenant, facility, and finer ABAC context where applicable.
- Queue offline only mutations explicitly allowed by the shared API contract. Authentication/session changes, payments, refunds, billing closeout, break-glass approvals, mortuary release, and final close workflows are online-only.
- Store sensitive documents, imaging assets, and generated reports through controlled, access-checked storage; never expose unrestricted storage paths.
- Use structured operational logging with sensitive-data redaction and scoped diagnostic context. Keep audit evidence separate from application logs and preserve `/health`, `/ready`, and `/live` checks.
- Localize all user-facing and accessibility text. Use locale-aware shared date, time, number, and currency formatters.
- Use comprehensive theme/design tokens only; do not hardcode colors, typography, spacing, shape, or elevation in feature code.
- Meet accessibility requirements for semantics, keyboard and focus behavior, text scaling, contrast, non-color status cues, and practical touch/click targets.
- Keep lists and workspaces performant through server-side filtering/pagination and lazy rendering where appropriate. Avoid unnecessary full-workspace reloads.
- Add or update unit, controller/service, API/integration, widget, responsive, authorization, and real-time multi-client tests in proportion to each change.
- A requirement is complete only when applicable quality gates pass and no obsolete duplicate implementation remains.

---

## 1. Authorization & Security

### Objectives

Build a secure authorization model that enforces access control across all parts of the application.

### Requirements

- Enforce RBAC, ABAC, tenant/facility scope, assigned modules, and active subscription entitlements throughout the application.
- Calculate effective access as:
  `union(role, module, and direct-user grants) ∩ active subscription permissions ∩ assigned modules ∩ ABAC scope`.
- Support multiple roles and module assignments per user without allowing any grant to exceed the active subscription or contextual scope.
- Keep backend authorization as the source of truth for every API operation, record, workflow transition, report, export, and real-time subscription. Frontend guards and visibility must mirror—not replace—backend enforcement.
- Do not render unauthorized pages, routes, navigation items, buttons, dialogs, fields, data, or workflow actions. Disabling is appropriate only when the user is authorized but a valid prerequisite or workflow state is unmet.
- Apply ABAC scope at the relevant tenant, facility, department, unit, ward, room, bed, encounter, ownership, and action level.
- Maintain a complete source-controlled default catalog of modules, subscription packages, roles, and permissions. Authorized administrators may customize or restore defaults only through atomic, versioned, and auditable changes.
- Any break-glass access must be explicit, justified, time-limited, narrowly scoped, and fully audited.
- Immediately dispose of authenticated providers, in-memory state, local database partitions, pending requests, real-time subscriptions, and user-specific caches on logout, account switch, or tenant/facility context change.
- Partition persisted non-sensitive state by user and tenant/facility context. Store credentials only in secure storage and never persist PHI in insecure preferences.
- Render a neutral loading state during session restoration or context switching; never display data from the previous context, even briefly.
- Ensure dashboards, pages, badges, exports, and shared components read only the current authorized scope.
- Test cross-user, cross-tenant, cross-facility, expired-subscription, revoked-permission, and account-switch isolation.

---

## 2. Responsive Design & Design System

### Objectives

Establish a design system with consistent, reusable, responsive UI across the application.

### Requirements

- Design natively for **mobile**, **tablet**, and **desktop**, including extra-small mobile and large desktop widths; do not merely scale one layout.
- Use the centralized responsive breakpoints, shell, spacing, and max-width utilities defined by the frontend rules. Avoid feature-specific breakpoint logic and fixed widths unless they are intentional min/max constraints.
- Adapt navigation, information density, column count, dialogs, tables, and input behavior to each form factor while keeping one consistent workflow.
- Standardize typography, spacing, color, shape, elevation, motion, feedback, and interaction patterns through shared design tokens.
- Keep interfaces concise and intuitive without replacing necessary labels with ambiguous icons.
- Maintain a unified icon system.
- Apply consistent icons to:
  - Buttons
  - Navigation
  - Menus
  - List items
  - Labels
  - Status indicators
  - Actions
  - Forms
  - Cards
  - Tabs
  - Dialogs
  - Alerts
  - Badges
  - Toolbars
- Icons must improve comprehension, include localized semantic labels where needed, and never be the only indicator of important status.
- Support touch, pointer, keyboard, focus, hover, and text scaling without hiding critical controls.
- Every reusable component must be fully responsive and accessible in light and dark themes.
- Verify representative screens at all centralized breakpoints, with long localized text, large text scaling, keyboard-only input, and constrained heights.

---

## 3. Shared Reusable Components

### Objectives

Develop high-utility reusable components as a priority, to drive UI/UX consistency and minimize duplication before feature modules are built.

### Requirements

Audit the shared component catalog first. Extend or create the following reusable capabilities under the appropriate `frontend/lib/shared/` subfolder only when they do not already exist:

- Patient details
- Permission-aware actions
- Clinical-results preview
- Report sections
- Status badges
- Loading, empty, error, and success states
- Timeline components
- Detail cards
- Dialog components

#### Core Reusable Component: Step Progress & Actions

Create or consolidate a **reusable workflow/progress step component** that visualizes the current, completed, upcoming, skipped, reverted, and unavailable steps for encounters, requests, and task progressions.

- The component must support customizable steps, each with:
  - A localized icon, label, description, semantic state, and stable step identifier.
  - Contextual action labels such as “Perform”, “Complete”, “Skip”, “Revert”, or “Resume” only when allowed by the backend-provided workflow capabilities and current state.
  - Permission-aware actions with loading, success, failure, confirmation, and retry behavior.
  - Explanations available by hover, keyboard focus, and touch-accessible help—not hover alone.
  - A localized reason when an authorized action is unavailable because of prerequisites or workflow constraints.
- Support clear differentiation between completed/active/pending/disabled steps.
- Do not expose an action at all when the user lacks effective permission.
- Never infer or mutate workflow state only in the client; persist valid transitions through the owning backend module.
- Make the component reusable for lab, radiology, admissions, appointments, billing, discharge, and other workflows without embedding module-specific business logic.
- Provide compact mobile and expanded tablet/desktop layouts with correct reading order and keyboard navigation.

#### Module Workspace Contract

- Clinical and operational queue screens must reuse the shared workspace stack (`AsyncStateScaffold`, `ResponsivePage`, `AppWorkspace`, `AppListTable`, `AppWorkspaceDetailPanel`, and `AppActionPanel`) unless the documented screen type is exempt.
- Workspaces must keep selection, filters, rows, details, summary counts, and navigation badges in Riverpod and update only affected state after successful actions.
- Paginate or lazy-load large worklists, debounce remote search where appropriate, and register the applicable shared real-time event groups in workspace controllers.

### General Requirements

- Modern, visually appealing, and responsive.
- Context-aware and fully configurable.
- Design for maximum reuse and extensibility.
- Remove duplicate code and legacy UI implementations.
- Keep business logic outside shared presentation components; accept typed data and callbacks.
- Include shared loading, empty, error, permission-denied, and retry behavior.
- Add component tests for responsiveness, semantics, permissions, and all supported states.

### Patient Details Component

- Display only patient information relevant for the current workflow.
- Provide a persistent **Show More / Show Less** toggle:
  - **Show Less**: Patient name, approved public patient identifier (for example MRN), age, and gender
  - **Show More**: All applicable patient/encounter information
- Persist this non-sensitive preference per user across sessions and, when server-side preference sync exists, across devices.
- Never cache the displayed patient data as part of the preference.

### Actions Component

- Must be RBAC and ABAC aware.
- Respect subscription/module entitlements and backend-provided action capabilities in addition to RBAC and ABAC.
- Support loading, prerequisite-disabled, confirmation, contextual, asynchronous, success, failure, and retry states.
- Prevent duplicate submission and use idempotency for retryable mutations.
- Used throughout all forms, dialogs, detail pages, and workflows.

### Clinical Results Preview

Reusable preview components for:

- Laboratory Results
- Radiology Reports
- Procedures
- Clinical Assessments
- Other clinical modules

Requirements:
- Support inline, modal, and full-screen previews.
- Consistent, chronological display across the application.
- Clearly distinguish preliminary, verified/final, corrected, and unavailable results.
- Enforce encounter scope, authorization, safe loading/error states, locale-aware timestamps, and print eligibility.

---

## 4. Laboratory Module Improvements

### Requirements

- Keep laboratory as an executing department: every order must link to its originating clinical encounter, while OPD/IPD orchestrators own patient-flow stage changes.
- Support the canonical order-to-result flow: order received, billing gate where required, sample collection, sample receipt/rejection with reason, processing, result entry, verification/release or rejection, and authorized reversal.
- Determine reference ranges from effective-dated, configurable laboratory rules using patient age, sex/gender data as clinically configured, test method, units, and other applicable clinical factors. Do not hardcode ranges in UI or feature logic.
- Persist the exact reference range and units applied to a released result so historical reports remain reproducible after catalog changes.
- Display only the applicable range in previews and printed reports; clearly flag abnormal and critical values without relying on color alone.
- Require appropriate verification and audit trails for release, correction, rejection, and reversal. Notify the responsible clinician/ward of critical results through the shared notification pipeline.
- Enable **Print Report** by default whenever the user is authorized and at least one printable released result exists. Selection reset or unrelated UI actions must not control eligibility.
- Ensure worklists use scoped pagination/filtering and update immediately after successful actions, with real-time reconciliation for other authorized clients.
- Enforce the configured Laboratory module entitlement and action permission for every order, result, report, print, and export endpoint.

---

## 5. Radiology Module & Workflow

### Objectives

Introduce a dedicated Radiology module with a full end-to-end workflow.

### Workflow

1. Order received
2. Billing gate, when required
3. Scheduling and assignment
4. Study started
5. Study completed and imaging assets captured
6. Report drafted
7. Report finalized and attested
8. Addendum or correction, when required

### Requirements

- Keep radiology as an executing department: every order must link to its originating clinical encounter, while OPD/IPD orchestrators own patient-flow stage changes.
- Automatically add new authorized orders to the scoped Radiology work queue.
- Provide role-appropriate workspaces for radiology clerks, radiographers, and radiologists.
- Reuse Patient Details, Clinical Request, Step Progress, status, preview, and action components.
- Support modality/room/equipment assignment, scheduling, study execution, imaging-asset upload, and PACS integration where configured.
- Support report drafting, review, finalization/attestation, correction, and addenda with version history and audit trails. Finalized reports must not be silently overwritten.
- Enforce the configured Radiology module entitlement and action permission for every order, study, asset, report, print, and export endpoint.
- Respect the Biomedical module boundary: Radiology may schedule equipment, but Biomedical owns equipment lifecycle and maintenance.
- Emit scoped domain events after committed workflow changes and reconcile all authorized clients through the standard real-time pipeline.
- Immediately patch the acting user's worklist, details, summaries, and result previews after successful persistence.
- Display current workflow state everywhere it is relevant without permitting the Radiology UI to perform OPD/IPD-owned transitions.

---

## 6. Billing Engine Integration

### Objectives

Fully integrate billing into every clinical workflow.

### Requirements

Automatically generate charges for each billable activity:

- Consultations
- Laboratory
- Radiology
- Procedures
- Pharmacy
- Admissions
- Theatre
- Nursing
- Consumables
- Future configurable services

Other requirements:

- Generate charges through the centralized billing engine at the owning workflow's configured billing point; feature modules must not create independent billing logic.
- Always use effective-dated configured billing-catalogue prices, coverage rules, taxes, discounts, and facility/tenant context; never hardcode financial values.
- Make charge creation atomic, idempotent, and traceable to the originating encounter, order, service, actor, and catalog item.
- Define an explicit uniqueness/idempotency rule for every billable event:
  - Never bill a consultation twice for one encounter.
  - Prevent duplicate service charges unless the catalog and authorized workflow explicitly allow a repeat.
  - Retries and real-time event reprocessing must not create additional charges.
- Display all and only in-scope billable items to authorized billing users.
- Support invoices, payments, receipts, refunds, adjustments, settlement, cashier close, audit, reporting, and reconciliation through Billing-owned workflows.
- Keep payments, refunds, billing closeout, and other financial finalization actions online-only; never queue them for offline execution.
- Require explicit permissions, confirmation, reason capture where applicable, immutable audit history, and balanced ledger behavior for adjustments, waivers, reversals, and refunds.
- Update clinical and billing views immediately after successful persistence and reconcile authorized clients without using real-time events to initiate charges.

---

## 7. Patient Reporting & Printing

### Objectives

Implement a unified reporting and printing solution for all departments.

Departments include (not limited to):

- OPD
- IPD
- Laboratory
- Radiology
- Theatre
- ICU
- Pharmacy
- Billing
- Other clinical departments

### Requirements

- **Reuse and extend the existing shared report template** for all printable reports; do not create department-specific document frameworks.
- Compose reports using shared, configurable sections and components for consistency.
- Avoid duplicate information and render each fact from its authoritative module.
- Generate comprehensive, sectioned patient reports.

Configurable sections may include:

- Patient information
- Encounter details
- Vitals
- Clinical notes
- Diagnoses
- Findings
- Laboratory results
- Radiology reports
- Procedures
- Prescriptions
- Medications
- Doctor's notes
- Billing information
- Other clinical records

Other requirements:

- Allow users to select authorized sections to print; sections without data must be unselected and disabled by default.
- Print only selected sections.
- Use chronological display with locale-aware dates/times and clear headings.
- Produce printer-optimized, high-quality output with stable page breaks, repeated headers where needed, and no clipped or interactive-only controls.
- Apply RBAC, ABAC, subscription, tenant, facility, and patient/encounter scope to report generation, preview, export, and printing on the backend.
- Audit PHI report access, generation, export, and printing with actor, scope, report type, and timestamp.
- Prevent hidden or unauthorized fields from entering generated output, API payloads, local caches, or real-time events.
- Retrieve generated documents only through controlled, access-checked storage. Large reports may use an asynchronous job with authoritative status metadata instead of blocking the request.
- Test empty, partial, long, multi-page, localized, and revoked-access cases.

---

## 8. Reception / Front-Desk Workspace

### Objectives

Create a role-focused Reception workspace over the existing Patient Registry, OPD, IPD, Billing, Claims/Insurance, and Communications modules. Reception is not a separate entitlement module.

### Reception Responsibilities

Reception staff should be able to:

- Register patients
- Search for existing patients and warn about likely duplicates before registration
- Edit patient information
- Schedule/reschedule/cancel appointments
- Check in patients
- Start encounters
- Reuse an active encounter when required by the canonical OPD flow; do not create parallel encounters
- Route patients
- View patient queues and appointments
- Check requested services, estimated charges, outstanding balances
- Advise on payment methods
- Capture:
  - Insurance information
  - Payment method
  - Cash payments through authorized Billing-owned cashier actions
  - Card payments through authorized Billing-owned cashier actions
  - Mobile Money through authorized Billing-owned cashier actions
  - Other supported payment methods

### Authorization

Receptionists must **not**, unless granted the specific effective Billing permission:

- Finalize, approve, adjust, waive, refund, reverse, reconcile, or close billing transactions.

Clearly separate billing guidance from Billing-owned operations. Hide unauthorized actions and enforce the same restriction on the backend.

### Design Requirements

- Streamlined for high-volume workflows.
- Minimize workflow steps and in-screen navigation depth while retaining the standard responsive application shell.
- Real-time display of queues, appointments, encounters, routing, and waiting status.
- Reuse all shared components, including the new step/progress component, for visual consistency.
- Provide fast search, keyboard-efficient desktop operation, touch-friendly mobile/tablet operation, duplicate-patient warnings, and safe recovery from failed submissions.
- Immediately update registration, appointment, check-in, routing, queue, and payment views after successful persistence.
- Keep triage capture in the Triage module; Reception routes patients to canonical queues and does not duplicate clinical triage workflows.
- Make check-in, encounter-start, and routing mutations idempotent under retries and deterministic under conflicts.

---

## 9. General Application Consistency

### Objectives

Mandate that the application follows a unified, modular, and maintainable architecture and user experience.

### Requirements

- Use standardized, reusable components and business logic throughout.
- Remove superseded duplicate code, routes, providers, services, components, and tests after verified migration.
- Keep workflows, terminology, status mapping, feedback, and UI patterns consistent across modules.
- Preserve the documented frontend/backend layer boundaries and module ownership for maintainability.
- Synchronize UI, workflow, billing, notifications, badges, and clinical results through immediate Riverpod updates plus scoped WebSocket reconciliation.
- Prioritize reuse: shared implementation first, extension second, new module-specific implementation only when the behavior is genuinely domain-specific.
- All new features must integrate with the overarching architecture, design system, authorization, reusable components, billing engine, and workflow step/progress components.
- Use public `human_friendly_id` references, normalized API contracts, localized text, shared formatters, design tokens, and auditable backend mutations everywhere.
- Maintain complete loading, empty, error, offline, conflict, forbidden, success, and retry states without leaking sensitive information.
- Update documentation and remove stale documentation when contracts, workflows, permissions, or shared components change.

### Definition of Done

For each delivered section:

- Existing behavior was audited and only gaps or non-compliant implementations were changed.
- Database migrations and backfills are safe and verified where applicable.
- Backend validation, authorization, transactionality, audit logging, idempotency, and domain-event behavior are covered.
- Frontend state updates immediately after successful persistence and reconciles correctly across a simulated second client.
- Unauthorized, cross-scope, cancellation, failure, conflict, reconnect, and retry paths are tested.
- Mobile, tablet, and desktop layouts are verified for responsiveness, accessibility, localization, and theme consistency.
- Relevant backend and frontend automated checks pass with no new warnings or failures.
