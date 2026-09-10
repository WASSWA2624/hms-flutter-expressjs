# Chronological Application Fix & Improvement Plan

# PHASE 1 — Fix Authentication and Session Stability

## Step 1 — Fix the Login Password Field

Investigate why the password field sometimes becomes unable to receive input.
Check:
* component lifecycle;
* focus handling;
* disabled/loading states;
* overlays;
* form validation;
* rerendering;
* browser autofill;
* event handlers;
* authentication state initialization.
**Acceptance test:**
Open login page repeatedly, enter username/password, submit, fail login, retry, navigate away/back, and confirm the password field always works without page refresh.
---

## Step 2 — Fix Registration False Errors
Trace the complete registration transaction:
`Registration Form → API → User Creation → Tenant/Facility Creation → Email Verification → Response`
Separate the following states:
* registration failed;
* account successfully created;
* verification email successfully sent;
* account created but email delayed/failed;
* request timed out while backend operation actually succeeded.
Do not allow the frontend to display "connection taking too long" when the backend has already successfully created the account.Also prevent duplicate accounts when a user retries registration after a timeout.
**Acceptance test:**
Register a new account under slow-network conditions and verify that the final UI matches the actual backend result.
---

## Step 3 — Implement Permanent/Persistent Login
Replace fragile session handling with proper persistent authentication.
Implement:
* persistent token/session storage;
* automatic token refresh;
* session restoration during application startup;
* graceful recovery from expired access tokens;
* prevention of unexpected logout during active workflows.
Test specifically:
`Login → Dispense → Wait → Navigate → Close App → Reopen App → Continue`
The user should remain authenticated until manually logging out, subject to any explicitly configured security policy.
**Acceptance test:**
Close and reopen the application several times and confirm the session is automatically restored.
---

# PHASE 2 — Fix Tenant and Data Isolation

This is the most important data-integrity phase.

## Step 4 — Audit New-Tenant Data Creation
Trace exactly what happens when a tenant/facility is created.
Identify every record automatically inserted.
Classify each record as:

### Allowed initial configuration

Examples:

* Lab tests
* Lab panels
* Radiology procedures
* Theatre procedures
* Clinical diagnoses
* Currencies
* Default Consultation
* Pharmacy/master configuration
* Units
* Departments
* Default user roles (these are globally accessible to the tenant/facility)
* Other approved presets

### Forbidden initial data
Examples:
* Patients
* Patient demographics
* Visits
* Consultations
* Prescriptions
* Lab orders
* Radiology orders
* Bills
* Payments
* Invoices
* Dispensing transactions
* Other patient-linked records
---

## Step 5 — Remove Patient Data From Tenant Initialization
Change tenant creation so that it creates **zero patient/transactional data**.
A new tenant must start with:
`Configuration + Presets + Empty Operational Data`
not:
`Configuration + Presets + Patient Data`
Test using a completely new tenant.
**Acceptance test:**
Immediately after tenant creation:
* Patients = 0
* Visits = 0
* Orders = 0
* Prescriptions = 0
* Bills = 0
* Payments = 0
* Other patient-linked records = 0
---

## Step 6 — Implement Proper Platform Presets
Create a clear distinction between:
**Global Platform Presets**
and
**Tenant/Facility Configuration**
Global presets are available to authorized administrators/users but cannot be modified or deleted by ordinary adminstrators except platform administrators.
Tenant administrators should be able to:
* view available presets;
* activate/select presets;
* add them to their facility;
* customize where permitted;
* create facility-specific entries.
Do this consistently for:
* Laboratory
* Radiology
* Theatre
* Clinical diagnoses
* Currencies
* Consultations
* Pharmacy
* Departments
* Other master data.
---

## Step 7 — Test Tenant Isolation
Create:
`Tenant A`
and
`Tenant B`
Then verify that:
* patients created in A cannot appear in B;
* facility data from A cannot appear in B;
* transactions from A cannot appear in B;
* configuration changes intended only for A do not accidentally modify B.
Perform the test at both:
* UI level;
* API/backend/database level.
**Do not proceed until this is confirmed.**
---

