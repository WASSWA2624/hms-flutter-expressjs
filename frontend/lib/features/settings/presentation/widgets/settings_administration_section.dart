import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Administration boundaries tab (`/settings?tab=administration`).
///
/// Inventory → matrix mapping (see [SettingsAdministrationAtomPermissions]):
///
/// | Atom | Intent | Gate |
/// | --- | --- | --- |
/// | Section chrome / tab strip entry | read | `profile:read` ∩ admin ∪ |
/// | Tenant and facility setup tile | navigate | catalog `setup:read` ∩ facility |
/// | Subscription plans tile | navigate | catalog platform-admin (`platform:admin` ∪ `PLATFORM_ADMIN`) |
/// | Users and access tile | navigate | catalog `access_admin:read` ∩ tenant |
/// | Create / update / delete / nested write | — | matrix keys; **not mounted** |
///
/// Denied destinations are filtered before build (no disabled tiles / no
/// routine "no access" banners). When all destinations are filtered the
/// section collapses to [SizedBox.shrink]. When Administrative setup workspace
/// is visible, tenant/facility and access tiles are omitted here (owned by
/// the workspace); only subscriptions remain.
class SettingsAdministrationSection extends ConsumerWidget {
  const SettingsAdministrationSection({
    required this.settingsWorkspaceVisible,
    super.key,
  });

  final bool settingsWorkspaceVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<_AdministrationAction> actions =
        _administrationActions(
          context,
          l10n,
          settingsWorkspaceVisible: settingsWorkspaceVisible,
        ).where((_AdministrationAction action) {
          return action.requirement.isAllowed(accessPolicy);
        }).toList(growable: false);

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppAccessGate(
      requirement: settingsAdministrationReadRequirement,
      child: AppCollapsibleSection(
        title: l10n.settingsAdministrationSectionTitle,
        description: l10n.settingsAdministrationSectionBody,
        child: _AdministrationActionList(actions: actions),
      ),
    );
  }
}

final class _AdministrationAction {
  const _AdministrationAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    required this.requirement,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final AccessRequirement requirement;
}

List<_AdministrationAction> _administrationActions(
  BuildContext context,
  AppLocalizations l10n, {
  required bool settingsWorkspaceVisible,
}) {
  final List<_AdministrationAction> subscriptions =
      <_AdministrationAction>[
        _AdministrationAction(
          icon: Icons.workspace_premium_outlined,
          title: l10n.navigationSubscriptionsLabel,
          body: l10n.settingsSubscriptionsActionBody,
          requirement: settingsAdministrationSubscriptionsNavigateRequirement,
          onTap: () => context.go(AppRoutes.subscriptions.location()),
        ),
      ];

  if (settingsWorkspaceVisible) {
    return subscriptions;
  }

  return <_AdministrationAction>[
    _AdministrationAction(
      icon: Icons.domain_add_outlined,
      title: l10n.settingsTenantFacilitySetupActionTitle,
      body: l10n.settingsTenantFacilitySetupActionBody,
      requirement: settingsAdministrationTenantFacilityNavigateRequirement,
      onTap: () => context.go(AppRoutes.tenantFacilitySetup.location()),
    ),
    ...subscriptions,
    _AdministrationAction(
      icon: Icons.manage_accounts_outlined,
      title: l10n.settingsAccessAdminActionTitle,
      body: l10n.settingsAccessAdminActionBody,
      requirement: settingsAdministrationAccessAdminNavigateRequirement,
      onTap: () => context.go(AppRoutes.accessAdmin.location()),
    ),
  ];
}

class _AdministrationActionList extends StatelessWidget {
  const _AdministrationActionList({required this.actions});

  final List<_AdministrationAction> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        for (var index = 0; index < actions.length; index += 1) ...<Widget>[
          _AdministrationActionTile(action: actions[index]),
          if (index < actions.length - 1)
            Divider(
              height: 1,
              indent: theme.spacing.sm,
              endIndent: theme.spacing.sm,
              color: theme.borders.faint,
            ),
        ],
      ],
    );
  }
}

class _AdministrationActionTile extends StatelessWidget {
  const _AdministrationActionTile({required this.action});

  final _AdministrationAction action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: action.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: theme.spacing.md,
            horizontal: theme.spacing.sm,
          ),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.sm),
                  child: Icon(
                    action.icon,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      action.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      action.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
