# Pharmacy — Catalog & Stock Dialog: Fixes, Feature Completion, and Web Test Coverage

## Context
The **Pharmacy** module exposes a **Catalog and Stock** dialog (opened from the Pharmacy screen) with four tabs: **Drugs**, **Formulary**, **Inventory**, and **Storage layout**. Review this dialog end to end and bring it to full, production-quality working order across both frontend and backend.

## Defects to fix
1. **Maximize by default.** The Catalog and Stock dialog opens un-maximized. Every dialog in the Diagnostics & Pharmacy (pharmacy) module — including this one and all nested dialogs (add/edit/delete forms, adjust-stock, room/shelf editors, etc.) — must open maximized by default.
2. **Layout overflow.** The dialog content overflows (e.g. "BOTTOM OVERFLOWED BY 40 PIXELS"). Fix all overflow so the layout is clean and fully responsive on mobile, tablet, and desktop, with consistent UI.

## Functional requirements
All create/edit/delete actions below must be fully wired on **frontend and backend**, persist correctly, and reflect in the UI in **real time with no delay** (no manual refresh):

- **Drugs tab:** Add drug, Edit drug, Delete drug.
- **Formulary tab:** Add formulary item, Edit formulary item, Delete formulary item.
- **Inventory tab:** Adjust stock and Clear stock.
- **Storage layout tab:** Add / Edit / Delete a room; within a room, Add / Edit / Delete a shelf.

## Access control
The Catalog and Stock dialog must be accessible to **every user with access to any pharmacy**, with full access granted to **pharmacists, facility admins, tenant admins, and super admins**. Verify this on both frontend (route/UI gating) and backend (authorization).

## Testing (web platform only)
- Add and/or update **unit, integration, E2E, and Patrol** tests covering all of the above: maximize-by-default behavior, overflow-free responsive layout, every add/edit/delete/adjust/clear action (frontend + backend), real-time UI updates, and role-based access for all four roles.
- Run the **entire** test suite **exclusively on the web platform**.
- **Resolve every applicable test failure until all web tests pass.**

## Constraints
- Maximize code reuse; keep the UI uniform and responsive across mobile, tablet, and desktop.
- Follow existing project conventions and applicable `.cursor` rules.
