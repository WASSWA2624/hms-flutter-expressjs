import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

/// Resolves secondary toolbar actions for a home dashboard profile.
List<Widget> buildHomeToolbarSecondary({
  required AppLocalizations l10n,
  required HomeDashboardProfile profile,
  required AppAccessPolicy policy,
  required BuildContext context,
}) {
  final List<Widget> actions = <Widget>[];

  for (final HomeToolbarActionId actionId in profile.toolbarActionIds) {
    switch (actionId) {
      case HomeToolbarActionId.openHrWorkspace:
        if (!homeHrMetricAccessAllowed(policy)) {
          continue;
        }
        actions.add(
          AppButton.secondary(
            label: l10n.homeOpenHrWorkspaceLink,
            leadingIcon: Icons.open_in_new_outlined,
            semanticLabel: l10n.homeOpenHrWorkspaceLink,
            tooltip: l10n.homeOpenHrWorkspaceLink,
            onPressed: () => context.go(AppRoutes.hr.location()),
          ),
        );
    }
  }

  return actions;
}
