import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

enum AppRouteAccess { public, authenticated }

final class AppRouteData {
  const AppRouteData({
    required this.name,
    required this.path,
    this.access = AppRouteAccess.public,
    this.requiredPermissions = const <AppPermission>[],
    this.requiredAnyPermissions = const <AppPermission>[],
    this.requiredAnyRoles = const <AppRole>[],
    this.requiredActiveModules = const <String>[],
    this.requiresTenantContext = false,
    this.requiresFacilityContext = false,
  });

  final String name;
  final String path;
  final AppRouteAccess access;
  final Iterable<AppPermission> requiredPermissions;
  final Iterable<AppPermission> requiredAnyPermissions;
  final Iterable<AppRole> requiredAnyRoles;
  final Iterable<String> requiredActiveModules;
  final bool requiresTenantContext;
  final bool requiresFacilityContext;

  bool get requiresAuthenticatedSession {
    return access == AppRouteAccess.authenticated ||
        accessRequirement.isEmpty == false;
  }

  AccessRequirement get accessRequirement {
    return AccessRequirement(
      allPermissions: requiredPermissions,
      anyPermissions: requiredAnyPermissions,
      anyRoles: requiredAnyRoles,
      activeModules: requiredActiveModules,
      requiresTenantContext: requiresTenantContext,
      requiresFacilityContext: requiresFacilityContext,
    );
  }

  bool get isAuthEntryRoute {
    return path == AppRoutes.login.path ||
        path == AppRoutes.register.path ||
        path == AppRoutes.verifyEmail.path ||
        path == AppRoutes.forgotPassword.path ||
        path == AppRoutes.resetPassword.path;
  }

  bool matchesPath(String locationPath) {
    return locationPath == path;
  }

  String location({
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    return Uri(
      path: path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ).toString();
  }

  String locationWithFrom(Uri from) {
    return location(queryParameters: <String, String>{'from': from.toString()});
  }
}

abstract final class AppRoutes {
  static const List<AppRole> adminShellRoles = <AppRole>[
    AppRole.superAdmin,
    AppRole.tenantAdmin,
    AppRole.facilityAdmin,
  ];

