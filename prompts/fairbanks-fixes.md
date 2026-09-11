# Chronological Application Fix & Improvement Plan

## PHASE 1 — Authentication, Registration & Session Stability

### Step 1 — Fix the Login Password Field

Investigate why the password field sometimes becomes unable to receive input.
Check:

- component lifecycle and remounting;
- focus management;
- disabled/loading states;
- overlays and z-index issues;
- form validation;
- browser autofill;
- event handlers;
- authentication-state initialization;
- unexpected rerenders.

**Acceptance test:**
Open the login page repeatedly, enter username/password, submit with both successful and failed credentials, retry, navigate away and back, and confirm that the password field remains fully functional without requiring a page refresh.

---



### Step 2 — Fix Registration False Errors

Trace the complete registration transaction:

`Registration Form → API → User Creation → Tenant/Facility Creation → Email Verification → Response`

Explicitly distinguish:

- registration failed;
- account successfully created;
- verification email successfully sent;
- account created but email delayed/failed;
- request timed out while the backend operation actually succeeded.

The frontend must not display **"connection taking too long"**, registration failure, or another misleading error when the backend has already successfully completed the operation.

Implement idempotency/duplicate-protection so that retrying a timed-out registration cannot create duplicate accounts, tenants, or facilities.

**Acceptance test:**
Register under slow/intermittent network conditions and verify that the final UI reflects the actual backend state.

---



### Step 3 — Implement Persistent Authentication

Replace fragile session handling with robust persistent authentication.

Implement:

- persistent access/session storage using the application's security architecture;
- refresh-token/session renewal;
- session restoration during application startup;
- graceful access-token expiry handling;
- secure logout;
- recovery from transient authentication failures;
- protection against unexpected logout during active workflows.

Test:

`Login → Dispense → Wait → Navigate → Close App → Reopen App → Continue`

The user should remain authenticated until explicitly logging out or until an intentionally configured security policy requires re-authentication.

**Acceptance test:**
Close and reopen the application repeatedly and confirm that valid sessions are restored automatically.

---



## PHASE 2 — Tenant Architecture & Data Isolation

**This is the highest-priority data-integrity phase.**

### Step 4 — Audit New-Tenant Data Creation

Trace exactly what happens when a tenant/facility is created and identify every automatically inserted record.

Classify records into:

#### Allowed Initial Configuration

Examples:

- laboratory tests;
- laboratory panels;
- radiology procedures;
- theatre procedures;
- clinical diagnoses;
- currencies;
- default consultations;
- pharmacy/master configuration;
- units;
- departments;
- default user roles;
- other approved master-data presets.



#### Forbidden Initial Operational Data

Examples:

- patients;
- patient demographics;
- visits;
- consultations;
- prescriptions;
- laboratory orders;
- radiology orders;
- bills;
- payments;
- invoices;
- dispensing transactions;
- other patient-linked or transactional records.

---



### Step 5 — Remove Patient/Transactional Data From Tenant Initialization

Tenant creation must generate:

`Configuration + Presets + Empty Operational Data`

and never:

`Configuration + Presets + Patient/Transactional Data`

**Acceptance test:**
Immediately after creating a completely new tenant:


| Entity                       | Expected |
| ---------------------------- | -------- |
| Patients                     | 0        |
| Visits                       | 0        |
| Orders                       | 0        |
| Prescriptions                | 0        |
| Bills                        | 0        |
| Payments                     | 0        |
| Dispensing Transactions      | 0        |
| Other Patient-Linked Records | 0        |


---



### Step 6 — Implement Proper Platform Presets

Establish a clear distinction between:

**Global Platform Presets**
and
**Tenant/Facility Configuration**

Global presets should be centrally managed and available to authorized tenants/users without allowing ordinary tenant administrators to modify or delete the source definitions.

Tenant administrators should be able to:

- view available presets;
- activate/select presets;
- add presets to their facility;
- customize permitted properties;
- create facility-specific entries.

Apply the model consistently to:

- laboratory;
- radiology;
- theatre;
- clinical diagnoses;
- currencies;
- consultations;
- pharmacy;
- departments;
- other master data.

---



### Step 7 — Verify Tenant Isolation

Create:

`Tenant A`
`Tenant B`

Verify that:

- patients created in A never appear in B;
- facilities and facility records from A never appear in B;
- transactions from A never appear in B;
- configuration changes intended only for A do not alter B;
- users cannot access data outside their authorized tenant/facility scope.

Test at:

1. UI level;
2. API level;
3. authorization layer;
4. database/query level.

**Gate:** Do not proceed until tenant isolation is confirmed.

---



## PHASE 3 — Users, Roles & Permissions

