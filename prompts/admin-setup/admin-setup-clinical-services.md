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
**Footer:** **Back** | Close | **Next** (when one or more available rows are selected)

- List is the platform pre-configured radiology procedures/tests.
- User can select **one or more** offerings in one pass (multi-select).
- **Next** opens the preview step (not the price form yet).
- **Back** returns to Step 1 when that step was shown; otherwise dismisses configure.

---

## Step 3 — Review selection (preview)

**Dialog title:** REVIEW SELECTION  
**Copy:** Review the procedures to enable. Deselect any you want to remove, then continue to set each price individually.  
**Footer:** **Back** (to Step 2) | Close | **Next** (requires at least one remaining selection)

- Shows only the selected procedures with checkboxes so the user can deselect before pricing.
- **Next** starts individual pricing for each remaining selection.

---

## Step 4 — Enable procedure (price, one at a time)

**Dialog title:** ENABLE PROCEDURE  
**Header:** Procedure name + metadata (e.g. `RAD-05245 · FLUOROSCOPY`)  
**Progress (multi):** *Procedure N of M*  
**Field:** Unit price * with currency selector  
**Footer:** **Back** | Close | **Enable procedure**

- Each selected procedure is priced **individually** (never a shared batch price).
- **Enable procedure** commits that one offering, then advances to the next selected item.
- **Back** on the first priced item returns to preview; on later items returns to the previous procedure in the queue.
- After the last item is enabled, return to Step 2 so more offerings can be configured.

### Currency / scope rules

- If the configure scope is **facility**, use the **facility** currency (default).
- If the configure scope is **tenant**, use the **tenant** currency.
- All enable writes must respect the active scope (tenant vs facility) for the rest of the wizard.

---

## Navigation rules

- This is one continuous wizard, not a stack of unrelated dialogs: **Back** / **Next** / **Close** between steps.
- **Close** / Cancel at any step dismisses the entire configure flow.
- Scope chosen in Step 1 stays in force through Steps 2–4.

## Acceptance criteria

1. **Configure** on Radiology opens the scope step (or skips it for facility admin).
2. Facility selection auto-fills tenant; Next stays disabled until scope is valid.
3. Step 2 shows platform radiology catalog with search/filters and **Back** / Close / Next.
4. Step 3 preview lets the user deselect items or go **Back** to the catalog.
5. Step 4 sets unit price **per procedure** in the correct tenant/facility currency and enables into that scope.
6. Multi-select is supported end-to-end via catalog → preview → individual prices.
)
