import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';

/// Module entitlement for the discharge workspace route and desk tabs.
const String dischargeInpatientBedModule = 'inpatient-bed-management';

/// Roles allowed to plan / finalize discharge (source inventory gate).
const List<AppRole> dischargeClinicalWriteRoles = <AppRole>[
  AppRole.superAdmin,
  AppRole.tenantAdmin,
  AppRole.facilityAdmin,
  AppRole.doctor,
  AppRole.nurse,
  AppRole.icuManager,
];

/// View / read UI for discharge queues (matrix ∪):
/// `clinical:read` | `last_office:read` + `inpatient-bed-management`.
const AccessRequirement dischargeWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.lastOfficeRead,
  ],
  activeModules: <String>[dischargeInpatientBedModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement dischargeReadRequirement =
    dischargeWorkspaceReadRequirement;

/// Route entry (∪): matches [AppRoutes.discharge] `requiredAnyPermissions`.
const AccessRequirement dischargeWorkspaceEntryRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.clinicalWrite,
    AppPermissions.pharmacyRead,
    AppPermissions.billingRead,
    AppPermissions.operationsRead,
  ],
  anyRoles: AppRoutes.dischargeWorkspaceRoles,
  activeModules: <String>[dischargeInpatientBedModule],
);

/// Planning / finalize mutations — source inventory
/// (`screens/discharge.md` → `_dischargeClinicalWriteRequirement`).
///
/// Matrix lists ∩ `clinical:write`; source keeps role pack ∪ `clinical:write`
/// plus `inpatient-bed-management` — keep source for planning chrome.
const AccessRequirement dischargeClinicalWriteRequirement = AccessRequirement(
  anyRoles: dischargeClinicalWriteRoles,
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>[dischargeInpatientBedModule],
);

/// Alias matching matrix create/update/delete ∩ (via source write gate).
const AccessRequirement dischargeWorkspaceWriteRequirement =
    dischargeClinicalWriteRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement dischargeWriteRequirement =
    dischargeClinicalWriteRequirement;

/// Follow-ups tab / panel read (matrix ∪): `clinical:read` | `last_office:read`.
///
/// Shared [FollowUpWorklistPanel] defaults to reception ∪; discharge overrides
/// with this requirement (see Follow-ups tab permission scan).
const AccessRequirement dischargeFollowUpsRequirement =
    dischargeWorkspaceReadRequirement;

/// Follow-ups complete / reschedule / delete — matrix ∩ `clinical:write`.
const AccessRequirement dischargeFollowUpsWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>[dischargeInpatientBedModule],
);

/// Clearance meds / pharmacy related-records panel (∩ `pharmacy:read`).
const AccessRequirement dischargePharmacyClearanceReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.pharmacyRead],
    );

/// Clearance bills / billing related-records panel — reuses billing read.
const AccessRequirement dischargeBillingClearanceReadRequirement =
    billingReadRequirement;

/// Room turnover clearance steps (∩ `operations:read`).
const AccessRequirement dischargeOperationsClearanceReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.operationsRead],
    );

/// Nursing cross-link navigate (∩ `last_office:read`).
const AccessRequirement dischargeNursingNavigateRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.lastOfficeRead],
);

/// IPD cross-link navigate — same as workspace read ∪.
const AccessRequirement dischargeIpdNavigateRequirement =
    dischargeWorkspaceReadRequirement;

/// Pharmacy cross-link navigate.
const AccessRequirement dischargePharmacyNavigateRequirement =
    dischargePharmacyClearanceReadRequirement;

/// Billing cross-link navigate.
const AccessRequirement dischargeBillingNavigateRequirement =
    dischargeBillingClearanceReadRequirement;

/// Housekeeping / room turnover cross-link navigate.
const AccessRequirement dischargeHousekeepingNavigateRequirement =
    dischargeOperationsClearanceReadRequirement;

/// Per-clearance-step read gate (union across sections, ∩ within section).
AccessRequirement dischargeClearanceItemReadRequirement(
  DischargeClearanceCode code,
) {
  return switch (code) {
    DischargeClearanceCode.pharmacy =>
      dischargePharmacyClearanceReadRequirement,
    DischargeClearanceCode.billing || DischargeClearanceCode.insurance =>
      dischargeBillingClearanceReadRequirement,
    DischargeClearanceCode.bedRelease ||
    DischargeClearanceCode.housekeeping =>
      dischargeOperationsClearanceReadRequirement,
    DischargeClearanceCode.doctor ||
    DischargeClearanceCode.nursing ||
    DischargeClearanceCode.documents =>
      dischargeWorkspaceReadRequirement,
  };
}