This phase establishes the authorization foundation required for billing, reporting, administration, and sensitive workflows.

### Step 8 — Stabilize User Creation

Fix existing user-creation issues.

Test:

- create user;
- assign facility/scope;
- assign role;
- activate/deactivate user;
- edit user;
- reset credentials;
- log in as created user;
- verify appropriate access.=

Backend errors must be returned in a meaningful format and displayed correctly in the frontend.

---



### Step 9 — Implement Global Default Roles

All platform-defined default roles should be:

- globally defined;
- available to authorized tenants;
- protected from deletion by tenant users;
- protected from unauthorized modification;
- assignable by authorized administrators.

---



### Step 10 — Implement Custom Role Creation

Support three creation methods.

#### Method A — Build From Scratch

Select individual permissions.

#### Method B — Inherit and Extend

Start from an existing role and add permissions.

Example:

`Nurse → Nurse + Selected Pharmacy Permissions`

#### Method C — Combine Roles

Combine two or more roles.

Example:

`Doctor + Administrator`

Result:

`Union of Doctor Permissions + Administrator Permissions`

Source roles must remain unchanged.

---



### Step 11 — Implement Role Hierarchy & Privilege Protection

Prevent users from granting permissions that exceed their own authority.

Example hierarchy:

`Platform Admin → Facility/Tenant Admin → Superior Staff → Staff`

The actual hierarchy should follow the application's organizational model.

Most importantly, privilege enforcement must occur at the backend/API level and not merely in the frontend.

Test:

- permission creation;
- permission assignment;
- role editing;
- privilege escalation attempts;
- cross-tenant access attempts.

---



### Step 12 — Add Scope-Based Access Control

Formalize the scope against which each role operates.

Examples:

- platform;
- tenant;
- facility;
- department;
- service;
- individual/assigned scope.

Every user session should resolve:

`User → Roles → Permissions → Scope`

This scope model will later drive:

- clinical access;
- billing authorization;
- reports;
- analytics;
- dashboards;
- exports;
- facility visibility.

---



## PHASE 4 — Core Billing, Payments, Waivers & Refunds



### Step 13 — Remove Unnecessary Pending-Payment Blocking

Change:

`Payment Pending → Block Service`

to:

`Payment Pending → Service Allowed + Payment Status Recorded`

Pending payment must not unnecessarily stop:

- consultation;
- prescription;
- dispensing;
- laboratory;
- admission;
- radiology;
- theatre;
- other legitimate services.

Only genuinely required financial or safety controls should block an action.

---



### Step 14 — Implement Payment Waivers

Authorized users should be able to waive an outstanding payment.

When waived:

- outstanding balance becomes zero;
- transaction is financially settled;
- waiver status is recorded;
- authorizing user is recorded;
- mandatory reason is recorded;
- audit trail is preserved.

Financial reporting must distinguish:

`Paid | Pending | Partially Paid | Waived | Refunded | Cancelled`

---



### Step 15 — Allow Authorized Performing Staff to Receive Payment

After roles and billing permissions are stable, allow authorized staff to collect payment for activities they perform.

Examples:

`Doctor → Consultation → Bill → Receive Payment`

`Pharmacist → Dispense → Bill → Receive Payment`

`Lab Staff → Laboratory Service → Bill → Receive Payment`

Create a dedicated permission:

`Can Receive Payments`

Do not automatically grant this permission to every user who performs a service.

Every payment must record:

- patient;
- transaction;
- service;
- amount;
- payment method;
- receiving staff;
- date/time;
- payment reference;
- facility;
- tenant.

---



### Step 16 — Fix Refund Approval

Create a dedicated permission:

`Can Approve Refund`

Trace:

`Refund Request → Authorization → Approval → Financial Transaction → Status Update`

Test:

- full refund;
- partial refund;
- authorized approver;
- unauthorized user;
- already processed refund;
- failed refund;
- duplicate refund attempts.

---



## PHASE 5 — Clinical Workflow Flexibility



### Step 17 — Remove Unnecessary Clinical Blocking

Review workflow dependencies across the entire clinical system.

Principle:

> A clinical action should not block another action unless that dependency is genuinely necessary for clinical safety, regulatory compliance, data integrity, or a clearly required business rule.

For example, prescribing should not unnecessarily depend on triage completion.

Review:

- consultation;
- prescription;
- laboratory;
- radiology;
- procedures;
- pharmacy;
- vital signs;
- clinical notes;
- diagnoses;
- referrals;
- follow-up;
- discharge;
- admission;
- other clinical workflows.

Do not remove legitimate safety controls. Remove only unnecessary restrictions.

