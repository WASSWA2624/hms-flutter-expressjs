import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

/// One shell/route entry atom: unique permission maps to at most one destination.
final class RouteAccessAtom {
  const RouteAccessAtom({
    required this.routeName,
    required this.path,
    required this.requirement,
    this.entryPermission,
  });

  final String routeName;
  final String path;

  /// Null = authenticated core (home/settings/profile).
  final AppPermission? entryPermission;
  final AccessRequirement requirement;

  /// Domain for custom-role shell scoping (`null` = core always allowed).
  Set<String>? get permissionScopedDomains {
    if (entryPermission == null) {
      return null;
    }
    final String value = entryPermission!.value;
    final int sep = value.indexOf(':');
    final String domain = sep > 0 ? value.substring(0, sep) : value;
    return <String>{domain};
  }
}

/// Central catalog of route/screen entry gates.
///
/// Shell menus, route guards, badges, and feature `routeEntry` aliases must
/// resolve from here — never redefine entry keys in feature `*_access.dart`.
abstract final class RouteAccessCatalog {
  static const AccessRequirement authenticatedCore = AccessRequirement();

  static const RouteAccessAtom home = RouteAccessAtom(
    routeName: 'home',
    path: '/',
    requirement: authenticatedCore,
  );
  static const RouteAccessAtom settings = RouteAccessAtom(
    routeName: 'settings',
    path: '/settings',
    requirement: authenticatedCore,
  );
  static const RouteAccessAtom profile = RouteAccessAtom(
    routeName: 'profile',
    path: '/profile',
    requirement: authenticatedCore,
  );

