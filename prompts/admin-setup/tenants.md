# Implement and refine tenant creation — `/admin/setup?section=tenants`

## Objective

Implement a complete, responsive, and secure tenant-creation workflow in **Admin Setup → Tenants**. Improve the create/edit tenant dialog and add a transparent duplicate-detection step before a new tenant is created.

Use the existing architecture, shared components, localization system, access policies, API conventions, and design patterns. Do not create a parallel implementation when an existing tenant workflow can be extended.

## Access and scope

- The Tenants tab is available only to platform administrators and tenant administrators.
- Platform administrators can:
  - View all tenants.
  - Create tenants.
  - Edit tenants.
  - Use the existing delete, restore, and permanent-delete actions when authorized.
- Tenant administrators can:
  - View only the tenant to which they belong.
  - Edit that tenant when authorized.
  - Never create, delete, restore, or permanently delete a tenant.
- Enforce these rules in both the frontend and backend. Do not rely on hidden UI controls as authorization.
- Keep the current platform-list and scoped-tenant experiences described in `screens/admin-setup/tenants.md`.

## Add tenant action

- Show **Add tenant** only when the current user is authorized to create tenants.
- Support both the tenant-list toolbar action and the empty-state primary action.
- Disable the action while the tenant list is loading or while an equivalent create action is already in progress.
- Open the existing tenant profile dialog in a clear **Create tenant** mode.

## Create/edit tenant dialog

The dialog must support these fields:

- Tenant name.
- Slug.
- Active status.
- Contact name.
- Contact phone number.
- Contact email address.
- Default currency.
- Default consultation fee.

Requirements:

- Use appropriate field types, labels, helper text, validation, keyboard types, and input formatting.
- Normalize values safely. Validate the slug, email address, phone number, currency, and non-negative consultation fee on both client and server.
- Preserve user-entered values when validation or duplicate checking fails.
- On larger screens, arrange related fields into balanced multi-column rows instead of stretching every input across the full dialog width.
- On narrow screens, collapse cleanly to one column without clipping, overflow, or inaccessible actions.
- Redesign the active-status control using the shared switch/toggle pattern with a clear label and state description. It must remain accessible by keyboard and screen reader.
- Use localized copy throughout.
- Show in-button loading feedback during checks and saves, prevent duplicate submissions, surface actionable errors, and close the dialog only after a successful save.
- Keep create and edit behavior explicit. Duplicate detection applies to creation and must not interfere with ordinary edits to the current tenant.

## Duplicate and similarity check

Before final creation, check the proposed tenant against existing non-permanently-deleted tenants.

### Comparison behavior

- Perform the authoritative comparison on the backend so it cannot be bypassed by calling the create endpoint directly.
- Normalize comparable values before scoring, including case, surrounding whitespace, punctuation where appropriate, phone formatting, email casing, currency codes, and slug format.
- Compare every relevant submitted field individually:
  - Tenant name.
  - Slug.
  - Contact name.
  - Contact phone number.
  - Contact email address.
  - Default currency.
  - Default consultation fee.
- Give each field a clearly defined similarity score and calculate a deterministic aggregate score.
- Weight identity fields such as tenant name, slug, email, and phone more strongly than configuration fields such as currency and consultation fee.
- Return only the strongest relevant candidates, their aggregate scores, and a per-field comparison breakdown. Avoid exposing unrelated sensitive tenant data.
- Exact unique-field conflicts, such as an existing slug that cannot legally be reused, must remain hard validation errors and cannot be overridden.

### Confirmation experience

- If no meaningful match is found, continue to creation without adding an unnecessary confirmation step.
- If one or more possible matches are found, show a review step before creation.
- For every candidate, display:
  - The existing tenant identity.
  - The aggregate similarity score.
  - A field-by-field comparison with matched, partially matched, and different values clearly identified.
- Allow the platform administrator to:
  - Cancel and return to editing without losing entered values.
  - Open or select the existing tenant instead of creating a duplicate.
  - Explicitly choose **Create anyway** when no hard uniqueness conflict exists.
- Creating despite a warning must require an intentional confirmation and must be auditable. Do not treat a stale client-side check as authorization to create.
- Re-run or atomically validate the comparison during final submission to avoid race conditions between checking and saving.

## Data and UI synchronization

- Persist all supported tenant fields through the real backend and database; do not mock the workflow.
- Return the created tenant using the established API response shape.
- Update the tenant list immediately after creation using the project’s smallest typed state patch or refresh plan.
- Publish and consume the appropriate scoped realtime event so other authorized sessions receive the new or updated tenant.
- Preserve pagination, searching, current selection, loading states, and soft-delete behavior.
- If a schema change is necessary, add and apply a Prisma migration rather than editing the schema alone.

## Verification

- Add or update backend tests for authorization, validation, similarity scoring, exact conflicts, override behavior, race-safe final creation, and tenant scoping.
- Add or update frontend tests for role visibility, responsive layout, field validation, loading/error states, duplicate review, returning to edit, selecting an existing tenant, and confirmed creation.
- Verify the workflow on mobile, tablet, and desktop breakpoints.
- Run the relevant formatter, analyzer/linter, and focused test suites, and report any unrelated pre-existing failures separately.

## Acceptance criteria

- A platform administrator can create a valid tenant end to end.
- A tenant administrator cannot access tenant creation through either the UI or API and can view/edit only their own tenant.
- The dialog is well-proportioned on large screens and usable without overflow on narrow screens.
- The active-status control is visually consistent and accessible.
- Potential duplicates are scored per field and reviewed before creation.
- The user can return to editing, use an existing tenant, or intentionally create anyway when permitted.
- Exact uniqueness conflicts cannot be overridden.
- Successful mutations update the acting UI immediately and synchronize to other authorized sessions.
- All changed behavior is localized, tested, and compliant with the repository’s loading, responsive, realtime, migration, and access-control rules.