The objective is maximum flexibility in patient flow with appropriate safeguards.

---



## PHASE 6 — Facility & Staff Management



### Step 18 — Fix Facility/Tenant Relationship Display

Investigate the facility → tenant relationship.

Correct:

`Tenant: Not Available`

to the actual associated tenant.

Verify the relationship at:

- database level;
- API level;
- authorization level;
- frontend level.

Do not merely patch the display.

---



### Step 19 — Fix Facility Logo Rendering

Trace:

`Stored Logo → Storage → API → Facility Data → Frontend → Image Component`

Check and fix:

- URL/path generation;
- storage permissions;
- API response;
- tenant/facility relationship;
- image loading;
- authorization;
- missing-image handling;
- supported image formats.

Test with multiple image dimensions and formats.

---



### Step 20 — Fix Create Staff

Under **Facility Details**:

`Create Staff → Existing Create Staff Dialog`

Reuse the existing component/workflow where appropriate.

Ensure:

- correct dialog opening;
- correct facility context;
- correct tenant context;
- successful staff creation;
- correct validation;
- automatic staff-list refresh.

---



### Step 21 — Improve Staff List

Fix action-button spacing and alignment.

Then implement:

`Click Staff Row → Nested Staff Details Dialog`

Reuse the existing Staff Details UI where possible.

The nested dialog must preserve the underlying Facility Details state and should not unnecessarily reload unrelated data.

---



## PHASE 7 — Shared UI Components



### Step 22 — Fix Phone Number + Speech-to-Text Duplication

Investigate the shared phone-number input state management.

Correct the update mechanism so that speech-to-text produces one value instead of duplicated values such as:

`+256... +256...`

Test:

- STT only;
- typing only;
- STT followed by typing;
- repeated STT;
- rerendering;
- component reopening;
- editing existing values.

Verify the corrected shared component everywhere it is used.

---



### Step 23 — Replace Country Selector Globally

Create one reusable country selector with a complete supported-country dataset.

Requirements:

- searchable;
- keyboard friendly;
- mobile friendly;
- complete dataset;
- consistent behavior;
- consistent appearance.

Replace duplicated implementations throughout the application, including **Edit Facility**.

---



### Step 24 — Change Active Toggle to Checkbox

Under **Edit Facility**:

`Active → Checkbox`

Default state:

`Checked`

Ensure the saved value maps correctly to the existing backend field and preserves compatibility with current records.

---



## PHASE 8 — Pharmacy Workflow & Data Model



### Step 25 — Simplify the Pharmacy Journey

Map the existing workflow:

`Prescription → Verification → Selection → Quantity → Pricing → Billing → Payment → Dispensing → Completion`

Identify every unnecessary interaction.

Automate internally where possible and expose only actions that genuinely require human intervention.

Goals:

- fewer clicks;
- minimal repeated information entry;
- automatic reuse of existing patient/prescription data;
- automatic calculations;
- minimal duplicate confirmations.

Do not remove:

- stock controls;
- financial controls;
- audit trails;
- prescription traceability;
- required authorization controls.

---



### Step 26 — Implement Flexible Drug Strength

Redesign **Create Drug → Strength** as a structured and extensible field.

Support:

**Single component**

`500 mg`

**Multiple components**

`Amoxicillin 500 mg + Clavulanic Acid 125 mg`

**Other combinations**

Support different units, quantities, concentrations, and multiple active components where applicable.

Prefer structured internal storage over a single uncontrolled text field.

The design should:

- support custom strengths;
- validate units and values;
- prevent common data-entry errors;
- provide intelligent suggestions where appropriate;
- preserve the original formulation accurately;
- remain extensible for future formulations.

---



### Step 27 — Implement Pharmacy Analytics

Build pharmacy-specific reporting and analytics covering:

- dispensing;
- sales;
- revenue;
- stock;
- purchases;
- suppliers;
- expiry;
- stock adjustments;
- returns;
- fast-moving medicines;
- slow-moving medicines;
- staff activity;
- outstanding payments;
- waived payments;
- refunds;
- prescription vs dispensing.

Provide filters such as:

`Date | Medicine | Category | Supplier | Staff | Department | Payment Status | Facility | Other Relevant Dimensions`

---



## PHASE 9 — Reporting & Analytics Framework



### Step 28 — Implement Role- and Permission-Based Reporting & Analytics

Build reporting and analytics as a centralized framework driven by the authenticated user's permissions and scope.

The system must support **zero, one, two, or many analytics/reporting tabs** depending on the user's authorized capabilities.

Examples:

**Tenant Administrator**

May see tabs such as:

