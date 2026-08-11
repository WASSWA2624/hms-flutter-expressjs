# IPD tab — Discharge planned

## 1. Tab strip

- Label: `ipdDischargeTabLabel`
- Icon: `Icons.fact_check_outlined`
- Count source: `state.dischargePlannedCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `discharge` (aliases `discharge-planned`, …)
- Tab gate: `IpdDischargeAtomPermissions.tab`
- **Omitted when unauthorized**
- Scope: `IpdQueueScope.dischargePlanned`

## 2. Search / Filters / Settings / Export / Print / context

**Filters → Settings → Export → Start admission**; table Print **absent**. Manage beds not mounted.

## 3. Table

- Row model: discharge-planned `IpdAdmissionSummary`
- Row select → admission detail
- Default columns: Patient, Location, Admitted at, Status, Next action
- Column choices: Owner role, Length of stay
- Next action often Plan/Manage discharge

## 4. Advanced filters / search fields

Same IPD filter model (ward, bed, critical, ICU, dates, ids). Transfer-status group **not** added for Discharge section (only admission queue / active / transfers).

## 5. Primary / secondary / row actions

- Start admission when operational write allows
- Next action: plan/manage discharge (clinical), plus other kinds if stage maps
- Detail: Release bed when discharge planned + active bed (operational)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Admission detail | IPD-owned |
| Discharge planning / manage | **reused** discharge feature dialogs |
| Release bed | **reused** shared ipd release-bed |
| Start admission | IPD-owned |

## 7. Nested / follow-on

`panel=discharge` → clinical write. Open billing for final bill / outstanding (billing read; never cashier). Insurance/billing panels when authorized.

## 8. Forms (summary)

Discharge plan fields; release bed confirm; start admission; clinical orders from detail.

## 9. Print / labels / preview

- Table Print: **absent**

## 10. Loading / empty / error / success

Shared IPD queue feedback.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome | board read ∪ |
| Plan/Manage discharge / nursing | clinical write ∩ |
| Start admission / Release bed / transfers | operational write ∪ |
| Open billing / billing panel | ∩ `billing:read` |
| `panel=discharge` | clinical write ∩ |
| Manage beds | not mounted |