  static const List<AppRole> patientRegistryRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.labTech,
    AppRole.receptionist,
    AppRole.pharmacist,
    AppRole.billing,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.theatreManager,
    AppRole.mortuaryStaff,
    AppRole.mortuaryManager,
  ];
  static const List<AppRole> patientFlowWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.receptionist,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.theatreManager,
  ];
  static const List<AppRole> inpatientFlowWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.wardManager,
    AppRole.icuManager,
  ];
  static const List<AppRole> nursingWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.nurse,
    AppRole.wardManager,
    AppRole.icuManager,
  ];
  static const List<AppRole> emergencyWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.receptionist,
    AppRole.ambulanceOperator,
  ];
  static const List<AppRole> roomsBedsWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.nurse,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.housekeepingManager,
  ];
  static const List<AppRole> icuWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.icuManager,
  ];
  static const List<AppRole> clinicalWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.theatreManager,
  ];
  static const List<AppRole> theaterWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.theatreManager,
  ];
  static const List<AppRole> dischargeWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.wardManager,
  ];
  static const List<AppRole> labWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.labTech,
  ];
  static const List<AppRole> radiologyWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.radiologyTech,
  ];
  static const List<AppRole> pharmacyWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.pharmacist,
  ];
  static const List<AppRole> billingWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.billing,
  ];
  static const List<AppRole> operationsWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.operations,
    AppRole.housekeepingManager,
  ];
  static const List<AppRole> housekeepingWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.houseKeeper,
    AppRole.housekeepingManager,
  ];
  static const List<AppRole> biomedicalWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.biomed,
    AppRole.biomedManager,
  ];
  static const List<AppRole> hrWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.hr,
    AppRole.unitManager,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.theatreManager,
    AppRole.housekeepingManager,
    AppRole.biomedManager,
  ];
  static const List<AppRole> communicationsWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.labTech,
    AppRole.radiologyTech,
    AppRole.pharmacist,
    AppRole.receptionist,
    AppRole.billing,
    AppRole.operations,
    AppRole.hr,
    AppRole.biomed,
    AppRole.houseKeeper,
    AppRole.ambulanceOperator,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.theatreManager,
    AppRole.housekeepingManager,
    AppRole.biomedManager,
    AppRole.mortuaryStaff,
    AppRole.mortuaryManager,
  ];
  static const List<AppRole> reportsWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.pharmacist,
    AppRole.billing,
    AppRole.hr,
    AppRole.biomed,
    AppRole.houseKeeper,
    AppRole.ambulanceOperator,
    AppRole.wardManager,
    AppRole.icuManager,
    AppRole.theatreManager,
    AppRole.housekeepingManager,
    AppRole.biomedManager,
    AppRole.mortuaryStaff,
    AppRole.mortuaryManager,
    AppRole.unitManager,
  ];
  static const List<AppRole> mortuaryWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.mortuaryStaff,
    AppRole.mortuaryManager,
  ];
  static const List<AppRole> tenantSetupWorkspaceRoles = <AppRole>[
    ...adminShellRoles,
    AppRole.hr,
  ];

  static const AppRouteData home = AppRouteData(
    name: 'home',
    path: '/',
    access: AppRouteAccess.authenticated,
  );
  static const AppRouteData settings = AppRouteData(
    name: 'settings',
    path: '/settings',
    access: AppRouteAccess.authenticated,
  );
  static const AppRouteData patients = AppRouteData(
    name: 'patients',
    path: '/patients',
    access: AppRouteAccess.authenticated,
    requiredPermissions: <AppPermission>[AppPermissions.patientRead],
    requiredAnyRoles: patientRegistryRoles,
    requiredActiveModules: <String>['patient-registry'],
  );
  static const AppRouteData reception = AppRouteData(
    name: 'reception',
    path: '/reception',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.patientRead,
      AppPermissions.lastOfficeRead,
    ],
    requiredAnyRoles: patientFlowWorkspaceRoles,
    requiredActiveModules: <String>['patient-registry', 'scheduling-queue'],
  );
  static const AppRouteData billing = AppRouteData(
    name: 'billing',
    path: '/billing',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
    ],
    requiredAnyRoles: billingWorkspaceRoles,
    requiredActiveModules: <String>['billing-payments'],
  );
  static const AppRouteData claims = AppRouteData(
    name: 'claims',
    path: '/claims',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
      AppPermissions.financialApprove,
    ],
    requiredAnyRoles: billingWorkspaceRoles,
    requiredActiveModules: <String>['insurance-claims'],
  );
  static const AppRouteData subscriptions = AppRouteData(
    name: 'subscriptions',
    path: '/subscriptions',
    access: AppRouteAccess.authenticated,
    requiredAnyRoles: <AppRole>[AppRole.superAdmin],
  );
  static const AppRouteData opd = AppRouteData(
    name: 'opd',
    path: '/opd',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.patientRead,
      AppPermissions.clinicalRead,
      AppPermissions.billingRead,
      AppPermissions.operationsRead,
      AppPermissions.emergencyRead,
    ],
    requiredAnyRoles: patientFlowWorkspaceRoles,
    requiredActiveModules: <String>['scheduling-queue'],
  );
  static const AppRouteData emergency = AppRouteData(
    name: 'emergency',
    path: '/emergency',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.emergencyRead,
      AppPermissions.emergencyWrite,
      AppPermissions.operationsRead,
    ],
    requiredAnyRoles: emergencyWorkspaceRoles,
    requiredActiveModules: <String>['scheduling-queue'],
    requiresTenantContext: true,
  );
  static const AppRouteData ipd = AppRouteData(
    name: 'ipd',
    path: '/ipd',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalRead,
      AppPermissions.operationsRead,
      AppPermissions.billingRead,
    ],
    requiredAnyRoles: inpatientFlowWorkspaceRoles,
    requiredActiveModules: <String>['inpatient-bed-management'],
  );
  static const AppRouteData roomsBeds = AppRouteData(
    name: 'roomsBeds',
    path: '/rooms-beds',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalRead,
      AppPermissions.operationsRead,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.systemAdmin,
    ],
    requiredAnyRoles: roomsBedsWorkspaceRoles,
    requiredActiveModules: <String>['inpatient-bed-management'],
  );
  static const AppRouteData icu = AppRouteData(
    name: 'icu',
    path: '/icu',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalRead,
      AppPermissions.emergencyRead,
      AppPermissions.operationsRead,
    ],
    requiredAnyRoles: icuWorkspaceRoles,
    requiredActiveModules: <String>['icu-critical-care'],
  );
  static const AppRouteData nursing = AppRouteData(
    name: 'nursing',
    path: '/nursing',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalRead,
      AppPermissions.patientRead,
      AppPermissions.lastOfficeRead,
      AppPermissions.operationsRead,
    ],
    requiredAnyRoles: nursingWorkspaceRoles,
    requiredActiveModules: <String>['inpatient-bed-management'],
  );
  static const AppRouteData clinical = AppRouteData(
    name: 'clinical',
    path: '/clinical',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    ],
    requiredAnyRoles: clinicalWorkspaceRoles,
    requiredActiveModules: <String>['encounters-vitals'],
  );
  static const AppRouteData physiotherapy = AppRouteData(
    name: 'physiotherapy',
    path: '/physiotherapy',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.patientRead,
      AppPermissions.billingRead,
    ],
    requiredAnyRoles: adminShellRoles,
    requiredActiveModules: <String>['physiotherapy'],
  );
  static const AppRouteData lab = AppRouteData(
    name: 'lab',
    path: '/lab',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.labRead,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
    ],
    requiredAnyRoles: labWorkspaceRoles,
    requiredActiveModules: <String>['lab-workflows'],
  );
  static const AppRouteData radiology = AppRouteData(
    name: 'radiology',
    path: '/radiology',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.radiologyRead,
      AppPermissions.radiologyWrite,
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.billingRead,
    ],
    requiredAnyRoles: radiologyWorkspaceRoles,
    requiredActiveModules: <String>['radiology-workflows'],
  );
  static const AppRouteData pharmacy = AppRouteData(
    name: 'pharmacy',
    path: '/pharmacy',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.pharmacyRead,
      AppPermissions.operationsRead,
    ],
    requiredAnyRoles: pharmacyWorkspaceRoles,
    requiredActiveModules: <String>['pharmacy-dispensing'],
  );
  static const AppRouteData operations = AppRouteData(
    name: 'operations',
    path: '/operations',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.operationsRead,
      AppPermissions.operationsWrite,
    ],
    requiredAnyRoles: operationsWorkspaceRoles,
    requiredActiveModules: <String>['facilities-maintenance'],
    requiresFacilityContext: true,
  );
  static const AppRouteData housekeeping = AppRouteData(
    name: 'housekeeping',
    path: '/housekeeping',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.operationsRead,
      AppPermissions.operationsWrite,
    ],
    requiredAnyRoles: housekeepingWorkspaceRoles,
    requiredActiveModules: <String>['facilities-maintenance'],
    requiresFacilityContext: true,
  );
  static const AppRouteData hr = AppRouteData(
    name: 'hr',
    path: '/hr',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.hrRead,
      AppPermissions.hrWrite,
    ],
    requiredAnyRoles: hrWorkspaceRoles,
    requiredActiveModules: <String>['hr-rosters'],
    requiresTenantContext: true,
  );
  static const AppRouteData biomedical = AppRouteData(
    name: 'biomedical',
    path: '/biomedical',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.biomedRead,
      AppPermissions.biomedWrite,
    ],
    requiredAnyRoles: biomedicalWorkspaceRoles,
    requiredActiveModules: <String>['biomedical-engineering-suite'],
  );
  static const AppRouteData communications = AppRouteData(
    name: 'communications',
    path: '/communications',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.communicationsRead,
      AppPermissions.communicationsWrite,
    ],
    requiredAnyRoles: communicationsWorkspaceRoles,
    requiredActiveModules: <String>['notifications-communications'],
  );
  static const AppRouteData integrations = AppRouteData(
    name: 'integrations',
    path: '/integrations',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.integrationRead,
      AppPermissions.integrationWrite,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.systemAdmin,
    ],
    requiredAnyRoles: adminShellRoles,
    requiredActiveModules: <String>['integrations-core'],
  );
  static const AppRouteData discharge = AppRouteData(
    name: 'discharge',
    path: '/discharge',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.clinicalRead,
      AppPermissions.clinicalWrite,
      AppPermissions.pharmacyRead,
      AppPermissions.billingRead,
      AppPermissions.operationsRead,
    ],
    requiredAnyRoles: dischargeWorkspaceRoles,
    requiredActiveModules: <String>['inpatient-bed-management'],
  );
  static const AppRouteData theater = AppRouteData(
    name: 'theater',
    path: '/theater',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.patientRead,
      AppPermissions.clinicalRead,
      AppPermissions.billingRead,
      AppPermissions.operationsRead,
    ],
    requiredAnyRoles: theaterWorkspaceRoles,
    requiredActiveModules: <String>['theatre-anesthesia'],
  );
  static const AppRouteData reports = AppRouteData(
    name: 'reports',
    path: '/reports',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.reportsRead,
      AppPermissions.reportsWrite,
      AppPermissions.complianceRead,
      AppPermissions.evidenceExport,
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.systemAdmin,
    ],
    requiredAnyRoles: reportsWorkspaceRoles,
    requiredActiveModules: <String>['reporting-analytics'],
  );
  static const AppRouteData mortuary = AppRouteData(
    name: 'mortuary',
    path: '/mortuary',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.mortuaryRead,
      AppPermissions.mortuaryWrite,
      AppPermissions.mortuaryApprove,
      AppPermissions.mortuaryRelease,
      AppPermissions.mortuaryAudit,
    ],
    requiredAnyRoles: mortuaryWorkspaceRoles,
    requiredActiveModules: <String>['mortuary'],
    requiresFacilityContext: true,
  );
  static const AppRouteData tenantFacilitySetup = AppRouteData(
    name: 'tenantFacilitySetup',
    path: '/admin/setup',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.systemAdmin,
      AppPermissions.hrRead,
      AppPermissions.hrWrite,
    ],
    requiredAnyRoles: tenantSetupWorkspaceRoles,
    requiresFacilityContext: true,
  );
  static const AppRouteData accessAdmin = AppRouteData(
    name: 'accessAdmin',
    path: '/admin/access',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.tenantAdmin,
      AppPermissions.facilityAdmin,
      AppPermissions.systemAdmin,
    ],
    requiredAnyRoles: <AppRole>[
      AppRole.superAdmin,
      AppRole.tenantAdmin,
      AppRole.facilityAdmin,
      AppRole.operations,
    ],
    requiresTenantContext: true,
  );
  static const AppRouteData profile = AppRouteData(
    name: 'profile',
    path: '/profile',
    access: AppRouteAccess.authenticated,
  );

  static const AppRouteData login = AppRouteData(name: 'login', path: '/login');

  static const AppRouteData register = AppRouteData(
    name: 'register',
    path: '/register',
  );

  static const AppRouteData verifyEmail = AppRouteData(
    name: 'verifyEmail',
    path: '/verify-email',
  );

  static const AppRouteData forgotPassword = AppRouteData(
    name: 'forgotPassword',
    path: '/forgot-password',
  );

  static const AppRouteData resetPassword = AppRouteData(
    name: 'resetPassword',
    path: '/reset-password',
  );

  static const AppRouteData sessionRestoring = AppRouteData(
    name: 'sessionRestoring',
    path: '/session-restoring',
  );

  static const AppRouteData authRequired = AppRouteData(
    name: 'authRequired',
    path: '/auth-required',
  );

  static const AppRouteData forbidden = AppRouteData(
    name: 'forbidden',
    path: '/forbidden',
  );

  static const List<AppRouteData> all = <AppRouteData>[
    home,
    patients,
    billing,
    claims,
    subscriptions,
    opd,
    emergency,
    ipd,
    roomsBeds,
    icu,
    nursing,
    clinical,
    physiotherapy,
    lab,
    radiology,
    pharmacy,
    operations,
    housekeeping,
    hr,
    biomedical,
    communications,
    integrations,
    discharge,
    mortuary,
    theater,
    reports,
    settings,
    tenantFacilitySetup,
    accessAdmin,
    profile,
    login,
    register,
    verifyEmail,
    forgotPassword,
    resetPassword,
    sessionRestoring,
    authRequired,
    forbidden,
  ];

  static const List<AppRouteData> shellRoutes = <AppRouteData>[
    home,
    patients,
    billing,
    claims,
    subscriptions,
    opd,
    emergency,
    ipd,
    roomsBeds,
    icu,
    nursing,
    clinical,
    physiotherapy,
    lab,
    radiology,
    pharmacy,
    operations,
    housekeeping,
    hr,
    biomedical,
    communications,
    integrations,
    discharge,
    mortuary,
    theater,
    reports,
    settings,
    tenantFacilitySetup,
    accessAdmin,
  ];

  static AppRouteData? matchPath(String locationPath) {
    for (final AppRouteData route in all) {
      if (route.matchesPath(locationPath)) {
        return route;
      }
    }

    return null;
  }

  /// Routes visible to [AppAccessPolicy.isLabFocusedShellUser] in the shell.
  static const List<AppRouteData> labFocusedShellRoutes = <AppRouteData>[
    home,
    patients,
    lab,
    communications,
    settings,
  ];

  static bool isLabFocusedShellRoute(AppRouteData route) {
    return labFocusedShellRoutes.any(
      (AppRouteData candidate) => candidate.name == route.name,
    );
  }

  /// Routes visible to [AppAccessPolicy.isPharmacistFocusedShellUser] in the shell.
  static const List<AppRouteData> pharmacistFocusedShellRoutes = <AppRouteData>[
    home,
    patients,
    pharmacy,
    communications,
    settings,
  ];

  static bool isPharmacistFocusedShellRoute(AppRouteData route) {
    return pharmacistFocusedShellRoutes.any(
      (AppRouteData candidate) => candidate.name == route.name,
    );
  }

  /// Routes visible to [AppAccessPolicy.isReceptionistFocusedShellUser] in the shell.
  static const List<AppRouteData> receptionistFocusedShellRoutes =
      <AppRouteData>[
        home,
        reception,
        patients,
        opd,
        emergency,
        communications,
        settings,
      ];

  static bool isReceptionistFocusedShellRoute(AppRouteData route) {
    return receptionistFocusedShellRoutes.any(
      (AppRouteData candidate) => candidate.name == route.name,
    );
  }

  /// Routes visible to [AppAccessPolicy.isBillingFocusedShellUser] in the shell.
  static const List<AppRouteData> billingFocusedShellRoutes = <AppRouteData>[
    home,
    patients,
    billing,
    claims,
    communications,
    reports,
    settings,
  ];

  static bool isBillingFocusedShellRoute(AppRouteData route) {
    return billingFocusedShellRoutes.any(
      (AppRouteData candidate) => candidate.name == route.name,
    );
  }
}
