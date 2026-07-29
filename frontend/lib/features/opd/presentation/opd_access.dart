import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_board_next_action.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';

/// Module entitlement for the OPD workspace route and board tabs.
const String opdSchedulingQueueModule = 'scheduling-queue';

/// View / read UI (matrix ∪): `patient:read` | `clinical:read` + module.
///
/// Billing / operations / emergency alone may satisfy [routeEntry] via catalog
/// `opd:read` role packs, but board chrome still requires this ∪.
const AccessRequirement opdWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.clinicalRead,
  ],
  activeModules: <String>[opdSchedulingQueueModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement opdReadRequirement = opdWorkspaceReadRequirement;

/// Route entry — unique atom from [RouteAccessCatalog.opd]
/// (∩ `opd:read` + `scheduling-queue`).
///
/// Prompt / AppRoutes also list ∪ `patient:read` | `clinical:read` |
/// `billing:read` | `operations:read` | `emergency:read`; catalog keeps the
/// unique `opd:read` key so other modules cannot leak into OPD — keep source.
const AccessRequirement opdWorkspaceEntryRequirement =
    RouteAccessCatalog.opdEntry;

/// Prompt / AppRoutes route-entry ∪ (`patient:read` | `clinical:read` |
/// `billing:read` | `operations:read` | `emergency:read`). Shell gate remains
/// [opdWorkspaceEntryRequirement] (`opd:read`) for unique destination isolation.
const AccessRequirement opdWorkspaceRouteUnionRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.clinicalRead,
    AppPermissions.billingRead,
    AppPermissions.operationsRead,
    AppPermissions.emergencyRead,
  ],
  activeModules: <String>[opdSchedulingQueueModule],
);

/// Matrix create / update / delete ∩ `clinical:write` + module.
///
/// Stage mutations keep source role / billing helpers
/// ([opdEncounterPermissionRequirement], [opdVitalsActionRequirement], …);
/// this gate documents the matrix verb for clinical write chrome.
const AccessRequirement opdClinicalWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>[opdSchedulingQueueModule],
);

/// Alias matching matrix create/update/delete when clinical ∩ is intended.
const AccessRequirement opdWriteRequirement = opdClinicalWriteRequirement;

/// Alias for workspace write when clinical ∩ is the verb.
const AccessRequirement opdWorkspaceWriteRequirement =
    opdClinicalWriteRequirement;

/// Delete — matrix ∩ `clinical:write` (no dedicated `clinical:delete` on OPD).
const AccessRequirement opdWorkspaceDeleteRequirement =
    opdClinicalWriteRequirement;

/// Start OPD encounter — source patient-flow / role gate
/// ([opdEncounterPermissionRequirement]), not matrix ∩ alone.
const AccessRequirement opdStartEncounterRequirement =
    opdEncounterPermissionRequirement;

/// Follow-ups panel read — matrix note: clinical:read (∪ with patient:read for
/// shared worklist parity).
const AccessRequirement opdFollowUpsRequirement = opdWorkspaceReadRequirement;

/// Follow-ups complete / reschedule — matrix ∩ `clinical:write`.
const AccessRequirement opdFollowUpsWriteRequirement =
    opdClinicalWriteRequirement;

/// Payment stage — source [opdBillingActionRequirement]
/// (∩ `billing:write` + `billing-payments`).
const AccessRequirement opdPaymentWriteRequirement = opdBillingActionRequirement;

