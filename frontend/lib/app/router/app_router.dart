import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/route_guards.dart';
import 'package:hosspi_hms/app/router/route_refresh_listenable.dart';
import 'package:hosspi_hms/app/router/route_status_pages.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/login_page.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/register_page.dart';
import 'package:hosspi_hms/features/auth/presentation/pages/verify_email_page.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/change_password_dialog.dart';
import 'package:hosspi_hms/features/home/presentation/pages/home_page.dart';
import 'package:hosspi_hms/features/profile/presentation/pages/user_profile_page.dart';
import 'package:hosspi_hms/features/settings/presentation/pages/settings_page.dart';
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
            path: AppRoutes.settings.path,
            name: AppRoutes.settings.name,
            builder: (_, _) => const SettingsPage(),
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
  AppLocalizations l10n,
) {
  return <_ShellDestinationRoute>[
    _ShellDestinationRoute(
      route: AppRoutes.home,
      destination: ResponsiveShellDestination(
        label: l10n.navigationHomeLabel,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
    ),
    _ShellDestinationRoute(
      route: AppRoutes.settings,
      destination: ResponsiveShellDestination(
        label: l10n.navigationSettingsLabel,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
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
    final List<_ShellDestinationRoute> shellDestinations =
        _localizedShellDestinations(l10n);
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
      notificationsUnreadLabel: l10n.appNotificationsUnreadLabel(0),
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
