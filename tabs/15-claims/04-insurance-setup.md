# Claims tab — Insurance setup

## 1. Tab strip

- Label: `claimsSectionInsuranceSetup`
- Icon: `Icons.business_outlined`
- Count: **omitted** (`null` — catalog hub, not a worklist)
- Count tone: `AppTabCountTone.info` (unused while count is null)
- Deep-link `section`: `insurance-setup`
- Tab gate: `ClaimsInsuranceSetupAtomPermissions.tab` = ∪ `billing:read` \| `facility:admin` \| `tenant:admin` ∩ `insurance-claims`
- **Omitted when unauthorized**
- Strip primary / Refresh: **absent**

## 2. Search / Filters / Settings / Export / Print / context

- **No** queue search / filters / settings / export / print on this tab
- Surface is description + `AppQuickActions` create strip

## 3. Table / panel surface

- Non-table panel: `_ClaimsInsuranceSetupPanel`
- Description: `claimsInsuranceSetupDescription`
- Quick actions (`AppQuickActionsPresentation.detailPanel`, `hideWhenEmpty`): collapses when all create actions filtered

## 4. Advanced filters / search fields

- **Absent**

## 5. Primary / secondary / row actions

Create atoms (each ∩ `billing:write`):

- Add company
- Add scheme
- Add offer
- Enroll patient
- Add price book entry
- Insurer API integration

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Company / Scheme / Offer / Enrollment / Price book / Insurer integration | Claims-owned `claims_insurance_config_dialogs.dart` |

## 7. Nested / follow-on

Each opener re-checks create requirement before mount. No queue detail nesting.

## 8. Forms (summary)

- Catalog identity fields, scheme/offer linkage, enrollment patient/coverage, price book amounts, insurer API credentials/endpoints (per dialog)

## 9. Print / labels / preview

- **Absent** on this tab

## 10. Loading / empty / error / success

- Read chrome always when tab visible
- Empty create strip when write denied (`hideWhenEmpty`)
- Dialog validation / snackbars on save

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / description | insurance setup read ∪ |
| Each Add / Enroll / API action | write ∩ (`ClaimsInsuranceSetupAtomPermissions.create` aliases) |
| Queue / Next / Print | **absent** |
