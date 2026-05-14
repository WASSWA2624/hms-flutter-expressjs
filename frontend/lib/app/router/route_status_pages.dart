import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:go_router/go_router.dart';

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

class ForbiddenPage extends StatelessWidget {
  const ForbiddenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _RouteStatusPage(
      icon: Icons.block_outlined,
      title: l10n.routeForbiddenTitle,
      body: l10n.routeForbiddenBody,
      actionLabel: l10n.commonGoHomeActionLabel,
    );
  }
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
