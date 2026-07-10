# Create Role & User Role Assignment

## Objective

Refine **Create role** (dashboard + Access Admin) into a compact form with explicit **tenant-wide vs facility** scope, enforce an **actor permission ceiling**, and keep **multi-role assignment** in User management as the way users receive permissions.

## Behavior

### Role definition

A role is a named permission pack. Assigning a role to a user grants the union of that role’s permissions. Users may hold one, several, or all assignable roles.

### Scope

| Scope | Storage | Visibility |
|-------|---------|------------|
| Entire organization | `tenant_id` set, `facility_id` null | All facilities in the tenant |
| One facility | `tenant_id` + `facility_id` | Only that facility |

Facility admins may only create facility-scoped roles. Super / tenant admins may create either.

### Permission ceiling

When creating/editing roles or assigning roles to users, the actor may only grant permissions (and assign roles) within their own effective permission set:

- Super admin → full catalog
- Tenant admin → up to tenant-admin permissions
- Facility admin → up to facility-admin permissions

Backend enforces this on reference-data lookups, role-permission create, and user-role create.

### UX

- Compact create/edit dialog: Scope → Name/Description → Permissions (no long intro copy)
- User create/edit already supports multi-role via `AppRoleAssignmentPicker` + `syncUserRoles`
- Facility-scoped role lookups include tenant-wide roles (`facility_id` null OR matching facility)

## Instant UI

- Create role goes through workspace controller refresh
- Manage Roles / workspace page reload on successful save
- Edit role syncs permission links (`syncRolePermissions`)

## Acceptance

- [x] Compact create-role dialog with tenant / facility scope
- [x] Facility admins forced to facility scope
- [x] Permission catalog filtered by actor ceiling
- [x] Role assignment filtered by actor ceiling
- [x] Multi-role user assignment retained
- [x] Edit role persists permission changes
