# Clinical Services — Configure Radiology (tenant / facility scope)

**Screen:** `/admin/setup?section=clinical-services`  
**Active nested tab:** Radiology (also Lab / Diagnoses exist; this prompt focuses on the Radiology **Configure** flow shown in screenshots)

## Screen chrome (Radiology tab)

- Nested tabs: **Radiology** | **Lab** | **Diagnoses**
- Search: placeholder *Search by name, code, or category*
- Toolbar: **Filters** | **Settings** | **Configure** | **+ Create imaging test**
- Table columns: `#` | **Name** | **Test code** | **Modality** | **Actions** (Edit / Delete)

## Goal

When the user clicks **Configure** on the Radiology tab, run a stepped wizard that configures radiology offerings for a given **tenant** and/or **facility** scope. Keep the flow simple: pick scope → browse platform catalog → set price(s) → enable.

---

## Step 1 — Select tenant and facility

**Dialog title:** SELECT TENANT AND FACILITY  
**Copy:** *Select tenant and facility to configure the radiology catalog.*  
**Fields:** Select tenant * | Facility *  
**Footer:** Cancel | Next (Next disabled until scope is valid)

### Role-based scope behavior

| Actor | Behavior |
| ----- | -------- |
| Super admin | Show tenant + facility pickers. Selecting a **facility** auto-selects its tenant. Selecting a **tenant** alone may allow tenant-scoped configuration, or the user may then pick a facility under that tenant. |
| Tenant admin (or other admin with tenant access) | Can select a facility under their tenant. Tenant is fixed / pre-filled as appropriate. |
| Facility admin | **Skip this step.** Tenant and facility are set automatically from the session. Proceed straight to Enable radiology offering. |

**Next** becomes active only when the required scope for the actor is complete (tenant + facility when both are required; auto-resolved pair for facility admin).

---

## Step 2 — Enable radiology offering

**Dialog title:** ENABLE RADIOLOGY OFFERING  
**Copy:** *Select a catalog procedure and set the facility price.*  
**Chrome:** Search (*Search tests, modality, code, source, or status*) | Filters | Settings  
**Table columns:** `#` | **Name** | **Code** | **Modality** | **Status** (e.g. Available)  
**Footer:** Close (dismisses the whole configure wizard). Prefer **Back** to return to Step 1 when that step was shown.

- List is the platform pre-configured radiology procedures/tests.
- User can select **one or more** offerings in one pass (multi-select) so enabling several procedures is as simple as possible.
- Selecting a not-yet-enabled row proceeds to Step 3 (price) for that selection (or for the batch when multi-select is used).

---

## Step 3 — Enable procedure (price)

**Dialog title:** ENABLE PROCEDURE  
**Header:** Procedure name + metadata (e.g. `RAD-05245 · FLUOROSCOPY`)  
**Field:** Unit price * with currency selector  
**Footer primary:** **Enable procedure**

### Currency / scope rules

- If the configure scope is **facility**, use the **facility** currency (default).
- If the configure scope is **tenant**, use the **tenant** currency.
- All enable writes must respect the active scope (tenant vs facility) for the rest of the wizard.

After enable, return to Step 2 so more offerings can be enabled, or close when done. On the last step of a batch, **Enable procedure** (or equivalent) commits into the selected scope.

---

## Navigation rules

- This is one continuous wizard, not a stack of unrelated dialogs: **Back** / **Next** (or Close) between steps.
- **Close** / Cancel at any step dismisses the entire configure flow.
- Scope chosen in Step 1 stays in force through Steps 2–3.

## Acceptance criteria

1. **Configure** on Radiology opens the scope step (or skips it for facility admin).
2. Facility selection auto-fills tenant; Next stays disabled until scope is valid.
3. Step 2 shows platform radiology catalog with search/filters and Close/Back.
4. Step 3 sets unit price in the correct tenant/facility currency and enables into that scope.
5. Multi-select of offerings is supported; flow stays simple end-to-end.
)