# PHASE 3 — Fix Users, Roles and Permissions
This phase should come before payment authorization because payment collection depends on reliable permissions.

## Step 8 — Stabilize User Creation
Fix the existing user-creation issues first.
Test:
* create user;
* assign facility;
* assign role;
* activate/deactivate user;
* edit user;
* reset credentials;
* login using created user.
Ensure errors returned by the backend are properly shown in the UI.
---

## Step 9 — Default User Roles
Ensure that all default user roles are: 
* global;
* read-only;
* cannot be deleted;
* cannot be modified by tenants;
* authorized administrators can assign them.
---

## Step 10 — Creating Custom User Roles
Support three creation methods:
### Method A — Build from scratch
Select individual permissions.
### Method B — Inherit and extend
Start from an existing role and add permissions.
Example:
`Nurse → Nurse + all/selected Pharmacy permissions`

### Method C — Combine roles
Combine two or more roles.
Example:
`Doctor + Administrator`
Result:
`Union of Doctor permissions + Administrator permissions`
The source roles must remain unchanged.
---

## Step 11 — Implement Role Hierarchy and Privilege Protection
A user must not be able to grant permissions that exceed their own authority.
Implement:
`Platform Admin → Facility Admin → Superior Staff → Staff`
subject to the actual organizational model.
Backend authorization must enforce this, not just the frontend.
---

# PHASE 4 — Fix Core Billing and Payment Logic

## Step 12 — Remove Pending Payment Blocking
This should be a major architectural change.
Change:
`Payment Pending → Block Service`
to:
`Payment Pending → Service Allowed + Payment Flag Created`
A pending transaction must never unnecessarily stop:
* consultation;
* prescription;
* dispensing;
* lab;
* Admission;
* radiology;
* theatre;
* other services.
---

## Step 13 — Implement Payment Waivers
Authorized users should be able to waive an outstanding payment.
When waived:
* outstanding balance becomes 0;
* transaction is financially settled;
* waiver is recorded;
* authorizing user is recorded;
* reason is recorded. This is required;
* audit trail is preserved.
Reports must distinguish:
`Paid | Pending | Partially Paid | Waived | Refunded | Cancelled`
---

## Step 14 — Allow Performing Staff to Receive Payment
Once permission management and billing logic are stable, allow authorized staff to collect payment for activities they perform.
Example:
`Doctor → Consultation → Bill → Receive Payment`
or
`Pharmacist → Dispense → Bill → Receive Payment`
or
`Lab Staff → Lab Order → Bill → Receive Payment`
Billing must record:
* patient;
* transaction;
* service;
* amount;
* payment method;
* receiving staff;
* date/time;
* reference;
* facility;
* tenant.
Provide a separate permission such as:
`Can Receive Payments`
rather than automatically giving payment authority to everyone who performs a service.
---

## Step 15 — Fix Refund Approval
Provide a separate permission such as:
`Can Approve Refund`.
Trace the refund workflow from:
`Refund Request → Authorization → Approval → Financial Transaction → Status Update`
Fix whichever layer is failing.
Test:
* full refund;
* partial refund;
* authorized approver;
* unauthorized user;
* already processed refund;
* failed refund.
---

# PHASE 5 — Fix Clinical Workflow Dependencies
## Step 16 — Remove Unnecessary Clinical Blocking
Review all clinical workflow dependencies.
Principle:
> A clinical action should not block another action unless the dependency is genuinely necessary.

For eaxample, prescribing must not depend on triage completion.

Review similar dependencies for:

* consultation;
* prescription;
* laboratory;
* radiology;
* procedures;
* pharmacy;
* vital signs;
* clinical notes;
* diagnoses;
* referal;
* follow up;
* discharge; 
* admission; etc.
Do not blindly remove legitimate safety constraints; remove only unnecessary workflow restrictions. The goal is to ensure maximum flexibility in petient flow.
---

# PHASE 6 — Facility Management
## Step 17 — Fix Facility Tenant Display
Investigate the facility → tenant relationship.
Correct:
**Tenant: Not available**
to the actual associated tenant.
Verify the relationship at API/database level rather than merely patching the UI.
---

