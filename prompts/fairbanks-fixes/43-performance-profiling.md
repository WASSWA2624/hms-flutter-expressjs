# 43 — Profile Slow Screens

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 13, Step 43
**Depends on:** 42
**Applies to:** development and production

> Performance work starts only after correctness, data integrity, authorization, and workflow behavior are stable.

## Context

Optimization must follow measurement. This step records actual timings for the slow paths before any architectural change, in both environments, so later work can be compared honestly.

## Requirements

1. Define the measurement method: device or browser, network profile, dataset size, warm and cold states, and the number of repetitions per measurement.
2. Measure application startup: time to first frame, time to interactive, and time to first authenticated screen.
3. Measure routing and navigation timings for the most used routes.
4. Measure modal and dialog opening, specifically facility details, staff details, and the pharmacy dispensing dialogs.
5. Measure table rendering and scrolling for the largest lists, at realistic row counts.
6. Measure form opening and submission round trips for the most used forms.
7. Measure API call durations per endpoint, including payload sizes, and identify duplicate calls per screen.
8. Measure database query durations for the slowest endpoints, capturing the query plan for each.
9. Measure report generation and analytics loading for the heaviest reports.
10. Record every result in `backend/docs/performance-baseline.md` (or a frontend equivalent) with environment, dataset size, timestamp, and the commit measured, and rank the findings by user impact.
11. Measure in both development and production per **Rollout** below.

## Constraints

- Do not change architecture, add caching, or refactor in this step; measure only.
- Use realistic production-like data volumes for development measurements, and state the volume for each environment.
- Do not capture patient-identifying data in the recorded artifacts.

## Acceptance Criteria

- [ ] **AC1 (R1)** The method is documented and repeatable by another engineer.
- [ ] **AC2 (R2–R9)** Every listed area has recorded timings with repetitions and variance.
- [ ] **AC3 (R7)** Duplicate API calls per screen are listed explicitly.
- [ ] **AC4 (R8)** Query plans are captured for the slowest endpoints.
- [ ] **AC5 (R10)** The baseline document ranks findings by user impact and names the measured commit.
- [ ] **AC6 (R11)** Development and production measurements are both recorded and compared.

## Verification

- Flutter performance profiling on a release build; browser performance traces for the web build.
- Backend timings from `backend/src/middlewares/performance.middleware.js` and database query plans.
- Peer review of the baseline document.

## Rollout — Development and Production

- Measurements must cover both environments; a development-only baseline is not acceptable, since production runs behind a reverse proxy with different data volumes.
- Config: confirm logging and tracing keys in `.env.development` and `.env.production` are documented in `backend/env.template.txt`, and disable verbose tracing again after measurement.
- Schema/data: no changes; record the dataset size and migration revision per environment.
- Release: measure the currently deployed production build, and record its commit alongside the development commit.

## Relevant Files

- `backend/src/middlewares/performance.middleware.js`, `backend/src/lib/`, `backend/src/config/`
- `backend/prisma/schema.prisma`
- `frontend/lib/core/network/`, `frontend/lib/core/logging/`
- `backend/docs/` (new performance baseline document)
