# HMS Access Verification & Simplification Plan

**Goal:** prove that every user reaches exactly what they are authorised to reach on every
screen — no more, no less — and use the evidence to delete the parts of the UI nobody can
legitimately reach.

**Method:** do not test 70 roles against 23 screens. Collapse roles into *equivalence classes*
per screen, test one account per class, and let a generator prove the collapse is safe.

---

## 1. What actually determines access

From `.cursor/access/permissions.mdc`, the authority order is:

```
subscription  ->  assigned modules  ->  roles/permissions  ->  ABAC
effective access = union(role, module, user grants) INTERSECT subscription INTERSECT modules INTERSECT ABAC
```

Four independent gates, so a screen can fail four different ways. Every test case below must
name which gate it is exercising, or a green result means nothing.

| Layer | Source of truth | Notes |
| ----- | --------------- | ----- |
| Permission catalog (85 keys) | `backend/src/config/permissions.js` | frontend mirrors it in `AppPermissions` |
| Role to permission packs (70 roles) | `BASE_ROLE_PERMISSIONS` + `DERIVED_ROLE_PARENTS` in the same file | 70 roles, only 38 distinct packs |
| Route entry gates (32 atoms) | `frontend/lib/core/permissions/route_access_catalog.dart` | one `*:read` key per menu destination |
| In-screen control gates | `frontend/lib/features/*/presentation/*_access.dart` (33 files) | tab/action atoms, already documented per control |
| Version-disabled domains (9) | `backend/src/config/version-disabled-permissions.js` + `frontend/lib/core/permissions/version_disabled_permissions.dart` | stripped for **everyone**, including platform owner |
| Subscription ceilings | `subscription-permission-caps.js` / `plan_permission_caps.dart` | second gate; role keys alone never open a route |

**Backend is authoritative.** `permissions.mdc` is explicit that hiding a control in the UI is
never sufficient. Every screen therefore needs both a UI check and a matching API check —
a passing UI test alone does not close a screen.

### Live surface

32 route atoms minus 9 version-disabled = **23 live destinations**, of which 3 (`home`,
`settings`, `profile`) are authenticated-core and 20 are permission-gated.

Version-disabled (must be unreachable for every account and every plan — this is a test
case, not an exclusion): Emergency, Rooms & beds, Physiotherapy, Operations, Housekeeping,
Biomedical Engineering, Mortuary, Communications, Integrations.

---

## 2. The efficiency lever: equivalence classes

Naive matrix: 70 roles x 23 screens = **1,610 cases**. Unrunnable, and mostly duplicates.

Three mechanical reductions, each provably lossless:

**(a) Roles to packs.** 70 roles collapse to 38 distinct permission packs; the other 32 are
`DERIVED_ROLE_PARENTS` aliases with byte-identical packs. `NURSE` alone covers 10 roles
(incl. `DISCHARGE_PLANNER`, `MIDWIFE`, `TRIAGE_NURSE`, `PHYSIOTHERAPIST`); `DOCTOR` covers 6.

**(b) Packs to per-screen classes.** A screen only branches on the permissions its
`*_access.dart` actually references. Reception references 9 live keys, so the 38 packs
collapse to 20 outcome classes there — and to 16 once you evaluate real seeded *accounts*
(which hold unions via `extra_roles`).

**(c) Classes to seeded accounts.** 58 accounts are seeded by
`backend/scripts/seeders/seed-catalog.js`; pick one per class.

Result across all 23 live screens: **~204 screen x persona cases**, an 87% cut, with a script
proving nothing was dropped.

Per-screen class counts (from the generator in Appendix A):

| Screen | Classes | Screen | Classes | Screen | Classes |
| ------ | ------: | ------ | ------: | ------ | ------: |
| nursing | 23 | pharmacy | 9 | accounts | 6 |
| reception | 20 | theater | 9 | reports | 6 |
| discharge | 14 | billing | 8 | subscriptions | 3 |
| patient_registry | 14 | radiology | 8 | profile | 2 |
| hr | 11 | claims | 7 | tenant_facility_setup | 2 |
| clinical | 10 | settings | 7 | home | 1 |
| lab | 10 | access_admin | 6 | | |
| icu / ipd / opd | 9 each | | | | |