## Step 18 — Fix Facility Logo Rendering
Trace:
`Stored Logo → API → Facility Data → Frontend → Image Component`
Correct:
* URL/path;
* storage access;
* API response;
* permissions;
* image loading;
* tenant/facility relationship.
Test with different image formats and missing-logo scenarios.
---

## Step 19 — Fix Create Staff
In **Facility Details**:
`Create Staff → Existing Create Staff Dialog`
Reuse the existing component and workflow.
Ensure:
* dialog opens;
* facility context is correct;
* tenant context is correct;
* staff can be created;
* staff list refreshes automatically.
---

## Step 20 — Improve Staff List
Fix action-button spacing.
Then implement:
`Click Staff Row → Nested Staff Details Dialog`
Reuse existing Staff Details UI.
The nested dialog should preserve the underlying Facility Details state.
---

# PHASE 7 — Fix Shared UI Components
## Step 21 — Fix Phone Number + STT Duplication
Investigate the shared phone input.
Correct the state-update mechanism so STT produces one value rather than:
`+256... +256...`
Test:
* STT only;
* typing only;
* STT followed by typing;
* repeated STT;
* rerendering;
* component reopening.
Then verify the fix everywhere the shared component is used.
---

## Step 22 — Replace/Improve Country Selector Globally
Create one reusable country selector containing the complete supported country list.
Required:
* searchable;
* keyboard friendly;
* mobile friendly;
* complete dataset;
* consistent across the application.
Then replace the current Edit Facility selector and all duplicated implementations.
---

## Step 23 — Change Active Toggle to Checkbox
Under **Edit Facility**:
`Active → Checkbox`
Default:
`Checked`
Ensure the saved value maps correctly to the existing backend field.
---

# PHASE 8 — Improve Application Performance
Only after core correctness is restored, optimize performance.
## Step 24 — Profile Slow Screens
Identify which operations cause delays in:
* routing;
* modal opening;
* table loading;
* forms;
* API requests;
* database queries.
Measure actual timings instead of guessing.
---

## Step 25 — Optimize Backend/API
Look for:
* duplicate API calls;
* N+1 database queries;
* missing indexes;
* oversized responses;
* unnecessary joins;
* repeated configuration queries.
---

## Step 26 — Optimize Frontend
Implement where appropriate:
* lazy loading;
* caching;
* memoization;
* component optimization;
* table virtualization;
* pagination;
* deferred loading of secondary modal data.
A modal should preferably open immediately while secondary information loads asynchronously.
---

## Step 27 — Re-test Performance
Compare:
`Before vs After`
for:
* application startup;
* route changes;
* facility dialog opening;
* staff dialog opening;
* pharmacy screens;
* billing screens;
* large tables.
---

# PHASE 9 — Printouts and PDF
## Step 28 — Uncheck Internal Information From Default Printouts
Uncheck by default:
* facility ID;
* Facility type;
* tenant/internal details; etc.
Keep them available for printing but unchecked by default.
---

## Step 29 — Fix Logo Print Layout
Increase padding between:
`Logo ↔ Border`
Ensure the logo remains properly contained regardless of logo dimensions.
---

## Step 30 — Implement PDF Naming
Default existing-patient filename:
`[patient-first-namw]-[patient-id]-[order/encounter-id].pdf`
Example:
`John-PAT00125-ORD00452.pdf`
When information is missing, use the best available combination.
Sanitize characters that cannot be used in filenames.
---

# PHASE 10 — Pharmacy
## Step 31 — Simplify the Pharmacy Journey
Map the current process:
`Prescription → Verification → Selection → Quantity → Pricing → Billing → Payment → Dispensing → Completion`
Identify every unnecessary step - Maximize automation by internally hiding steps that can be completed without human intervation. The goal is to have as few steps as possible and as minimal human intervention as possible.
Then reduce clicks, repeated information entry and duplicate confirmations.
Do not remove:
* stock controls;
* financial controls;
* audit trail;
* prescription traceability.
---

