import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_requirement_l10n.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class SessionRestoringPage extends StatelessWidget {
  const SessionRestoringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _RouteStatusPage(
      icon: Icons.lock_clock_outlined,
      title: l10n.routeSessionRestoringTitle,
      body: l10n.routeSessionRestoringBody,
      actionLabel: l10n.commonGoHomeActionLabel,
    );
  }
}

class AuthRequiredPage extends StatelessWidget {
  const AuthRequiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _RouteStatusPage(
      icon: Icons.lock_outline,
      title: l10n.routeAuthRequiredTitle,
      body: l10n.routeAuthRequiredBody,
      actionLabel: l10n.commonGoHomeActionLabel,
    );
  }
}

class ForbiddenPage extends ConsumerWidget {
  const ForbiddenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final String? fromPath = GoRouterState.of(
      context,
    ).uri.queryParameters['from'];
    final AppRouteData? deniedRoute = _matchRoute(fromPath);
    final String body;
    if (deniedRoute == null) {
      body = l10n.routeForbiddenBody;
    } else {
      body = accessRequirementDenialMessage(
        l10n,
        deniedRoute.accessRequirement,
        ref.watch(appAccessPolicyProvider),
      );
    }

    return _RouteStatusPage(
      icon: Icons.block_outlined,
      title: l10n.routeForbiddenTitle,
      body: body,
      detail: fromPath,
      actionLabel: l10n.commonGoHomeActionLabel,
    );
  }
}

AppRouteData? _matchRoute(String? locationPath) {
  if (locationPath == null || locationPath.trim().isEmpty) {
    return null;
  }
  final String path = Uri.tryParse(locationPath)?.path ?? locationPath;
  for (final AppRouteData route in AppRoutes.all) {
    if (route.matchesPath(path)) {
      return route;
    }
  }
  return null;
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({this.location, super.key});

  final String? location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _RouteStatusPage(
      icon: Icons.travel_explore_outlined,
      title: l10n.routeNotFoundTitle,
      body: l10n.routeNotFoundBody,
      detail: location,
      actionLabel: l10n.commonGoHomeActionLabel,
    );
  }
}

class _RouteStatusPage extends StatelessWidget {
  const _RouteStatusPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return AppStateScaffold(
      appBarTitle: context.l10n.appTitle,
      icon: icon,
      title: title,
      body: body,
      detail: detail,
      action: AppButton.primary(
        label: actionLabel,
        onPressed: () {
          context.go(AppRoutes.home.location());
        },
      ),
    );
  }
}
