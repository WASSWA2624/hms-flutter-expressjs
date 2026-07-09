# Home Dashboard Quick Actions — Dialog UX & Role Permissions

## Context

Home dashboard quick actions (`create_tenant`, `create_facility`, `create_role`) open modal dialogs. The flows work, but dialog layout, shared components, validation, and role creation are incomplete. Align all three with existing `AppDialog` / shared patterns.

**Entry points**
- `homeInvokeAction` → `showTenantFacilityTenantFormDialog`, `showTenantFacilityFacilityFormDialog`, `showAccessAdminCreateRoleDialog`
- Forms live in `tenant_facility_setup_page.dart`; role dialog in `access_admin_dialogs.dart`

---

## 1. Create Tenant dialog

**Current issues (see screenshot):** Active toggle layout is inconsistent; Save sits inside scrollable form content.

**Requirements**
- Use shared `AppSwitchField` for the Active field (do not use a raw `Switch` / `SwitchListTile`).
- Move all action buttons (**Save tenant**, **Cancel**) into `AppDialog.actions` with `pinActionsToBottom: true` and `scrollable: true` so the footer stays fixed while the form scrolls.
- Save button: `AppButton.primary` with `Icons.save_outlined`.
- Cancel button: `AppButton.secondary` with a leading icon.
- Refactor `_SetupDetailDialog` / `_TenantProfileForm` (and facility form below) to support footer actions—prefer `showAppWorkspaceMutationDialog` or an equivalent shared pattern already used in `tenant_facility_management_dialogs.dart`.

---

## 2. Create Facility dialog

**Current issues (see screenshots):** Save is inside the form body; email is optional; logo upload is feature-local.

**Requirements**

### Dialog footer
- Same footer pattern as tenant: **Cancel** + **Save facility** pinned to `AppDialog` footer (`pinActionsToBottom: true`).
- Save uses `Icons.save_outlined`; footer must not scroll with form content.

### Validation
- **Email** is **required** (`AppEmailField` with `isRequired: true` and validation). Facilities need a contact email for communication and account workflows.

### Facility type
- Keep existing `AppSelectField<FacilitySetupType>` options: Hospital, Clinic, Lab, Pharmacy, Other (with icons).

### Logo upload — shared reusable component
- Extract `FacilityLogoUploadField` into `shared/components` as a generic image upload field (e.g. `AppImageUploadField`).
- Support **single-file** upload now; API/design should allow **multi-file** later without breaking callers.
- Preserve current behavior: square preview, JPG/PNG/WebP, 5 MB limit, choose/clear actions, pending-bytes preview.
- Replace facility-specific usage with the shared component; keep `pickFacilityLogoFile` logic reusable.

---

## 3. Create Role dialog

**Current issues (see screenshot):** Name + description only; Cancel/Save lack icons; no permission assignment.

**Requirements**

### Reusable dialog
- Build a shared **Create/Edit Role** dialog (e.g. `showRoleMutationDialog`) usable from:
  - Home quick action (`create_role`)
  - Access Admin workspace
  - Any future HR/access flows
- Accept mode (`create` | `edit`), optional existing role, tenant/facility context, and callbacks.

### Form fields
- **Role name** (required)
- **Description** (optional)
- **Permissions** (required: at least one permission selected)

### Permission picker
- Source permissions from the **predefined catalog** (`AppPermissions` + `permissionCatalogLabel` / access-admin lookups)—do **not** hardcode permission lists in the UI.
- Fetch available permissions from `AccessAdminWorkspaceState.data.lookups.permissions` (or equivalent provider).
- Render as **grouped checkbox lists** by module/domain (e.g. Clinical, Lab, Radiology, HR, Operations, Admin).
- Support select one, select many, and bulk deselect per group.
- On save, attach selected permissions to the role via existing role-permission APIs (`AccessAdminRolePermissionDraft` / `assignRolePermission`).

### Data model & API
- Extend `AccessAdminRoleDraft` with `permissionIds` (mirror `AccessAdminUserDraft`).
- Update `createRole` repository/controller to create the role, then assign permissions—or send `permission_ids` if the API supports it.

### Dialog footer
- **Cancel** (`AppButton.secondary`, icon) and **Save** (`AppButton.primary`, `Icons.save_outlined`) in `AppDialog.actions` with `pinActionsToBottom: true`.

---

## Acceptance criteria

| Area | Done when |
|------|-----------|
| Tenant | Active toggle uses `AppSwitchField`; Save/Cancel in fixed footer |
| Facility | Email required; Save/Cancel in fixed footer; logo uses shared upload component |
| Role | Permissions grouped & selectable; Save/Cancel have icons; dialog reusable; permissions persisted on create |
| All | Responsive on mobile, tablet, desktop; matches existing `AppDialog` / `AppButton` styling |

---

## Files to touch (indicative)

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_logo_upload_field.dart` → migrate to shared
- `frontend/lib/shared/components/` (new image upload field; export via `components.dart`)
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/features/access_admin/domain/entities/access_admin_entities.dart`
- `frontend/lib/features/access_admin/data/repositories/access_admin_repository_impl.dart`
- `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart` (wire reusable role dialog)
- `frontend/lib/l10n/app_en.arb` (labels for permission groups if needed)
