# Laboratory — Configuration & Test Catalog: Review, Fixes, and Web Test Coverage

## Context
The **Laboratory** module exposes a **Laboratory Configuration** view (opened via "Lab config"). Review it end to end and bring it to full, production-quality working order across frontend and backend. Tests are **pre-configured**; the core workflow is **enabling a test** (set a price, then enable it) so it becomes available for ordering.

## Defects to fix
1. **Enable-test dialog icons.** On the enable-test dialog, add icons to both the **Cancel** and **Enable test** buttons, consistent with existing button/icon conventions.
2. **Global visibility of enabled tests.** When a test is enabled, it must immediately become visible to all relevant users **within that facility** — with **no manual refresh** (real-time propagation).

## Functional requirements
All actions must be fully wired on **frontend and backend**, persist correctly, and reflect in the UI in **real time with no delay**:

- **Enable test:** Set price and enable a pre-configured test; the enabled test (and its price) appears globally to relevant facility users in real time.
- **Disable / edit price:** Verify disabling a test and updating its price persist and propagate in real time.
- **Test ordering / requesting:** Confirm the request (order) workflow works end to end — clinicians and other authorized roles can view enabled tests and place requests, and all screens that consume lab data stay in sync in real time.

## Access control
- **Laboratory Configuration** and all its settings must be accessible to **lab technicians, facility admins, tenant admins, and platform (super) admins**.
- The **test-requesting** workflow must be accessible to all relevant clinicians and authorized roles.
- Verify gating on both frontend (route/UI) and backend (authorization).

## Testing (web platform only)
- Add and/or update **unit, integration, and E2E** tests using **Flutter's built-in testing tools** and **Patrol**, covering: enable-test dialog icons, enabling a test (price + enable, frontend + backend), global/real-time visibility of enabled tests, price edit and disable, the request/ordering workflow, cross-screen real-time sync, and role-based access for all listed roles.
- Run the tests **exclusively on the web platform**.
- **Resolve every applicable test failure until all web tests pass.**

## Constraints
- Modify only application/test code required for the above; maximize code reuse.
- Keep the UI uniform and fully responsive on mobile, tablet, and desktop.
- Follow existing project conventions and applicable `.cursor` rules.