Nursing and Reception carry the most branching — which is why Reception first is the right
call: it shakes out the harness on the second-hardest screen.

---

## 3. Test layers (cheapest first)

Run in this order per screen. A failure at layer *n* makes layer *n+1* noise, so stop and fix.

| Layer | What | Where | Cost | Catches |
| ----- | ---- | ----- | ---- | ------- |
| **L0 Static** | catalog parity, route atom uniqueness, disabled-domain stripping | `frontend/test/core/permissions/`, `backend/src/tests/` | seconds | drift between BE and FE catalogs |
| **L1 API** | per-persona 200/403 on the screen's endpoints | Jest, `backend/src/tests/` | seconds | **over-grant — the security bug that matters** |
| **L2 Gate** | `AccessRequirement.isAllowed` per persona for every control | `flutter test`, pure Dart | seconds | UI gate wrong vs. documented matrix |
| **L3 Widget** | screen renders correct controls under a mocked policy | `flutter test` + `integration_test` | ~1 min | gate correct but control not wired to it |
| **L4 E2E** | real login, real backend, real navigation | `patrol_test/` | minutes | session/module/ABAC integration |
| **L5 Manual** | only what L0-L4 cannot express | browser | slow | layout, copy, judgement |

L0-L3 need no backend. L4 needs `npm run db:reset:demo` + `npm run dev`.

**Do not push a persona up to L4 unless it is one of:** the canonical allowed persona, the
canonical denied persona, or a *partial* persona (read-but-not-write). Everything else stays
at L1+L2. That is the difference between a 2-day pass and a 3-week one.

### Existing assets — reuse, don't rebuild

- `frontend/test/core/permissions/` already has 11 suites incl.
  `app_permission_catalog_parity_test.dart`, `route_access_catalog_test.dart`,
  `custom_role_rbac_accuracy_test.dart`, `version_disabled_permissions_test.dart`.
- `frontend/integration_test/module_navigation_test.dart` already deep-links every workspace
  route with a mocked session — extend it per persona rather than writing a new suite.
- `frontend/patrol_test/` has 17 flow suites and a real-login harness
  (`helpers/patrol_harness.dart`, `helpers/demo_credentials.dart`).
- `DemoAccount` currently wires **18 of the 58** seeded accounts. Extending that enum is the
  single highest-leverage change in this plan (see §6).

---

## 4. The per-screen loop

Repeat this for each screen in §5. Budget ~half a day per screen after the first.

**Step 1 — Generate the matrix.** Run the Appendix A generator for the screen. Output:
its permission surface, its classes, and one seeded account per class.

**Step 2 — Inventory the controls.** Every `*_access.dart` already documents its tab and
action atoms (Reception's, for example, maps each Appointments / Desk-queue control to its
permission). Turn that into a flat list: *control -> requirement -> expected personas*.
If a control has no entry in the access file, that is finding #1.

**Step 3 — Write expectations before running anything.** Fill the table in Step 6 with the
expected verdict for every (persona x control) cell **from the access file, not from the
running app**. Testing against observed behaviour proves only that the app agrees with
itself.

**Step 4 — Run L0 through L4.** Record actuals.

**Step 5 — Triage.** Severity is not about how visible the bug is:

| Class | Symptom | Severity |
| ----- | ------- | -------- |
| **Over-grant** | persona reaches a control/endpoint it should not | **P0** — security |
| **UI/API disagree** | UI hides it, API allows it (or vice versa) | **P0** — the hidden half is exploitable |
| **Under-grant** | authorised persona blocked | P1 — breaks the job |
| **Dead control** | no persona can reach it | P2 -> §7 simplification |
| **Phantom distinction** | two personas differ in role but never in outcome | P3 -> §7 |

**Step 6 — Record.** One file per screen at `plans/results/<screen>.md`:

