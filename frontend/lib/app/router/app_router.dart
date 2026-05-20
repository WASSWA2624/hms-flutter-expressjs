import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/route_guards.dart';
import 'package:hosspi_hms/app/router/route_refresh_listenable.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/register_page.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/verify_email_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/change_password_dialog.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart';
import 'package:hosspi_hms/features/billing/presentation/pages/billing_workspace_page.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart';
import 'package:hosspi_hms/features/biomedical/presentation/pages/biomedical_workspace_page.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/controllers/claims_workspace_controller.dart';
import 'package:hosspi_hms/features/claims/presentation/pages/claims_workspace_page.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/features/communications/presentation/pages/communications_workspace_page.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/controllers/discharge_workspace_controller.dart';
import 'package:hosspi_hms/features/discharge/presentation/pages/discharge_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/pages/hr_workspace_page.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';
import 'package:hosspi_hms/features/integrations/presentation/controllers/integrations_workspace_controller.dart';
import 'package:hosspi_hms/features/integrations/presentation/pages/integrations_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';
import 'package:hosspi_hms/features/mortuary/presentation/controllers/mortuary_workspace_controller.dart';
import 'package:hosspi_hms/features/mortuary/presentation/pages/mortuary_workspace_page.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/pages/nursing_workspace_page.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/pages/opd_workspace_page.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';
import 'package:hosspi_hms/features/operations/presentation/controllers/operations_workspace_controller.dart';
import 'package:hosspi_hms/features/operations/presentation/pages/operations_workspace_page.dart';
import 'package:hosspi_hms/features/patients/presentation/pages/patient_registry_page.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart';
import 'package:hosspi_hms/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart';
import 'package:hosspi_hms/features/profile/presentation/pages/user_profile_page.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/presentation/controllers/radiology_workspace_controller.dart';
import 'package:hosspi_hms/features/radiology/presentation/pages/radiology_workspace_page.dart';
import 'package:hosspi_hms/features/reports/presentation/pages/reports_workspace_page.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart';
import 'package:hosspi_hms/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart';
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart';
import 'package:hosspi_hms/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/presentation/controllers/theater_workspace_controller.dart';
import 'package:hosspi_hms/features/theater/presentation/pages/theater_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/responsive_shell_scaffold.dart';