bool canReadOpd(AppAccessPolicy policy) {
  return opdWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteOpdClinical(AppAccessPolicy policy) {
  return opdClinicalWriteRequirement.isAllowed(policy);
}

bool canWriteOpdBilling(AppAccessPolicy policy) {
  return opdPaymentWriteRequirement.isAllowed(policy);
}

bool canWriteOpdAdmissionHandoff(AppAccessPolicy policy) {
  return opdAdmissionHandoffRequirement.isAllowed(policy);
}

bool canStartOpdEncounter(AppAccessPolicy policy) {
  return opdStartEncounterRequirement.isAllowed(policy);
}

bool canEnterOpdWorkspace(AppAccessPolicy policy) {
  return opdWorkspaceEntryRequirement.isAllowed(policy);
}

/// Per-section tab strip gate.
AccessRequirement opdBoardTabRequirement(OpdWorkspaceSection section) {
  return switch (section) {
    OpdWorkspaceSection.all => OpdAllAtomPermissions.tab,
    OpdWorkspaceSection.arrivals => OpdArrivalsAtomPermissions.tab,
    OpdWorkspaceSection.queue => OpdQueueAtomPermissions.tab,
    OpdWorkspaceSection.triage => OpdTriageAtomPermissions.tab,
    OpdWorkspaceSection.active => OpdActiveAtomPermissions.tab,
    OpdWorkspaceSection.followUps => OpdFollowUpsAtomPermissions.tab,
  };
}

/// Alias used by All / Arrivals permission scans.
AccessRequirement opdSectionTabRequirement(OpdWorkspaceSection section) {
  return opdBoardTabRequirement(section);
}

bool canViewOpdTab(AppAccessPolicy policy, OpdWorkspaceSection section) {
  return opdBoardTabRequirement(section).isAllowed(policy);
}

bool canViewOpdAll(AppAccessPolicy policy) {
  return OpdAllAtomPermissions.tab.isAllowed(policy);
}

bool canViewOpdArrivals(AppAccessPolicy policy) {
  return OpdArrivalsAtomPermissions.tab.isAllowed(policy);
}

bool canViewOpdQueue(AppAccessPolicy policy) {
  return OpdQueueAtomPermissions.tab.isAllowed(policy);
}

bool canViewOpdTriage(AppAccessPolicy policy) {
  return OpdTriageAtomPermissions.tab.isAllowed(policy);
}

bool canViewOpdActive(AppAccessPolicy policy) {
  return OpdActiveAtomPermissions.tab.isAllowed(policy);
}

bool canViewOpdFollowUps(AppAccessPolicy policy) {
  return OpdFollowUpsAtomPermissions.tab.isAllowed(policy);
}

bool canReadOpdFollowUps(AppAccessPolicy policy) {
  return opdFollowUpsRequirement.isAllowed(policy);
}

bool canWriteOpdFollowUps(AppAccessPolicy policy) {
  return opdFollowUpsWriteRequirement.isAllowed(policy);
}

/// Tabs the user may open; empty when no board read passes.
List<OpdWorkspaceSection> opdAllowedBoardTabs(AppAccessPolicy policy) {
  return OpdWorkspaceSection.values
      .where((OpdWorkspaceSection section) => canViewOpdTab(policy, section))
      .toList(growable: false);
}

/// Alias used by the workspace page / All-worklist scan.
List<OpdWorkspaceSection> opdAllowedSections(AppAccessPolicy policy) {
  return opdAllowedBoardTabs(policy);
}

OpdWorkspaceSection? opdFallbackTab(AppAccessPolicy policy) {
  final List<OpdWorkspaceSection> allowed = opdAllowedBoardTabs(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(OpdWorkspaceSection.active)) {
    return OpdWorkspaceSection.active;
  }
  if (allowed.contains(OpdWorkspaceSection.all)) {
    return OpdWorkspaceSection.all;
  }
  return allowed.first;
}

/// Alias used by the workspace page / All-worklist scan.
OpdWorkspaceSection? opdFallbackSection(AppAccessPolicy policy) {
  return opdFallbackTab(policy);
}

/// Maps board next-action kinds to shared source gates.
AccessRequirement? opdNextActionRequirement(OpdBoardNextActionKind kind) {
  return opdBoardNextActionRequirement(kind);
}

/// Start-encounter gate for the active tab toolbar.
AccessRequirement opdStartEncounterRequirementForSection(
  OpdWorkspaceSection section,
) {
  return switch (section) {
    OpdWorkspaceSection.arrivals => OpdArrivalsAtomPermissions.startEncounter,
    OpdWorkspaceSection.all => OpdAllAtomPermissions.startEncounter,
    OpdWorkspaceSection.queue => OpdQueueAtomPermissions.startEncounter,
    OpdWorkspaceSection.triage => OpdTriageAtomPermissions.startEncounter,
    OpdWorkspaceSection.active => OpdActiveAtomPermissions.startEncounter,
    // Start OPD is absent on Follow-ups chrome; keep source gate for callers.
    OpdWorkspaceSection.followUps => OpdFollowUpsAtomPermissions.startEncounter,
  };
}

/// Requirement for a deep-linked `panel=` mutation on OPD flows.
///
/// Mirrors board next-action panel mapping without importing the board UI
/// library (avoids cycles with the workspace page).
AccessRequirement? opdFocusedPanelRequirement(String panel) {
  final String key = panel.trim().toUpperCase();
  if (key.isEmpty) {
    return null;
  }
  return switch (key) {
    'PAYMENT' ||
    'BILLING' ||
    'PAYMENT_DUE' ||
    'WAITING_CONSULTATION_PAYMENT' => opdBillingActionRequirement,
    'VITALS' || 'VITALS_NEEDED' || 'WAITING_VITALS' => opdVitalsActionRequirement,
    'DOCTOR' ||
    'DOCTOR_NEEDED' ||
    'ASSIGNMENT' ||
    'WAITING_DOCTOR_ASSIGNMENT' => opdReceptionActionRequirement,
    'REVIEW' ||
    'WITH_DOCTOR' ||
    'WAITING_DOCTOR_REVIEW' => opdDoctorActionRequirement,
    'LAB' ||
    'LAB_PENDING' ||
    'LAB_REQUESTED' ||
    'LAB_AND_RADIOLOGY_REQUESTED' ||
    'IMAGING' ||
    'RADIOLOGY' ||
    'IMAGING_PENDING' ||
    'RADIOLOGY_REQUESTED' ||
    'PHARMACY' ||
    'PHARMACY_PENDING' ||
    'PHARMACY_REQUESTED' => opdReceptionActionRequirement,
    'DISPOSITION' ||
    'DECISION' ||
    'DECISION_NEEDED' ||
    'WAITING_DISPOSITION' => opdDoctorActionRequirement,
    'ADMISSION' ||
    'ADMISSION_PENDING' ||
    'ADMITTED' => opdAdmissionHandoffRequirement,
    _ => null,
  };
}

/// Whether any workflow next-action column may mount for [section].
bool opdBoardShowsNextActionColumn(
  AppAccessPolicy policy,
  OpdWorkspaceSection section,
) {
  return switch (section) {
    OpdWorkspaceSection.followUps => false,
    // Inventory: queue next-action is empty; row select is the sole hub entry.
    OpdWorkspaceSection.queue => false,
    OpdWorkspaceSection.arrivals =>
      OpdArrivalsAtomPermissions.startEncounter.isAllowed(policy) ||
          OpdArrivalsAtomPermissions.frontDesk.isAllowed(policy) ||
          OpdArrivalsAtomPermissions.nextActionCheckIn.isAllowed(policy),
    OpdWorkspaceSection.all =>
      OpdAllAtomPermissions.startEncounter.isAllowed(policy) ||
          OpdAllAtomPermissions.nextAction.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionVitals.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionPay.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionCheckIn.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionAssignDoctor.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionDoctorReview.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionDisposition.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionAdmissionHandoff.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionCorrectStage.isAllowed(policy) ||
          OpdAllAtomPermissions.nextActionDepartmentHandoff.isAllowed(policy) ||
          OpdAllAtomPermissions.frontDesk.isAllowed(policy),
    OpdWorkspaceSection.triage =>
      OpdTriageAtomPermissions.startEncounter.isAllowed(policy) ||
          OpdTriageAtomPermissions.nextActionVitals.isAllowed(policy) ||
          OpdTriageAtomPermissions.nextActionAssignDoctor.isAllowed(policy) ||
          OpdTriageAtomPermissions.nextActionCorrectStage.isAllowed(policy),
    OpdWorkspaceSection.active =>
      OpdActiveAtomPermissions.nextAction.isAllowed(policy) ||
          OpdActiveAtomPermissions.nextActionVitals.isAllowed(policy) ||
          OpdActiveAtomPermissions.nextActionPay.isAllowed(policy) ||
          OpdActiveAtomPermissions.nextActionAssignDoctor.isAllowed(policy) ||
          OpdActiveAtomPermissions.nextActionDoctorReview.isAllowed(policy) ||
          OpdActiveAtomPermissions.nextActionDisposition.isAllowed(policy) ||
          OpdActiveAtomPermissions.nextActionAdmissionHandoff.isAllowed(
            policy,
          ) ||
          OpdActiveAtomPermissions.nextActionCorrectStage.isAllowed(policy) ||
          OpdActiveAtomPermissions.nextActionDepartmentHandoff.isAllowed(
            policy,
          ) ||
          OpdActiveAtomPermissions.startEncounter.isAllowed(policy),
  };
}

/// Active tab atom → permission mapping (inventory + matrix).
///
/// In-consultation encounters (`/opd?section=active`). Nested cross-module
/// matrix rows are _(n/a)_ — billing payment keeps source
/// [opdBillingActionRequirement]; admission handoff keeps source
/// [opdAdmissionHandoffRequirement]. Start encounter / vitals / doctor /
/// front-desk / reception keep source role gates rather than matrix ∩
/// `clinical:write` alone. Route entry keeps catalog ∩ `opd:read`. Tab
/// chrome stays ∪ `patient:read` | `clinical:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active tab / count badge | navigate | read ∪ ([tab]) |
/// | Start OPD encounter (toolbar) | create | source encounter ([startEncounter]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | clinical write / form |
/// | Row select → Flow Actions | read | ([rowSelect] / [detail]) |
/// | Next action Record vitals | update | source vitals ([nextActionVitals]) |
/// | Next action Pay consultation | update | source billing ([nextActionPay]) |
/// | Next action Assign / change doctor | update | source reception |
/// | Next action Doctor review / Disposition | update | source doctor |
/// | Next action Admission handoff | update | source admission |
/// | Next action Correct stage / department handoff | update / navigate | source reception |
/// | Nested Flow Actions writes | update | matching source stage gate |
/// | Deep link `panel=` mutation | update | [opdFocusedPanelRequirement] |
/// | Route entry (deep link) | navigate | catalog ∩ `opd:read` |
abstract final class OpdActiveAtomPermissions {
  static const AccessRequirement tab = opdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = opdWorkspaceReadRequirement;
  static const AccessRequirement search = opdWorkspaceReadRequirement;
  static const AccessRequirement filters = opdWorkspaceReadRequirement;
  static const AccessRequirement settings = opdWorkspaceReadRequirement;
  static const AccessRequirement empty = opdWorkspaceReadRequirement;
  static const AccessRequirement loading = opdWorkspaceReadRequirement;
  static const AccessRequirement retry = opdWorkspaceReadRequirement;
  static const AccessRequirement success = opdClinicalWriteRequirement;
  static const AccessRequirement validation = opdClinicalWriteRequirement;
  static const AccessRequirement rowSelect = opdWorkspaceReadRequirement;
  static const AccessRequirement detail = opdWorkspaceReadRequirement;

  /// Matrix ∩ `clinical:write`; toolbar create uses [startEncounter] (source).
  static const AccessRequirement create = opdClinicalWriteRequirement;
  static const AccessRequirement update = opdClinicalWriteRequirement;
  static const AccessRequirement delete = opdWorkspaceDeleteRequirement;
  static const AccessRequirement write = opdClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = opdClinicalWriteRequirement;
  static const AccessRequirement startEncounter = opdStartEncounterRequirement;
  static const AccessRequirement nextAction = opdClinicalWriteRequirement;
  static const AccessRequirement nextActionVitals = opdVitalsActionRequirement;
  static const AccessRequirement nextActionPay = opdBillingActionRequirement;
  static const AccessRequirement nextActionAssignDoctor =
      opdReceptionActionRequirement;
  static const AccessRequirement nextActionDoctorReview =
      opdDoctorActionRequirement;
  static const AccessRequirement nextActionDisposition =
      opdDoctorActionRequirement;
  static const AccessRequirement nextActionAdmissionHandoff =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement nextActionCorrectStage =
      opdReceptionActionRequirement;

  /// Source keep: board maps department handoff → [opdReceptionActionRequirement].
  static const AccessRequirement nextActionDepartmentHandoff =
      opdReceptionActionRequirement;
  static const AccessRequirement recordVitals = opdVitalsActionRequirement;
  static const AccessRequirement payConsultation = opdBillingActionRequirement;
  static const AccessRequirement assignDoctor = opdReceptionActionRequirement;
  static const AccessRequirement doctorReview = opdDoctorActionRequirement;
  static const AccessRequirement disposition = opdDoctorActionRequirement;
  static const AccessRequirement admissionHandoff =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement correctStage = opdReceptionActionRequirement;
  static const AccessRequirement frontDesk = opdFrontDeskActionRequirement;

  /// Nested cross-module write — matrix _(n/a)_; billing uses [payConsultation].
  static const AccessRequirement nestedWrite = opdClinicalWriteRequirement;

  /// Nested cross-module read — matrix _(n/a)_; reuses board read ∪.
  static const AccessRequirement nestedRead = opdWorkspaceReadRequirement;
  static const AccessRequirement nestedBillingWrite =
      opdBillingActionRequirement;
  static const AccessRequirement nestedAdmissionWrite =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement panelDeepLink = opdClinicalWriteRequirement;
  static const AccessRequirement entry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      opdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.opdEntry;
}

/// All worklist tab atom → permission mapping (inventory + matrix).
///
/// Combined OPD worklist (`/opd` / `?section=all`). Nested cross-module matrix
/// rows are _(n/a)_ — billing payment keeps source [opdBillingActionRequirement];
/// admission handoff keeps source [opdAdmissionHandoffRequirement]. Start
/// encounter / vitals / doctor / front-desk / reception keep source role gates
/// rather than matrix ∩ `clinical:write` alone. Appointment hub / check-in
/// next-action keep source [opdFrontDeskActionRequirement] on [write] /
/// [nextActionCheckIn]. Route entry keeps catalog ∩ `opd:read`. Tab chrome
/// stays ∪ `patient:read` | `clinical:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All worklist tab / count badge | navigate | read ∪ ([tab]) |
/// | Start OPD encounter (toolbar) | create | source encounter ([startEncounter]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | clinical write / form |
/// | Row select → Flow / Appointment / Queue Actions | read | ([rowSelect] / [detail]) |
/// | Next action Start / Continue (arrival) | create / update | source front-desk |
/// | Next action Record vitals | update | source vitals ([nextActionVitals]) |
/// | Next action Pay consultation | update | source billing ([nextActionPay]) |
/// | Next action Assign / change doctor | update | source reception |
/// | Next action Doctor review / Disposition | update | source doctor |
/// | Next action Admission handoff | update | source admission |
/// | Next action Correct stage / department handoff | update / navigate | source reception |
/// | Nested hub writes | update | matching source stage / front-desk gate |
/// | Deep link `panel=` mutation | update | [opdFocusedPanelRequirement] |
/// | Route entry (deep link) | navigate | catalog ∩ `opd:read` |
abstract final class OpdAllAtomPermissions {
  static const AccessRequirement tab = opdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = opdWorkspaceReadRequirement;
  static const AccessRequirement search = opdWorkspaceReadRequirement;
  static const AccessRequirement filters = opdWorkspaceReadRequirement;
  static const AccessRequirement settings = opdWorkspaceReadRequirement;
  static const AccessRequirement empty = opdWorkspaceReadRequirement;
  static const AccessRequirement loading = opdWorkspaceReadRequirement;
  static const AccessRequirement retry = opdWorkspaceReadRequirement;
  static const AccessRequirement success = opdClinicalWriteRequirement;
  static const AccessRequirement validation = opdClinicalWriteRequirement;
  static const AccessRequirement rowSelect = opdWorkspaceReadRequirement;
  static const AccessRequirement detail = opdWorkspaceReadRequirement;

  /// Matrix ∩ `clinical:write`; toolbar create uses [startEncounter] (source).
  static const AccessRequirement create = opdClinicalWriteRequirement;
  static const AccessRequirement update = opdClinicalWriteRequirement;
  static const AccessRequirement delete = opdWorkspaceDeleteRequirement;

  /// Source front-desk gate for appointment / queue hub writes (keep source).
  static const AccessRequirement write = opdFrontDeskActionRequirement;
  static const AccessRequirement clinicalWrite = opdClinicalWriteRequirement;
  static const AccessRequirement startEncounter = opdStartEncounterRequirement;
  static const AccessRequirement nextAction = opdClinicalWriteRequirement;
  static const AccessRequirement nextActionVitals = opdVitalsActionRequirement;
  static const AccessRequirement nextActionPay = opdBillingActionRequirement;
  static const AccessRequirement nextActionCheckIn = opdFrontDeskActionRequirement;
  static const AccessRequirement nextActionContinue =
      opdFrontDeskActionRequirement;
  static const AccessRequirement nextActionAssignDoctor =
      opdReceptionActionRequirement;
  static const AccessRequirement nextActionDoctorReview =
      opdDoctorActionRequirement;
  static const AccessRequirement nextActionDisposition =
      opdDoctorActionRequirement;
  static const AccessRequirement nextActionAdmissionHandoff =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement nextActionCorrectStage =
      opdReceptionActionRequirement;

  /// Source keep: board maps department handoff → [opdReceptionActionRequirement].
  static const AccessRequirement nextActionDepartmentHandoff =
      opdReceptionActionRequirement;
  static const AccessRequirement recordVitals = opdVitalsActionRequirement;
  static const AccessRequirement payConsultation = opdBillingActionRequirement;
  static const AccessRequirement assignDoctor = opdReceptionActionRequirement;
  static const AccessRequirement doctorReview = opdDoctorActionRequirement;
  static const AccessRequirement disposition = opdDoctorActionRequirement;
  static const AccessRequirement admissionHandoff =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement correctStage = opdReceptionActionRequirement;
  static const AccessRequirement frontDesk = opdFrontDeskActionRequirement;

  /// Nested cross-module write — matrix _(n/a)_; appointment hub uses front-desk.
  static const AccessRequirement nestedWrite = opdFrontDeskActionRequirement;

  /// Nested cross-module read — matrix _(n/a)_; reuses board read ∪.
  static const AccessRequirement nestedRead = opdWorkspaceReadRequirement;
  static const AccessRequirement nestedBillingWrite =
      opdBillingActionRequirement;
  static const AccessRequirement nestedAdmissionWrite =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement panelDeepLink = opdClinicalWriteRequirement;
  static const AccessRequirement entry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      opdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.opdEntry;
}

/// Arrivals tab atom → permission mapping (inventory + matrix).
///
/// Check-in / arrival processing (`/opd?section=arrivals`). Nested cross-module
/// matrix rows are _(n/a)_. Start OPD encounter keeps source
/// [opdEncounterPermissionRequirement]; appointment hub / check-in next-action
/// keep source [opdFrontDeskActionRequirement]. Matrix create/update/delete
/// document ∩ `clinical:write`. Tab chrome stays ∪ `patient:read` |
/// `clinical:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Arrivals tab / count badge | navigate | read ∪ ([tab]) |
/// | Start OPD encounter (toolbar) | create | source encounter ([startEncounter]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | clinical write / form |
/// | Row select → Appointment Actions | read | ([rowSelect] / [detail]) |
/// | Next action Start OPD encounter (check-in) | create / update | source front-desk |
/// | Next action Continue encounter | update | source front-desk |
/// | Nested appointment hub reschedule / cancel | update / delete | source front-desk |
/// | Nested encounter dialog | create | source encounter |
/// | Nested new-patient mode | create | patient:write (dialog-local) |
/// | Route entry (deep link) | navigate | catalog ∩ `opd:read` |
abstract final class OpdArrivalsAtomPermissions {
  static const AccessRequirement tab = opdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = opdWorkspaceReadRequirement;
  static const AccessRequirement search = opdWorkspaceReadRequirement;
  static const AccessRequirement filters = opdWorkspaceReadRequirement;
  static const AccessRequirement settings = opdWorkspaceReadRequirement;
  static const AccessRequirement empty = opdWorkspaceReadRequirement;
  static const AccessRequirement loading = opdWorkspaceReadRequirement;
  static const AccessRequirement retry = opdWorkspaceReadRequirement;
  static const AccessRequirement success = opdClinicalWriteRequirement;
  static const AccessRequirement validation = opdClinicalWriteRequirement;
  static const AccessRequirement rowSelect = opdWorkspaceReadRequirement;
  static const AccessRequirement detail = opdWorkspaceReadRequirement;

  /// Matrix ∩ `clinical:write`; toolbar create uses [startEncounter] (source).
  static const AccessRequirement create = opdClinicalWriteRequirement;
  static const AccessRequirement update = opdClinicalWriteRequirement;
  static const AccessRequirement delete = opdWorkspaceDeleteRequirement;

  /// Source front-desk gate for appointment hub writes (keep source).
  static const AccessRequirement write = opdFrontDeskActionRequirement;
  static const AccessRequirement clinicalWrite = opdClinicalWriteRequirement;
  static const AccessRequirement startEncounter = opdStartEncounterRequirement;
  static const AccessRequirement nextAction = opdFrontDeskActionRequirement;
  static const AccessRequirement nextActionCheckIn = opdFrontDeskActionRequirement;
  static const AccessRequirement nextActionContinue =
      opdFrontDeskActionRequirement;
  static const AccessRequirement checkIn = opdFrontDeskActionRequirement;
  static const AccessRequirement reschedule = opdFrontDeskActionRequirement;
  static const AccessRequirement cancelAppointment = opdFrontDeskActionRequirement;
  static const AccessRequirement frontDesk = opdFrontDeskActionRequirement;

  /// Nested cross-module write — matrix _(n/a)_; arrival hub uses front-desk.
  static const AccessRequirement nestedWrite = opdFrontDeskActionRequirement;

  /// Nested cross-module read — matrix _(n/a)_; reuses board read ∪.
  static const AccessRequirement nestedRead = opdWorkspaceReadRequirement;
  static const AccessRequirement nestedBillingWrite =
      opdBillingActionRequirement;
  static const AccessRequirement nestedAdmissionWrite =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement panelDeepLink = opdFrontDeskActionRequirement;
  static const AccessRequirement entry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      opdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.opdEntry;
}

/// Queue tab atom → permission mapping (inventory + matrix).
///
/// Waiting queue call-next / requeue (`/opd?section=queue`). Nested
/// cross-module matrix rows are _(n/a)_. Start OPD encounter keeps source
/// [opdEncounterPermissionRequirement]; queue hub mutations (prioritize /
/// change status / assign doctor) keep source [opdFrontDeskActionRequirement]
/// rather than matrix ∩ `clinical:write` alone (prompt note maps stage
/// actions to clinical write — source front-desk is authoritative). Matrix
/// create/update/delete document ∩ `clinical:write`. No row next-action
/// column (inventory: row select is the sole hub entry). Tab chrome stays ∪
/// `patient:read` | `clinical:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Queue tab / count badge | navigate | read ∪ ([tab]) |
/// | Start OPD encounter (toolbar) | create | source encounter ([startEncounter]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | clinical write / form |
/// | Row select → Queue Actions | read | ([rowSelect] / [detail]) |
/// | Next action column | update | absent on Queue ([nextAction] unused) |
/// | Nested prioritize / change status / assign doctor | update | source front-desk |
/// | Nested encounter dialog (toolbar) | create | source encounter |
/// | Nested billing / admission panels | nested write | _(n/a)_ — not reachable |
/// | Route entry (deep link) | navigate | catalog ∩ `opd:read` |
abstract final class OpdQueueAtomPermissions {
  static const AccessRequirement tab = opdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = opdWorkspaceReadRequirement;
  static const AccessRequirement search = opdWorkspaceReadRequirement;
  static const AccessRequirement filters = opdWorkspaceReadRequirement;
  static const AccessRequirement settings = opdWorkspaceReadRequirement;
  static const AccessRequirement empty = opdWorkspaceReadRequirement;
  static const AccessRequirement loading = opdWorkspaceReadRequirement;
  static const AccessRequirement retry = opdWorkspaceReadRequirement;
  static const AccessRequirement success = opdClinicalWriteRequirement;
  static const AccessRequirement validation = opdClinicalWriteRequirement;
  static const AccessRequirement rowSelect = opdWorkspaceReadRequirement;
  static const AccessRequirement detail = opdWorkspaceReadRequirement;
  static const AccessRequirement close = opdWorkspaceReadRequirement;

  /// Matrix ∩ `clinical:write`; toolbar create uses [startEncounter] (source).
  static const AccessRequirement create = opdClinicalWriteRequirement;
  static const AccessRequirement update = opdClinicalWriteRequirement;
  static const AccessRequirement delete = opdWorkspaceDeleteRequirement;

  /// Source front-desk gate for queue hub writes (keep source).
  static const AccessRequirement write = opdFrontDeskActionRequirement;
  static const AccessRequirement clinicalWrite = opdClinicalWriteRequirement;
  static const AccessRequirement startEncounter = opdStartEncounterRequirement;

  /// Inventory: queue next-action is empty; row select is the sole hub entry.
  static const AccessRequirement nextAction = opdFrontDeskActionRequirement;
  static const AccessRequirement prioritize = opdFrontDeskActionRequirement;
  static const AccessRequirement changeStatus = opdFrontDeskActionRequirement;
  static const AccessRequirement moveQueue = opdFrontDeskActionRequirement;
  static const AccessRequirement assignDoctor = opdFrontDeskActionRequirement;
  static const AccessRequirement frontDesk = opdFrontDeskActionRequirement;

  /// Nested cross-module write — matrix _(n/a)_; queue hub uses front-desk.
  static const AccessRequirement nestedWrite = opdFrontDeskActionRequirement;

  /// Nested cross-module read — matrix _(n/a)_; reuses board read ∪.
  static const AccessRequirement nestedRead = opdWorkspaceReadRequirement;
  static const AccessRequirement nestedBillingWrite =
      opdBillingActionRequirement;
  static const AccessRequirement nestedAdmissionWrite =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement panelDeepLink = opdFrontDeskActionRequirement;
  static const AccessRequirement entry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      opdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.opdEntry;
}

/// Triage tab atom → permission mapping (inventory + matrix).
///
/// Triage vitals/acuity (`/opd?section=triage`). Nested cross-module matrix
/// rows are _(n/a)_ — billing payment keeps source
/// [opdBillingActionRequirement]; admission handoff keeps source
/// [opdAdmissionHandoffRequirement] (not reachable from triage queue stages).
/// Start encounter keeps source [opdEncounterPermissionRequirement]; vitals /
/// assign-doctor / correct-stage keep source role gates rather than matrix ∩
/// `clinical:write` alone. Route entry keeps catalog ∩ `opd:read`. Tab chrome
/// stays ∪ `patient:read` | `clinical:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Triage tab / count badge | navigate | read ∪ ([tab]) |
/// | Start OPD encounter (toolbar) | create | source encounter ([startEncounter]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Triage scope filter (waiting/urgent/…) | read chrome | ([filters]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | clinical write / form |
/// | Row select → Flow Actions | read | ([rowSelect] / [detail]) |
/// | Next action Record vitals | update | source vitals ([nextActionVitals]) |
/// | Next action Assign / Change doctor | update | source reception ([nextActionAssignDoctor]) |
/// | Next action Correct stage | update | source reception ([nextActionCorrectStage]) |
/// | Nested vitals / assign / routing dialogs | update | source stage gates |
/// | Nested billing / admission panels | nested write | _(n/a)_ — not on triage stages |
/// | Route entry (deep link) | navigate | catalog ∩ `opd:read` |
abstract final class OpdTriageAtomPermissions {
  static const AccessRequirement tab = opdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = opdWorkspaceReadRequirement;
  static const AccessRequirement search = opdWorkspaceReadRequirement;
  static const AccessRequirement filters = opdWorkspaceReadRequirement;
  static const AccessRequirement settings = opdWorkspaceReadRequirement;
  static const AccessRequirement empty = opdWorkspaceReadRequirement;
  static const AccessRequirement loading = opdWorkspaceReadRequirement;
  static const AccessRequirement retry = opdWorkspaceReadRequirement;
  static const AccessRequirement success = opdClinicalWriteRequirement;
  static const AccessRequirement validation = opdClinicalWriteRequirement;
  static const AccessRequirement rowSelect = opdWorkspaceReadRequirement;
  static const AccessRequirement detail = opdWorkspaceReadRequirement;

  /// Matrix ∩ `clinical:write`; toolbar create uses [startEncounter] (source).
  static const AccessRequirement create = opdClinicalWriteRequirement;
  static const AccessRequirement update = opdClinicalWriteRequirement;
  static const AccessRequirement delete = opdWorkspaceDeleteRequirement;
  static const AccessRequirement write = opdClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = opdClinicalWriteRequirement;
  static const AccessRequirement startEncounter = opdStartEncounterRequirement;
  static const AccessRequirement nextAction = opdClinicalWriteRequirement;
  static const AccessRequirement nextActionVitals = opdVitalsActionRequirement;
  static const AccessRequirement nextActionAssignDoctor =
      opdReceptionActionRequirement;
  static const AccessRequirement nextActionCorrectStage =
      opdReceptionActionRequirement;
  static const AccessRequirement recordVitals = opdVitalsActionRequirement;
  static const AccessRequirement assignDoctor = opdReceptionActionRequirement;
  static const AccessRequirement correctStage = opdReceptionActionRequirement;

  /// Nested cross-module write — matrix _(n/a)_; reuses clinical write ∩.
  static const AccessRequirement nestedWrite = opdClinicalWriteRequirement;

  /// Nested cross-module read — matrix _(n/a)_; reuses board read ∪.
  static const AccessRequirement nestedRead = opdWorkspaceReadRequirement;
  static const AccessRequirement nestedBillingWrite =
      opdBillingActionRequirement;
  static const AccessRequirement nestedAdmissionWrite =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement panelDeepLink = opdClinicalWriteRequirement;
  static const AccessRequirement entry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      opdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.opdEntry;
}

/// Follow-ups tab atom → permission mapping (inventory + matrix).
///
/// Shared follow-up worklist (`/opd?section=follow-ups`). Hosted via
/// [FollowUpWorklistPanel] with OPD read/write overrides. Nested cross-module
/// matrix rows are _(n/a)_ — billing / admission / Start OPD are **not**
/// reachable from this tab. Create / update / delete use matrix ∩
/// `clinical:write` via [opdClinicalWriteRequirement]. Route entry keeps
/// catalog ∩ `opd:read` ([routeEntry]); prompt ∪ is [routeEntryUnion]. Tab
/// chrome stays ∪ `patient:read` | `clinical:read`. No Start OPD primary /
/// row next-action on this tab.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → Follow-up details | read | ([detail]) |
/// | Detail Close (read-only footer) | progressive disclosure | ([close]) |
/// | Reschedule follow-up | update | write ∩ ([reschedule]) |
/// | Mark completed | update | write ∩ ([markCompleted] / [complete]) |
/// | Save follow-up (nested reschedule dialog) | update | write ∩ ([saveFollowUp]) |
/// | Hard delete / void | delete | write ∩ ([delete]) — not mounted |
/// | Start OPD encounter | create | absent on this tab ([startEncounter] unused) |
/// | Nested billing / admission panels | nested write | _(n/a)_ — not reachable |
/// | Route entry (deep link) | navigate | catalog ∩ `opd:read` ([routeEntry]) |
abstract final class OpdFollowUpsAtomPermissions {
  static const AccessRequirement tab = opdFollowUpsRequirement;
  static const AccessRequirement listChrome = opdFollowUpsRequirement;
  static const AccessRequirement search = opdFollowUpsRequirement;
  static const AccessRequirement settings = opdFollowUpsRequirement;
  static const AccessRequirement empty = opdFollowUpsRequirement;
  static const AccessRequirement loading = opdFollowUpsRequirement;
  static const AccessRequirement retry = opdFollowUpsRequirement;

  /// Authorized success path after complete / reschedule (write-gated entry).
  static const AccessRequirement success = opdFollowUpsWriteRequirement;

  /// Authorized form validation feedback (nested reschedule dialog).
  static const AccessRequirement validation = opdFollowUpsWriteRequirement;
  static const AccessRequirement rowSelect = opdFollowUpsRequirement;
  static const AccessRequirement detail = opdFollowUpsRequirement;
  static const AccessRequirement close = opdFollowUpsRequirement;
  static const AccessRequirement create = opdFollowUpsWriteRequirement;
  static const AccessRequirement update = opdFollowUpsWriteRequirement;
  static const AccessRequirement delete = opdFollowUpsWriteRequirement;
  static const AccessRequirement reschedule = opdFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted = opdFollowUpsWriteRequirement;
  static const AccessRequirement complete = opdFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp = opdFollowUpsWriteRequirement;
  static const AccessRequirement write = opdFollowUpsWriteRequirement;
  static const AccessRequirement clinicalWrite = opdClinicalWriteRequirement;

  /// Source encounter gate — toolbar does not mount Start OPD on Follow-ups.
  static const AccessRequirement startEncounter = opdStartEncounterRequirement;

  /// Nested cross-module — matrix _(n/a)_; reuses clinical write ∩ / read ∪.
  static const AccessRequirement nestedWrite = opdFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = opdFollowUpsRequirement;
  static const AccessRequirement nestedBillingWrite =
      opdBillingActionRequirement;
  static const AccessRequirement nestedAdmissionWrite =
      opdAdmissionHandoffRequirement;
  static const AccessRequirement entry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = opdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      opdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.opdEntry;
  static const AccessRequirement read = opdFollowUpsRequirement;
}