```markdown
# <Screen> — access verification
Commit: <hash>   Date: <date>   Backend: <seed state>

| Persona (account) | Class grants | Route | Tab A | Action B | ... | API parity |
| ----------------- | ------------ | ----- | ----- | -------- | --- | ---------- |
| reception@        | patient:read,write; last_office:read | OK | OK | OK | | OK |
| hr@               | (none)       | DENIED (expected) | - | - | | DENIED |

## Findings
| # | Class | Persona | Control | Expected | Actual | Severity |
```

Legend: `OK` allowed-and-expected · `DENIED` denied-and-expected · `OVER` over-grant ·
`UNDER` under-grant · `DEAD` unreachable control.

---

## 5. Screen order

Follow the patient journey, not the menu. Each screen's E2E run leaves data the next one
consumes (a registered patient -> an OPD visit -> an order -> a result -> a bill), so this
ordering removes most fixture setup.

| # | Screen | Route | Why here |
| - | ------ | ----- | -------- |
| 1 | **Reception** | `/reception` | your pick; 20 classes, exercises patient/clinical/billing cross-domain gates — hardest harness shakedown |
| 2 | Patient Registry | `/patients` | 14 classes; note `pharmacist` is deliberately excluded (`default_user_roles.mdc`) |
| 3 | OPD | `/opd` | consumes #1's appointments |
| 4 | Clinical | `/clinical` | the doctor-side twin of OPD — **test the overlap explicitly** (same action, two entry points, must give the same verdict) |
| 5 | Lab | `/lab` | orders from #4; walk-in lab-order path is a separate class |
| 6 | Radiology | `/radiology` | tech vs radiologist (acquire vs interpret) |
| 7 | Pharmacy | `/pharmacy` | dispense vs stock vs `PHARMACY_BILLING` |
| 8 | IPD | `/ipd` | admissions from #3 |
| 9 | ICU | `/icu` | `ICU_DOCTOR` / `ICU_MANAGER` are distinct packs |
| 10 | Nursing | `/nursing` | **23 classes — the heaviest**; do it once the harness is proven |
| 11 | Theater | `/theater` | `SURGEON`/`ANESTHESIOLOGIST` share a pack; `THEATRE_MANAGER` does not |
| 12 | Discharge | `/discharge` | 14 classes; `DISCHARGE_PLANNER` is a `NURSE` alias — verify that is intended |
| 13 | Billing | `/billing` | consumes everything upstream |
| 14 | Accounts | `/accounts` | `hr_staff` **must not** reach it; billing-only packs must not either |
| 15 | Claims | `/claims` | requires the `insurance-claims` module |
| 16 | HR | `/hr` | 11 classes; HR gets Facility-Admin user/role tabs but no Accounts |
| 17 | Reports | `/reports` | scope-limited per role — check row scoping, not just entry |
| 18 | Setup | `/admin/setup` | the three tiers below |
| 19 | Access Admin | `/admin/access` | `requiresTenantContext: true`; also where custom roles are made |
| 20 | Subscriptions | `/subscriptions` | the ceiling gate itself |
| 21 | Settings / Profile / Home | `/settings`, `/profile`, `/` | authenticated-core: must work for *every* account incl. `patient.portal@` and `visitor@` |
| 22 | **Disabled sweep** | 9 routes | all 9 must 403/404 for **all 58 accounts**, platform owner included |

### Setup tiers (#18)

You named three levels; they are distinct gates, test all three:

- **Tenant setup** — `TENANT_ADMIN`, cross-facility scope.
- **Facility setup** — `FACILITY_ADMIN`, `ADMIN_ACCESS` minus tenant-scoped keys.
- **Basic/partial setup** — anything holding `setup:read` without admin packs (e.g. HR's
  facility user/role tabs). Verify the *tab set* differs, not just that the route opens.

The route atom is a single `setup:read`, so the tier distinction lives entirely in-screen —
which makes it the most likely place for an over-grant to hide.

---

## 6. Prerequisites (do these once, before screen #1)