final appInitialLocationProvider = Provider<String?>((ref) {
  return null;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final String? initialLocation = ref.watch(appInitialLocationProvider);
  final RouteRefreshListenable refreshListenable = ref.watch(
    routeRefreshListenableProvider,
  );

  return GoRouter(
    initialLocation: initialLocation,
    overridePlatformDefaultLocation: initialLocation != null,
    refreshListenable: refreshListenable,
    redirect: (_, GoRouterState state) {
      final AppRouteGuards guards = AppRouteGuards(
        sessionState: ref.read(sessionStateProvider),
      );

      return guards.redirect(
        AppRouteGuardRequest(
          location: state.uri,
          grantedPermissions: ref.read(grantedAppPermissionsProvider),
        ),
      );
    },
    routes: <RouteBase>[
      ShellRoute(
        builder: (_, GoRouterState state, Widget child) {
          return _AppShell(location: state.uri, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home.path,
            name: AppRoutes.home.name,
            builder: (_, _) => const HomePage(),
          ),
          GoRoute(
            path: AppRoutes.patients.path,
            name: AppRoutes.patients.name,
            builder: (_, _) => const PatientRegistryPage(),
          ),
          GoRoute(
            path: AppRoutes.billing.path,
            name: AppRoutes.billing.name,
            builder: (_, _) => const BillingWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.claims.path,
            name: AppRoutes.claims.name,
            builder: (_, _) => const ClaimsWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.subscriptions.path,
            name: AppRoutes.subscriptions.name,
            builder: (_, _) => const SubscriptionsWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.opd.path,
            name: AppRoutes.opd.name,
            builder: (_, _) => const OpdWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.emergency.path,
            name: AppRoutes.emergency.name,
            builder: (_, _) => const EmergencyWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.ipd.path,
            name: AppRoutes.ipd.name,
            builder: (_, _) => const IpdWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.roomsBeds.path,
            name: AppRoutes.roomsBeds.name,
            builder: (_, _) => const RoomsBedsWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.icu.path,
            name: AppRoutes.icu.name,
            builder: (_, _) => const IcuWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.nursing.path,
            name: AppRoutes.nursing.name,
            builder: (_, _) => const NursingWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.clinical.path,
            name: AppRoutes.clinical.name,
            builder: (_, _) => const ClinicalWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.physiotherapy.path,
            name: AppRoutes.physiotherapy.name,
            builder: (_, _) => const PhysiotherapyWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.lab.path,
            name: AppRoutes.lab.name,
            builder: (_, _) => const LabWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.radiology.path,
            name: AppRoutes.radiology.name,
            builder: (_, _) => const RadiologyWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.pharmacy.path,
            name: AppRoutes.pharmacy.name,
            builder: (_, _) => const PharmacyWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.operations.path,
            name: AppRoutes.operations.name,
            builder: (_, _) => const OperationsWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.housekeeping.path,
            name: AppRoutes.housekeeping.name,
            builder: (_, _) => const HousekeepingWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.hr.path,
            name: AppRoutes.hr.name,
            builder: (_, _) => const HrWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.biomedical.path,
            name: AppRoutes.biomedical.name,
            builder: (_, _) => const BiomedicalWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.communications.path,
            name: AppRoutes.communications.name,
            builder: (_, GoRouterState state) {
              return CommunicationsWorkspacePage(
                initialQuery: CommunicationsWorkspaceQuery.fromUri(state.uri),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.integrations.path,
            name: AppRoutes.integrations.name,
            builder: (_, _) => const IntegrationsWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.discharge.path,
            name: AppRoutes.discharge.name,
            builder: (_, _) => const DischargeWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.mortuary.path,
            name: AppRoutes.mortuary.name,
            builder: (_, _) => const MortuaryWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.theater.path,
            name: AppRoutes.theater.name,
            builder: (_, _) => const TheaterWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.reports.path,
            name: AppRoutes.reports.name,
            builder: (_, _) => const ReportsWorkspacePage(),
          ),
          GoRoute(
            path: AppRoutes.settings.path,
            name: AppRoutes.settings.name,
            builder: (_, _) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.tenantFacilitySetup.path,
            name: AppRoutes.tenantFacilitySetup.name,
            builder: (_, _) => const TenantFacilitySetupPage(),
          ),
          GoRoute(
            path: AppRoutes.profile.path,
            name: AppRoutes.profile.name,
            builder: (_, _) => const UserProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.login.path,
        name: AppRoutes.login.name,
        builder: (_, GoRouterState state) {
          return LoginPage(from: state.uri.queryParameters['from']);
        },
      ),
      GoRoute(
        path: AppRoutes.register.path,
        name: AppRoutes.register.name,
        builder: (_, _) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail.path,
        name: AppRoutes.verifyEmail.name,
        builder: (_, GoRouterState state) {
          return VerifyEmailPage(
            token: state.uri.queryParameters['token'],
            email: state.uri.queryParameters['email'],
            reason: state.uri.queryParameters['reason'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sessionRestoring.path,
        name: AppRoutes.sessionRestoring.name,
        builder: (_, _) => const SessionRestoringPage(),
      ),
      GoRoute(
        path: AppRoutes.authRequired.path,
        name: AppRoutes.authRequired.name,
        builder: (_, _) => const AuthRequiredPage(),
      ),
      GoRoute(
        path: AppRoutes.forbidden.path,
        name: AppRoutes.forbidden.name,
        builder: (_, _) => const ForbiddenPage(),
      ),
    ],
    errorBuilder: (_, GoRouterState state) {
      return NotFoundPage(location: state.uri.path);
    },
  );
});

final class _ShellDestinationRoute {
  const _ShellDestinationRoute({
    required this.route,
    required this.destination,
  });

  final AppRouteData route;
  final ResponsiveShellDestination destination;
}

List<_ShellDestinationRoute> _localizedShellDestinations(
  AppLocalizations l10n, {
  int? billingWorkloadCount,
  int? claimsWorkloadCount,
  int? subscriptionsWorkloadCount,
  int? opdWorkloadCount,
  int? emergencyWorkloadCount,
  int? ipdWorkloadCount,
  int? roomsBedsWorkloadCount,
  int? icuCriticalCount,
  int? nursingWorkloadCount,
  int? clinicalWorkloadCount,
  int? labWorkloadCount,
  int? radiologyWorkloadCount,
  int? pharmacyWorkloadCount,
  int? operationsWorkloadCount,
  int? housekeepingWorkloadCount,
  int? hrWorkloadCount,
  int? biomedicalWorkloadCount,
  int? communicationsWorkloadCount,
  int? integrationsWorkloadCount,
  int? dischargeWorkloadCount,
  int? mortuaryWorkloadCount,
  int? theaterWorkloadCount,
}) {
  return <_ShellDestinationRoute>[
    _ShellDestinationRoute(
      route: AppRoutes.home,
      destination: ResponsiveShellDestination(
        label: l10n.navigationHomeLabel,
        icon: AppRouteIcons.home,
        selectedIcon: AppRouteIcons.homeSelected,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.patients,
      destination: ResponsiveShellDestination(
        label: l10n.navigationPatientsLabel,
        icon: AppRouteIcons.patients,
        selectedIcon: AppRouteIcons.patientsSelected,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.billing,
      destination: ResponsiveShellDestination(
        label: 'Billing',
        icon: AppRouteIcons.billing,
        selectedIcon: AppRouteIcons.billingSelected,
        badgeCount: billingWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.claims,
      destination: ResponsiveShellDestination(
        label: l10n.navigationClaimsLabel,
        icon: AppRouteIcons.claims,
        selectedIcon: AppRouteIcons.claimsSelected,
        badgeCount: claimsWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.subscriptions,
      destination: ResponsiveShellDestination(
        label: 'Subscriptions',
        icon: AppRouteIcons.subscriptions,
        selectedIcon: AppRouteIcons.subscriptionsSelected,
        badgeCount: subscriptionsWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.opd,
      destination: ResponsiveShellDestination(
        label: l10n.navigationOpdLabel,
        icon: AppRouteIcons.opd,
        selectedIcon: AppRouteIcons.opdSelected,
        badgeCount: opdWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.emergency,
      destination: ResponsiveShellDestination(
        label: 'Emergency',
        icon: AppRouteIcons.emergency,
        selectedIcon: AppRouteIcons.emergencySelected,
        badgeCount: emergencyWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.ipd,
      destination: ResponsiveShellDestination(
        label: l10n.navigationIpdLabel,
        icon: AppRouteIcons.ipd,
        selectedIcon: AppRouteIcons.ipdSelected,
        badgeCount: ipdWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.roomsBeds,
      destination: ResponsiveShellDestination(
        label: l10n.roomsBedsTitle,
        icon: AppRouteIcons.roomsBeds,
        selectedIcon: AppRouteIcons.roomsBedsSelected,
        badgeCount: roomsBedsWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.icu,
      destination: ResponsiveShellDestination(
        label: 'ICU',
        icon: AppRouteIcons.icu,
        selectedIcon: AppRouteIcons.icuSelected,
        badgeCount: icuCriticalCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.nursing,
      destination: ResponsiveShellDestination(
        label: l10n.navigationNursingLabel,
        icon: AppRouteIcons.nursing,
        selectedIcon: AppRouteIcons.nursingSelected,
        badgeCount: nursingWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.clinical,
      destination: ResponsiveShellDestination(
        label: l10n.navigationClinicalLabel,
        icon: AppRouteIcons.clinical,
        selectedIcon: AppRouteIcons.clinicalSelected,
        badgeCount: clinicalWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.physiotherapy,
      destination: ResponsiveShellDestination(
        label: l10n.navigationPhysiotherapyLabel,
        icon: AppRouteIcons.physiotherapy,
        selectedIcon: AppRouteIcons.physiotherapySelected,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.lab,
      destination: ResponsiveShellDestination(
        label: l10n.navigationLabLabel,
        icon: AppRouteIcons.lab,
        selectedIcon: AppRouteIcons.labSelected,
        badgeCount: labWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.radiology,
      destination: ResponsiveShellDestination(
        label: l10n.navigationRadiologyLabel,
        icon: AppRouteIcons.radiology,
        selectedIcon: AppRouteIcons.radiologySelected,
        badgeCount: radiologyWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.pharmacy,
      destination: ResponsiveShellDestination(
        label: l10n.navigationPharmacyLabel,
        icon: AppRouteIcons.pharmacy,
        selectedIcon: AppRouteIcons.pharmacySelected,
        badgeCount: pharmacyWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.operations,
      destination: ResponsiveShellDestination(
        label: l10n.navigationOperationsLabel,
        icon: AppRouteIcons.operations,
        selectedIcon: AppRouteIcons.operationsSelected,
        badgeCount: operationsWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.housekeeping,
      destination: ResponsiveShellDestination(
        label: l10n.housekeepingTitle,
        icon: AppRouteIcons.housekeeping,
        selectedIcon: AppRouteIcons.housekeepingSelected,
        badgeCount: housekeepingWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.hr,
      destination: ResponsiveShellDestination(
        label: 'HR',
        icon: AppRouteIcons.hr,
        selectedIcon: AppRouteIcons.hrSelected,
        badgeCount: hrWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.biomedical,
      destination: ResponsiveShellDestination(
        label: l10n.navigationBiomedicalLabel,
        icon: AppRouteIcons.biomedical,
        selectedIcon: AppRouteIcons.biomedicalSelected,
        badgeCount: biomedicalWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.communications,
      destination: ResponsiveShellDestination(
        label: l10n.navigationCommunicationsLabel,
        icon: AppRouteIcons.communications,
        selectedIcon: AppRouteIcons.communicationsSelected,
        badgeCount: communicationsWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.integrations,
      destination: ResponsiveShellDestination(
        label: l10n.navigationIntegrationsLabel,
        icon: AppRouteIcons.integrations,
        selectedIcon: AppRouteIcons.integrationsSelected,
        badgeCount: integrationsWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.discharge,
      destination: ResponsiveShellDestination(
        label: 'Discharge',
        icon: AppRouteIcons.discharge,
        selectedIcon: AppRouteIcons.dischargeSelected,
        badgeCount: dischargeWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.mortuary,
      destination: ResponsiveShellDestination(
        label: l10n.navigationMortuaryLabel,
        icon: AppRouteIcons.mortuary,
        selectedIcon: AppRouteIcons.mortuarySelected,
        badgeCount: mortuaryWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.theater,
      destination: ResponsiveShellDestination(
        label: l10n.navigationTheaterLabel,
        icon: AppRouteIcons.theater,
        selectedIcon: AppRouteIcons.theaterSelected,
        badgeCount: theaterWorkloadCount,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.reports,
      destination: ResponsiveShellDestination(
        label: l10n.navigationReportsLabel,
        icon: AppRouteIcons.reports,
        selectedIcon: AppRouteIcons.reportsSelected,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.settings,
      destination: ResponsiveShellDestination(
        label: l10n.navigationSettingsLabel,
        icon: AppRouteIcons.settings,
        selectedIcon: AppRouteIcons.settingsSelected,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.tenantFacilitySetup,
      destination: ResponsiveShellDestination(
        label: l10n.navigationSetupLabel,
        icon: AppRouteIcons.setup,
        selectedIcon: AppRouteIcons.setupSelected,
      ),
    ),
  ];
}

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.location, required this.child});

  final Uri location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool canAccessBilling = _canAccessShellRoute(
      AppRoutes.billing,
      accessPolicy,
    );
    final bool canAccessClaims = _canAccessShellRoute(
      AppRoutes.claims,
      accessPolicy,
    );
    final bool canAccessSubscriptions = _canAccessShellRoute(
      AppRoutes.subscriptions,
      accessPolicy,
    );
    final bool canAccessOpd = _canAccessShellRoute(AppRoutes.opd, accessPolicy);
    final bool canAccessEmergency = _canAccessShellRoute(
      AppRoutes.emergency,
      accessPolicy,
    );
    final bool canAccessIpd = _canAccessShellRoute(AppRoutes.ipd, accessPolicy);
    final bool canAccessRoomsBeds = _canAccessShellRoute(
      AppRoutes.roomsBeds,
      accessPolicy,
    );
    final bool canAccessIcu = _canAccessShellRoute(AppRoutes.icu, accessPolicy);
    final bool canAccessNursing = _canAccessShellRoute(
      AppRoutes.nursing,
      accessPolicy,
    );
    final bool canAccessClinical = _canAccessShellRoute(
      AppRoutes.clinical,
      accessPolicy,
    );
    final bool canAccessLab = _canAccessShellRoute(AppRoutes.lab, accessPolicy);
    final bool canAccessRadiology = _canAccessShellRoute(
      AppRoutes.radiology,
      accessPolicy,
    );
    final bool canAccessPharmacy = _canAccessShellRoute(
      AppRoutes.pharmacy,
      accessPolicy,
    );
    final bool canAccessOperations = _canAccessShellRoute(
      AppRoutes.operations,
      accessPolicy,
    );
    final bool canAccessHousekeeping = _canAccessShellRoute(
      AppRoutes.housekeeping,
      accessPolicy,
    );
    final bool canAccessHr = _canAccessShellRoute(AppRoutes.hr, accessPolicy);
    final bool canAccessBiomedical = _canAccessShellRoute(
      AppRoutes.biomedical,
      accessPolicy,
    );
    final bool canAccessCommunications = _canAccessShellRoute(
      AppRoutes.communications,
      accessPolicy,
    );
    final bool canAccessIntegrations = _canAccessShellRoute(
      AppRoutes.integrations,
      accessPolicy,
    );
    final bool canAccessDischarge = _canAccessShellRoute(
      AppRoutes.discharge,
      accessPolicy,
    );
    final bool canAccessMortuary = _canAccessShellRoute(
      AppRoutes.mortuary,
      accessPolicy,
    );
    final bool canAccessTheater = _canAccessShellRoute(
      AppRoutes.theater,
      accessPolicy,
    );
    final int? opdWorkloadCount = canAccessOpd
        ? ref
              .watch(opdWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (OpdWorkspaceState state) => state.workloadCount,
                failure: (_) => null,
              )
        : null;
    final int? emergencyWorkloadCount = canAccessEmergency
        ? ref
              .watch(emergencyWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (EmergencyWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? ipdWorkloadCount = canAccessIpd
        ? ref
              .watch(ipdWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (IpdWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? roomsBedsWorkloadCount = canAccessRoomsBeds
        ? ref
              .watch(roomsBedsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (RoomsBedsWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? icuCriticalCount = canAccessIcu
        ? ref
              .watch(icuWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (IcuWorkspaceState state) {
                  return state.criticalCount > 0 ? state.criticalCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? nursingWorkloadCount = canAccessNursing
        ? ref
              .watch(nursingWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (NursingWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? clinicalWorkloadCount = canAccessClinical
        ? ref
              .watch(clinicalWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (ClinicalWorkspaceState state) {
                  final int count =
                      state.waitingReviewCount +
                      state.urgentCount +
                      state.resultsReadyCount;
                  return count > 0 ? count : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? labWorkloadCount = canAccessLab
        ? ref
              .watch(labWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (LabWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? radiologyWorkloadCount = canAccessRadiology
        ? ref
              .watch(radiologyWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (RadiologyWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? billingWorkloadCount = canAccessBilling
        ? ref
              .watch(billingWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (BillingWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? claimsWorkloadCount = canAccessClaims
        ? ref
              .watch(claimsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (ClaimsWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? subscriptionsWorkloadCount = canAccessSubscriptions
        ? ref
              .watch(subscriptionsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (SubscriptionsWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? pharmacyWorkloadCount = canAccessPharmacy
        ? ref
              .watch(pharmacyWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (PharmacyWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? operationsWorkloadCount = canAccessOperations
        ? ref
              .watch(operationsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (OperationsWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? housekeepingWorkloadCount = canAccessHousekeeping
        ? ref
              .watch(housekeepingWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (HousekeepingWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? hrWorkloadCount = canAccessHr
        ? ref
              .watch(hrWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (HrWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? biomedicalWorkloadCount = canAccessBiomedical
        ? ref
              .watch(biomedicalWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (BiomedicalWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? communicationsWorkloadCount = canAccessCommunications
        ? ref
              .watch(communicationsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (CommunicationsWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? integrationsWorkloadCount = canAccessIntegrations
        ? ref
              .watch(integrationsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (IntegrationWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? notificationUnreadCount = canAccessCommunications
        ? ref
              .watch(communicationsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (CommunicationsWorkspaceState state) {
                  return state.unreadBadgeCount > 0
                      ? state.unreadBadgeCount
                      : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? dischargeWorkloadCount = canAccessDischarge
        ? ref
              .watch(dischargeWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (DischargeWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? mortuaryWorkloadCount = canAccessMortuary
        ? ref
              .watch(mortuaryWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (MortuaryWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final int? theaterWorkloadCount = canAccessTheater
        ? ref
              .watch(theaterWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (TheaterWorkspaceState state) {
                  return state.workloadCount > 0 ? state.workloadCount : null;
                },
                failure: (_) => null,
              )
        : null;
    final List<_ShellDestinationRoute> shellDestinations =
        _localizedShellDestinations(
              l10n,
              billingWorkloadCount: billingWorkloadCount,
              claimsWorkloadCount: claimsWorkloadCount,
              subscriptionsWorkloadCount: subscriptionsWorkloadCount,
              opdWorkloadCount: opdWorkloadCount,
              emergencyWorkloadCount: emergencyWorkloadCount,
              ipdWorkloadCount: ipdWorkloadCount,
              roomsBedsWorkloadCount: roomsBedsWorkloadCount,
              icuCriticalCount: icuCriticalCount,
              nursingWorkloadCount: nursingWorkloadCount,
              clinicalWorkloadCount: clinicalWorkloadCount,
              labWorkloadCount: labWorkloadCount,
              radiologyWorkloadCount: radiologyWorkloadCount,
              pharmacyWorkloadCount: pharmacyWorkloadCount,
              operationsWorkloadCount: operationsWorkloadCount,
              housekeepingWorkloadCount: housekeepingWorkloadCount,
              hrWorkloadCount: hrWorkloadCount,
              biomedicalWorkloadCount: biomedicalWorkloadCount,
              communicationsWorkloadCount: communicationsWorkloadCount,
              integrationsWorkloadCount: integrationsWorkloadCount,
              dischargeWorkloadCount: dischargeWorkloadCount,
              mortuaryWorkloadCount: mortuaryWorkloadCount,
              theaterWorkloadCount: theaterWorkloadCount,
            )
            .where((_ShellDestinationRoute destination) {
              return _canAccessShellRoute(destination.route, accessPolicy);
            })
            .toList(growable: false);
    final int selectedIndex = _selectedIndexForPath(
      location.path,
      shellDestinations,
    );
    final AuthSession? session = ref.watch(
      sessionStateProvider.select((state) => state.session),
    );
    final AppConnectivityStatus connectivityStatus = ref
        .watch(appConnectivityStatusProvider)
        .when(
          data: (AppConnectivityStatus status) => status,
          error: (_, _) => AppConnectivityStatus.online,
          loading: () => AppConnectivityStatus.online,
        );

    return ResponsiveAppShell(
      title: l10n.appTitle,
      compactTitle: l10n.appShortTitle,
      connectivityStatus: connectivityStatus,
      onlineLabel: l10n.appStatusOnlineLabel,
      offlineLabel: l10n.appStatusOfflineLabel,
      openMenuTooltip: l10n.appOpenNavigationMenuTooltip,
      closeDrawerTooltip: l10n.appCloseNavigationMenuTooltip,
      toggleSidebarTooltip: l10n.appToggleSidebarTooltip,
      accountTooltip: l10n.appAccountTooltip,
      notificationsTooltip: l10n.appNotificationsTooltip,
      unreadNotificationCount: notificationUnreadCount ?? 0,
      notificationsUnreadLabel: l10n.appNotificationsUnreadLabel(
        notificationUnreadCount ?? 0,
      ),
      onNotificationsSelected: canAccessCommunications
          ? () {
              context.go(
                AppRoutes.communications.location(
                  queryParameters: <String, String>{
                    'panel': CommunicationsPanel.notifications.serverValue,
                  },
                ),
              );
            }
          : null,
      profileLabel: l10n.appUserMenuProfileLabel,
      settingsLabel: l10n.appUserMenuSettingsLabel,
      changePasswordLabel: l10n.appUserMenuChangePasswordLabel,
      logoutLabel: l10n.appUserMenuLogoutLabel,
      signedInLabel: l10n.appUserMenuSignedInLabel,
      userProfile: _userMenuProfile(session),
      showUserAvatar: session != null,
      onProfileSelected: () {
        if (!AppRoutes.profile.matchesPath(location.path)) {
          context.go(AppRoutes.profile.location());
        }
      },
      onSettingsSelected: () {
        if (!AppRoutes.settings.matchesPath(location.path)) {
          context.go(AppRoutes.settings.location());
        }
      },
      onChangePasswordSelected: () async {
        final changed = await showAppDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const ChangePasswordDialog(),
        );
        if (changed == true && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.authPasswordChangedMessage)),
          );
          context.go(AppRoutes.login.location());
        }
      },
      onLogoutSelected: () async {
        await ref.read(authRepositoryProvider).logout();
        await ref.read(sessionStateProvider.notifier).logout();
        if (context.mounted) {
          context.go(AppRoutes.login.location());
        }
      },
      destinations: <ResponsiveShellDestination>[
        for (final _ShellDestinationRoute destination in shellDestinations)
          destination.destination,
      ],
      selectedIndex: selectedIndex,
      onDestinationSelected: (int index) {
        if (index == selectedIndex) {
          return;
        }

        context.go(shellDestinations[index].route.location());
      },
      child: child,
    );
  }

  int _selectedIndexForPath(
    String locationPath,
    List<_ShellDestinationRoute> shellDestinations,
  ) {
    final int index = shellDestinations.indexWhere((
      _ShellDestinationRoute destination,
    ) {
      return destination.route.matchesPath(locationPath);
    });

    return index < 0 ? 0 : index;
  }
}

bool _canAccessShellRoute(AppRouteData route, AppAccessPolicy accessPolicy) {
  return route.accessRequirement.isAllowed(accessPolicy);
}

UserMenuProfileData? _userMenuProfile(AuthSession? session) {
  if (session == null) {
    return null;
  }

  final AuthUserProfile? user = session.user;
  final String? subject = _nonEmpty(session.subject);
  final String? email = _nonEmpty(user?.email) ?? _emailFromSubject(subject);
  final String? name =
      _nonEmpty(user?.fullName) ??
      _nonEmpty(user?.effectiveTitle) ??
      _distinct(subject, email) ??
      email;
  final String? initials =
      _nonEmpty(user?.initials) ?? _initialsFrom(name ?? email);

  return UserMenuProfileData(
    name: name,
    email: email,
    title: _distinct(user?.effectiveTitle, name),
    overallRole: user?.overallRole,
    userType: user?.userType,
    initials: initials,
  );
}

String? _emailFromSubject(String? subject) {
  if (subject == null || !subject.contains('@')) {
    return null;
  }

  return subject;
}

String? _initialsFrom(String? value) {
  final String? normalized = _nonEmpty(value);
  if (normalized == null) {
    return null;
  }

  final List<String> words = normalized
      .replaceAll(RegExp(r'[@._-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return null;
  }
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }

  return <String>[
    words.first.substring(0, 1),
    words.last.substring(0, 1),
  ].join().toUpperCase();
}

String? _distinct(String? value, String? other) {
  final String? normalized = _nonEmpty(value);
  final String? normalizedOther = _nonEmpty(other);
  if (normalized == null) {
    return null;
  }
  if (normalizedOther != null &&
      normalized.toLowerCase() == normalizedOther.toLowerCase()) {
    return null;
  }

  return normalized;
}

String? _nonEmpty(String? value) {
  final String? normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
