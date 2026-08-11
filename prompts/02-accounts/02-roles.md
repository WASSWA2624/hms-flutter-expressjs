# Accounts — Roles

## Context

Define which **roles** receive Accounts workspace rights (`accounts:read`, `accounts:write`, and where appropriate `financial:approve`) for `/accounts` ∩ `facility-accounts`. Source of truth: root `accounts.md` §9 plus product rule: **all accountants and admins have Accounts rights; HR roles do not.** Pair with `01-permissions.md` for catalog keys and gates.

## Requirements

1. Grant Accounts rights to the **ACCOUNTANT** role pack: include at least `accounts:read` and `accounts:write`. Keep existing finance-related keys on ACCOUNTANT (`financial:approve`, billing embeds as already defined) unless a later prompt explicitly narrows them.
2. Grant Accounts rights to **admin** role packs: `PLATFORM_OWNER`, `PLATFORM_ADMIN`, `TENANT_ADMIN`, and `FACILITY_ADMIN` (via `ADMIN_ACCESS` / full catalog as already structured). Admins must receive `accounts:read` and `accounts:write` (and retain `financial:approve` where admins already have it).
3. **Do not** grant `accounts:read` or `accounts:write` to **HR** or **HR_STAFF** role packs. HR payroll may later post summary journals into Accounts; that does not imply HR users open the Accounts desk.
4. Do not imply Accounts rights for other clinical / operations / receptionist packs unless they already inherit admin or accountant. Billing-only (`BILLING`, `PHARMACY_BILLING`) does not automatically receive Accounts keys from this prompt.
5. Update role → permission seeds / `BASE_ROLE_PERMISSIONS` so new environments and demo users (e.g. `accountant@hosspi.com`) resolve Accounts access correctly after seed.
6. Update role catalog metadata if display copy should mention ledgers / books for ACCOUNTANT; keep HR metadata free of Accounts desk claims.
7. Ensure custom roles created in Access admin can be assigned `accounts:read` / `accounts:write` individually; built-in packs above are the defaults only.
8. Keep subscription entitlement `facility-accounts` as a second gate: role permissions alone do not open Accounts when the module is not entitled.
9. Document the matrix in tests:

   | Role pack | `accounts:read` | `accounts:write` | Notes |
   |---|---|---|---|
   | ACCOUNTANT | yes | yes | Books desk primary |
   | PLATFORM_OWNER / PLATFORM_ADMIN | yes | yes | Full / near-full catalog |
   | TENANT_ADMIN / FACILITY_ADMIN | yes | yes | Via admin access |
   | HR / HR_STAFF | no | no | Explicit exclusion |
   | Other non-admin packs | no (default) | no (default) | Unless separately assigned |

10. After role-map changes, verify demo accountant can enter `/accounts` and HR demo users cannot, when `facility-accounts` is entitled.

## Constraints

- Do not give HR Accounts rights “because payroll touches money.”
- Do not remove Billing permissions from ACCOUNTANT as a side effect of this work unless explicitly required.
- Do not invent a separate `ACCOUNTS` role key unless product later requests it; use existing `ACCOUNTANT` plus admins.
- Reuse existing roles config, permission seeding, and Access admin custom-role flows.
- No unrelated refactoring outside role ↔ Accounts permission mapping.

## Acceptance Criteria

- [ ] AC1: ACCOUNTANT includes `accounts:read` and `accounts:write`. (R1, R5)
- [ ] AC2: PLATFORM_OWNER, PLATFORM_ADMIN, TENANT_ADMIN, and FACILITY_ADMIN include Accounts read/write. (R2, R5)
- [ ] AC3: HR and HR_STAFF role packs omit `accounts:read` and `accounts:write`. (R3, R9)
- [ ] AC4: BILLING / other non-listed packs do not gain Accounts keys solely from this change. (R4)
- [ ] AC5: Seeded accountant demo user can authorize Accounts route when `facility-accounts` is active. (R5, R10)
- [ ] AC6: Seeded HR demo user cannot authorize Accounts route via role pack alone. (R3, R10)
- [ ] AC7: Custom roles can still be granted Accounts permissions via Access admin. (R7)
- [ ] AC8: Missing `facility-accounts` still blocks Accounts for accountant/admin. (R8)

## Verification

- Backend `permissions.test.js` (or role-pack tests): assert inclusion/exclusion matrix above.
- Seed / demo-user smoke: accountant enters Accounts; HR does not.
- Frontend access tests with role-derived permission lists for accountant, facility admin, and HR.
- Confirm Access admin permission picker lists `accounts:read` / `accounts:write` for custom roles.

## Relevant Files

- `accounts.md` (§9)
- `prompts/02-accounts/01-permissions.md`
- `backend/src/config/roles.js`
- `backend/src/config/permissions.js`
- `backend/src/config/permission-catalog-metadata.js`
- `backend/src/config/demo-users.js`
- `backend/scripts/seeders/seed-catalog.js`
- `backend/src/tests/config/permissions.test.js`
- `frontend/lib/features/accounts/presentation/accounts_access.dart`
- `frontend/test/features/accounts/presentation/accounts_access_test.dart`
