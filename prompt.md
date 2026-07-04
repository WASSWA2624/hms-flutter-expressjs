## Bug: Enable lab offering fails with "Connection problem"

### Context
- **App:** HOSSPI Hospital Management (`http://127.0.0.1:5201/lab`)
- **Role:** Super admin
- **Feature:** Lab → Lab Configurations → **Enable lab offering** → select a platform catalog item → set unit price → **Enable test** / **Enable panel**

### Observed behavior
When enabling a platform lab test or panel at a facility, the price dialog shows:

> **Connection problem**  
> Check your connection and try again.

Reproduced for at least:
- **Test:** `1,3 beta glucan [Mass/volume] in Serum | 42176-8` — unit price `50,000 UGX`
- **Panel:** `Abdominal Pain Panel | ABDP` — unit price `40,000 UGX`

The catalog list loads and search works; the failure occurs only on submit.

### Prior / related symptoms
- Earlier attempts returned an **invalid ID** error (frontend); the backend did not surface a corresponding error in logs.
- One test (CBC) may already be enabled; other catalog items still fail on enable.

### Expected behavior
Submitting **Enable test** or **Enable panel** with a valid unit price and currency should create or update the facility offering and close the dialog successfully.

### Investigation scope
Trace the full enable flow end to end and align frontend, API, and database:

1. **Frontend**
   - `LabEnableFacilityOfferingDialog` / `_LabEnableOfferingPriceDialog` in `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
   - `LabWorkspaceController.updateLabTest` / `updateLabPanel` and `LabRepositoryImpl.upsertFacilityLabTestOffering` / `upsertFacilityLabPanelOffering`
   - Confirm the ID sent in the request (`item.apiId`) matches what the backend expects
   - Confirm failures are mapped correctly (`AppFailure.network` vs validation/server errors)

2. **Backend**
   - `PUT /api/v1/facility-lab-catalog/tests/:id` and `.../panels/:id`
   - `facility-lab-catalog` service/repository upsert logic and validation schema
   - Ensure errors (invalid ID, missing tenant/facility scope, validation) return actionable HTTP responses and are logged

3. **Database**
   - Verify `facility_lab_test_offering` / `facility_lab_panel_offering` rows are created/updated for the selected tenant, facility, and catalog item

### Acceptance criteria
- Enable test/panel succeeds for catalog items not yet offered at the facility
- Real API/validation errors show accurate messages (not a generic connection error when online)
- Backend logs reflect failed requests with enough detail to diagnose ID/scope issues
- Frontend catalog refreshes and shows the newly enabled item with the configured price