1. **Extend `DemoAccount`.** `frontend/patrol_test/helpers/demo_credentials.dart` wires 18
   accounts; the class analysis needs at least these 5 more for Reception alone —
   `pathologist@`, `pharmacy.billing@`, `coder@`, `paramedic@`, `mortuary.manager@` — and
   more for later screens. Generate the enum from `seed-catalog.js` rather than hand-editing.
2. **Seed a known backend.**
   ```bash
   cd backend && npm run prisma:migrate:deploy && npm run db:reset:demo && npm run db:verify:demo
   ```
   Seeds are deterministic (`SEED_RANDOM_SEED`), so re-seed between screens freely.
   Password for all seeded accounts is the committed dev default documented in
   `patrol_test/README.md`; override with `SEED_DEFAULT_PASSWORD`.
3. **Green baseline.** `cd backend && npm run test:all` and `cd frontend && flutter test`.
   Verify against a known-good baseline before starting; investigate pre-existing failures
   first so they are not mistaken for findings later.
4. **Land the generator** (Appendix A) as `tools/access_matrix.js` and commit its output for
   all 23 screens as `plans/matrices/<screen>.md`. This is the expectation baseline for
   Step 3 and the diff target for regressions.
5. **Add a subscription axis.** Pick two plans — lowest tier and highest — and run every
   screen's *route* check under both. Role-level testing under one plan cannot see
   subscription-cap bugs.

---

## 7. The simplification pass

Run this **after** a screen's verification is green, using its own results table. Simplify
from evidence, never ahead of it — deleting a control before you know who reaches it is how
authorised users lose function.

Four candidates, in descending confidence:

1. **Dead controls.** No persona in any class reaches it under any plan. Either the gate
   is wrong (P1 bug) or the control is dead (delete). Check `git log` on the access file
   before deleting — a recently-added gate is more likely wrong than dead.
2. **Phantom role distinctions.** Two roles with identical packs *and* identical outcomes on
   every screen. The 32 `DERIVED_ROLE_PARENTS` aliases exist for labelling (job title in HR),
   which is legitimate — but any *base* pack that never differs from another base pack is a
   real duplication. `roles.js` already says: avoid identical packs under different codes.
3. **Disabled-domain residue.** The 9 disabled domains still ship code, menu entries and
   access files. Once §5 #22 proves they are unreachable, they are the largest single
   simplification available — but that is a release decision, so record the finding and stop
   there.
4. **Duplicate entry points.** Where the same action is reachable from two screens (OPD and
   Clinical, Reception and the OPD front desk), keep both only if the verification shows they
   give the *same* verdict. Two entry points with different gates is a bug, not a feature.

Do not consolidate permission keys. One `*:read` key per destination is a deliberate
invariant (`permissions.mdc`); merging them breaks route gating and the parity tests.

---

## 8. Definition of done

**Per screen:**

| Check | Expected |
| ----- | -------- |
| Matrix generated and committed | `plans/matrices/<screen>.md` |
| Expectations written before execution | Step 3 table filled from access files |
| Every class has at least one executed persona | no empty rows |
| L1 API parity for every class | UI verdict equals API verdict, both directions |
| L2 gate assertions | one per control per class |
| L4 E2E | allowed + denied + partial personas at minimum |
| Over-grants | zero, or filed P0 with a reproduction |
| Under-grants | zero, or filed P1 |
| Results file | `plans/results/<screen>.md` committed |

**Overall:**

- All 23 live destinations have a green results file.
- All 9 disabled destinations deny all 58 accounts, including `platform.owner@`.
- Both subscription tiers exercised on every route.
- Simplification findings filed per §7; deletions made only against evidence.
- `npm run test:all` and `flutter test` green; new L1/L2 assertions added to CI so the
  matrix cannot silently drift.

---

## 9. Reception — ready to execute

Generated from `reception_access.dart` (9 live permission keys: `patient:read/write/delete`,
`clinical:read/write`, `billing:read/write`, `last_office:read`, `evidence:export`;
modules `patient-registry`, `scheduling-queue`, `billing-payments`, `insurance-claims`).
`emergency:read` and `operations:read` are referenced but version-disabled — **that is a test
case**: no persona may gain anything through them.

