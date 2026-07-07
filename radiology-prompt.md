# Radiology — Configuration, Requests & Delivery: Review, Fixes, and Web Test Coverage

## Context
The **Radiology** module exposes a **Radiology Configuration** view (configure the radiology test catalog and attach prices per facility) and a **Radiology Request** workflow (order tests and process their delivery). Review both end to end and bring them to full, production-quality working order across frontend and backend. Prices are **facility-specific**, and every action must reflect in the UI in **real time with no manual refresh**.

## Functional requirements
All actions must be fully wired on **frontend and backend**, persist correctly, and reflect in the UI in **real time with no delay** across every screen that consumes radiology data:

- **Configure tests:** Authorized users can create/enable radiology tests for a given facility and attach **facility-specific prices**.
- **Edit / disable tests & prices:** Verify editing a test, updating its price, and disabling a test persist and propagate in real time.
- **Request / order tests:** The request workflow works end to end — authorized roles can view enabled tests and place requests using the price specific to that facility.
- **Delivery request flow:** The delivery/result flow works correctly wherever it is used and applies the correct facility-specific price.
- **Real-time sync:** Any edit, request, result, or action reflects instantly across the entire UI wherever radiology tests, results, or procedures are shown.

## Access control
- **Radiology Configuration** and all its settings must be accessible to **radiologists, facility admins, tenant admins, and platform (super) admins**.
- The **test-requesting** and **delivery** workflows must be accessible to all relevant clinicians and authorized roles.
- Verify gating on both frontend (route/UI) and backend (authorization).

## Testing (web platform only)
- Add and/or update **unit, integration, and E2E** tests using **Flutter's built-in testing tools** and **Patrol**, covering: configuring/enabling a test with a facility-specific price (frontend + backend), price edit and disable, global/real-time visibility of configured tests, the request/ordering workflow, the delivery request flow with correct facility-specific pricing, cross-screen real-time sync, and role-based access for all listed roles.
- Run the tests **exclusively on the web platform**.
- **Resolve every applicable test failure until all web tests pass.**

## Constraints
- Modify only application/test code required for the above; maximize code reuse.
- Keep the UI uniform and fully responsive on mobile, tablet, and desktop.
- Follow existing project conventions and applicable `.cursor` rules.
