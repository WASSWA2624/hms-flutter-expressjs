# HOSSPI HMS Product Source Of Truth

## 1. Ownership
- `app-write-up.md` owns product scope, modules, workflows, roles, and quality outcomes.
- `*/app-rules/*` own technical standards only.
- `*/dev-plan/*` own build order only.

Conflict order:
1. law, safety, privacy, and security obligations
2. stable data and API contracts unless a migration path is defined
3. this file
4. `app-rules/*`
5. `dev-plan/*`

## 2. Product Posture
HOSSPI HMS is a modular, multi-tenant hospital platform for staff web/mobile workspaces and patient-facing journeys.

Shared platform capabilities included with the base platform:
- identity, session, and tenant context
- audit logging and compliance evidence
- notifications, documents, reporting foundations
- RBAC and ABAC enforcement
- localisation, theming, and shared UI primitives
- integration plumbing and analytics foundations

## 3. Product Invariants
- Every paid module is independently purchasable.
- Every paid module is task-complete when used alone.
- Cross-module integration may use summaries, deep links, attachments, or billable events, but routine completion in one module must not require another paid module.
- Module enablement is entitlement-driven, not deployment-driven.
- One user may hold multiple active roles at the same time.
- Authorization combines RBAC, ABAC, entitlements, and audited break-glass access.
- Database tables, columns, Prisma models, queries, migrations, and docs use lowercase `snake_case`.
- Public code and complex logic require professional JSDoc-style documentation.
- Shared UI primitives, shared frontend workflow code, thin routes, reusable workbench shells, and low-radius styling are mandatory.
- Circular dependencies and redundant scripts are defects.

## 4. Access Model
`user_role` is the role-assignment source of truth. Roles are scoped and may be time-bound.

Supported scopes:
- tenant
- facility
- branch
- department
- unit
- ward
- patient relationship
- shift or time window

Required role families:
- `SUPER_ADMIN`, `TENANT_ADMIN`, `FACILITY_ADMIN`
- `DOCTOR`, `NURSE`, `LAB_TECH`, `RADIOLOGY_TECH`, `PHARMACIST`, `BILLING`, `HR`, `OPERATIONS`, `HOUSE_KEEPER`
- `BIOMED`, `BIOMED_MANAGER`
- `UNIT_MANAGER`, `WARD_MANAGER`, `ICU_MANAGER`, `THEATRE_MANAGER`
- `MORTUARY_STAFF`, `MORTUARY_MANAGER`
- `PATIENT`

Valid examples:
- `DOCTOR + THEATRE_MANAGER`
- `NURSE + WARD_MANAGER`
- `BIOMED + BIOMED_MANAGER`
- `HR + UNIT_MANAGER`

Permission resolution order:
1. authenticate the user and active tenant or facility context
2. load active scoped roles from `user_role`
3. union RBAC permissions
4. apply module entitlements
5. apply ABAC conditions for scope, ownership, shift, patient relationship, separation of duties, and emergency state
6. apply explicit denies or suspensions
7. allow break-glass only through audited, time-limited emergency access
8. log sensitive reads and sensitive decisions

## 5. Business Modules
| Module | Purpose | Standalone outcome |
| --- | --- | --- |
| Identity and access | users, facilities, roles, sessions, policies, entitlements | tenant admin can onboard and operate the tenant |
| Patient registry | patient identity, contacts, guardians, consent, documents | registration and patient lookup are complete |
| Scheduling and OPD | appointments, queues, triage intake, provider availability | front desk and outpatient flow are complete |
| Clinical documentation | encounters, notes, diagnoses, procedures, care plans, referrals | clinicians can document care independently |
| Inpatient care | admissions, beds, nursing notes, rounds, discharge | ward workflows are complete |
| ICU | ICU stays, observations, critical alerts | ICU teams can operate independently |
| Theatre | theatre cases, anaesthesia, post-op handover | theatre teams can run peri-operative workflows |
| Diagnostics | lab and radiology ordering, processing, results | diagnostics can operate without clinical screens open |
| Pharmacy | formulary, medication orders, dispensing, returns | pharmacy operations are complete |
| Billing and insurance | invoices, payments, refunds, claims, plans | revenue operations are complete |
| HR and unit management | staff profiles, assignments, leave, shifts, rosters | HR and scoped unit managers can manage staffing |
| Inventory and procurement | stock, suppliers, requests, orders, receipts, adjustments | procurement and stock control are complete |
| Facilities and asset management | non-clinical assets, maintenance, housekeeping, service evidence | operational assets can be managed independently |
| Biomedical engineering | clinical equipment lifecycle, maintenance, calibration, downtime | biomedical teams can manage equipment end to end |
| Mortuary | deceased intake, storage, custody, viewing, post-mortem, release | mortuary teams can run the full deceased workflow |
| Communications and reporting | notifications, conversations, dashboards, reports, exports | communication and reporting remain useful on their own |
| Subscriptions and entitlements | plans, enabled modules, licenses, fit checks | commercial management works independently |
| Integrations and compliance | API keys, webhooks, audit review, PHI review, evidence export | integration and compliance teams can operate independently |
| Patient portal | appointments, results, prescriptions, billing, messages | patient self-service is complete |
| Last Office | shift close, handover, custody snapshots, closeout packs | end-of-shift closeout is complete |

