# HR — Staff Compensation: Implementation, Fixes, and Web Test Coverage

## Context
The **HR** module exposes an **Update Compensation** dialog (opened for a staff member) with two tabs: **Pay structure** and **History**. Each staff member's pay structure is built from one or more **pay lines**, where each line has a **pay type** (e.g. Consultation fee, Management fee, Procedure), an optional **base rate** in a facility currency (e.g. UGX), an **Effective from** date (required), and an optional **Effective to** date. Review this dialog end to end and bring compensation to full, production-quality working order across frontend and backend.

## Defects to fix
1. **Bottom overflow.** The Update Compensation dialog overflows (e.g. "BOTTOM OVERFLOWED BY 71 PIXELS"), and the dialog does not open maximized. The dialog (and all nested add/edit/delete pay-line controls) must open **maximized by default** and be **overflow-free** and fully responsive on mobile, tablet, and desktop, with consistent UI.

## Functional requirements
All actions must be fully wired on **frontend and backend**, persist correctly, and reflect in the UI in **real time with no delay** (no manual refresh):

- **Assign compensation:** Assign one or more pay lines to a staff member (e.g. assign a consultation fee to Dr. Belinda Lim). A staff member may have **multiple compensation types** simultaneously, depending on the services they provide.
- **Pay lines:** Add, edit, and delete pay lines; each supports pay type, base rate + currency, Effective from (required), and Effective to (optional). Validate dates (effective-to must not precede effective-from) and rates.
- **History tab:** Persist and display the compensation change history for the staff member, reflecting every add/edit/delete.
- **Service-linked application:** The assigned compensation must be applied to the matching service — e.g. when a doctor assigned a **consultation fee** sees a patient at OPD as a consultation, that consultation fee is used for billing that service.
- **Availability from schedule:** Staff availability must derive from the **schedule attached** to the staff member, and integrate correctly with compensation/consultation workflows.

## Access control
- The **Update Compensation** dialog and pay-structure management must be accessible to **HR staff, facility admins, tenant admins, and platform (super) admins**.
- Verify gating on both frontend (route/UI) and backend (authorization).

## Testing (web platform only)
- Add and/or update **unit, integration, E2E, and Patrol** tests using **Flutter's built-in testing tools** and **Patrol**, covering: maximize-by-default and overflow-free responsive layout; add/edit/delete pay lines with validation (frontend + backend); multiple compensation types per staff member; real-time UI propagation; History tab persistence; service-linked fee application (consultation fee applied at OPD consultation); schedule-driven availability; and role-based access for all listed roles.
- Run the tests **exclusively on the web platform**.
- **Resolve every applicable test failure until all web tests pass.**

## Constraints
- Modify only application/test code required for the above; maximize code reuse.
- Keep the UI uniform and fully responsive on mobile, tablet, and desktop.
- Follow existing project conventions and applicable `.cursor` rules.
