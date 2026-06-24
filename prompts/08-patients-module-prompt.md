# Patient Registry Module — Implementation Prompt

## Objective

Complete the **Patient Registry Module** for HOSSPI HMS so registration staff and clinicians can manage patients end-to-end: search and register, maintain demographics and identifiers, contacts and guardians, allergies and medical history, documents and consent, duplicate detection/merge, and **launch** OPD/IPD/Emergency workflows without duplicating patient master records.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Patient registry boundaries vs OPD, Clinical, IPD, Emergency, Billing
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §2 entry paths (search patient first, register if needed)
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §2 admission paths, step 3 registration, §16 encounter links to patient

**Central rule:** one **patient master record** per person per tenant scope. OPD encounters, IPD admissions, and emergency cases reference `patient_id` — the registry does not own clinical queues or bed assignment.

Deliver a **search-first registry workspace**: fast lookup, safe registration, rich patient detail, and contextual quick actions to start downstream flows.

---

## Flow Integration Requirements

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Patient registry responsibility |
| ----------- | ----------------------------- |
| §2 Walk-in / new patient | Search existing patient first; register only when no match |
| §2 Appointment check-in | Verify patient identity before check-in handoff to OPD |
| Start OPD encounter | Quick action → `startOpdFlow` / bootstrap with `patient_id` — registry does not own OPD stages |
| Triage vitals | Optional quick triage dialog routes to OPD/triage APIs on same patient |

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Patient registry responsibility |
| ----------- | ----------------------------- |
| Step 3 Registration | Complete demographics for `Pending Registration` admissions |
| §2.1 Emergency | Support minimal/temporary registration; complete later |
| Admit from registry | Link to IPD `startAdmission` with verified `patient_id` |
| §16 Encounter hub | Patient is parent of encounter — show read-only clinical summary links |

### App write-up (`../.cursor/app-write-up.mdc`)

| Product rule | Patient registry implementation |
| ------------ | ------------------------------- |
| Patient registry row | Demographics, identifiers, contacts, guardians, allergies, documents, consent, lookup |
| OPD/IPD boundary | Registry launches flows; does not replace OPD/IPD workspaces |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/patients/` | `patient_registry_page.dart`, controller, repository |
| Backend | `backend/src/modules/patient/` + related resources | CRUD, workspace overview, duplicates, merge |
| Key APIs | `GET/POST/PUT /patients`, `/patients/workspace/overview`, `/patients/duplicates`, `/merge`, `/:id/workspace` | Aggregate and granular |
| Quick actions | OPD start, vitals/triage, IPD disposition hooks | Embedded in registry page |
| Localization | `app_en.arb` | Patient strings substantial |

### Known gaps

- Monolithic registry page (~7k lines) — extract panels/widgets
- Per-patient workspace API underused vs client-side composition
- Emergency minimal registration path incomplete vs full demographics
- Deep links from OPD/IPD/Emergency to patient detail with context
- Frontend tests limited

---

## Scope — Core Capabilities

1. **Search and register** — fast search; create with required identifiers and consent flags.
2. **Patient detail** — contacts, guardians, allergies, history, documents; edit with permission gates.
3. **Duplicates and merge** — preview and merge with audit trail.
4. **Quick actions** — start OPD, triage vitals, open clinical context — without duplicating flow UIs.
5. **Cross-navigation** — links to active OPD encounter, IPD admission, billing ledger when permitted.

---

## Module Boundaries

- Do not own OPD queues, IPD bed board, or clinical documentation depth (Clinical module).
- Do not post charges — Billing owns financial records.

---

## Acceptance Criteria

- [ ] Staff can search, register, and maintain patient records end-to-end.
- [ ] OPD/IPD quick actions use correct patient and do not duplicate encounters/admissions.
- [ ] Duplicate merge works with confirmation and audit.
- [ ] No raw UUIDs in UI; permissions enforced.

---

## Key File References

```
frontend/lib/features/patients/
backend/src/modules/patient/

Related prompts: prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/13-emergency-module-prompt.md, prompts/11-triage-module-prompt.md
```