## 6. Cross-Module Boundary Rules
- Billing owns invoices, payments, refunds, and claims. Other modules may emit billable events but do not own the ledger.
- Inventory owns stock and procurement. Pharmacy owns medication workflows. Biomedical owns clinical equipment lifecycle. Facilities owns non-clinical assets.
- Clinical modules own care documentation. Mortuary owns deceased intake, custody, storage, viewing, post-mortem coordination, and release.
- Patient portal is patient-facing only and does not replace staff workspaces.

## 7. Workforce, Unit Management, And Rosters
HR retains tenant-wide workforce authority.

Scoped managers must also exist:
- `UNIT_MANAGER`
- `WARD_MANAGER`
- `ICU_MANAGER`
- `THEATRE_MANAGER`

Roster rules:
- HR can create, edit, publish, rebalance, and override rosters across the tenant.
- Scoped managers can create, edit, publish, and review rosters only inside assigned scope.
- Scoped managers can manage shift swaps, staffing gaps, and leave impacts inside their unit.
- Frontend visibility, backend authorization, and audit logs must align on the same scope rules.

## 8. Biomedical And Asset Management
Required outcomes:
- one authoritative clinical equipment master record
- lifecycle tracking from procurement through retirement
- preventive maintenance, corrective work orders, calibration, recall, downtime, and safety checks
- procurement planning informed by service history, downtime, and replacement risk
- designated technical staff may work under biomedical authority without breaking asset ownership rules

Boundary rules:
- Biomedical owns clinical equipment.
- Facilities and asset management own non-clinical and operational assets.
- Inventory supports procurement and spare parts but is not the equipment lifecycle system of record.

## 9. Mortuary Module
Mortuary is a first-class module and must not be treated as an appendix to IPD, theatre, billing, or compliance.

Mortuary owns:
- `mortuary_case`
- `mortuary_deceased_profile`
- `mortuary_storage_unit`
- `mortuary_storage_slot`
- `mortuary_storage_assignment`
- `mortuary_custody_event`
- `mortuary_viewing`
- `mortuary_post_mortem_request`
- `mortuary_release_authorisation`
- `mortuary_billable_event`

Core workflow:
1. receive a deceased case from IPD, emergency, theatre, or an external handover
2. identify and link the deceased to a patient record when available
3. record receipt source, receiving staff, identifiers, next-of-kin, and legal authority
4. assign storage without double occupancy
5. maintain a full chain of custody
6. schedule viewing and post-mortem activities
7. emit billable events without forcing staff into Billing screens
8. verify release authority, release the body, and close the case with evidence

Stable mortuary permissions:
- `mortuary:read`
- `mortuary:write`
- `mortuary:manage_storage`
- `mortuary:viewing`
- `mortuary:post_mortem_request`
- `mortuary:release`
- `mortuary:approve`
- `mortuary:billing_event`
- `mortuary:audit`
- `mortuary:export`

Out of scope:
- replacing clinical documentation
- replacing the billing ledger
- replacing funeral-home systems

## 10. Canonical Workflow Families
1. commercial onboarding: tenant signup, plan and module selection, payment, facility setup, starter users
2. identity and access: invite, activate, assign multiple roles, switch context, enforce entitlements, audit access
3. patient journey: register, consent, schedule, triage, document, diagnose, order, dispense, bill, discharge, portal follow-up
4. acute and inpatient care: admit, assign bed, manage ICU or theatre transitions, record observations, discharge or hand over to mortuary
5. workforce operations: define staff structures, assign staff, build rosters, manage leave, approve swaps, monitor gaps
6. operational assets: request procurement, receive stock, track assets, service equipment, handle downtime and recalls
7. mortuary operations: intake, storage, custody, viewing, post-mortem coordination, release, evidence, billing event emission
8. revenue and closeout: invoice, receive payment, refund or claim, reconcile shift close, produce closeout pack

## 11. UX And Component Direction
- one shared component library across web and mobile
- one shared frontend workflow architecture across modules for forms, tables, filters, action bars, dialogs, and detail panes
- thin route files and reusable workbench shells
- forms and common actions default to shared modal flows; full-screen flows are for long, high-risk, or multi-step tasks only
- UI should feel simple, lightweight, elegant, and obvious to use
- primary, secondary, and destructive actions should stay visually and positionally consistent across modules
- minimal or zero corner radius by default
- responsive desktop and mobile layouts are required
- loading, empty, error, offline, and permission-denied states are required
- `light`, `dark`, and `high-contrast` themes remain supported
- module navigation, entitlements, and permission labels must stay aligned across backend and frontend

## 12. Repository And Documentation Hygiene
- `app-write-up.md` stays concise and product-only
- `app-rules/*` stay technical-only
- `dev-plan/*` stay chronological-only
- repetition across these document families is a defect
- script inventories must stay lean; remove obsolete or duplicate scripts in the same change that makes them obsolete
- new components, hooks, services, modal flows, or modules must reuse existing patterns before adding new ones

## 13. Product Quality Gates
Work is not complete unless:
- each paid module is useful and complete when used alone
- module keys, permission families, entitlements, route roots, and navigation labels agree across docs and code
- users can hold multiple active roles with scoped assignments at the same time
- RBAC and ABAC both participate in authorization
- HR and scoped unit managers can both manage rosters at their intended level
- biomedical and asset ownership stays separated and traceable
- Mortuary is implemented and documented as a complete first-class module
- database naming remains lowercase `snake_case`
- public and complex code paths use professional JSDoc-style documentation
- forms and common actions reuse shared modal-first UI and workflow code across modules unless a longer workflow requires otherwise
- component architecture avoids circular dependencies and preserves separation of concerns
- tests, validation, and release checks pass, or blockers are recorded with concrete reasons
