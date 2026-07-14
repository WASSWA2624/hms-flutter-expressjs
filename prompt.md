# Application Improvement Requirements

The requirements are structured in a logical sequence, beginning with foundational improvements (security, authorization, reusable components, responsiveness), followed by feature modules, workflows, billing, reporting, and department-specific functionality. Each section can be implemented independently.

---

## 1. Authorization & Security

### Objectives

Build a secure authorization model that enforces access control across all parts of the application.

### Requirements

- Enforce both **RBAC (Role-Based Access Control)** and **ABAC (Attribute-Based Access Control)** throughout the app.
- Ensure authorization checks exist in both frontend and backend APIs.
- Users must never see, interact with, or even have visible any functionality (pages, buttons, menus, workflows, or data) unless authorized.
- Hide, rather than merely disable, features for unauthorized users.
- Immediately clear all user-specific cached state on logout or account switch.
- All dashboards, pages, and UI components must load only the currently authenticated user’s data.
- Prevent display of prior user information after switching users, even briefly.
- Eliminate any risk of stale/cached UI exposing sensitive patient or operational data.

---

## 2. Responsive Design & Design System

### Objectives

Establish a design system with consistent, reusable, responsive UI across the application.

### Requirements

- Design natively for **Mobile**, **Tablet**, and **Desktop** (not simple scaling).
- Fully optimize layouts for each form factor.
- Standardize typography, spacing, color, elevation, animation, and interaction paradigms.
- Minimize extraneous text by maximizing intuitive visual communication.
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
- Icons should enhance usability and uphold accessibility standards.
- Every reusable component must be fully responsive.

---

## 3. Shared Reusable Components

### Objectives

Develop high-utility reusable components as a priority, to drive UI/UX consistency and minimize duplication before feature modules are built.

### Requirements

Must include the following reusable components (not exhaustive):

- Patient Details
- Actions
- Clinical Results Preview
- Report Sections
- Status Badges
- Empty States
- Loading States
- Timeline Components
- Detail Cards
- Dialog Components

#### Core Reusable Component: Step Progress & Actions

Create a **reusable workflow/progress step component** that visualizes the current step, completed steps, upcoming steps, and available actions for all types of encounters, workflows, requests, and task progressions.  
- The component must support customizable steps, each with:
  - An appropriate icon and label.
  - Dynamic action labels such as: “Perform”, “Complete”, “Skip”, “Revert”, “Resume”, etc., intelligently reflecting what is allowed in the current context.
  - Action buttons for each actionable step.
  - Tooltip support: On hover, each action button displays a tooltip clearly explaining what action will be performed at that step.
  - If an action is disabled, the tooltip must explain the reason (e.g. permissions, prerequisites, or workflow constraints).
- Support clear differentiation between completed/active/pending/disabled steps.
- Make this component fully reusable throughout the application (e.g. for lab, radiology, admissions, appointments, billing, etc).

### General Requirements

- Modern, visually appealing, and responsive.
- Context-aware and fully configurable.
- Design for maximum reuse and extensibility.
- Remove duplicate code and legacy UI implementations.

### Patient Details Component

- Display only patient information relevant for the current workflow.
- Provide a persistent **Show More / Show Less** toggle:
  - **Show Less**: Patient Name, Patient ID, Age, Gender
  - **Show More**: All applicable patient/encounter information
- User’s toggle preference must persist across sessions and devices.

### Actions Component

- Must be RBAC and ABAC aware.
- Support loading, disabled, confirmation, contextual, asynchronous states.
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

---

## 4. Laboratory Module Improvements

### Requirements

- Automatically determine appropriate reference ranges for lab results by patient age and gender.
- Display only the relevant reference ranges in previews/printed reports.
- **Print Report** button enabled by default if printable results exist (not dependent on “Reset Selection” or other triggers).

---

## 5. Radiology Module & Workflow

### Objectives

Introduce a dedicated Radiology module with a full end-to-end workflow.

### Workflow

1. Request Created
2. Pending
3. In Progress
4. Procedure Completed
5. Awaiting Report
6. Report Submitted
7. Completed

### Requirements

- All new requests auto-populate the Radiology work queue.
- Provide a specialized workspace for radiographers/radiologists.
- Use the reusable Patient Details, Radiology Request, and Step Progress components.
- Support creation, editing, review, and submission of radiology reports.
- Workflow updates must synchronize in real-time.
- Display up-to-date workflow status to all authorized users everywhere in the application.

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

- Always use configured billing catalogue prices; never hardcode.
- Display all billable items for authorized billing users.
- Support billing, settlement, audit, reporting, and reconciliation.
- Prevent duplicate billing:
  - Never bill a consultation twice for a single encounter.
  - Prevent duplicate service charges unless explicitly allowed.

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

- **Reuse the existing report template** for all printable reports.
- Compose reports using shared, configurable sections and components for consistency.
- Avoid duplicate information or content.
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

- Allow user selection of sections to print (sections without data unselected by default).
- Print only selected sections.
- Chronological display.
- Clear headings.
- Printer-optimized, high-quality reports.
- Limit report printing to authorized RBAC/ABAC users.

---

## 8. Reception Module

### Objectives

Create a dedicated Reception module tailored for front-desk operations.

### Reception Responsibilities

Reception staff should be able to:

- Register patients
- Edit patient information
- Schedule/reschedule/cancel appointments
- Check in patients
- Start encounters
- Route patients
- View patient queues and appointments
- Check requested services, estimated charges, outstanding balances
- Advise on payment methods
- Capture:
  - Insurance information
  - Payment method
  - Cash payments
  - Card payments
  - Mobile Money
  - Other supported payment methods

### Authorization

Receptionists must **not**:

- Finalize, approve, adjust, waive, reverse, or complete billing transactions  
unless granted explicit billing permission.

Clearly separate billing guidance from billing operations and conceal unauthorized actions.

### Design Requirements

- Streamlined for high-volume workflows.
- Minimized navigation.
- Real-time display of queues, appointments, encounters, routing, and waiting status.
- Reuse all shared components, including the new step/progress component, for visual consistency.

---

## 9. General Application Consistency

### Objectives

Mandate that the application follows a unified, modular, and maintainable architecture and user experience.

### Requirements

- Use standardized, reusable components and business logic throughout.
- Continuously remove duplicate code and UI.
- Keep workflows and UI patterns consistent.
- Modularize architecture for maintainability.
- Synchronize UI, workflow, billing, and clinical results in real-time.
- Always prioritize reuse—reuse first, new implementation second.
- All new features must integrate with the overarching architecture, design system, authorization, reusable components, billing engine, and workflow step/progress components.
