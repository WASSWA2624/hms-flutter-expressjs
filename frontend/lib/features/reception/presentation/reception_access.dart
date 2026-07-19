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

/// Full patient registry navigation must mirror its route authorization.
const AccessRequirement receptionPatientRegistryRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.patientRead],
  activeModules: <String>['patient-registry'],
);

/// Full OPD navigation must mirror the readable OPD route domains.
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

/// Billing toolbar navigation must be absent unless Billing is accessible.
const AccessRequirement receptionBillingWorkspaceRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      ],
      activeModules: <String>['billing-payments'],
    );

AccessRequirement receptionDeskSectionRequirement(
  ReceptionDeskSection section,
) {
  return switch (section) {
    ReceptionDeskSection.appointments ||
    ReceptionDeskSection.queue => receptionSchedulingReadRequirement,
    ReceptionDeskSection.activeVisits => receptionActiveVisitsRequirement,
    ReceptionDeskSection.paymentGate => receptionPaymentGateRequirement,
  };
}

/// Cashier / billing-owned payment capture (not default reception).
const AccessRequirement receptionBillingCashierRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.billingWrite],
  activeModules: <String>['billing-payments'],
);

/// Read-only billing guidance (estimates, outstanding, payment methods).
const AccessRequirement receptionBillingGuidanceRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientRead,
    AppPermissions.billingRead,
  ],
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
