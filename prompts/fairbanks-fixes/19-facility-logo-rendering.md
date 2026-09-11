# 19 — Fix Facility Logo Rendering

**Source:** [fairpanks-fixes.md](../fairpanks-fixes.md) → Phase 6, Step 19
**Depends on:** 18
**Applies to:** development and production

## Context

A stored facility logo does not render. The chain is `Stored Logo → Storage → API → Facility Data → Frontend → Image Component`, crossing `backend/uploads/`, the facility module, and the Flutter image widgets. In production the backend serves from the cPanel host with a server-owned `uploads/` directory, so URL generation and permissions differ from development and must both be correct.

## Requirements

1. Trace the full chain and identify the exact failure point: stored path, storage permissions, URL generation, API response field, tenant and facility association, authorization on the asset request, or the image component.
2. Generate logo URLs from configuration rather than a hardcoded host so the same code yields a working URL in development and in production.
3. Ensure storage permissions and directory ownership allow the served path in both environments, and document the required production directory state.
4. Ensure the API returns the logo reference for every authorized facility read, and that fetching the asset is authorized without leaking assets across tenants.
5. Handle missing, deleted, or corrupt logos with a defined placeholder state instead of a broken image or an error.
6. Support the documented image formats and a stated maximum size, validating on upload and rejecting unsupported input with a clear message.
7. Render correctly across aspect ratios and dimensions wherever the logo appears, including facility screens, headers, and printouts, without distortion or overflow.
8. Add backend tests for URL generation, authorization, and validation, and frontend tests for loaded, missing, and error states.
9. Ship the change to both development and production per **Rollout** below.

## Constraints

- Do not commit binary logo assets into the repository as a workaround.
- Reuse the existing upload and storage handling in the backend and the shared image components in the frontend.
- Keep tenant isolation intact for asset access.
- Follow `prompts/.cursor/printing.mdc` for the printed appearance.

## Acceptance Criteria

- [ ] **AC1 (R1)** The failure point is identified and stated in the pull request description.
- [ ] **AC2 (R2, R3)** The same build renders the logo correctly against both the development API and `https://api.hosspi.com`.
- [ ] **AC3 (R4)** An unauthorized or cross-tenant asset request is denied.
- [ ] **AC4 (R5)** A facility with no logo renders the defined placeholder, never a broken image.
- [ ] **AC5 (R6)** Unsupported formats and oversized files are rejected with a localized message.
- [ ] **AC6 (R7)** Square, wide, tall, small, and large logos render correctly on screen and in print.
- [ ] **AC7 (R8)** New backend and frontend tests pass.
- [ ] **AC8 (R9)** Logos render in both environments after deployment.

## Verification

- `npm run test:backend`, `npm run lint`, `npm run openapi:validate` in `backend/`.
- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: upload at least four logos of different dimensions and formats in each environment and view them on screen and in a print preview.

## Rollout — Development and Production

- Behavior must be identical under `NODE_ENV=development` and `NODE_ENV=production`; URL generation must be configuration-driven, never environment-branched in code.
- Config: document the public asset base URL, upload directory, allowed formats, and size limit in `backend/env.template.txt` with dev and prod guidance, set them in `.env.development` and `.env.production`, and mirror any client-visible value in both `frontend/env` example files.
- Schema/data: apply logo-reference schema changes with `npm run prisma:migrate` locally and `npm run prisma:migrate:deploy` on the host; repair existing stored paths idempotently in both databases.
- Release: `python deploy/deploy-backend.py` and `python deploy/deploy-frontend.py`; confirm the server-owned `uploads/` directory exists with correct permissions after deployment, then re-check logo rendering in production.

## Relevant Files

- `backend/src/modules/facility/`, `backend/uploads/`, `backend/src/config/`
- `backend/env.template.txt`, `deploy/deploy-backend.py`, `deploy/backend/DEPLOY.md`
- `frontend/lib/features/tenant_facility/presentation/widgets/`
- `frontend/lib/shared/components/`, `frontend/lib/shared/printing/`