Route gate: `reception:read` plus modules. In-screen gates are broader (`patient:read` or
`last_office:read`), so expect route-open-but-empty personas — verify they get a usable
fallback tab, not a blank workspace.

58 accounts collapse to **16 personas**:

| # | Account | Role | Grants on this screen | Covers | Wired? |
| - | ------- | ---- | --------------------- | -----: | ------ |
| 1 | `nurse@` | NURSE | clinical:r/w, last_office:read, patient:r/w | 11 | yes |
| 2 | `doctor@` | DOCTOR | clinical:r/w, patient:r/w | 11 | yes |
| 3 | `radiology@` | RADIOLOGY_TECH | patient:read | 9 | yes |
| 4 | `hr@` | HR | **(none)** | 5 | yes |
| 5 | `platform.owner@` | PLATFORM_OWNER | all 9 incl. patient:delete | 4 | yes |
| 6 | `reception@` | RECEPTIONIST | last_office:read, patient:r/w | 4 | yes |
| 7 | `operations@` | OPERATIONS | evidence:export, last_office:read | 3 | yes |
| 8 | `biomed@` | BIOMED | evidence:export | 2 | yes |
| 9 | `lab@` | LAB_TECH | patient:r/w | 2 | yes |
| 10 | `accountant@` | ACCOUNTANT | billing:r/w, evidence:export, patient:read | 1 | yes |
| 11 | `billing@` | BILLING | billing:r/w, evidence:export, last_office:read, patient:read | 1 | yes |
| 12 | `pathologist@` | PATHOLOGIST | clinical:read, patient:r/w | 1 | **no** |
| 13 | `pharmacy.billing@` | PHARMACY_BILLING | billing:r/w, last_office:read, patient:read | 1 | **no** |
| 14 | `coder@` | MEDICAL_CODER | billing:read, patient:read | 1 | **no** |
| 15 | `paramedic@` | PARAMEDIC | clinical:read, patient:read | 1 | **no** |
| 16 | `mortuary.manager@` | MORTUARY_MANAGER | evidence:export, patient:read | 1 | **no** |

Five accounts (12-16) need adding to `DemoAccount` first — prerequisite §6.1.

**Sharpest cases on this screen — write these first:**

- **#6 `reception@` is the reference persona.** Its pack deliberately omits `patient:delete`,
  so *Cancel appointment* must fall back to the front-desk gate, not the delete gate. The
  access file documents this; confirm the code agrees.
- **#5 `platform.owner@` is the only persona with `patient:delete`.** It is the sole positive
  case for the delete path — and the check that `evidence:export` does not leak a delete.
- **#4 `hr@` holds none of the 9 keys.** Route must deny outright. If it opens at all, that
  is a P0. It is also the cleanest probe for whether denial is a clean 403 or a broken shell.
- **#8 `biomed@` holds only `evidence:export`.** Export without read — either the route
  denies, or Export appears with nothing to export. Both are defensible; the access file
  should say which, and if it does not, that is a finding.
- **#3 `radiology@` has read but no write.** The canonical *partial* persona; send to L4.
- **#12 vs #2:** `pathologist@` has `clinical:read` where `doctor@` has `clinical:read+write`.
  One permission apart; the smallest real behavioural delta on the screen and the most likely
  place for a gate to be written with the wrong key.

**Minimum L4 (Patrol) set — 4 of 16:** `reception@` (allowed), `hr@` (denied),
`radiology@` (partial), `platform.owner@` (full incl. delete). The other 12 stay at L1+L2.

---

## Appendix A — matrix generator

Save as `tools/access_matrix.js`; run with
`NODE_PATH=backend/node_modules node tools/access_matrix.js [screen]`.

It reads the backend catalogs and the frontend access files, so it cannot drift from the app.
It is a *derivation*, not a test: it tells you what the code claims. The verification is
proving the running app matches.

