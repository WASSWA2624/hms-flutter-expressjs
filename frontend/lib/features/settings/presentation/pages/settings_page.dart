import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/locale/app_locale_controller.dart';
import 'package:hosspi_hms/app/router/app_route_icons.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_mode_controller.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/auth/presentation/widgets/change_password_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeMode themeMode = ref.watch(appThemeModeProvider);
    final Locale selectedLocale =
        ref.watch(appLocaleProvider) ?? _englishLocale;
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final List<_SettingsAction> adminActions = _adminActions(context, l10n)
        .where((_SettingsAction action) {
          return action.requirement?.isAllowed(accessPolicy) ?? true;
        })
        .toList(growable: false);

    return AppScreen(
      title: l10n.settingsTitle,
      body: l10n.settingsBody,
      leadingIcon: AppRouteIcons.settings,
      headerActions: <Widget>[
        AppButton.secondary(
          label: l10n.commonRefreshActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: () {
            ref
              ..invalidate(appLocaleProvider)
              ..invalidate(appThemeModeProvider)
              ..invalidate(appAccessPolicyProvider);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.commonRefreshActionLabel)),
            );
          },
        ),
      ],
      maxWidth: PageMaxWidth.dashboard,
      children: <Widget>[
        _SettingsSectionGrid(
          sections: <Widget>[
            AppScreenSection(
              title: l10n.settingsPreferencesSectionTitle,
              body: l10n.settingsPreferencesSectionBody,
              child: Column(
                children: <Widget>[
                  AppSelectField<Locale>(
                    labelText: l10n.settingsLanguageFieldLabel,
                    value: selectedLocale,
                    options: <AppSelectOption<Locale>>[
                      AppSelectOption<Locale>(
                        value: _englishLocale,
                        label: l10n.settingsLanguageEnglish,
                        leadingIcon: const _LanguageFlag('EN'),
                      ),
                    ],
                    onChanged: (Locale? locale) {
                      if (locale == null) {
                        return;
                      }

                      unawaited(_setLocale(context, ref, locale));
                    },
                  ),
                  SizedBox(height: Theme.of(context).spacing.lg),
                  AppRadioGroup<ThemeMode>(
                    labelText: l10n.settingsThemeModeFieldLabel,
                    value: themeMode,
                    options: <AppRadioOption<ThemeMode>>[
                      AppRadioOption<ThemeMode>(
                        value: ThemeMode.system,
                        label: l10n.settingsThemeModeSystem,
                        description: l10n.settingsThemeModeSystemDescription,
                        secondary: const Icon(Icons.brightness_auto_outlined),
                      ),
                      AppRadioOption<ThemeMode>(
                        value: ThemeMode.light,
                        label: l10n.settingsThemeModeLight,
                        description: l10n.settingsThemeModeLightDescription,
                        secondary: const Icon(Icons.light_mode_outlined),
                      ),
                      AppRadioOption<ThemeMode>(
                        value: ThemeMode.dark,
                        label: l10n.settingsThemeModeDark,
                        description: l10n.settingsThemeModeDarkDescription,
                        secondary: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    onChanged: (ThemeMode? mode) {
                      if (mode == null) {
                        return;
                      }

                      unawaited(_setThemeMode(context, ref, mode));
                    },
                  ),
                ],
              ),
            ),
            AppScreenSection(
              title: l10n.settingsAccountSectionTitle,
              body: l10n.settingsAccountSectionBody,
              child: _SettingsActionList(
                actions: <_SettingsAction>[
                  _SettingsAction(
                    icon: Icons.person_outline,
                    title: l10n.settingsProfileActionTitle,
                    body: l10n.settingsProfileActionBody,
                    onTap: () => context.go(AppRoutes.profile.location()),
                  ),
                  _SettingsAction(
                    icon: Icons.lock_reset_outlined,
                    title: l10n.settingsChangePasswordActionTitle,
                    body: l10n.settingsChangePasswordActionBody,
                    onTap: () => unawaited(_changePassword(context)),
                  ),
                ],
              ),
            ),
            if (adminActions.isNotEmpty)
              AppScreenSection(
                title: l10n.settingsAdministrationSectionTitle,
                body: l10n.settingsAdministrationSectionBody,
                child: _SettingsActionList(actions: adminActions),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _setLocale(
    BuildContext context,
    WidgetRef ref,
    Locale locale,
  ) async {
    try {
      await ref.read(appLocaleProvider.notifier).setLocale(locale);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
    }
  }

  Future<void> _setThemeMode(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
  ) async {
    try {
      await ref.read(appThemeModeProvider.notifier).setThemeMode(themeMode);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangePasswordDialog(),
    );

    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.authPasswordChangedMessage)),
      );
      context.go(AppRoutes.login.location());
    }
  }

  void _showSaveError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.settingsSaveErrorMessage)),
      );
  }
}

final class _SettingsAction {
  const _SettingsAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.requirement,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final AccessRequirement? requirement;
}

List<_SettingsAction> _adminActions(
  BuildContext context,
  AppLocalizations l10n,
) {
  return <_SettingsAction>[
    _SettingsAction(
      icon: Icons.domain_add_outlined,
      title: l10n.settingsTenantFacilitySetupActionTitle,
      body: l10n.settingsTenantFacilitySetupActionBody,
      requirement: _tenantFacilitySetupRequirement,
      onTap: () => context.go(AppRoutes.tenantFacilitySetup.location()),
    ),
    _SettingsAction(
      icon: Icons.admin_panel_settings_outlined,
      title: l10n.settingsSecurityBoundaryLabel,
      body: l10n.settingsSecurityBoundaryBody,
      requirement: _tenantFacilitySetupRequirement,
      onTap: () => context.go(AppRoutes.tenantFacilitySetup.location()),
    ),
  ];
}

const AccessRequirement _tenantFacilitySetupRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ],
  anyRoles: <AppRole>[
    AppRole.superAdmin,
    AppRole.tenantAdmin,
    AppRole.facilityAdmin,
  ],
);

class _SettingsActionList extends StatelessWidget {
  const _SettingsActionList({required this.actions});

  final List<_SettingsAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var index = 0; index < actions.length; index += 1) ...<Widget>[
          _SettingsActionTile(action: actions[index]),
          if (index < actions.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({required this.action});

  final _SettingsAction action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
          child: Row(
            children: <Widget>[
              Icon(
                action.icon,
                size: theme.appTokens.listIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(action.title, style: theme.textTheme.titleSmall),
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
                size: theme.appTokens.listIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageFlag extends StatelessWidget {
  const _LanguageFlag(this.flag);

  final String flag;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(flag, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SettingsSectionGrid extends StatelessWidget {
  const _SettingsSectionGrid({required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useTwoColumns = constraints.maxWidth >= _twoColumnMinWidth;
        final double itemWidth = useTwoColumns
            ? (constraints.maxWidth - theme.spacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.md,
          children: <Widget>[
            for (final Widget section in sections)
              SizedBox(width: itemWidth, child: section),
          ],
        );
      },
    );
  }
}

const Locale _englishLocale = Locale('en');
const double _twoColumnMinWidth = 920;
