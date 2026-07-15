# Implement Tenant & Facility Configuration Settings (Currency + Consultation Fee)

## Objective

Add a **Configuration** section to the Settings screen — positioned immediately above the existing **Administrative Setup Workspace** section — that allows authorized administrators to configure **default currency** and **default consultation fee** at the tenant and/or facility level, with full CRUD operations.

---

## Scope

### 1. Configuration Section Placement & Access Control

- Add the new **Configuration** section in `frontend/lib/features/settings/presentation/pages/settings_page.dart`, directly above the Settings Workspace / Administrative Setup section.
- Enforce RBAC using existing `facility_settings` and `tenant_settings` permissions (see `.cursor/access/permissions.mdc`):
  - **Super Admins** and **Tenant Admins**: can configure both tenant-level and facility-level settings.
  - **Facility Admins**: can configure facility-level settings only.
- The section must dynamically show/hide tenant vs. facility configuration options based on the authenticated user's role and permissions.

### 2. Default Currency Configuration

- Provide a currency selector using the existing `AppCurrencySelectField` (`frontend/lib/shared/components/app_currency_select_field.dart`) to set the default currency at both tenant and facility levels.
- **Storage**: persist the selected currency in `extension_json.currency` on the `tenant` and `facility` models (backend Prisma schema already supports this via `extension_json Json?`).
- **Resolution hierarchy** (already implemented in `backend/src/lib/opd-flow.service.js` → `resolveDefaultCurrency`):
  1. Facility `extension_json.currency` (highest priority)
  2. Tenant `extension_json.currency`
  3. Fallback: `'UGX'`
- **App-wide awareness**: the existing `effectiveDefaultCurrencyProvider` (`frontend/lib/core/currency/effective_default_currency_provider.dart`) already reactively resolves the default currency from the tenant/facility setup state. Ensure that after saving a currency configuration change, this provider updates so all `AppCurrencyAmountField` instances across the app reflect the new default currency.
- **FX conversion**: the existing `FxRateService` (`frontend/lib/core/currency/fx_rate_service.dart`) must continue to handle conversions when amounts are entered in a currency different from the configured default.
- **Fallback alignment**: if no currency is configured at any level, default to `UGX` (matching `appDefaultCurrencyCode` in `frontend/lib/core/currency/app_currency.dart`).

### 3. Default Consultation Fee Configuration

- Provide an amount input using the existing `AppCurrencyAmountField` (`frontend/lib/shared/components/app_currency_amount_field.dart`) to set the default standard consultation fee at both tenant and facility levels.
- The currency displayed on this field must use the resolved default currency for the current scope (tenant or facility).
- **Storage**: persist the fee in `extension_json.billing.standard_consultation_fee` on the `tenant` and `facility` models.
- **Resolution hierarchy** (already implemented in `backend/src/lib/opd-flow.service.js` → `resolveConsultationFeeDefaults`):
  1. Individual practitioner's `staff_profile.consultation_fee` (highest priority — if the doctor has a preset fee)
  2. Facility `extension_json.billing.standard_consultation_fee`
  3. Tenant `extension_json.billing.standard_consultation_fee`
  4. `null` (no default fee)
- Ensure the OPD flow and billing workflows (`OpdBillingDefaults`) continue to resolve the consultation fee using this chain without regression.

### 4. CRUD Operations

Implement complete Create, Read, Update, and Delete operations for both configuration values:

- **Backend**: add or extend endpoints under the settings workspace module (`backend/src/modules/settings-workspace/`) or the tenant-facility-setup module to support reading and writing `extension_json` fields for currency and billing configuration.
- **Frontend**: build the configuration UI with form validation, loading states, success/error feedback, and confirmation dialogs for destructive actions (delete/reset).
- On save, refresh the tenant/facility setup state so downstream providers (`effectiveDefaultCurrencyProvider`, billing defaults) reactively update.

---

## Technical Constraints

- **Architecture**: follow the project's clean architecture pattern — `data/` (DTOs, repository impls), `domain/` (entities, repository interfaces), `presentation/` (controllers, pages, widgets) — within the `settings` feature module.
- **State management**: use Riverpod, consistent with the rest of the app.
- **Reusable components**: use existing shared components (`AppCurrencyAmountField`, `AppCurrencySelectField`). Any new reusable widgets must be placed under `frontend/lib/shared/`.
- **Localization**: all user-facing text must be localized via `l10n`.
- **Responsiveness**: the configuration UI must be fully responsive (mobile, tablet, desktop).
- **No hard-coded values**: do not hard-code currency codes or fee amounts; use the resolution chain and configured defaults.
- **Database migrations**: if any schema changes are needed beyond `extension_json`, create and run the appropriate Prisma migrations.
- **Existing tests**: ensure no regressions in OPD flow consultation fee resolution or currency resolution logic.

---

## Acceptance Criteria

1. Authorized admins can set a default currency at tenant and/or facility level from the Settings > Configuration section.
2. Authorized admins can set a default consultation fee at tenant and/or facility level from the Settings > Configuration section.
3. Facility-level configurations override tenant-level configurations wherever both exist.
4. A practitioner's individual consultation fee (on `staff_profile`) overrides all facility/tenant defaults.
5. The configured default currency is applied app-wide to all currency/amount displays and inputs.
6. FX conversion works correctly when amounts are entered in non-default currencies.
7. Unauthorized users cannot see or access the configuration section.
8. All CRUD operations (create, read, update, delete/reset) work end-to-end for both settings.
9. UI updates reactively after configuration changes — no manual refresh required.