  static const AccessRequirement receptionEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.receptionRead],
    activeModules: <String>['patient-registry', 'scheduling-queue'],
  );
  static const RouteAccessAtom reception = RouteAccessAtom(
    routeName: 'reception',
    path: '/reception',
    entryPermission: AppPermissions.receptionRead,
    requirement: receptionEntry,
  );

  static const AccessRequirement patientsEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.patientsRead],
    activeModules: <String>['patient-registry'],
  );
  static const RouteAccessAtom patients = RouteAccessAtom(
    routeName: 'patients',
    path: '/patients',
    entryPermission: AppPermissions.patientsRead,
    requirement: patientsEntry,
  );

  static const AccessRequirement opdEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.opdRead],
    activeModules: <String>['scheduling-queue'],
  );
  static const RouteAccessAtom opd = RouteAccessAtom(
    routeName: 'opd',
    path: '/opd',
    entryPermission: AppPermissions.opdRead,
    requirement: opdEntry,
  );

  /// Route entry ∪ matches [AppRoutes.emergency] / Active matrix:
  /// `emergency:read` | `emergency:write` | `operations:read`.
  static const AccessRequirement emergencyEntry = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.emergencyRead,
      AppPermissions.emergencyWrite,
      AppPermissions.operationsRead,
    ],
    activeModules: <String>['scheduling-queue'],
    requiresTenantContext: true,
  );
  static const RouteAccessAtom emergency = RouteAccessAtom(
    routeName: 'emergency',
    path: '/emergency',
    entryPermission: AppPermissions.emergencyRead,
    requirement: emergencyEntry,
  );

  static const AccessRequirement ipdEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.ipdRead],
    activeModules: <String>['inpatient-bed-management'],
  );
  static const RouteAccessAtom ipd = RouteAccessAtom(
    routeName: 'ipd',
    path: '/ipd',
    entryPermission: AppPermissions.ipdRead,
    requirement: ipdEntry,
  );

  static const AccessRequirement roomsBedsEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.roomsBedsRead],
    activeModules: <String>['inpatient-bed-management'],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom roomsBeds = RouteAccessAtom(
    routeName: 'roomsBeds',
    path: '/rooms-beds',
    entryPermission: AppPermissions.roomsBedsRead,
    requirement: roomsBedsEntry,
  );

  static const AccessRequirement icuEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.icuRead],
    activeModules: <String>['icu-critical-care'],
  );
  static const RouteAccessAtom icu = RouteAccessAtom(
    routeName: 'icu',
    path: '/icu',
    entryPermission: AppPermissions.icuRead,
    requirement: icuEntry,
  );

  static const AccessRequirement nursingEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.nursingRead],
    activeModules: <String>['inpatient-bed-management'],
  );
  static const RouteAccessAtom nursing = RouteAccessAtom(
    routeName: 'nursing',
    path: '/nursing',
    entryPermission: AppPermissions.nursingRead,
    requirement: nursingEntry,
  );

  static const AccessRequirement clinicalEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.clinicalRead],
    activeModules: <String>['encounters-vitals'],
  );
  static const RouteAccessAtom clinical = RouteAccessAtom(
    routeName: 'clinical',
    path: '/clinical',
    entryPermission: AppPermissions.clinicalRead,
    requirement: clinicalEntry,
  );

  static const AccessRequirement physiotherapyEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.physiotherapyRead],
    activeModules: <String>['physiotherapy'],
  );
  static const RouteAccessAtom physiotherapy = RouteAccessAtom(
    routeName: 'physiotherapy',
    path: '/physiotherapy',
    entryPermission: AppPermissions.physiotherapyRead,
    requirement: physiotherapyEntry,
  );

  static const AccessRequirement theaterEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.theaterRead],
    activeModules: <String>['theatre-anesthesia'],
  );
  static const RouteAccessAtom theater = RouteAccessAtom(
    routeName: 'theater',
    path: '/theater',
    entryPermission: AppPermissions.theaterRead,
    requirement: theaterEntry,
  );

  static const AccessRequirement dischargeEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.dischargeRead],
    activeModules: <String>['inpatient-bed-management'],
  );
  static const RouteAccessAtom discharge = RouteAccessAtom(
    routeName: 'discharge',
    path: '/discharge',
    entryPermission: AppPermissions.dischargeRead,
    requirement: dischargeEntry,
  );

  static const AccessRequirement labEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.labRead],
    activeModules: <String>['lab-workflows'],
  );
  static const RouteAccessAtom lab = RouteAccessAtom(
    routeName: 'lab',
    path: '/lab',
    entryPermission: AppPermissions.labRead,
    requirement: labEntry,
  );

  static const AccessRequirement radiologyEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.radiologyRead],
    activeModules: <String>['radiology-workflows'],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom radiology = RouteAccessAtom(
    routeName: 'radiology',
    path: '/radiology',
    entryPermission: AppPermissions.radiologyRead,
    requirement: radiologyEntry,
  );

  static const AccessRequirement pharmacyEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.pharmacyRead],
    activeModules: <String>['pharmacy-dispensing'],
  );
  static const RouteAccessAtom pharmacy = RouteAccessAtom(
    routeName: 'pharmacy',
    path: '/pharmacy',
    entryPermission: AppPermissions.pharmacyRead,
    requirement: pharmacyEntry,
  );

  static const AccessRequirement billingEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.billingRead],
    activeModules: <String>['billing-payments'],
  );
  static const RouteAccessAtom billing = RouteAccessAtom(
    routeName: 'billing',
    path: '/billing',
    entryPermission: AppPermissions.billingRead,
    requirement: billingEntry,
  );

  static const AccessRequirement claimsEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.claimsRead],
    activeModules: <String>['insurance-claims'],
  );
  static const RouteAccessAtom claims = RouteAccessAtom(
    routeName: 'claims',
    path: '/claims',
    entryPermission: AppPermissions.claimsRead,
    requirement: claimsEntry,
  );

  static const AccessRequirement subscriptionsEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.subscriptionsRead],
    activeModules: <String>['subscription-controls'],
  );
  static const RouteAccessAtom subscriptions = RouteAccessAtom(
    routeName: 'subscriptions',
    path: '/subscriptions',
    entryPermission: AppPermissions.subscriptionsRead,
    requirement: subscriptionsEntry,
  );

  static const AccessRequirement operationsEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.operationsRead],
    activeModules: <String>['facilities-maintenance'],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom operations = RouteAccessAtom(
    routeName: 'operations',
    path: '/operations',
    entryPermission: AppPermissions.operationsRead,
    requirement: operationsEntry,
  );

  /// Route entry matches [AppRoutes.housekeeping]: ∪ `operations:read` |
  /// `operations:write` + facilities-maintenance + facility context.
  /// Unique shell domain stays `housekeeping` via [entryPermission].
  static const AccessRequirement housekeepingEntry = AccessRequirement(
    anyPermissions: <AppPermission>[
      AppPermissions.operationsRead,
      AppPermissions.operationsWrite,
    ],
    activeModules: <String>['facilities-maintenance'],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom housekeeping = RouteAccessAtom(
    routeName: 'housekeeping',
    path: '/housekeeping',
    entryPermission: AppPermissions.housekeepingRead,
    requirement: housekeepingEntry,
  );

  static const AccessRequirement biomedicalEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.biomedRead],
    activeModules: <String>['biomedical-engineering-suite'],
  );
  static const RouteAccessAtom biomedical = RouteAccessAtom(
    routeName: 'biomedical',
    path: '/biomedical',
    entryPermission: AppPermissions.biomedRead,
    requirement: biomedicalEntry,
  );

  static const AccessRequirement mortuaryEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.mortuaryRead],
    activeModules: <String>['mortuary'],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom mortuary = RouteAccessAtom(
    routeName: 'mortuary',
    path: '/mortuary',
    entryPermission: AppPermissions.mortuaryRead,
    requirement: mortuaryEntry,
  );

  static const AccessRequirement hrEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.hrRead],
    activeModules: <String>['hr-rosters'],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom hr = RouteAccessAtom(
    routeName: 'hr',
    path: '/hr',
    entryPermission: AppPermissions.hrRead,
    requirement: hrEntry,
  );

  static const AccessRequirement communicationsEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.communicationsRead],
    activeModules: <String>['notifications-communications'],
  );
  static const RouteAccessAtom communications = RouteAccessAtom(
    routeName: 'communications',
    path: '/communications',
    entryPermission: AppPermissions.communicationsRead,
    requirement: communicationsEntry,
  );

  static const AccessRequirement integrationsEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.integrationRead],
    activeModules: <String>['integrations-core'],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom integrations = RouteAccessAtom(
    routeName: 'integrations',
    path: '/integrations',
    entryPermission: AppPermissions.integrationRead,
    requirement: integrationsEntry,
  );

  static const AccessRequirement reportsEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.reportsRead],
    activeModules: <String>['reporting-analytics'],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom reports = RouteAccessAtom(
    routeName: 'reports',
    path: '/reports',
    entryPermission: AppPermissions.reportsRead,
    requirement: reportsEntry,
  );

  static const AccessRequirement setupEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.setupRead],
    requiresFacilityContext: true,
  );
  static const RouteAccessAtom tenantFacilitySetup = RouteAccessAtom(
    routeName: 'tenantFacilitySetup',
    path: '/admin/setup',
    entryPermission: AppPermissions.setupRead,
    requirement: setupEntry,
  );

  static const AccessRequirement accessAdminEntry = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.accessAdminRead],
    requiresTenantContext: true,
  );
  static const RouteAccessAtom accessAdmin = RouteAccessAtom(
    routeName: 'accessAdmin',
    path: '/admin/access',
    entryPermission: AppPermissions.accessAdminRead,
    requirement: accessAdminEntry,
  );

  static const List<RouteAccessAtom> allAtoms = <RouteAccessAtom>[
    home,
    settings,
    profile,
    reception,
    patients,
    opd,
    emergency,
    ipd,
    roomsBeds,
    icu,
    nursing,
    clinical,
    physiotherapy,
    theater,
    discharge,
    lab,
    radiology,
    pharmacy,
    billing,
    claims,
    subscriptions,
    operations,
    housekeeping,
    biomedical,
    mortuary,
    hr,
    communications,
    integrations,
    reports,
    tenantFacilitySetup,
    accessAdmin,
  ];

  static final Map<String, RouteAccessAtom> _byName =
      <String, RouteAccessAtom>{
        for (final RouteAccessAtom atom in allAtoms) atom.routeName: atom,
      };

  static RouteAccessAtom? atomForName(String routeName) => _byName[routeName];

  static AccessRequirement? requirementForName(String routeName) {
    return atomForName(routeName)?.requirement;
  }

  /// Entry permission keys that must remain unique across atoms.
  static List<AppPermission> get allEntryPermissions {
    return <AppPermission>[
      for (final RouteAccessAtom atom in allAtoms)
        if (atom.entryPermission != null) atom.entryPermission!,
    ];
  }
}
