# Application Improvement Requirements

The requirements below are arranged in a logical implementation sequence, starting with the foundational improvements (security, authorization, reusable components, responsiveness), followed by feature modules, workflows, billing, reporting, and department-specific functionality. Each section is self-contained so it can be implemented independently.

---

## 1. Authorization & Security

### Objectives

Implement a secure authorization model that consistently enforces access control throughout the application.

### Requirements

- Enforce both **RBAC (Role-Based Access Control)** and **ABAC (Attribute-Based Access Control)** across the entire application.
- Authorization must be enforced in both the frontend and backend APIs.
- Users must never see pages, buttons, menus, actions, workflows, or data they are not authorized to access.
- Hide unauthorized functionality instead of simply disabling it.
- Immediately clear all user-specific cached state during logout or account switching.
- Ensure dashboards, cached pages, and all UI components load only data belonging to the currently authenticated user.
- Prevent any previous user's information from being displayed, even momentarily, after another user signs in.
- Eliminate any possibility of exposing sensitive patient or operational data through stale UI state or cached data.

---

## 2. Responsive Design & Design System

### Objectives

Establish a consistent, responsive, reusable design system that will be used throughout the application.

### Requirements

- Design specifically for **Mobile**, **Tablet**, and **Desktop** devices.
- Optimize layouts for each screen size instead of scaling desktop layouts.
- Standardize typography, spacing, colors, elevations, animations, and interaction patterns.
- Minimize unnecessary text by using intuitive visual design.
- Establish a unified icon system.
- Use consistent icons for:
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
- Icons should improve usability while maintaining accessibility.
- Ensure every reusable component is fully responsive.

---

## 3. Shared Reusable Components

### Objectives

Create reusable UI components before implementing feature modules to maximize consistency and reduce duplication.

### Requirements

Implement reusable components including, but not limited to:

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

### General Requirements

- Modern, elegant, and responsive design.
- Context-aware.
- Fully configurable.
- Maximum reuse.
- Eliminate duplicated implementations.
- Remove obsolete code introduced by previous implementations.

### Patient Details Component

- Display only relevant patient information for the current workflow.
- Include a persistent **Show More / Show Less** toggle.

**Show Less**

- Patient Name
- Patient ID
- Age
- Gender

**Show More**

- Display all applicable patient information.

Persist the user's preference across sessions and devices.

### Actions Component

- RBAC/ABAC aware.
- Support loading, disabled, confirmation, contextual, and asynchronous states.
- Reuse across all forms, dialogs, detail pages, and workflows.

### Clinical Results Preview

Create reusable preview components for:

- Laboratory Results
- Radiology Reports
- Procedures
- Clinical Assessments
- Other clinical modules

Support:

- Inline preview
- Modal preview
- Full-screen preview

Display information chronologically and consistently across the application.

---

## 4. Laboratory Module Improvements

### Requirements

- Automatically determine laboratory reference ranges based on patient age and gender.
- Display only the applicable reference ranges in previews and printed reports.
- Enable the **Print Report** button by default whenever printable results exist.
- The button must never depend on clicking **Reset Selection**.

---

## 5. Radiology Module & Workflow

### Objectives

Implement a dedicated Radiology module with an end-to-end workflow.

### Workflow

1. Request Created
2. Pending
3. In Progress
4. Procedure Completed
5. Awaiting Report
6. Report Submitted
7. Completed

### Requirements

- Automatically add new requests to the Radiology work queue.
- Provide a dedicated workspace for radiographers and radiologists.
- Use reusable Patient Details and Radiology Request components.
- Allow report creation, editing, review, and submission.
- Synchronize workflow updates in real time.
- Display workflow status to all authorized users throughout the application.

---

## 6. Billing Engine Integration

### Objectives

Integrate billing seamlessly into every clinical workflow.

### Requirements

Automatically generate configured charges for every billable activity, including:

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

Additional requirements:

- Use only configured billing catalogue prices.
- Never hardcode charges.
- Display every billable item to authorized billing users.
- Support billing, settlement, auditing, reporting, and reconciliation.
- Prevent duplicate billing.
- Never bill consultation twice for one encounter.
- Never generate duplicate service charges unless explicitly permitted.

---

## 7. Patient Reporting & Printing

### Objectives

Implement a unified reporting and printing system for every department.

Supported departments include:

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

- **Reuse the existing report template** as the foundation for all printable reports.
- Reuse shared report components wherever possible to ensure consistency.
- Reports must never duplicate content or display the same clinical information more than once.
- Generate comprehensive patient reports using reusable report sections.

Support configurable sections including:

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

Additional requirements:

- Allow users to select which sections to print.
- Sections with no available data should not be selected by default.
- Print only selected sections.
- Display information chronologically.
- Use clear section headings.
- Produce printer-friendly, professional-quality reports.
- Restrict printing to authorized RBAC/ABAC users only.

---

## 8. Reception Module

### Objectives

Implement a dedicated Reception module optimized for front-desk operations.

### Reception Responsibilities

Receptionists should be able to:

- Register patients.
- Update patient information.
- Schedule appointments.
- Reschedule appointments.
- Cancel appointments.
- Check in patients.
- Start encounters.
- Route patients.
- View patient queues.
- View appointments.
- View requested services.
- View estimated charges.
- View outstanding balances.
- Guide patients regarding payment methods.
- Capture:
  - Insurance information
  - Payment method
  - Cash payments
  - Card payments
  - Mobile Money
  - Other supported payment methods

### Authorization

Receptionists must **not**:

- Finalize billing
- Approve billing
- Waive charges
- Reverse charges
- Adjust charges
- Complete billing transactions

unless they explicitly possess billing permissions.

Clearly separate billing guidance from billing operations.

Hide all unauthorized billing actions.

### Design Requirements

- Optimize for high-volume reception workflows.
- Minimize navigation.
- Display queues, appointments, encounters, routing, and waiting status in real time.
- Reuse all shared components to ensure consistency.

---

## 9. General Application Consistency

### Objectives

Ensure the entire application follows a unified architecture and user experience.

### Requirements

- Standardize reusable components throughout the application.
- Eliminate duplicated UI implementations.
- Eliminate duplicated business logic.
- Improve maintainability through modular architecture.
- Keep workflows consistent across all modules.
- Synchronize UI updates, workflow changes, billing updates, and clinical results in real time.
- Continuously remove obsolete code.
- Prioritize reuse before introducing new implementations.
- Ensure every newly implemented feature integrates seamlessly with the existing architecture, design system, authorization model, reusable components, and billing engine.

