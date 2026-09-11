# 42 — Implement Automated Appreciation Messages

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 12, Step 42
**Depends on:** 12, 17
**Applies to:** development and production

## Context

Facilities want configurable post-service messages over WhatsApp, SMS, and email, for example `Service Completed → Appreciation Message`, generated from approved templates with service context, and fully logged. Existing building blocks: `backend/src/modules/communications-workspace/`, `notification/`, `notification-delivery/`, `template/`, `template-variable/`, `campaign/`, `message/`, `consent/`, `contact/`.

## Requirements

1. Implement trigger configuration per tenant and facility: which events send a message, through which channels, to which recipients, with an enable and disable switch and a permission gate.
2. Implement approved message templates with variables (facility name, patient name, service, date), validated so a template cannot reference an undefined variable or exceed channel limits.
3. Implement channel adapters for WhatsApp, SMS, and email behind one sending interface, with per-channel credentials supplied by configuration in each environment.
4. Respect consent, communication preferences, and opt-out before sending, and never send to a recipient who has opted out or lacks a valid contact.
5. Send asynchronously with retry and backoff so a provider failure never blocks or fails the clinical or billing workflow that triggered it.
6. Maintain a communication log recording recipient, channel, template, date and time, delivery status, failure reason, and the originating service or event, scoped to the tenant.
7. Provide a management surface to view logs, filter them, retry a failed send where appropriate, and preview a rendered template, with permission and scope gating.
8. Protect patient privacy: no clinical detail beyond the approved template content, no identifiers in message bodies beyond what the template defines, and no credentials in logs.
9. Add backend tests for trigger evaluation, template rendering, consent enforcement, retry behavior, and log completeness; add frontend tests for configuration and log surfaces.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Reuse the existing communications, notification, template, and consent modules; do not create a parallel messaging stack.
- Provider credentials must come from environment configuration, never from committed files.
- Sending must be disabled by default for a tenant until explicitly configured and enabled.
- Follow the localization rules for templates and the management surface.

## Acceptance Criteria

- [ ] **AC1 (R1)** A tenant can configure, enable, and disable triggers per channel, and an unauthorized user cannot.
- [ ] **AC2 (R2)** Templates render with correct variable substitution and are rejected when invalid or over the channel limit.
- [ ] **AC3 (R3)** Each channel sends successfully using environment-supplied credentials.
- [ ] **AC4 (R4)** Opted-out recipients and recipients without a valid contact are never messaged.
- [ ] **AC5 (R5)** A provider outage leaves the triggering workflow unaffected, with retries recorded.
- [ ] **AC6 (R6, R7)** The log records every listed field, and the management surface filters, previews, and retries within scope.
- [ ] **AC7 (R8)** No message or log contains clinical detail beyond the template or any credential.
- [ ] **AC8 (R9)** New backend and frontend tests pass.
- [ ] **AC9 (R10)** Messaging works in development against test credentials and in production against live credentials, with sending disabled for tenants that have not opted in.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: complete a service and confirm one message per enabled channel in each environment, using test recipients.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`, except that development must use provider sandbox credentials and must not message real patients.
- Config: document every provider credential, sender identity, rate limit, and retry key in `backend/env.template.txt` with dev and prod guidance, then set sandbox values in `.env.development` and live values in `.env.production`.
- Schema/data: create trigger, template, and log tables with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; seed approved templates in both databases idempotently.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`, then send one verified test message per channel in production before enabling any tenant.

## Relevant Files

- `backend/src/modules/communications-workspace/`, `notification/`, `notification-delivery/`, `message/`, `template/`, `template-variable/`, `campaign/`, `consent/`, `contact/`, `patient-contact/`
- `backend/src/config/`, `backend/env.template.txt`
- `frontend/lib/features/communications/`, `frontend/lib/features/settings/`
