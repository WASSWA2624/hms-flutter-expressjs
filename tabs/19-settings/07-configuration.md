# Settings section — Configuration

## 1. Section chrome

- Label: `settingsConfigurationSectionTitle` / body `settingsConfigurationSectionBody`
- Icon: `tune_outlined`
- Deep-link `tab`: `configuration`
- Gate: `settingsConfigurationReadRequirement` = `profile:read` ∩ admin ∪
- Visible if read gate **and** (tenant panel ∨ facility panel)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Absent
- Context: Save / Reset per panel

## 3. Inner surfaces

- Data: `tenantFacilitySetupControllerProvider`
- Tenant panel (`settingsConfigurationTenantTitle`): `AppCurrencyAmountField` currency + consultation fee
- Facility panel (`settingsConfigurationFacilityTitle` + `settingsConfigurationFacilityOverrideHint`): same fields
- Keys: `settingsConfigurationCurrencyLabel`, `ConsultationFeeLabel`/`Helper`

## 4. Advanced filters / search fields

- Absent (context from session/setup snapshot)

## 5. Primary / secondary / row actions

- Save: `settingsConfigurationSaveAction` — tenant/facility source write gates
- Reset: `settingsConfigurationResetAction` — same
- Create/delete matrix ∩ `facility:admin` — not mounted (reset clears via save)

## 6. Dialogs from this section

| Dialog | Owner |
| --- | --- |
| Reset confirm (`settingsConfigurationResetConfirmTitle`/`Body`) | Settings-owned `AppDialog` (×2 panels) |

## 7. Nested / follow-on

- None

## 8. Forms (summary)

- Tenant/facility: currency + fee only
- Cancel on confirm uses **Material** `cancelButtonLabel` (not `commonCancelActionLabel`)

## 9. Print / labels / preview

- Absent

## 10. Loading / empty / error / success

- Loading: bare `CircularProgressIndicator` (**not** `AppStateView`)
- Error/failure: `settingsConfigurationSaveError` title + section body + `commonRefreshActionLabel`
- No tenant / no panels: `settingsConfigurationNoTenantContext`
- Success/error snackbars: `settingsConfigurationSaveSuccess` / `SaveError`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / loading / empty / retry / success chrome | `settingsConfigurationReadRequirement` |
| Tenant panel / fields / save / reset / dialog | `settingsConfigurationTenantRequirement` (`tenant:admin` ∪ `platform:admin` + tenant ctx) |
| Facility panel / fields / save / reset / dialog | `settingsConfigurationFacilityRequirement` (admin ∪ + facility ctx) |
