# Feature: Facility-scoped radiology configuration (mirror lab flow)

## Goal

Implement a **radiology configuration flow that matches the existing lab configuration pattern** (see attached screenshots). Users who configure radiology for a facility should work from a **platform catalog** and enable only the procedures relevant to that facility—with facility-specific pricing—rather than rebuilding the catalog from scratch.

## Reference implementation

Use the lab configuration UX and architecture as the template:

1. **Lab Configurations** — tenant/facility scope selectors, facility offerings table (search, filters, edit/delete), **Enable test** action.
2. **Enable Lab Offering** — browse the platform catalog; items already offered show **Already offered**.
3. **Enable Test** — confirm selection and set **unit price** + currency before saving.

Mirror this three-step pattern for radiology procedures/tests.

## Entry point

From the radiology workspace overflow menu, **Configurations** opens the radiology configuration dialog (same placement and behavior as lab).

## Scope selection (first screen in dialog)

Behavior must match lab account/scope rules:

| User access | Behavior |
|-------------|----------|
| **Multi-tenant** (e.g. superadmin) | Show **Tenant** dropdown first; after tenant is selected, show **Facility** dropdown. |
| **Single-tenant** | Show **Facility** selector only (or pre-select when unambiguous). |

- Do not load or show facility offerings until both required scope fields are set.
- Show a context label such as: *“Configuring radiology catalog for {facility}.”*
- Reload the facility catalog whenever tenant or facility changes.

## Main dialog: Radiology Configurations

Once scope is ready, display the **facility’s enabled radiology procedures** in a searchable, filterable table.

**Required capabilities:**

- Search across procedure name, code, modality/category, and related metadata.
- **Laboratory-style filters** (adapted for radiology: modality, category, etc.).
- Table column settings (visibility).
- Row actions: **Edit** and **Delete** (remove from facility offerings).
- Primary action: **Enable procedure** (or equivalent label)—opens the platform catalog picker.

Columns should include at minimum: procedure name, code, category/modality, and **unit price** (facility currency).

## Enable offering flow (two dialogs)

### 1. Enable radiology offering (catalog picker)

- Lists **platform-level radiology catalog** items the user is allowed to configure.
- Same search + filter affordances as the main table.
- Rows already enabled for the selected facility show **Already offered** and are not selectable again.
- Selecting an available item opens the enable dialog.

### 2. Enable procedure (price confirmation)

- Show selected procedure summary (name, code, modality/category, units if applicable).
- Required **Unit price** field with currency selector (default facility/tenant currency).
- **Cancel** and **Enable procedure** actions.
- On success: close dialogs, refresh facility offerings, show success feedback.

## Edit existing offering

Editing a facility offering should allow updating facility-specific fields (at minimum **unit price** and offered/enabled state), consistent with lab’s configure/edit dialog—not re-creating the platform catalog item.

## Business rules

- **Ordering scope:** Clinicians and request workflows must only see radiology procedures **enabled for their facility**, with the configured facility price.
- **Catalog source:** Configurers browse the **platform catalog**; they do not author new global procedures in this flow.
- **Permissions:** Only users who can configure radiology for a facility may access the platform catalog picker and mutate facility offerings.
- **Parity:** Reuse lab patterns for scope resolution, API shape, loading/empty/error states, and dialog structure wherever possible.

## Acceptance criteria

- [ ] Configurations opens scope selectors before showing data (tenant → facility when applicable).
- [ ] Facility offerings table lists only procedures enabled for the selected facility.
- [ ] **Enable procedure** opens platform catalog picker with search, filters, and “Already offered” state.
- [ ] Enabling a procedure requires a valid unit price; saved price appears in the main table.
- [ ] Edit updates facility offering; delete removes it from the facility (not from platform catalog).
- [ ] Radiology ordering/request flows surface only the selected facility’s enabled procedures and prices.
