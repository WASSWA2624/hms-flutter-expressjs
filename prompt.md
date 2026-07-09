# Refine and complete the Facility Create dialog

## Context

The **Create Tenant** dialog is working — tenants save successfully. The **Facility Create** dialog (`showTenantFacilityFacilityFormDialog` / `_FacilityProfileForm` in `tenant_facility_setup_page.dart`) still has functional, layout, and UX gaps shown in the attached screenshots.

## Goals

Deliver a production-ready **Create Facility** flow that is correct, responsive (mobile / tablet / desktop), and keeps frontend and backend in sync with immediate UI updates after create/edit.

---

## Required changes

### 1. Dialog title and mode

- When **creating** a facility, title must be **“Create facility”** (not “Facility profile”).
- When **editing**, keep **“Facility profile”** (or equivalent edit label).
- Update l10n keys in `app_en.arb` as needed.

### 2. Tenant selector (blocking bug)

**Current:** “Select tenant” is empty on open even when tenants exist.

**Expected:**
- Searchable select (`AppSelectField.searchable`) populated from `listTenants`.
- Opening the field shows all existing tenants; search filters by name.
- Required; show validation if missing on save.
- Load failures: show inline error + retry (do not silently leave an empty list).

**Files:** `_FacilityProfileForm._loadTenantOptions`, `_openFacilityProfileModal`.

### 3. Tenant-gated form fields

- Until a tenant is selected, disable all facility fields (name, type, logo, phone, email, address, city, country, active).
- Save remains disabled without a tenant.
- Tenant selection is mandatory to create a facility.

### 4. Facility logo upload UI

**Current:** Preview tile and “Choose image” feel visually disconnected.

**Expected:**
- Unified upload control: preview + action as one cohesive block (match existing app patterns).
- Square preview, clear empty state, consistent spacing/alignment with other form fields.
- After pick → crop → apply, preview updates immediately.

**Files:** `AppImageUploadField`, `_FacilityProfileForm._pickLogo`.

### 5. Crop image dialog — layout + capabilities

**Current:** “Crop image” modal overflows (~55 px bottom overflow on web).

**Fix:**
- Remove overflow at all breakpoints; crop area must flex within dialog height.
- Support **crop and resize** (zoom/pan to frame, output square logo).
- Responsive on mobile, tablet, and desktop.

**Files:** `app_image_crop_dialog.dart`, `AppDialog` usage.

### 6. Country field

- Replace free-text **Country** with a **searchable country selector** (name + flag), reusing phone-field country data/patterns where possible (`AppPhoneField` country list).
- **City** stays a plain text field.

### 7. Duplicate facility prevention (per tenant)

- Within one tenant, facility names must be unique (case-insensitive, trimmed).
- Duplicates across **different** tenants are allowed.
- On likely duplicate: warn before save (mirror tenant similarity UX in `tenant_similarity_dialog.dart`).
- Enforce on backend; surface API errors clearly in the dialog.
- After successful create, lists/dashboard reflect the new facility without manual refresh.

### 8. Instant UI updates

**Current:** Creates/updates do not always appear immediately.

**Fix:**
- Invalidate or refresh relevant providers after save (setup controller, facility lists, dashboard).
- Remove stale-cache bottlenecks between repository → controller → UI.
- Success: close dialog, show confirmation, updated data visible on reopen and in facility lists.

### 9. Unchanged (verify only)

- Facility type selector
- Phone (`AppPhoneField`), email (required), address line, active toggle

---

## Acceptance criteria

| # | Criterion |
|---|-----------|
| 1 | Create mode title is “Create facility”; edit mode uses profile title |
| 2 | Tenant dropdown lists all tenants; search works; required validation works |
| 3 | Facility fields disabled until tenant selected |
| 4 | Logo upload looks unified; preview updates after crop |
| 5 | Crop dialog: no overflow; crop + resize work on all screen sizes |
| 6 | Country uses flag + searchable selector |
| 7 | Duplicate name blocked per tenant with user-visible warning |
| 8 | New/updated facility appears in UI immediately after save |
| 9 | Backend validation and frontend rules stay aligned |

---

## Key files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/shared/components/app_image_upload_field.dart`
- `frontend/lib/shared/components/app_image_crop_dialog.dart`
- `frontend/lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart`
- `frontend/lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart`
- `frontend/lib/l10n/app_en.arb`

## Constraints

- Reuse existing shared components (`AppSelectField.searchable`, `AppPhoneField` country data, `AppDialog`, form validators).
- Responsive on mobile, tablet, and desktop.
- No unrelated refactors; scope to facility create/edit flow.