`Facilities | Finance | Clinical | HR | Pharmacy | Laboratory | Radiology | Theatre | Inventory | Other Authorized Areas`

**Department/Service User**

May see only the reporting areas relevant to their role.

**Single-Scope User**

May have no visible tab navigation and instead see the reports/analytics for their authorized scope directly.

The reporting layer must therefore support:

`User → Roles → Permissions → Scope → Available Reports/Analytics`

---



### Step 29 — Define Analytics Tab Selection & Default View

When multiple tabs are available, the default tab should be the one most relevant to the user's **basic/primary role**.

For example:

- Doctor → Clinical;
- Pharmacist → Pharmacy;
- Accountant/Billing User → Finance;
- HR User → HR;
- Facility Administrator → Facility/Operations;
- Tenant Administrator → appropriate administrative overview.

Where the user has only one reporting scope, the interface should avoid unnecessary tab navigation.

Where the user has no authorized reporting/analytics access, the analytics section should display no unauthorized content.

---



### Step 30 — Implement Searchable, Collapsible Reporting Sections

Reports and analytics within each tab should be organized into logical, collapsible sections.

For example, **Finance** could contain:

`Revenue`
`Payments`
`Outstanding Balances`
`Refunds`
`Waivers`
`Expenses`
`Financial Performance`

Each section should support:

- expand/collapse;
- search;
- permission-based visibility;
- relevant filters;
- report availability;
- consistent naming;
- responsive presentation.

Users should be able to quickly find a report without scrolling through a long unstructured list.

---



### Step 31 — Implement Reporting Scope & Data Security

Every report and analytic query must automatically enforce the user's authorized scope.

Examples:

`Tenant Admin → Tenant-wide data`

`Facility Admin → Facility-level data`

`Department User → Department data`

`Service User → Authorized service data`

No frontend filter or URL parameter should be capable of bypassing backend scope restrictions.

---



### Step 32 — Implement Standard Reporting Dimensions

Where applicable, reports should support common filters:

`Date Range | Tenant | Facility | Department | Staff | Service | Patient | Status | Payment Method | Category | Supplier | Other Relevant Dimensions`

Reports should support appropriate combinations of filters without creating inconsistent or contradictory results.

---



### Step 33 — Implement Core Cross-System Analytics

After individual module analytics are working, create higher-level analytics combining trusted data from:

- facilities;
- clinical;
- pharmacy;
- laboratory;
- radiology;
- theatre;
- finance;
- HR;
- inventory;
- procurement;
- patient activity.

Ensure that analytics use consistent definitions for metrics such as:

- revenue;
- outstanding balance;
- service volume;
- patient volume;
- dispensing volume;
- stock value;
- refunds;
- waivers;
- staff activity.

---



### Step 34 — Implement Report Export & Print Integration

Reporting should support appropriate:

- on-screen viewing;
- print;
- PDF;
- Excel/CSV export.

Exports must respect the exact same:

- permissions;
- tenant boundaries;
- facility boundaries;
- filters;
- report scope.

---



## PHASE 10 — Excel Data Exchange



### Step 35 — Design the Import/Update/Export Data Model

Before generating Excel templates, map application entities and their relationships.

Examples:

- medicines;
- suppliers;
- patients;
- users;
- roles;
- permissions;
- diagnoses;
- laboratory tests;
- laboratory panels;
- radiology;
- theatre;
- departments;
- consultations;
- sales;
- purchases;
- stock;
- other master data.

---



### Step 36 — Create Official Excel Templates

Each dataset should define:

- worksheet;
- column names;
- field definitions;
- required/optional status;
- data types;
- allowed values;
- IDs;
- relationship fields;
- validation rules;
- example rows where useful.

Templates should be versioned so future changes do not silently break existing imports.

---



### Step 37 — Implement Safe Import Validation

Never insert uploaded Excel data directly into production records.

Use:

`Upload → Validate → Preview → Show Errors → Confirm → Import`

Support:

- accept all valid rows;
- reject all invalid rows;
- select specific valid rows;
- correct and revalidate failed rows;
- merge where applicable.

Provide row-level errors such as:

`Row 24: Supplier ID does not exist`

`Row 31: Invalid date`

`Row 42: Duplicate Medicine ID`

---



### Step 38 — Implement Update/Upsert

Use reliable unique identifiers so imports can:

- add new records;
- update existing records;
- merge supported records;
- prevent duplicates;
- report conflicts.

---



## PHASE 11 — Printouts & PDF



### Step 39 — Uncheck Internal Information From Default Printouts

Keep internal information available but unchecked by default.

Examples:

- facility ID;
- facility type;
- tenant/internal identifiers;
- other internal administrative fields.

