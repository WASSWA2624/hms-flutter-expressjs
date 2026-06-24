# OPD Triage Module — Implementation Prompt

## Objective

Complete **OPD Triage** for HOSSPI HMS so nurses and front-office staff can capture pre-consultation triage end-to-end: vital signs, chief complaint, priority/triage level, triage notes, emergency indicators, and **routing decisions** before doctor consultation — aligned with OPD flow stages and distinct from Emergency department triage where applicable.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — OPD triage vs OPD flow vs Emergency boundaries
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — `WAITING_VITALS`, nurse role §5, entry paths §2
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — urgent routing to admission when triage indicates (via disposition, not triage-owned)

**Central rule:** triage data attaches to the **OPD encounter** (or triage queue row linked to it). Triage does not create duplicate OPD encounters. Emergency cases use `triage-assessments` on the emergency case — coordinate boundaries with [prompts/13-emergency-module-prompt.md](./13-emergency-module-prompt.md).

**Note:** There is no standalone `features/triage/` route — triage is implemented across OPD workspace, Clinical worklist, Patient registry quick actions, and Emergency. This prompt defines the **cross-cutting triage contract** to keep implementations aligned.

---

## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Triage responsibility |
| ----------- | ------------------- |
| `WAITING_VITALS` | Primary triage queue stage — record vitals, complaint, priority |
| `WAITING_DOCTOR_ASSIGNMENT` | Nurse-supported provider assignment when role permits |
| §5 Nurse role | Vitals and triage capture — no doctor disposition from triage UI alone |
| §6 UI rules | Reuse `AppRecordVitalsDialog`, shared triage components in `frontend/lib/shared/` |
| §2 Entry paths | Walk-in and appointment patients enter triage after registration/payment gate |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Triage responsibility |
| ----------- | ------------------- |
| Urgent admit | Triage may flag urgency; **admission** is doctor/disposition via OPD — not triage module |
| §2.1 Emergency | ED triage is Emergency module — do not mix ED assessment APIs with OPD `/triage` |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Triage implementation |
| ------------ | --------------------- |
| OPD triage row | Vitals, complaint, priority, notes, routing before consultation |
| OPD flow row | Owns queue stages after triage routes patient forward |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| OPD triage API | `backend/src/modules/triage/` | `GET /triage`, `POST .../record-vitals`, `assign-provider`, `route`, `correct-stage` |
| OPD flow vitals | `opd-flow` | Embedded vitals on encounter |
| OPD UI | `opd_workspace_page.dart`, `opd_repository_impl.dart` | Triage queue integration |
| Clinical UI | `clinical_workspace_page.dart` | `listTriageQueue` handoff |
| Patient registry | Quick triage dialog | Routes to OPD APIs |
| Emergency | `triage-assessments` | Separate entity for ED |
| Shared UI | `app_triage_components`, `opd_encounter_dialog` | Reusable vitals/triage fields |

### Known gaps

- Split model: `/triage` flow queue vs `/triage-assessments` on emergency cases
- Nursing workspace lacks dedicated OPD vitals queue (see [prompts/15-nursing-module-prompt.md](./15-nursing-module-prompt.md))
- No dedicated triage workspace backend aggregator (unlike lab/pharmacy workbench)
- OPD and Emergency triage UIs use different entities — document mapping
- No standalone `/triage` route in Flutter router

---

## Scope — Core Capabilities

1. **Unified triage contract** — document which API owns which context (OPD vs ED).
2. **Vitals capture** — `AppRecordVitalsDialog` + triage level, complaint, notes, emergency flags.
3. **Routing** — forward to doctor queue, ED, or hold for payment per backend `route` action.
4. **Queue visibility** — OPD `WAITING_VITALS` worklist shows next action and responsible nurse role.
5. **Correction** — `correct-stage` with reason when triage routed incorrectly.

---

## Acceptance Criteria

- [ ] OPD patients in `WAITING_VITALS` can complete triage and advance via backend APIs.
- [ ] No duplicate OPD encounters created during triage.
- [ ] ED triage stays in Emergency module; OPD triage uses `/triage` or opd-flow vitals consistently.
- [ ] Shared triage components reused across OPD, Clinical, Patients quick actions.
- [ ] Hospital-language labels; no raw enum names in UI.

---

## Key File References

```
backend/src/modules/triage/
backend/src/modules/triage-assessment/
backend/src/modules/opd-flow/
frontend/lib/features/opd/
frontend/lib/shared/ (triage/vitals components)

Related prompts: prompts/12-opd-module-prompt.md, prompts/15-nursing-module-prompt.md, prompts/08-patients-module-prompt.md, prompts/13-emergency-module-prompt.md
```
