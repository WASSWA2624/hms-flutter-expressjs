import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_active_work_helpers.dart';
import 'package:hosspi_hms/shared/components/opd_encounter_dialog.dart';

/// Module entitlement for the patients registry route and tabs.
const String patientRegistryModule = 'patient-registry';

/// View / read UI (matrix ∩ `patient:read`).
///
/// [PermissionModuleMap] also requires [patientRegistryModule] via the
/// permission domain. Matches [AppRoutes.patients] `requiredPermissions`.
/// [RouteAccessCatalog.patientsEntry] historically uses `patients:read` — keep
/// catalog; page / atom maps use this matrix ∩ key.
const AccessRequirement patientRegistryReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.patientRead],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement patientReadRequirement = patientRegistryReadRequirement;

/// Route entry — AppRoutes ∩ `patient:read` + module (matrix). Catalog atom
/// [RouteAccessCatalog.patientsEntry] uses `patients:read` — note in tests.
const AccessRequirement patientRegistryEntryRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.patientRead],
  activeModules: <String>[patientRegistryModule],
);

/// Catalog route-entry atom (`patients:read` + module) — reuse only when
/// matching shell catalog checks; UI chrome uses [patientRegistryReadRequirement].
const AccessRequirement patientRegistryCatalogEntryRequirement =
    RouteAccessCatalog.patientsEntry;

/// Create / update (register, edit, complete record, schedule, duplicate).
///
/// Matrix ∩ `patient:write`. Source inventory (`screens/patients.md`) documents
/// the same gate for register / edit / complete / schedule / duplicate review.
const AccessRequirement patientRegistryWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.patientWrite],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement patientWriteRequirement = patientRegistryWriteRequirement;

/// Delete patient / related records (matrix ∩ `patient:delete`).
const AccessRequirement patientRegistryDeleteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.patientDelete],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement patientDeleteRequirement =
    patientRegistryDeleteRequirement;

/// Schedule appointment / appointment Active Work continue (source ∩ write).
const AccessRequirement patientAppointmentWriteRequirement =
    patientRegistryWriteRequirement;

/// Start / continue OPD — source keeps [opdEncounterPermissionRequirement]
/// (roles + `scheduling-queue`), not matrix ∩ alone.
const AccessRequirement patientOpdEncounterRequirement =
    opdEncounterPermissionRequirement;

/// View / continue active OPD when no Active Work OPD item (source ∪).
const AccessRequirement patientOpdViewActiveRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.clinicalWrite,
    AppPermissions.billingRead,
    AppPermissions.billingWrite,
  ],
);

/// Request admission / discharge handoff (source ∪ clinical:write + IPD module).
const AccessRequirement patientAdmissionWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['inpatient-bed-management'],
);

/// Lab order create / Active Work continue (source ∪ clinical:write + lab).
const AccessRequirement patientLabOrderWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['lab'],
);

/// Radiology order create / Active Work continue.
const AccessRequirement patientRadiologyOrderWriteRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
      activeModules: <String>['radiology'],
    );

/// Theater schedule create / Active Work continue.
const AccessRequirement patientTheaterWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['theater'],
);

/// Physiotherapy create / Active Work continue.
const AccessRequirement patientPhysiotherapyWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>['physiotherapy'],
);

/// Enroll insurance (source ∪ patient|billing|clinical write + claims module).
///
/// Prompt narrative mentions billing:read/write ∩; source inventory keeps this
/// union — keep source and map in tests.
const AccessRequirement patientEnrollInsuranceRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientWrite,
    AppPermissions.billingWrite,
    AppPermissions.clinicalWrite,
  ],
  activeModules: <String>['insurance-claims'],
);

/// Patient report preview (matrix / source ∩ `reports:read`).
const AccessRequirement patientReportReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.reportsRead],
);

/// Billing context panel open-workbench (source ∪ billing:write + module).
const AccessRequirement patientBillingWorkbenchRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.billingWrite],
  activeModules: <String>['billing-payments'],
);

/// Pharmacy context panel open-workbench (∩ `pharmacy:read`).
const AccessRequirement patientPharmacyWorkbenchRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.pharmacyRead],
);

bool isPharmacyRegistryReader(AppAccessPolicy policy) {
  return policy.hasRole(AppRole.pharmacist) &&
      !policy.grants(AppPermissions.patientWrite);
}

bool isBillingRegistryReader(AppAccessPolicy policy) {
  return policy.hasRole(AppRole.billing) &&
      !policy.grants(AppPermissions.patientWrite);
}