## Step 32 — Implement Flexible Drug Strength
Under **Create Drug**, redesign Strength as a flexible structured field.
It must support:
### Single component
`500 mg`
### Multiple components
`Amoxicillin 500 mg + Clavulanic Acid 125 mg`
### Other combinations
Different units and component strengths should be supported where applicable.
Prefer a structured representation internally rather than forcing everything into one plain-text field.
The design should be extensible for future formulations.
This should also be smartly/intelligently automated to ensure its prevents room errors.
There should be support for custom drug strengths
---

## Step 33 — Build Pharmacy Analytics
Implement dashboards and reports covering:
* dispensing;
* sales;
* revenue;
* stock;
* purchases;
* suppliers;
* expiry;
* adjustments;
* returns;
* fast-moving medicines;
* slow-moving medicines;
* staff activity;
* outstanding payments;
* waived payments;
* refunds;
* prescription vs dispensing.
Add filters such as:
`Date | Medicine | Category | Supplier | Staff | Department | And more`
---

# PHASE 11 — Excel Data Exchange
## Step 34 — Design the Import/Update/Export Data Model
Before creating Excel files, map the application's entities and relationships.
Examples:
* Medicines
* Suppliers
* Patients
* Users
* Roles
* Permissions
* Diagnoses
* Lab Tests
* Lab Panels
* Radiology
* Theatre
* Departments
* Consultations
* Sales
* Purchases
* Stock
* Other master data
---

## Step 35 — Create Official Excel Templates
Each dataset should have:
* worksheet;
* column definitions;
* required/optional fields;
* data types;
* allowed values;
* IDs;
* relationship fields;
* example rows where useful.
---

## Step 36 — Implement Import Validation
Do not immediately insert Excel data into the database.
Use:
`Upload → Validate → Preview → Errors → Confirm → Import`. Support for merge, edit, reject/accept(all, selected)
Provide row-level errors.
Example:
`Row 24: Supplier ID does not exist`, `Invalid date`, etc
---

## Step 37 — Implement Update/Upsert
Use unique identifiers so users can:
* add new records;
* update existing records;
* avoid duplicates.
---

# PHASE 12 — Client Communication
## Step 38 — Implement Automated Appreciation Messages
Add configurable notifications through:
* WhatsApp;
* SMS;
* Email.
Example trigger:
`Service Completed → Appreciation Message`
Maintain communication logs with:
* recipient;
* channel;
* template;
* date/time;
* delivery status;
* failure status.
Respect communication preferences and opt-outs.
The communication might include information like: "Thank you for choosing [Facility name]. We wish you a quick recovery.", etc. The messages can be fabricated basing on the service trigger.
---

# PHASE 13 — Final Integration Testing
## Step 39 — Test End-to-End Facility Journeys
Do not test features only in isolation.
Test complete journeys such as:
### New Facility
`Create Tenant → Create Facility → Configure Presets → Create Users → Assign Roles → Login`
### Consultation
`Login → Patient → Consultation → Payment/Pending → Complete`
### Pharmacy
`Prescription → Pharmacy → Dispensing → Payment → Receipt`
### Laboratory
`Order → Payment/Pending → Sample → Result → Completion`
### Refund
`Transaction → Refund Request → Approval → Refund`
### Staff
`Create Staff → Assign Role → Login → Perform Activity → Receive Payment`
---

# PHASE 14 — Security, Audit and Regression Testing
## Step 40 — Verify Backend Authorization
Every sensitive action must be secured at the API/backend.
Test for unauthorized access to:
* payments;
* refunds;
* waivers;
* roles;
* permissions;
* users;
* facility configuration;
* tenant data.
---

## Step 41 — Verify Audit Trails
Ensure important actions record:
`Who | What | When | Where | Before | After | Reference`
especially for:
* payments;
* refunds;
* waivers;
* dispensing;
* role changes;
* permission changes;
* user management;
* imports.
---

## Step 42 — Full Regression Test
Test:
* authentication;
* registration;
* tenant creation;
* facility creation;
* patient management;
* clinical;
* pharmacy;
* laboratory;
* radiology;
* theatre;
* billing;
* reports;
* printing;
* staff management;
* roles/permissions;
* imports.
---
