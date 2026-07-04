# Fix false “Sign-in required” on authenticated workspace routes

## Goal

Authenticated users with valid permissions must be able to open every entitled workspace. The **Sign-in required** state must appear only when the session is genuinely unauthenticated or expired—not when bootstrap API calls fail or auth context is not yet ready.

## Problem

After signing in as **Platform Administrator**, the shell shows an active session (profile: **Platform Demo**, `super.admin@hosspi.com`, **Super Admin**; header: **Subscribed**). The dashboard and several modules load correctly, but many workspace routes show:

- **Title:** Sign-in required  
- **Message:** Sign in again to continue.

Logging out and signing back in does **not** fix the affected routes.

### Affected routes (Platform Admin, local dev)

| Route | Path |
|-------|------|
| Inpatient (IPD) | `/ipd` |
| ICU | `/icu` |
| Nursing | `/nursing` |
| Clinical notes | `/clinical` |
| Operating theater | `/theater` |
| Laboratory | `/lab` |
| Radiology | `/radiology` |
| Pharmacy | `/pharmacy` |
| Operations | `/operations` |
| Biomedical | `/biomedical` |
| Mortuary | `/mortuary` |
| Human resources | `/hr` |

### Working routes (same session)

Dashboard (`/`), Patient registry (`/patients`), OPD (`/opd`), Emergency (`/emergency`), Rooms & beds (`/rooms-beds`), Physiotherapy (`/physiotherapy`), Claims (`/claims`), Subscriptions (`/subscriptions`), Housekeeping (`/housekeeping`), Communications (`/communications`), Integrations (`/integrations`), Reports (`/reports`), Settings (`/settings`), Tenant setup (`/admin/setup`).

### Secondary issue: subscription header flash

On initial load, the header briefly shows an incorrect subscription state (e.g. **Subscription expired**) before settling on **Subscribed**. Do not render a definitive subscription label until session/subscription data has finished loading.

## Expected behavior

- All workspace routes above load for users who are signed in **and** meet existing route permissions, roles, and active-module requirements.
- Platform admin, tenant admin, facility admin, and role-specific staff retain access per current rules in `AppRoutes`.
- **Sign-in required** is reserved for HTTP 401 / expired or missing sessions—not for forbidden access, missing module entitlements, or transient bootstrap failures.
- The subscription badge shows a neutral loading state (or nothing) until `subscriptionSummary` is hydrated; no misleading **expired** default.

## Reproduction

1. Run the app locally at `http://127.0.0.1:5201` (backend + frontend dev).
2. Sign in with the Platform Admin credentials below.
3. Confirm dashboard loads and header shows **Subscribed**.
4. Open each affected route from the sidebar (start with `/lab`).
5. Observe **Sign-in required** despite an active session.
6. (Optional) Log out, sign in again, repeat step 4—behavior unchanged.

## Investigation hints

- Error copy maps to `errorUnauthorizedTitle` / `errorUnauthorizedMessage` (401 / `AppFailureCategory.unauthorized`), not the route-level auth gate (`route_guards.dart`). Likely a workspace bootstrap API failure misreported as sign-in required.
- Affected pages use `runWorkspaceInitialLoad` in their workspace controllers (`workspace_session_guard.dart`). Compare failing vs working controllers and their first authenticated API calls.
- Route guards require permissions, roles, and `requiredActiveModules` (e.g. `lab-workflows` for `/lab`). Super admin passes guards but still hits the error—focus on backend responses and frontend failure mapping after guards succeed.
- Subscription flash: `TenantSubscriptionSummary` defaults `headerState` to `expired` when `subscriptionSummary` is null before hydration (`tenant_subscription_summary.dart`).

## Acceptance criteria

- [ ] Platform admin can open every affected route listed above and see the workspace UI.
- [ ] Tenant admin, facility admin, and authorized staff retain access per existing permission rules.
- [ ] Unauthorized messaging appears only for truly unauthenticated or expired sessions; forbidden/module errors use the correct copy.
- [ ] No incorrect subscription label flash during app startup.

## Test credentials

**Password (all accounts):** `Hosspi@2624`

| Role | Email |
|------|-------|
| Platform admin | `super.admin@hosspi.com` |
| Tenant admin | `tenant.admin@hosspi.com` |
| Facility admin | `facility.admin@hosspi.com` |
| Doctor | `doctor@hosspi.com` |
| Nurse | `nurse@hosspi.com` |
| Lab | `lab@hosspi.com` |
| Pharmacy | `pharmacy@hosspi.com` |
| Reception | `reception@hosspi.com` |
| Billing | `billing@hosspi.com` |
| Operations | `operations@hosspi.com` |
| HR | `hr@hosspi.com` |
| Biomed | `biomed@hosspi.com` |
| Housekeeping | `housekeeping@hosspi.com` |
| Ambulance | `ambulance@hosspi.com` |
| Patient portal | `patient.portal@hosspi.com` |

Use Platform Admin for primary verification; spot-check at least one role-specific account on a representative failing route (e.g. `/lab` with `lab@hosspi.com`).
