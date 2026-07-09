# Create Tenant Dialog — UX & Validation Hardening

## Objective

Fix the **Create tenant** modal opened from the home dashboard quick action (`create_tenant`) and **Manage tenants → Add tenant** so it behaves as a true create flow: correct title, empty defaults, smart slug generation, field-specific errors, and duplicate/similarity awareness before save.

## Problem (observed)

| Issue | Current behavior | Expected behavior |
| ----- | ---------------- | ----------------- |
| Dialog title | Always **Tenant profile** | **Create tenant** in create mode; **Tenant profile** (or **Edit tenant**) in edit mode |
| Pre-filled fields | Name/slug populated with the signed-in session tenant (e.g. *DemoCare General Hospital* / *democare-general-hospital*) | Create mode starts **empty** (Active defaults to on) |
| Slug entry | Manual only | Auto-generate from tenant name as the user types; remain **editable**; stop auto-overwriting once the user edits slug manually |
| Save errors | Generic messages such as **You do not have permission.** or **Field is already in use.** | Name the conflicting field (e.g. **Tenant slug is already in use.**); use a create-specific permission message when the user lacks platform create rights |
| Duplicate awareness | None | Warn before save when the new tenant is an exact or near match to existing tenants |

**Root cause (create mode):** `_openTenantProfileModal` passes `tenant: resolvedTenant ?? snapshot.tenant` even when `forceCreate: true`, so the form inherits the workspace snapshot tenant instead of `null`.

## Scope

### In scope

1. **Create vs edit mode**
   - Pass `tenant: null` when `forceCreate` or `isCreate` is true — never fall back to `snapshot.tenant`.
   - Set dialog title and primary action from mode (`tenantFacilityAddTenantAction` / new l10n keys for create title & body).
   - Keep existing footer pattern (`Cancel` + `Save tenant` / `Create tenant`).

2. **Slug auto-fill**
   - On name change, derive a URL-safe slug (lowercase, hyphenated, trimmed).
   - Track whether the user manually edited the slug; only auto-update while slug is auto-managed.
   - Reuse or add a small shared slug helper under `frontend/lib/core/utils/` if none exists.

3. **Field-specific validation errors**
   - Surface backend `409` unique-constraint failures via `ValidationMessagePresenter` + `failure.fieldMessages` so users see which field conflicts (`name` vs `slug`).
   - Map tenant field keys to localized labels in `validation_message_presenter.dart` if missing.
   - Replace generic forbidden text for create attempts with a message such as *You do not have permission to create tenants.*

4. **Duplicate & similarity guard (create only)**
   - Before POST, check entered name/slug against existing tenants (`listTenants` search or dedicated check).
   - **Exact match** (name or slug): block save; show inline field error.
   - **Similar match** (fuzzy name comparison, e.g. ≥ 80%): show a confirmation dialog listing similar tenants (name, slug, active status, match score/reason). Actions: **Proceed anyway** | **Cancel** (dismiss dialog, keep form data).
   - Mirror the patient duplicate-review UX pattern (`PatientDuplicateWarningPanel`, duplicate confirmation dialogs in `patient_registry_page.dart`) — adapt for tenants, do not copy patient-specific APIs.

5. **Permissions**
   - Create: require platform create rights (`AppPermissions.systemAdmin` / `SUPER_ADMIN`), aligned with `home_dashboard_actions.dart` `create_tenant` action.
   - Edit existing tenant: keep `canManageTenant()` behavior.
   - Disable save + show permission hint when create rights are missing; do not allow a silent API 403.

### Out of scope

- Facility create/edit flows
- Tenant deletion or subscription onboarding
- Full tenant-facility module refactor (see `prompts/03-tenant-facility-module-prompt.md`)

## Key files

| Area | Path |
| ---- | ---- |
| Dialog & form | `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` — `_openTenantProfileModal`, `_TenantProfileForm`, `_SetupProfileDialog` |
| Entry points | `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart`, `tenant_facility_management_dialogs.dart` |
| Submission | `tenant_facility_setup_controller.dart`, `tenant_facility_repository_impl.dart` |
| Errors / i18n | `validation_message_presenter.dart`, `app_en.arb` |
| Backend reference | `backend/src/modules/tenant/` — POST `409` duplicate slug via `errors.database.unique_field` |
| Pattern reference | Patient duplicate flow in `frontend/lib/features/patients/` |

## Acceptance criteria

- [ ] **Create tenant** quick action opens a dialog titled for creation with **empty** name/slug fields.
- [ ] Typing a tenant name auto-fills slug; manual slug edits are preserved.
- [ ] Saving a duplicate slug/name shows which field is in use, not a generic message.
- [ ] Similar-tenant warning appears before create when names are near-duplicates; user can proceed or cancel.
- [ ] Edit flow (existing tenant row / setup wizard) is unchanged except for clearer titles if touched.
- [ ] Users without create permission see a clear disabled state, not a post-submit 403.
- [ ] Responsive layout preserved (mobile / tablet / desktop); all strings in `app_en.arb`.
- [ ] Tests added/updated for slug helper, create-mode form init, and duplicate-check decision logic.

## Quality gate

From `frontend/`:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Add targeted backend tests only if a new similarity-check API endpoint is introduced.
