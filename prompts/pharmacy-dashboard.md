# Pharmacy Dashboard: Quick Actions and Denser Home Layout

Align the pharmacist home Quick actions with real destinations (new-orders queue, create-order dialog, single stock entry) and tighten home section spacing/padding—without changing KPI cards, Most sold drugs, or Order status mix beyond shared layout density.

## Context

**Current behavior (codebase)**

- Pharmacist Quick actions (max 4): `dispense_medication` labeled **Dispense medication** → `/pharmacy?section=orders`; `record_pharmacy_sale` labeled **Record pharmacy sale** → `/pharmacy?section=sales`; `receive_pharmacy_stock` and `adjust_pharmacy_stock` both → `/pharmacy?section=inventory` (duplicate targets).
- Walk-in create flow already exists: `showPharmacyWalkInOrderDialog` / `PharmacyWalkInOrderDialog` (pharmacy write gated). It picks an **existing** patient and line items; it does not yet expose a clear existing / new / anonymous patient mode, and it is not wired as the dashboard “Record pharmacy sale” action.
- Clinical/OPD medication ordering elsewhere must be reused for drug lines and validation where possible—do not invent a second pharmaceuticals picker stack.
- Home shell (`RoleDashboardScaffold`) uses large inter-section gaps (`spacing.xl`). Chart/section panels often use spacious content density; pharmacist home feels padded relative to the intended denser dashboard.

**Intended behavior**

- **New orders**: rename Dispense medication; navigate to the pharmacy new/queue orders surface (same destination the current dispense action already uses).
- **Create order** (rename Record pharmacy sale appropriately): open a create-order dialog supporting **existing patient**, **new patient**, and **anonymous (walk-in) pharmacy order**. Anonymous orders are pharmacy-module only (pharmacists / pharmacy write). Reuse the clinical pharmaceuticals ordering procedure for lines; extend walk-in for anonymous when patient is omitted.
- **Stock**: one Quick action that covers receive and adjust (single inventory entry point).
- **Density**: reduce gap between home sections and reduce inner content padding for dashboard sections (shared shell/section tokens), keeping hierarchy readable on mobile/tablet/desktop and light/dark.

**Definitions**

- *New orders*: pharmacy desk section for newly queued / ready-to-work orders (today’s `section=orders` / queue equivalent—keep the working route the dispense action already uses).
- *Create order*: dialog that creates a pharmacy order for an existing patient, a newly registered patient, or an anonymous walk-in (no patient record), then syncs pharmacy/home state.
- *Anonymous pharmacy order*: order without a linked patient; visible/creatable only with pharmacy write (and pharmacy module entitlement).
- *Stock action*: single Quick action opening pharmacy inventory where receive and adjust already live.

## Requirements

1. Rename `dispense_medication` label to **New orders** (keep id unless a rename is required for inventory/tests). Keep navigation to the pharmacy new-orders/queue section; unauthorized users must not see the action.
2. Replace **Record pharmacy sale** with a **Create order** (or equivalent clear label) Quick action that opens the create-order dialog on the pharmacist home (and remains available where pharmacy already opens walk-in). Support existing patient, new patient, and anonymous walk-in. Reuse clinical pharmaceuticals line UX/contracts via the existing pharmacy walk-in / drug-picker path; extend for anonymous (patient optional) without a parallel order API. Gate on `pharmacy:write` (+ pharmacy module); hide when unauthorized. On success: close dialog, refresh pharmacy/home data, show standard success feedback; validation/error/forbidden use existing patterns.
3. Merge `receive_pharmacy_stock` and `adjust_pharmacy_stock` into **one** stock Quick action (single label/icon/route to inventory). Remove the duplicate from the pharmacist quick-action list so max four slots stay coherent (expect three actions after merge unless product adds another).
4. Reduce inter-section spacing on the home role dashboard scaffold and reduce section content padding for titled dashboard panels (theme tokens; no hard-coded px). Apply denser layout without clipping filters, charts, or Quick actions on narrow widths; preserve light/dark.
5. Do not change KPI strip, Most sold defaults/controls, or Order status mix behavior except incidental shared density from R4.

## Constraints

- Scope: pharmacist Quick actions + create-order/anonymous walk-in wiring + home section density.
- Reuse `PharmacyWalkInOrderDialog` / pharmacy workspace create path, existing inventory section, home action catalog, permissions, and sync—no new analytics or parallel pharmaceuticals stack.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.
- Anonymous create must remain unavailable outside pharmacy write/module; no “no access” placeholders for missing actions.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Pharmacist sees **New orders**; tap opens pharmacy new-orders/queue; action absent without write/module. | R1 |
| A2 | **Create order** opens dialog with existing / new / anonymous paths; success syncs; unauthorized UI absent; clinical-style drug lines reused. | R2 |
| A3 | One stock Quick action to inventory; receive+adjust duplicates gone from the strip. | R3 |
| A4 | Home section gaps and section content padding are visibly tighter; no overflow on mobile/desktop; light/dark OK. | R4 |
| A5 | KPI strip, Most sold, and Order status mix behavior unchanged aside from shared density. | R5 |

## Relevant Files

- `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`
- `frontend/lib/features/home/domain/entities/home_dashboard_billing_inventory.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_walk_in_order_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- `frontend/lib/shared/dashboard/role_dashboard_scaffold.dart`
- `frontend/lib/shared/components/app_collapsible_section.dart` / `app_content_panel.dart` (section padding)
- Tests: home quick-action labels/routes; walk-in existing/new/anonymous; stock action uniqueness; layout density smoke

## Verification

- Widget/unit: New orders label+route; Create order opens dialog; anonymous create allowed only with pharmacy write; stock actions merged; unauthorized actions absent.
- Integration: create order (existing / new / anonymous) refreshes pharmacy/home; inventory action lands on stock section.
- Manual pharmacist: three coherent Quick actions; denser section spacing/padding; light/dark; mobile and desktop without clip/overflow.