```js
const path = require('path');
const fs = require('fs');
const ma = require('module-alias');

const ROOT = path.resolve(__dirname, '..');
const BE = path.join(ROOT, 'backend');
const FE = path.join(ROOT, 'frontend');
ma.addAliases({ '@config': path.join(BE, 'src/config'), '@lib': path.join(BE, 'src/lib') });

const { ROLE_PERMISSIONS, PERMISSIONS } = require(path.join(BE, 'src/config/permissions'));
const { filterVersionDisabledPermissionNames } =
  require(path.join(BE, 'src/config/version-disabled-permissions'));

// AppPermissions.camelCase -> "resource:action"
const byCamel = {};
for (const v of Object.values(PERMISSIONS)) {
  byCamel[v.replace(/[:_](\w)/g, (_, c) => c.toUpperCase())] = v;
}

// Seeded accounts, including extra_roles unions.
const catalog = fs.readFileSync(path.join(BE, 'scripts/seeders/seed-catalog.js'), 'utf8');
const accounts = [...catalog.matchAll(
  /\{ key: '([^']+)', role: '([^']+)', email: '([^']+)'[^}]*?(?:extra_roles: \[([^\]]*)\])?[^}]*\}/g
)].map((m) => ({
  key: m[1],
  role: m[2],
  email: m[3],
  extras: (m[4] || '').split(',').map((s) => s.trim().replace(/'/g, '')).filter(Boolean),
}));

const wired = new Set(
  fs.readFileSync(path.join(FE, 'patrol_test/helpers/demo_credentials.dart'), 'utf8')
    .match(/[a-z0-9._]+@hosspi\.com/g) || []
);

const accessFiles = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('_access.dart')) accessFiles.push(p);
  }
})(path.join(FE, 'lib/features'));

const only = process.argv[2];

for (const file of accessFiles) {
  const screen = path.basename(file).replace('_access.dart', '');
  if (only && screen !== only) continue;

  const src = fs.readFileSync(file, 'utf8');
  const referenced = [...new Set(
    [...src.matchAll(/AppPermissions\.(\w+)/g)].map((m) => byCamel[m[1]]).filter(Boolean)
  )];
  const surface = filterVersionDisabledPermissionNames(referenced).sort();
  const stripped = referenced.filter((p) => !surface.includes(p));

  const classes = new Map();
  for (const a of accounts) {
    const eff = new Set();
    for (const r of [a.role, ...a.extras]) for (const p of ROLE_PERMISSIONS[r] || []) eff.add(p);
    const live = new Set(filterVersionDisabledPermissionNames([...eff]));
    const sig = surface.filter((p) => live.has(p)).join(', ') || '(none)';
    if (!classes.has(sig)) classes.set(sig, []);
    classes.get(sig).push(a);
  }

  console.log(`\n## ${screen} — ${classes.size} personas / ${accounts.length} accounts`);
  console.log(`surface: ${surface.join(', ') || '(none)'}`);
  if (stripped.length) console.log(`version-disabled (must grant nothing): ${stripped.join(', ')}`);
  console.log('');
  console.log('| # | Account | Role | Grants | Covers | Wired |');
  console.log('| - | ------- | ---- | ------ | -----: | ----- |');

  [...classes].sort((a, b) => b[1].length - a[1].length).forEach(([sig, members], i) => {
    const pick = members.find((m) => wired.has(m.email)) || members[0];
    console.log(
      `| ${i + 1} | ${pick.email} | ${pick.role} | ${sig} | ${members.length} | ` +
      `${wired.has(pick.email) ? 'yes' : '**no**'} |`
    );
  });
}
```

---

## Appendix B — commands

```bash
cd backend && npm run prisma:migrate:deploy && npm run db:reset:demo && npm run db:verify:demo
```

```bash
cd backend && npm run test:all
```

```bash
cd frontend && flutter test test/core/permissions test/app/router
```

```bash
cd frontend && flutter test integration_test
```

```bash
cd frontend && patrol test -t patrol_test/reception_flow_test.dart -d chrome --dart-define-from-file=env/development.json.example
```