bool canReadPatientRegistry(AppAccessPolicy policy) {
  return patientRegistryReadRequirement.isAllowed(policy);
}

bool canWritePatientRegistry(AppAccessPolicy policy) {
  return patientRegistryWriteRequirement.isAllowed(policy);
}

bool canDeletePatientRegistry(AppAccessPolicy policy) {
  return patientRegistryDeleteRequirement.isAllowed(policy);
}

bool canEnterPatientRegistry(AppAccessPolicy policy) {
  return patientRegistryEntryRequirement.isAllowed(policy);
}

bool canViewPatientActiveTab(AppAccessPolicy policy) {
  return PatientActiveAtomPermissions.tab.isAllowed(policy);
}

/// Active Work Continue gate per in-flight kind (matches Quick Action sources).
AccessRequirement patientActiveWorkContinueRequirement(
  PatientActiveWorkKind kind,
) {
  return switch (kind) {
    PatientActiveWorkKind.appointment => patientAppointmentWriteRequirement,
    PatientActiveWorkKind.encounter ||
    PatientActiveWorkKind.queue => patientOpdEncounterRequirement,
    PatientActiveWorkKind.admission => patientAdmissionWriteRequirement,
    PatientActiveWorkKind.labOrder => patientLabOrderWriteRequirement,
    PatientActiveWorkKind.radiologyOrder =>
      patientRadiologyOrderWriteRequirement,
    PatientActiveWorkKind.theater => patientTheaterWriteRequirement,
    PatientActiveWorkKind.therapy => patientPhysiotherapyWriteRequirement,
  };
}

/// Registry tabs share ∩ `patient:read`; all four remain when read is granted.
AccessRequirement patientRegistrySectionTabRequirement(
  PatientRegistrySection section,
) {
  return switch (section) {
    PatientRegistrySection.all ||
    PatientRegistrySection.active ||
    PatientRegistrySection.admitted ||
    PatientRegistrySection.balanceDue => patientRegistryReadRequirement,
  };
}

bool canViewPatientRegistrySection(
  AppAccessPolicy policy,
  PatientRegistrySection section,
) {
  return patientRegistrySectionTabRequirement(section).isAllowed(policy);
}

/// Tabs the user may open; empty when registry read fails.
List<PatientRegistrySection> patientRegistryAllowedSections(
  AppAccessPolicy policy,
) {
  return PatientRegistrySection.values
      .where(
        (PatientRegistrySection section) =>
            canViewPatientRegistrySection(policy, section),
      )
      .toList(growable: false);
}

