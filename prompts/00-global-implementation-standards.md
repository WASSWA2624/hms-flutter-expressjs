# Global Module Implementation Standards

This companion is mandatory for every numbered module prompt. Module-specific
requirements may specialize it but must not weaken security, data integrity, or
realtime synchronization rules.

- Follow the authority order in [the monorepo rules index](../.cursor/index.mdc),
  the applicable patient-flow rules, and each stack's owner index.
- Preserve module boundaries and the encounter model: one active OPD encounter per
  visit; an IPD admission is the inpatient hub; overlays and executing departments
  attach instead of creating parallel admissions.
- Build responsive, accessible UI for mobile, tablet, and desktop using shared
  components, design tokens, theming, localized `app_en.arb` strings, and
  hospital-facing language rather than raw IDs or enum values.
- Use modal-first within-module actions. Full-page shell routes and explicitly
  documented exceptions such as unauthenticated auth screens remain allowed.
- Keep the dependency direction widgets/controllers → repository → API. Enforce
  backend authorization and matching frontend visibility for RBAC, ABAC, tenant/
  facility scope, and entitlements.
- Keep migrations, schemas, API contracts, DTOs, and domain models aligned.
- Every user-visible shared mutation must follow
  [`instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc): immediately
  patch Riverpod after success, publish a scoped backend event, subscribe through
  `RealtimeEventGroups`, and reconcile with `WorkspaceSyncEngine` plus reconnect
  coverage. Never wait for a full refetch when a correct local delta is available.
- Run frontend formatting, analysis, and tests plus targeted backend tests for
  touched modules.