The user may manually enable them when required.

---



### Step 40 — Fix Logo Print Layout

Increase padding between:

`Logo ↔ Border`

The logo must remain correctly contained regardless of its dimensions or aspect ratio.

---



### Step 41 — Implement Consistent PDF Naming

Default existing-patient filename:

`[patient-first-name]-[patient-id]-[order-or-encounter-id].pdf`

Example:

`John-PAT00125-ORD00452.pdf`

When information is missing, use the best available combination.

Sanitize unsupported filename characters and prevent duplicate-name collisions where necessary.

---



## PHASE 12 — Client Communication



### Step 42 — Implement Automated Appreciation Messages

Support configurable notifications through:

- WhatsApp;
- SMS;
- Email.

Example trigger:

`Service Completed → Appreciation Message`

Messages may be dynamically generated using approved templates and service context.

Example:

> Thank you for choosing [Facility Name]. We wish you a quick recovery.

Maintain communication logs containing:

- recipient;
- channel;
- template;
- date/time;
- delivery status;
- failure status;
- originating service/event.

Respect communication preferences, consent requirements, and opt-outs.

---



## PHASE 13 — Performance Optimization

**Performance optimization should begin only after core correctness, data integrity, authorization, and workflow behavior are stable.**

### Step 43 — Profile Slow Screens

Measure actual performance before changing architecture.

Profile:

- application startup;
- routing;
- modal opening;
- tables;
- forms;
- API calls;
- database queries;
- report generation;
- analytics loading.

Record actual timings.

---



### Step 44 — Optimize Backend/API

Investigate:

- duplicate API calls;
- N+1 queries;
- missing indexes;
- oversized responses;
- unnecessary joins;
- repeated configuration queries;
- expensive report/analytics queries;
- inefficient pagination.

---



### Step 45 — Optimize Frontend

Implement where justified:

- lazy loading;
- caching;
- memoization;
- component optimization;
- table virtualization;
- pagination;
- deferred loading;
- asynchronous loading of secondary modal information.

A modal should open promptly while non-critical secondary information loads asynchronously where practical.

---



### Step 46 — Re-test Performance

Compare:

`Before vs After`

for:

- application startup;
- route changes;
- facility dialog opening;
- staff dialog opening;
- pharmacy;
- billing;
- reporting/analytics;
- large tables.

---



## PHASE 14 — End-to-End Integration Testing



### Step 47 — Test Complete Facility Journeys

Do not test features only in isolation.

#### New Facility

`Create Tenant → Create Facility → Configure Presets → Create Users → Assign Roles → Login`

#### Consultation

`Login → Patient → Consultation → Payment/Pending → Complete`

#### Pharmacy

`Prescription → Pharmacy → Dispensing → Payment → Receipt`

#### Laboratory

`Order → Payment/Pending → Sample → Result → Completion`

#### Refund

`Transaction → Refund Request → Approval → Refund`

#### Staff

`Create Staff → Assign Role → Login → Perform Activity → Receive Payment`

#### Reporting

`Login → Resolve Roles/Permissions → Resolve Scope → Display Authorized Analytics Tabs → Filter → View Report → Export`

---



## PHASE 15 — Security, Audit & Regression



### Step 48 — Verify Backend Authorization

Every sensitive action must be secured at the API/backend level.

Test unauthorized access to:

- payments;
- refunds;
- waivers;
- roles;
- permissions;
- users;
- facility configuration;
- tenant data;
- reports;
- analytics;
- exports.

---



### Step 49 — Verify Audit Trails

Important actions should record:

`Who | What | When | Where | Before | After | Reference`

At minimum, audit:

- payments;
- refunds;
- waivers;
- dispensing;
- role changes;
- permission changes;
- user management;
- imports;
- exports;
- configuration changes;
- sensitive report access where required.

---



### Step 50 — Full Regression Test

Test the complete application across:

- authentication;
- registration;
- persistent sessions;
- tenant creation;
- tenant isolation;
- facility creation;
- patient management;
- clinical workflows;
- pharmacy;
- laboratory;
- radiology;
- theatre;
- billing;
- payments;
- waivers;
- refunds;
- reporting;
- analytics;
- printing;
- PDF generation;
- staff management;
- roles/permissions;
- Excel import/export;
- communication;
- security;
- audit trails.



### Final Release Gate

Release only when all of the following are confirmed:

`Correctness → Data Isolation → Authorization → Workflow Integrity → Reporting/Analytics → Performance → Security → Regression`

No performance optimization or UI enhancement should be considered complete if it compromises tenant isolation, authorization, financial integrity, clinical safety, auditability, or reporting accuracy.