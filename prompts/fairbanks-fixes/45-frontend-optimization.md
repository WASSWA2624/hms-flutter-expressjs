# 45 — Optimize the Frontend

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 13, Step 45
**Depends on:** 43, 44
**Applies to:** development and production

## Context

Apply frontend optimizations where the baseline justifies them: lazy loading, caching, memoization, component optimization, table virtualization, pagination, deferred loading, and asynchronous loading of secondary modal content. A modal should open promptly while non-critical detail loads behind it.

## Requirements

1. Make dialogs open immediately with their primary content, loading secondary information asynchronously with explicit loading states per section.
2. Virtualize or paginate large tables so rendering cost does not grow with row count, keeping sorting, filtering, and selection behavior intact.
3. Remove unnecessary rebuilds in the heaviest screens by narrowing provider scopes and memoizing derived values, guided by the baseline rather than guesswork.
4. Defer non-critical work at startup so the first authenticated screen renders sooner, without delaying session restoration from step 03.
5. Cache stable reference data on the client with an explicit invalidation rule tied to session and scope, never persisting another user data across sessions.
6. Lazy-load heavy features and assets so they do not cost startup time, verifying web bundle impact.
7. Remove duplicate client-side requests per screen identified in the baseline, coordinating through the existing repository and provider layer.
8. Keep behavior identical: no optimization may change what data a user sees, alter permission gating, or bypass scope.
9. Re-measure each optimized surface against the baseline and record before and after numbers.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Optimize only what the baseline identifies; do not refactor unrelated code.
- Client caches must respect session isolation and never serve data across users or scopes.
- Follow `prompts/.cursor/tables.mdc`, `dialogs.mdc`, `responsiveness.mdc`, and `screens.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1)** Facility details, staff details, and pharmacy dialogs open promptly with primary content while secondary sections show their own loading states.
- [ ] **AC2 (R2)** Large tables render and scroll smoothly at realistic row counts with sorting, filtering, and selection intact.
- [ ] **AC3 (R3, R4, R6)** Startup and the heaviest screens improve measurably without breaking session restoration.
- [ ] **AC4 (R5)** Client caches are scope-aware and cleared on logout and user switch.
- [ ] **AC5 (R7)** Duplicate client requests per screen are eliminated, verified in the network log.
- [ ] **AC6 (R8)** Visible data, permission gating, and scope behavior are unchanged.
- [ ] **AC7 (R9)** Before and after numbers are recorded per surface.
- [ ] **AC8 (R10)** Improvements are confirmed in development and production builds.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- Flutter profile-mode measurements and browser traces on the release web build.
- Re-run of the step 43 measurement method for the affected surfaces in both environments.

## Rollout — Development and Production

- Behavior must be identical under both Flutter define files; no optimization may be gated to one environment.
- Config: mirror any lazy-loading or cache define in `frontend/env/development.json.example` and `frontend/env/production.json.example`, keeping production logging at its configured level.
- Schema/data: none.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, then re-measure on `https://app.hosspi.com` and the release APK.

## Relevant Files

- `frontend/lib/core/network/http_response_cache_interceptor.dart`, `api_client.dart`, `network_providers.dart`
- `frontend/lib/core/storage/`, `frontend/lib/core/security/session_isolation.dart`
- `frontend/lib/shared/widgets/`, `frontend/lib/shared/layout/`, `frontend/lib/shared/management/`
- `frontend/lib/app/`, `frontend/lib/bootstrap.dart`
- `backend/docs/performance-baseline.md`
