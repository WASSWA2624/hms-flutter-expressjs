# Detail viewers — dialog prompts

One actionable agent prompt per inventory row in [`03-detail-viewers.md`](03-detail-viewers.md).
Normative contract: [`../prompts/detail-viewers/prompt.md`](../prompts/detail-viewers/prompt.md) (also [`../.cursor/api-contract.mdc`](../.cursor/api-contract.mdc), [`../frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc), [`../frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc)).

Prompt files live in [`../prompts/detail-viewers/`](../prompts/detail-viewers/) (named `NN-<dialog-slug>.md`). Keep this index here so it is not mistaken for an implementation brief.

Each prompt is generated to be actionable, professional, contextual, specific, and complete against `prompts/detail-viewers/prompt.md` (shells, shared detail-component reuse, loading/actions, titles, backend sync, verification).

Regenerate with:

```bash
python tool/generate_detail_viewer_prompts.py
```

| # | Prompt | Symbol | Purpose |
| --- | --- | --- | --- |
| 01 | [`../prompts/detail-viewers/01-access-admin-detail-dialog.md`](../prompts/detail-viewers/01-access-admin-detail-dialog.md) | `_openDetailDialog` | Detail |
| 02 | [`../prompts/detail-viewers/02-access-admin-role-detail-dialog.md`](../prompts/detail-viewers/02-access-admin-role-detail-dialog.md) | `_AccessAdminRoleDetailDialog` | Access Admin Role Detail |
| 03 | [`../prompts/detail-viewers/03-access-admin-user-detail-dialog.md`](../prompts/detail-viewers/03-access-admin-user-detail-dialog.md) | `_AccessAdminUserDetailDialog` | Access Admin User Detail |
| 04 | [`../prompts/detail-viewers/04-billing-show-billing-detail-dialog.md`](../prompts/detail-viewers/04-billing-show-billing-detail-dialog.md) | `_showBillingDetailDialog` | Billing Detail |
| 05 | [`../prompts/detail-viewers/05-billing-ledger-dialog.md`](../prompts/detail-viewers/05-billing-ledger-dialog.md) | `_BillingLedgerDialog` | Billing Ledger |
| 06 | [`../prompts/detail-viewers/06-biomedical-open-asset-detail-dialog.md`](../prompts/detail-viewers/06-biomedical-open-asset-detail-dialog.md) | `_openAssetDetailDialog` | Asset Detail |
| 07 | [`../prompts/detail-viewers/07-claims-open-claims-detail-dialog.md`](../prompts/detail-viewers/07-claims-open-claims-detail-dialog.md) | `_openClaimsDetailDialog` | Claims Detail |
| 08 | [`../prompts/detail-viewers/08-communications-show-communications-notification-detail-dialog.md`](../prompts/detail-viewers/08-communications-show-communications-notification-detail-dialog.md) | `showCommunicationsNotificationDetailDialog` | Communications Notification Detail |
| 09 | [`../prompts/detail-viewers/09-communications-show-communications-delivery-detail-dialog.md`](../prompts/detail-viewers/09-communications-show-communications-delivery-detail-dialog.md) | `showCommunicationsDeliveryDetailDialog` | Communications Delivery Detail |
| 10 | [`../prompts/detail-viewers/10-communications-show-communications-template-detail-dialog.md`](../prompts/detail-viewers/10-communications-show-communications-template-detail-dialog.md) | `showCommunicationsTemplateDetailDialog` | Communications Template Detail |
| 11 | [`../prompts/detail-viewers/11-discharge-open-discharge-detail-dialog.md`](../prompts/detail-viewers/11-discharge-open-discharge-detail-dialog.md) | `_openDischargeDetailDialog` | Discharge Detail |
| 12 | [`../prompts/detail-viewers/12-emergency-open-emergency-detail-dialog.md`](../prompts/detail-viewers/12-emergency-open-emergency-detail-dialog.md) | `openEmergencyDetailDialog` | Emergency encounter detail viewer |
| 13 | [`../prompts/detail-viewers/13-housekeeping-open-task-detail-dialog.md`](../prompts/detail-viewers/13-housekeeping-open-task-detail-dialog.md) | `_openTaskDetailDialog` | Task Detail |
| 14 | [`../prompts/detail-viewers/14-housekeeping-report-preview-dialog.md`](../prompts/detail-viewers/14-housekeeping-report-preview-dialog.md) | `_showReportPreviewDialog` | Report Preview |
| 15 | [`../prompts/detail-viewers/15-hr-work-queue-dialog.md`](../prompts/detail-viewers/15-hr-work-queue-dialog.md) | `showHrWorkQueueDialog` | Hr Work Queue |
| 16 | [`../prompts/detail-viewers/16-hr-staff-directory-dialog.md`](../prompts/detail-viewers/16-hr-staff-directory-dialog.md) | `showHrStaffDirectoryDialog` | Hr Staff Directory |
| 17 | [`../prompts/detail-viewers/17-hr-show-hr-staff-detail-dialog.md`](../prompts/detail-viewers/17-hr-show-hr-staff-detail-dialog.md) | `showHrStaffDetailDialog` | Hr Staff Detail |
| 18 | [`../prompts/detail-viewers/18-hr-show-activity-dialog.md`](../prompts/detail-viewers/18-hr-show-activity-dialog.md) | `_showActivityDialog` | Activity |
| 19 | [`../prompts/detail-viewers/19-hr-show-work-item-dialog.md`](../prompts/detail-viewers/19-hr-show-work-item-dialog.md) | `_showWorkItemDialog` | Work Item |
| 20 | [`../prompts/detail-viewers/20-hr-show-hr-access-permission-detail-dialog.md`](../prompts/detail-viewers/20-hr-show-hr-access-permission-detail-dialog.md) | `showHrAccessPermissionDetailDialog` | Hr Access Permission Detail |
| 21 | [`../prompts/detail-viewers/21-hr-show-hr-access-role-detail-dialog.md`](../prompts/detail-viewers/21-hr-show-hr-access-role-detail-dialog.md) | `showHrAccessRoleDetailDialog` | Hr Access Role Detail |
| 22 | [`../prompts/detail-viewers/22-hr-access-user-detail-dialog.md`](../prompts/detail-viewers/22-hr-access-user-detail-dialog.md) | `_HrAccessUserDetailDialog` | Hr Access User Detail |
| 23 | [`../prompts/detail-viewers/23-hr-assignment-detail-dialog.md`](../prompts/detail-viewers/23-hr-assignment-detail-dialog.md) | `_HrAssignmentDetailDialog` | Hr Assignment Detail |
| 24 | [`../prompts/detail-viewers/24-hr-show-hr-compensation-detail-dialog.md`](../prompts/detail-viewers/24-hr-show-hr-compensation-detail-dialog.md) | `showHrCompensationDetailDialog` | Hr Compensation Detail |
| 25 | [`../prompts/detail-viewers/25-hr-preview-payroll-dialog.md`](../prompts/detail-viewers/25-hr-preview-payroll-dialog.md) | `showHrPreviewPayrollDialog` | Hr Preview Payroll |
| 26 | [`../prompts/detail-viewers/26-hr-preview-roster-dialog.md`](../prompts/detail-viewers/26-hr-preview-roster-dialog.md) | `showHrPreviewRosterDialog` | Hr Preview Roster |
| 27 | [`../prompts/detail-viewers/27-hr-show-hr-schedule-template-detail-dialog.md`](../prompts/detail-viewers/27-hr-show-hr-schedule-template-detail-dialog.md) | `showHrScheduleTemplateDetailDialog` | Hr Schedule Template Detail |
| 28 | [`../prompts/detail-viewers/28-hr-show-hr-leave-detail-dialog.md`](../prompts/detail-viewers/28-hr-show-hr-leave-detail-dialog.md) | `showHrLeaveDetailDialog` | Hr Leave Detail |
| 29 | [`../prompts/detail-viewers/29-hr-show-hr-shift-detail-dialog.md`](../prompts/detail-viewers/29-hr-show-hr-shift-detail-dialog.md) | `showHrShiftDetailDialog` | Hr Shift Detail |
| 30 | [`../prompts/detail-viewers/30-icu-open-icu-detail-dialog.md`](../prompts/detail-viewers/30-icu-open-icu-detail-dialog.md) | `openIcuDetailDialog` | ICU patient detail viewer |
| 31 | [`../prompts/detail-viewers/31-integrations-open-integration-detail-dialog.md`](../prompts/detail-viewers/31-integrations-open-integration-detail-dialog.md) | `_openIntegrationDetailDialog` | Integration Detail |
| 32 | [`../prompts/detail-viewers/32-ipd-open-ipd-detail-dialog.md`](../prompts/detail-viewers/32-ipd-open-ipd-detail-dialog.md) | `_openIpdDetailDialog` | Ipd Detail |
| 33 | [`../prompts/detail-viewers/33-lab-report-preview-dialog.md`](../prompts/detail-viewers/33-lab-report-preview-dialog.md) | `_LabReportPreviewDialog` | Lab Report Preview |
| 34 | [`../prompts/detail-viewers/34-mortuary-open-mortuary-detail-dialog.md`](../prompts/detail-viewers/34-mortuary-open-mortuary-detail-dialog.md) | `_openMortuaryDetailDialog` | Mortuary case detail viewer |
| 35 | [`../prompts/detail-viewers/35-nursing-patient-detail-dialog.md`](../prompts/detail-viewers/35-nursing-patient-detail-dialog.md) | `NursingPatientDetailDialog` | Nursing Patient Detail |
| 36 | [`../prompts/detail-viewers/36-nursing-print-summary-dialog.md`](../prompts/detail-viewers/36-nursing-print-summary-dialog.md) | `NursingPrintSummaryDialog` | Nursing Print Summary |
| 37 | [`../prompts/detail-viewers/37-operations-open-request-detail-dialog.md`](../prompts/detail-viewers/37-operations-open-request-detail-dialog.md) | `_openRequestDetailDialog` | Request Detail |
| 38 | [`../prompts/detail-viewers/38-patient-report-print-preview-dialog.md`](../prompts/detail-viewers/38-patient-report-print-preview-dialog.md) | `_PatientReportPrintPreviewDialog` | Patient Report Print Preview |
| 39 | [`../prompts/detail-viewers/39-patient-detail-dialog.md`](../prompts/detail-viewers/39-patient-detail-dialog.md) | `PatientDetailDialog` | Patient Detail |
| 40 | [`../prompts/detail-viewers/40-pharmacy-open-pharmacy-detail-dialog.md`](../prompts/detail-viewers/40-pharmacy-open-pharmacy-detail-dialog.md) | `_openPharmacyDetailDialog` | Pharmacy Detail |
| 41 | [`../prompts/detail-viewers/41-physiotherapy-open-therapy-detail-dialog.md`](../prompts/detail-viewers/41-physiotherapy-open-therapy-detail-dialog.md) | `_openTherapyDetailDialog` | Therapy Detail |
| 42 | [`../prompts/detail-viewers/42-radiology-open-radiology-detail-dialog.md`](../prompts/detail-viewers/42-radiology-open-radiology-detail-dialog.md) | `_openRadiologyDetailDialog` | Radiology Detail |
| 43 | [`../prompts/detail-viewers/43-radiology-request-details-edit-dialog.md`](../prompts/detail-viewers/43-radiology-request-details-edit-dialog.md) | `_RequestDetailsEditDialog` | Request Details Edit |
| 44 | [`../prompts/detail-viewers/44-reports-report-detail-dialog.md`](../prompts/detail-viewers/44-reports-report-detail-dialog.md) | `openReportDetailDialog` | Report run/detail viewer |
| 45 | [`../prompts/detail-viewers/45-reports-compliance-detail-dialog.md`](../prompts/detail-viewers/45-reports-compliance-detail-dialog.md) | `openComplianceDetailDialog` | Compliance item detail viewer |
| 46 | [`../prompts/detail-viewers/46-rooms-beds-open-bed-detail-dialog.md`](../prompts/detail-viewers/46-rooms-beds-open-bed-detail-dialog.md) | `_openBedDetailDialog` | Bed Detail |
| 47 | [`../prompts/detail-viewers/47-subscriptions-open-subscription-detail-dialog.md`](../prompts/detail-viewers/47-subscriptions-open-subscription-detail-dialog.md) | `_openSubscriptionDetailDialog` | Subscription Detail |
| 48 | [`../prompts/detail-viewers/48-subscription-report-admins-dialog.md`](../prompts/detail-viewers/48-subscription-report-admins-dialog.md) | `SubscriptionReportAdminsDialog` | Subscription Report Admins |
| 49 | [`../prompts/detail-viewers/49-tenant-facility-setup-detail-dialog.md`](../prompts/detail-viewers/49-tenant-facility-setup-detail-dialog.md) | `_SetupDetailDialog` | Setup Detail |
| 50 | [`../prompts/detail-viewers/50-tenant-facility-tenant-details-dialog.md`](../prompts/detail-viewers/50-tenant-facility-tenant-details-dialog.md) | `_TenantDetailsDialog` | Tenant Details |
| 51 | [`../prompts/detail-viewers/51-tenant-facility-facility-details-dialog.md`](../prompts/detail-viewers/51-tenant-facility-facility-details-dialog.md) | `_FacilityDetailsDialog` | Facility Details |
| 52 | [`../prompts/detail-viewers/52-app-patient-detail-dialog.md`](../prompts/detail-viewers/52-app-patient-detail-dialog.md) | `AppPatientDetailDialog` | Shared patient detail content shell |