/// Atom → requirement map for Patients registry **Active**
/// (`/patients?section=active`).
///
/// Inventory: `screens/patients.md` → Active tab (active outpatients / open
/// visits; same CRUD as registry). Nested matrix rows are _(n/a)_; Quick Action
/// / Active Work continues keep source module + clinical gates (documented
/// below). Route entry uses AppRoutes ∩ `patient:read` ([entry]); catalog
/// `patients:read` is [catalogEntry].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active strip tab / count | navigate | read ∩ `patient:read` |
/// | Register patient (primary) | create | write ∩ `patient:write` |
/// | Duplicate review (secondary) | update | write ∩ |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → patient detail | read | read ∩ |
/// | Next action Complete record | update | write ∩ |
/// | Next action Open record (label) | progressive disclosure | read ∩ |
/// | Detail Edit | update | write ∩ |
/// | Detail Delete | delete | delete ∩ `patient:delete` |
/// | Active Work Continue (appointment) | update | write ∩ |
/// | Active Work Continue (OPD) | update / navigate | OPD encounter source |
/// | Active Work Continue (admission) | update | clinical write + IPD module |
/// | Active Work Continue (lab/rad/theater/therapy) | navigate | clinical write + module |
/// | Quick Action Schedule appointment | create | write ∩ |
/// | Quick Action Start OPD | create | OPD encounter source |
/// | Quick Action View/Continue OPD | navigate | clinical\|billing ∪ |
/// | Quick Action Request admission / Discharge | create / update | clinical write + IPD |
/// | Quick Action Lab / Radiology / Theater / Physio | create | clinical write + module |
/// | Quick Action Enroll insurance | create | source ∪ + claims module |
/// | Quick Action Report | export / read | reports:read ∩ |
/// | Related record add/edit | create / update | write ∩ |
/// | Related record delete | delete | delete ∩ |
/// | Pharmacy / billing context panels | nested read | role reader helpers |
/// | Open billing workbench | navigate | billing:write ∪ + module |
/// | Open pharmacy workbench | navigate | pharmacy:read ∩ |
/// | Route entry (deep link) | navigate | patient:read ∩ + module |
abstract final class PatientActiveAtomPermissions {
  static const AccessRequirement tab = patientRegistryReadRequirement;
  static const AccessRequirement listChrome = patientRegistryReadRequirement;
  static const AccessRequirement search = patientRegistryReadRequirement;
  static const AccessRequirement filters = patientRegistryReadRequirement;
  static const AccessRequirement settings = patientRegistryReadRequirement;
  static const AccessRequirement pagination = patientRegistryReadRequirement;
  static const AccessRequirement empty = patientRegistryReadRequirement;
  static const AccessRequirement loading = patientRegistryReadRequirement;
  static const AccessRequirement retry = patientRegistryReadRequirement;
  static const AccessRequirement success = patientRegistryWriteRequirement;
  static const AccessRequirement validation = patientRegistryWriteRequirement;
  static const AccessRequirement rowSelect = patientRegistryReadRequirement;
  static const AccessRequirement detail = patientRegistryReadRequirement;
  static const AccessRequirement nextActionComplete =
      patientRegistryWriteRequirement;
  static const AccessRequirement nextActionOpenRecord =
      patientRegistryReadRequirement;
  static const AccessRequirement create = patientRegistryWriteRequirement;
  static const AccessRequirement update = patientRegistryWriteRequirement;
  static const AccessRequirement delete = patientRegistryDeleteRequirement;
  static const AccessRequirement write = patientRegistryWriteRequirement;
  static const AccessRequirement register = patientRegistryWriteRequirement;
  static const AccessRequirement duplicateReview =
      patientRegistryWriteRequirement;
  static const AccessRequirement edit = patientRegistryWriteRequirement;
  static const AccessRequirement scheduleAppointment =
      patientAppointmentWriteRequirement;
  static const AccessRequirement startOpd = patientOpdEncounterRequirement;
  static const AccessRequirement viewActiveOpd = patientOpdViewActiveRequirement;
  static const AccessRequirement requestAdmission =
      patientAdmissionWriteRequirement;
  static const AccessRequirement discharge = patientAdmissionWriteRequirement;
  static const AccessRequirement labOrder = patientLabOrderWriteRequirement;
  static const AccessRequirement radiologyOrder =
      patientRadiologyOrderWriteRequirement;
  static const AccessRequirement theaterSchedule = patientTheaterWriteRequirement;
  static const AccessRequirement physiotherapy =
      patientPhysiotherapyWriteRequirement;
  static const AccessRequirement enrollInsurance =
      patientEnrollInsuranceRequirement;
  static const AccessRequirement report = patientReportReadRequirement;
  static const AccessRequirement activeWorkContinueAppointment =
      patientAppointmentWriteRequirement;
  static const AccessRequirement activeWorkContinueOpd =
      patientOpdEncounterRequirement;
  static const AccessRequirement activeWorkContinueAdmission =
      patientAdmissionWriteRequirement;
  static const AccessRequirement activeWorkContinueLab =
      patientLabOrderWriteRequirement;
  static const AccessRequirement activeWorkContinueRadiology =
      patientRadiologyOrderWriteRequirement;
  static const AccessRequirement activeWorkContinueTheater =
      patientTheaterWriteRequirement;
  static const AccessRequirement activeWorkContinueTherapy =
      patientPhysiotherapyWriteRequirement;
  static const AccessRequirement billingWorkbench =
      patientBillingWorkbenchRequirement;
  static const AccessRequirement pharmacyWorkbench =
      patientPharmacyWorkbenchRequirement;
  /// Nested cross-module write — matrix _(n/a)_; reuses clinical+module sources.
  static const AccessRequirement nestedWrite = patientAdmissionWriteRequirement;
  /// Nested cross-module read — matrix _(n/a)_; reuses registry read.
  static const AccessRequirement nestedRead = patientRegistryReadRequirement;
  static const AccessRequirement entry = patientRegistryEntryRequirement;
  static const AccessRequirement routeEntry = patientRegistryEntryRequirement;
  static const AccessRequirement catalogEntry =
      patientRegistryCatalogEntryRequirement;
  static const AccessRequirement read = patientRegistryReadRequirement;
}
