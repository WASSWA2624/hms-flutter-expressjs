# Auth & Subscription Onboarding — Review and Implementation

## Objective

Review the existing **Authentication** and **Subscription** modules, close gaps, and wire them together so tenant self-registration, email verification, platform approval, and subscription entitlements form one coherent onboarding path.

Login, registration, change password, and email verification appear functional today — **validate end-to-end behavior** before extending.

**Parent prompts:** [prompts/01-auth-module-prompt.md](./prompts/01-auth-module-prompt.md), [prompts/02-subscriptions-module-prompt.md](./prompts/02-subscriptions-module-prompt.md), [prompts/03-tenant-facility-module-prompt.md](./prompts/03-tenant-facility-module-prompt.md), [prompts/04-access-admin-module-prompt.md](./prompts/04-access-admin-module-prompt.md)

---

## Target Onboarding Flow

```
Register → Email verification → Platform admin activation → Login → Trial subscription → Paid upgrade
```

| Step | Requirement |
|------|-------------|
| **1. Registration** | Self-register creates a **tenant** (not just a user). Capture **tenant display name** (global name visible to others), **facility type**, admin name, email, phone, and password. Branches, departments, and other org structure are configured later in tenant/facility settings. **Before submit**, validate email and/or phone against existing tenants; block duplicate tenant creation and surface clear recovery paths (log in, verify email, contact support). |
| **1a. Duplicate guard** | At or before registration, detect when **email** and/or **phone** already belong to an existing tenant user. Normalize identifiers (lowercase email, E.164 or canonical phone). Reject new tenant bootstrap on conflict; do not create a second tenant for the same contact. Existing-email flows may resend verification for pending accounts — must not silently provision a duplicate org. |
| **2. Email verification** | Send a **6-digit verification code** to the tenant email. User enters the code on the verify-email screen. **Code entry only** — no magic links, clickable verify URLs, or auto-verification from email. Login is blocked until email is verified. |
| **3. Platform activation** | After email verification, account remains **pending platform approval**. A **platform super admin** sees new registrations (email, phone, facility/tenant name) in an admin workspace, can contact the registrant (e.g. phone link), and **activates** the account. Only then may the user log in and access services. |
| **4. Trial subscription** | On activation, provision a **trial** subscription for the tenant. Default: **3 months** full access to all modules (duration must be configurable on the plan/subscription tier — not hardcoded). |
| **5. Post-trial** | When the trial ends, restrict access to paid tiers. Tenant must **pay or upgrade** to Basic, Pro, Advanced, or Custom to unlock modules again. |
| **6. Entitlement gating** | Module and service access everywhere (routes, `AccessGate`, backend `module-entitlement` middleware) must reflect the tenant's **active subscription** and enabled module subscriptions. |

---

## Review Checklist

### Auth (`frontend/lib/features/auth/`, `backend/src/modules/auth/`)

- [ ] Registration bootstraps tenant + facility + tenant admin (`registerFacilityOwner`).
- [ ] Registration fields align with UX: tenant name, facility type, email, phone — not only facility name.
- [ ] **Duplicate guard:** email and phone checked against existing tenants **before** or **on** register (frontend field validation and/or `POST /auth/identify` or dedicated availability check; backend enforces as source of truth).
- [ ] Conflicting email/phone returns actionable errors (e.g. account exists → log in; pending → verify email) — no duplicate tenant or facility created.
- [ ] Phone uniqueness enforced with the same rigor as email (normalize format before compare).
- [ ] Email verification is **code-only**: send, resend, verify, and expiry work via 6-digit OTP on the verify-email screen.
- [ ] Verification emails contain the code only — no verify links, `href`, or one-click URL activation; remove any legacy link-based paths.
- [ ] **Separate** email verification from platform activation (today `verifyEmail` may set user `ACTIVE` immediately — adjust if admin approval is required).
- [ ] Login returns clear states for: unverified email, pending admin approval, suspended/inactive.
- [ ] `registration_follow_up` records are created/updated on register and status transitions.
- [ ] Change password and session restore still work after flow changes.

### Subscriptions (`frontend/lib/features/subscriptions/`, `backend/src/modules/subscription*`)

- [ ] New tenant receives a **TRIAL** (or equivalent) subscription on platform activation with configurable duration (default **90 days**).
- [ ] Trial grants full module access; expiry transitions to restricted/past-due state.
- [ ] Upgrade paths to Basic, Pro, Advanced, Custom are reachable from subscription workspace.
- [ ] Entitlements in session (`auth_session`, `/auth/me`) match subscription + module-subscription state.
- [ ] Disabling a module hides routes and returns 403 from API.

### Platform admin (`frontend/lib/features/access_admin/` or appropriate super-admin surface)

- [ ] Queue/list of **pending tenant registrations** with email, phone, tenant/facility name, registration date.
- [ ] **Activate** action (and optional reject/suspend) with audit trail.
- [ ] Contact affordances (e.g. `tel:` link for phone) for sales/onboarding calls.

---

## Acceptance Criteria

- [ ] Email verification completes only by entering the code on the verify-email screen (not via email link).
- [ ] Registering with an email or phone already tied to a tenant is blocked with a clear message; no duplicate tenant is created.
- [ ] New user can register → verify email → wait for admin activation → log in after activation.
- [ ] Activated tenant has a trial subscription; all modules work during trial.
- [ ] After trial expiry, paid modules are gated until upgrade/payment.
- [ ] Platform super admin can discover, review, and activate pending accounts.
- [ ] Auth and subscription state stay consistent across frontend guards and backend middleware.
- [ ] Quality gate passes: `flutter analyze`, `flutter test`, targeted backend `npm test` for touched modules.

---

## Key References

```
frontend/lib/features/auth/
frontend/lib/features/subscriptions/
frontend/lib/features/access_admin/
frontend/lib/core/security/auth_session.dart
backend/src/modules/auth/
backend/src/modules/subscription/
backend/src/modules/subscriptions-workspace/
backend/src/middlewares/module-entitlement.middleware.js
backend/prisma/schema.prisma  — registration_follow_up, subscription, UserStatus
```
