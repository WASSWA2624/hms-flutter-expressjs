import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart';

/// Roles that may open the Reception / front-desk workspace.
const AccessRequirement receptionWorkspaceRequirement = AccessRequirement(
  anyRoles: AppRoutes.patientFlowWorkspaceRoles,
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.lastOfficeRead,
  ],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Front-desk mutations: register, check-in, route, assign provider.
const AccessRequirement receptionFrontDeskWriteRequirement =
    opdFrontDeskActionRequirement;

/// Patient creation and appointment scheduling additionally require write data
/// rights; a front-desk role by itself is not sufficient for these controls.
const AccessRequirement receptionPatientWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.patientWrite],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Appointment and queue worklists contain patient-identifiable scheduling data.
const AccessRequirement receptionSchedulingReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.patientRead],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Active visits mirror the backend OPD flow list authorization.
const AccessRequirement receptionActiveVisitsRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.clinicalRead,
    AppPermissions.billingRead,
    AppPermissions.operationsRead,
    AppPermissions.emergencyRead,
  ],
  activeModules: <String>['scheduling-queue'],
);

/// Payment-gate guidance uses authoritative invoice data and therefore mirrors
/// the backend Billing read scope. It never grants cashier mutations.
const AccessRequirement receptionPaymentGateRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.billingRead],
  activeModules: <String>['billing-payments'],
);

/// Patient registry navigation uses the route's authoritative access policy.
final AccessRequirement receptionPatientRegistryRequirement =
    AppRoutes.patients.accessRequirement;

/// Outpatient navigation must mirror the readable OPD route domains.
const AccessRequirement receptionOpdWorkspaceRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.clinicalRead,
    AppPermissions.billingRead,
    AppPermissions.operationsRead,
    AppPermissions.emergencyRead,
  ],
  activeModules: <String>['scheduling-queue'],
);

AccessRequirement receptionDeskSectionRequirement(
  ReceptionDeskSection section,
) {
  return switch (section) {
    ReceptionDeskSection.appointments ||
    ReceptionDeskSection.queue ||
    ReceptionDeskSection.highPriority => receptionSchedulingReadRequirement,
    ReceptionDeskSection.activeVisits => receptionActiveVisitsRequirement,
    ReceptionDeskSection.followUps => receptionFollowUpsRequirement,
    ReceptionDeskSection.paymentGate => receptionPaymentGateRequirement,
  };
}

/// Follow-ups worklist: patient or clinical read (matches follow-up list auth).
const AccessRequirement receptionFollowUpsRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.clinicalRead,
  ],
  activeModules: <String>['patient-registry', 'scheduling-queue'],
);

/// Front-desk insurance enrollment capture (not claims finalize).
const AccessRequirement receptionInsuranceCaptureRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.patientWrite,
        AppPermissions.billingWrite,
      ],
      activeModules: <String>['insurance-claims'],
    );