/// Per-section tab strip gate.
AccessRequirement dischargeSectionTabRequirement(DischargeDeskSection section) {
  return switch (section) {
    DischargeDeskSection.all => dischargeWorkspaceReadRequirement,
    DischargeDeskSection.completed => dischargeWorkspaceReadRequirement,
    DischargeDeskSection.followUps => dischargeFollowUpsRequirement,
    // Other desk tabs stay route-gated until their permission scans land.
    _ => dischargeWorkspaceEntryRequirement,
  };
}

bool canEnterDischargeWorkspace(AppAccessPolicy policy) {
  return dischargeWorkspaceEntryRequirement.isAllowed(policy);
}

bool canReadDischarge(AppAccessPolicy policy) {
  return dischargeWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteDischarge(AppAccessPolicy policy) {
  return dischargeClinicalWriteRequirement.isAllowed(policy);
}

bool canReadDischargeFollowUps(AppAccessPolicy policy) {
  return dischargeFollowUpsRequirement.isAllowed(policy);
}

bool canWriteDischargeFollowUps(AppAccessPolicy policy) {
  return dischargeFollowUpsWriteRequirement.isAllowed(policy);
}

bool canViewDischargeSection(
  AppAccessPolicy policy,
  DischargeDeskSection section,
) {
  return dischargeSectionTabRequirement(section).isAllowed(policy);
}

bool canViewDischargeAll(AppAccessPolicy policy) {
  return DischargeAllPatientsAtomPermissions.tab.isAllowed(policy);
}

bool canViewDischargeCompleted(AppAccessPolicy policy) {
  return DischargeCompletedAtomPermissions.tab.isAllowed(policy);
}

bool canReadDischargePharmacyClearance(AppAccessPolicy policy) {
  return dischargePharmacyClearanceReadRequirement.isAllowed(policy);
}

bool canReadDischargeBillingClearance(AppAccessPolicy policy) {
  return dischargeBillingClearanceReadRequirement.isAllowed(policy);
}

bool canReadDischargeOperationsClearance(AppAccessPolicy policy) {
  return dischargeOperationsClearanceReadRequirement.isAllowed(policy);
}

List<DischargeClearanceItem> dischargeVisibleClearanceItems(
  AppAccessPolicy policy,
  List<DischargeClearanceItem> items,
) {
  return items
      .where(
        (DischargeClearanceItem item) =>
            dischargeClearanceItemReadRequirement(item.code).isAllowed(policy),
      )
      .toList(growable: false);
}

/// Sections the user may open; Follow-ups / All omitted without their read ∪.
List<DischargeDeskSection> dischargeAllowedSections(AppAccessPolicy policy) {
  return DischargeDeskSection.values
      .where(
        (DischargeDeskSection section) =>
            canViewDischargeSection(policy, section),
      )
      .toList(growable: false);
}

DischargeDeskSection? dischargeFallbackSection(AppAccessPolicy policy) {
  final List<DischargeDeskSection> allowed = dischargeAllowedSections(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(DischargeDeskSection.all)) {
    return DischargeDeskSection.all;
  }
  return allowed.first;
}

/// All patients tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?section=all` (default). Planning / finalize / request mutations
/// need write. Clearance checklist meds / bills / room-turnover steps use
/// nested ∩ reads (pharmacy / billing / operations); union across sections.
/// Matrix nested cross-module write rows are _(n/a)_.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All patients tab / count badge | navigate | read ∪ `clinical:read` \| `last_office:read` |
/// | Search / filters / columns | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Row select → detail | read | read ∪ |
/// | Next action Start plan / Manage clearance | create / update | write source ∩ |
/// | Next action Print (completed) | export / read | read ∪ |
/// | Detail Continue discharge | create / update | write source ∩ |
/// | Detail Request billing / pharmacy | create | write source ∩ |
/// | Detail Print summary | export / read | read ∪ |
/// | Detail clearance pharmacy step / meds panel | nested read | pharmacy:read ∩ |
/// | Detail clearance billing step / invoices panel | nested read | billing:read ∩ |
/// | Detail clearance bed / housekeeping steps | nested read | operations:read ∩ |
/// | Detail Open IPD | navigate | read ∪ |
/// | Detail Open Nursing | navigate | last_office:read ∩ |
/// | Detail Open Pharmacy | navigate | pharmacy:read ∩ |
/// | Detail Open Billing | navigate | billing:read ∩ |
/// | Detail Open Housekeeping | navigate | operations:read ∩ |
/// | Planning Save plan / Finalize | create / update | write source ∩ |
/// | Route entry (deep link) | navigate | entry ∪ |
///
/// Write keeps source roles + `clinical:write` + module rather than matrix ∩
/// `clinical:write` alone. Inventory previously left request billing/pharmacy
/// ungated; matrix create ∩ applies via [create]/[requestBilling]/
/// [requestPharmacy].
abstract final class DischargeAllPatientsAtomPermissions {
  static const AccessRequirement tab = dischargeWorkspaceReadRequirement;
  static const AccessRequirement listChrome = dischargeWorkspaceReadRequirement;
  static const AccessRequirement search = dischargeWorkspaceReadRequirement;
  static const AccessRequirement filters = dischargeWorkspaceReadRequirement;
  static const AccessRequirement settings = dischargeWorkspaceReadRequirement;
  static const AccessRequirement empty = dischargeWorkspaceReadRequirement;
  static const AccessRequirement loading = dischargeWorkspaceReadRequirement;
  static const AccessRequirement retry = dischargeWorkspaceReadRequirement;
  static const AccessRequirement rowSelect = dischargeWorkspaceReadRequirement;
  static const AccessRequirement detail = dischargeWorkspaceReadRequirement;
  static const AccessRequirement nextActionPlan =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement nextActionClearance =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement nextActionPrint =
      dischargeWorkspaceReadRequirement;
  static const AccessRequirement continueDischarge =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement create = dischargeClinicalWriteRequirement;
  static const AccessRequirement update = dischargeClinicalWriteRequirement;
  static const AccessRequirement delete = dischargeClinicalWriteRequirement;
  static const AccessRequirement write = dischargeClinicalWriteRequirement;
  static const AccessRequirement requestBilling =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement requestPharmacy =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement printSummary =
      dischargeWorkspaceReadRequirement;
  static const AccessRequirement medicinesPanel =
      dischargePharmacyClearanceReadRequirement;
  static const AccessRequirement billingPanel =
      dischargeBillingClearanceReadRequirement;
  static const AccessRequirement roomTurnover =
      dischargeOperationsClearanceReadRequirement;
  static const AccessRequirement openIpd = dischargeIpdNavigateRequirement;
  static const AccessRequirement openNursing =
      dischargeNursingNavigateRequirement;
  static const AccessRequirement openPharmacy =
      dischargePharmacyNavigateRequirement;
  static const AccessRequirement openBilling =
      dischargeBillingNavigateRequirement;
  static const AccessRequirement openHousekeeping =
      dischargeHousekeepingNavigateRequirement;
  static const AccessRequirement nestedPharmacyRead =
      dischargePharmacyClearanceReadRequirement;
  static const AccessRequirement nestedBillingRead =
      dischargeBillingClearanceReadRequirement;
  static const AccessRequirement nestedOperationsRead =
      dischargeOperationsClearanceReadRequirement;
  static const AccessRequirement nestedWrite =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement nestedRead = dischargeWorkspaceReadRequirement;
  static const AccessRequirement entry = dischargeWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = dischargeWorkspaceEntryRequirement;
}

/// Completed tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?section=completed`. Prefer read: next-action Print (no write
/// gate); Continue plan omitted when completed. Request billing/pharmacy still
/// use write source ∩ when detail is open. Clearance checklist meds / bills /
/// room-turnover steps use nested ∩ reads; union across sections. Matrix nested
/// cross-module write rows are _(n/a)_.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Completed tab / count badge | navigate | read ∪ `clinical:read` \| `last_office:read` |
/// | Search / filters / columns | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Row select → detail | read | read ∪ |
/// | Next action Print | export / read | read ∪ |
/// | Detail Continue discharge | create / update | write (absent when completed) |
/// | Detail Request billing / pharmacy | create | write source ∩ |
/// | Detail Print summary | export / read | read ∪ |
/// | Detail clearance pharmacy / meds panel | nested read | pharmacy:read ∩ |
/// | Detail clearance billing / invoices panel | nested read | billing:read ∩ |
/// | Detail clearance bed / housekeeping | nested read | operations:read ∩ |
/// | Detail Open IPD | navigate | read ∪ |
/// | Detail Open Nursing | navigate | last_office:read ∩ |
/// | Detail Open Pharmacy | navigate | pharmacy:read ∩ |
/// | Detail Open Billing | navigate | billing:read ∩ |
/// | Detail Open Housekeeping | navigate | operations:read ∩ |
/// | Route entry (deep link) | navigate | entry ∪ |
///
/// Write keeps source roles + `clinical:write` + module rather than matrix ∩
/// `clinical:write` alone. Shared detail chrome reuses the same requirement
/// instances as [DischargeAllPatientsAtomPermissions].
abstract final class DischargeCompletedAtomPermissions {
  static const AccessRequirement tab = dischargeWorkspaceReadRequirement;
  static const AccessRequirement listChrome = dischargeWorkspaceReadRequirement;
  static const AccessRequirement search = dischargeWorkspaceReadRequirement;
  static const AccessRequirement filters = dischargeWorkspaceReadRequirement;
  static const AccessRequirement settings = dischargeWorkspaceReadRequirement;
  static const AccessRequirement empty = dischargeWorkspaceReadRequirement;
  static const AccessRequirement loading = dischargeWorkspaceReadRequirement;
  static const AccessRequirement retry = dischargeWorkspaceReadRequirement;
  static const AccessRequirement rowSelect = dischargeWorkspaceReadRequirement;
  static const AccessRequirement detail = dischargeWorkspaceReadRequirement;
  static const AccessRequirement nextActionPrint =
      dischargeWorkspaceReadRequirement;
  static const AccessRequirement continueDischarge =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement create = dischargeClinicalWriteRequirement;
  static const AccessRequirement update = dischargeClinicalWriteRequirement;
  static const AccessRequirement delete = dischargeClinicalWriteRequirement;
  static const AccessRequirement write = dischargeClinicalWriteRequirement;
  static const AccessRequirement requestBilling =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement requestPharmacy =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement printSummary =
      dischargeWorkspaceReadRequirement;
  static const AccessRequirement medicinesPanel =
      dischargePharmacyClearanceReadRequirement;
  static const AccessRequirement billingPanel =
      dischargeBillingClearanceReadRequirement;
  static const AccessRequirement roomTurnover =
      dischargeOperationsClearanceReadRequirement;
  static const AccessRequirement openIpd = dischargeIpdNavigateRequirement;
  static const AccessRequirement openNursing =
      dischargeNursingNavigateRequirement;
  static const AccessRequirement openPharmacy =
      dischargePharmacyNavigateRequirement;
  static const AccessRequirement openBilling =
      dischargeBillingNavigateRequirement;
  static const AccessRequirement openHousekeeping =
      dischargeHousekeepingNavigateRequirement;
  static const AccessRequirement nestedPharmacyRead =
      dischargePharmacyClearanceReadRequirement;
  static const AccessRequirement nestedBillingRead =
      dischargeBillingClearanceReadRequirement;
  static const AccessRequirement nestedOperationsRead =
      dischargeOperationsClearanceReadRequirement;
  static const AccessRequirement nestedWrite =
      dischargeClinicalWriteRequirement;
  static const AccessRequirement nestedRead = dischargeWorkspaceReadRequirement;
  static const AccessRequirement entry = dischargeWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = dischargeWorkspaceEntryRequirement;
}

/// Atom → requirement map for Discharge Follow-ups (`/discharge?section=follow-ups`).
///
/// Inventory: `screens/discharge.md` → Follow-ups tab (`FollowUpWorklistPanel`).
/// Planning / clearance / billing / pharmacy nested UI is **not** reachable from
/// this tab (matrix nested rows _(n/a)_). Shared panel defaults remain reception
/// ∪; discharge host overrides with these gates.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups strip tab | navigate | read ∪ `clinical:read` \| `last_office:read` |
/// | Search / clear / Settings / columns | read chrome | read ∪ |
/// | Empty / loading / error / retry | read chrome | read ∪ |
/// | Row select → Follow-up details | read | read ∪ |
/// | Detail Close (read-only footer) | progressive disclosure | read ∪ |
/// | Reschedule follow-up | update | write ∩ `clinical:write` |
/// | Mark completed | update | write ∩ `clinical:write` |
/// | Save follow-up (nested reschedule dialog) | update | write ∩ |
/// | Route entry (deep link) | navigate | entry ∪ |
abstract final class DischargeFollowUpsAtomPermissions {
  static const AccessRequirement tab = dischargeFollowUpsRequirement;
  static const AccessRequirement listChrome = dischargeFollowUpsRequirement;
  static const AccessRequirement search = dischargeFollowUpsRequirement;
  static const AccessRequirement settings = dischargeFollowUpsRequirement;
  static const AccessRequirement empty = dischargeFollowUpsRequirement;
  static const AccessRequirement loading = dischargeFollowUpsRequirement;
  static const AccessRequirement retry = dischargeFollowUpsRequirement;
  static const AccessRequirement rowSelect = dischargeFollowUpsRequirement;
  static const AccessRequirement detail = dischargeFollowUpsRequirement;
  static const AccessRequirement close = dischargeFollowUpsRequirement;
  static const AccessRequirement create = dischargeFollowUpsWriteRequirement;
  static const AccessRequirement update = dischargeFollowUpsWriteRequirement;
  static const AccessRequirement delete = dischargeFollowUpsWriteRequirement;
  static const AccessRequirement reschedule = dischargeFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted =
      dischargeFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp =
      dischargeFollowUpsWriteRequirement;
  static const AccessRequirement write = dischargeFollowUpsWriteRequirement;
  /// Nested cross-module write — not used on this tab (matrix _(n/a)_).
  static const AccessRequirement nestedWrite =
      dischargeFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = dischargeFollowUpsRequirement;
  static const AccessRequirement entry = dischargeWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = dischargeWorkspaceEntryRequirement;
}
