# Actions / confirmations

[Index](README.md)

_Actions / confirmations (8)_

| Symbol | Purpose | Defined in | Kind | Extends / uses | Paired opener(s) | Used from |
| --- | --- | --- | --- | --- | --- | --- |
| `_showVoidDialog` | Confirm/action: Void (billing). | `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart:799` | custom | showAppDialog / showAppWorkspace* (inline) | — | — |
| `_showRejectDialog` | Confirm/action: Reject (billing). | `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart:1035` | custom | showAppDialog / showAppWorkspace* (inline) | — | — |
| `_RejectOrderItemDialog` | Confirm/action: Reject Order Item (lab). | `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart:3715` | custom | AppDialog / showAppDialog (typical) | `_openRejectDialog` | — |
| `_DeleteOrderItemDialog` | Confirm/action: Delete Order Item (lab). | `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart:3871` | custom | AppDialog / showAppDialog (typical) | — | — |
| `_showDeleteDialog` | Confirm/action: Delete (patients). | `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart:5834` | custom | showAppDialog / showAppWorkspace* (inline) | — | `frontend/lib/features/patients/presentation/widgets/patient_detail_dialog_body.dart` |
| `_CancelOrderDialog` | Confirm/action: Cancel Order (pharmacy). | `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart:2501` | custom | AppDialog / showAppDialog (typical) | `_openCancelDialog` | — |
| `_ClinicalRequestRemoveItemsConfirmationDialog` | Confirm/action: Clinical Request Remove Items Confirmation (shared/clinical_actions). | `frontend/lib/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart:124` | shared | AppDialog / showAppDialog (typical) | `showClinicalRequestRemoveItemsConfirmationDialog` | — |
| `LabDeleteReasonDialog` | Confirm/action: Lab Delete Reason (shared/lab_catalog). | `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart:1813` | shared | AppDialog / showAppDialog (typical) | `_openDeleteOfferingDialog`, `_openDeleteSelectedOfferingsDialog`, `_openDeleteLabOrderDialog`, `_openDeleteLabTestDialog`, `_openDeleteLabPanelDialog` | `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart`<br>`frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` |
