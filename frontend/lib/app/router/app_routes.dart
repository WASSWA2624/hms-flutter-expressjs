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
    return path == AppRoutes.login.path || path == AppRoutes.register.path;
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
  );
  static const AppRouteData billing = AppRouteData(
    name: 'billing',
    path: '/billing',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[
      AppPermissions.billingRead,
      AppPermissions.billingWrite,
    ],
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
    requiredActiveModules: <String>['billing-insurance'],
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
    requiredActiveModules: <String>['opd-flow'],
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
    requiresTenantContext: true,
  );
  static const AppRouteData ipd = AppRouteData(
    name: 'ipd',
    path: '/ipd',
    access: AppRouteAccess.authenticated,
    requiredAnyPermissions: <AppPermission>[AppPermissions.clinicalRead],
    requiredActiveModules: <String>['ipd-flow'],
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
    requiredActiveModules: <String>['inpatient-bed-management'],
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
    requiredActiveModules: <String>['encounters-vitals'],
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
    requiredActiveModules: <String>['theatre-anesthesia'],
  );
  static const AppRouteData tenantFacilitySetup = AppRouteData(
    name: 'tenantFacilitySetup',
    path: '/admin/setup',
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
    ],
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
    opd,
    emergency,
    ipd,
    icu,
    nursing,
    clinical,
    lab,
    radiology,
    pharmacy,
    discharge,
    theater,
    settings,
    tenantFacilitySetup,
    profile,
    login,
    register,
    verifyEmail,
    sessionRestoring,
    authRequired,
    forbidden,
  ];

  static const List<AppRouteData> shellRoutes = <AppRouteData>[
    home,
    patients,
    billing,
    claims,
    opd,
    emergency,
    ipd,
    icu,
    nursing,
    clinical,
    lab,
    radiology,
    pharmacy,
    discharge,
    theater,
    settings,
    tenantFacilitySetup,
    profile,
  ];

  static AppRouteData? matchPath(String locationPath) {
    for (final AppRouteData route in all) {
      if (route.matchesPath(locationPath)) {
        return route;
      }
    }

    return null;
  }
}
