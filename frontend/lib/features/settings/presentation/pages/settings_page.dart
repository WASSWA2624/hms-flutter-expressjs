import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_controller.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_preferences.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/app/theme/app_theme_mode_controller.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_account_section.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_configuration_section.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_workspace_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

@immutable
final class SettingsPageQuery {
  const SettingsPageQuery({this.tab = 'preferences', this.panel});

  factory SettingsPageQuery.fromUri(Uri uri) {
    final Map<String, String> params = uri.queryParameters;
    return SettingsPageQuery(
      tab: _nonEmptyParam(params['tab']) ?? 'preferences',
      panel: _nonEmptyParam(params['panel']),
    );
  }

  final String tab;
  final String? panel;

  String location() {
    final Map<String, String> query = <String, String>{};
    if (tab != 'preferences') {
      query['tab'] = tab;
    }
    if (panel != null && panel!.isNotEmpty) {
      query['panel'] = panel!;
    }
    return AppRoutes.settings.location(queryParameters: query);
  }

  SettingsPageQuery copyWith({
    String? tab,
    String? panel,
    bool clearPanel = false,
  }) {
    return SettingsPageQuery(
      tab: tab ?? this.tab,
      panel: clearPanel ? null : (panel ?? this.panel),
    );
  }

  static String? _nonEmptyParam(String? value) {
    final String? trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({required this.initialQuery, super.key});

  final SettingsPageQuery initialQuery;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late String? _expandedSectionId;

  @override
  void initState() {
    super.initState();
    _expandedSectionId = widget.initialQuery.tab;
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery.tab != widget.initialQuery.tab) {
      _expandedSectionId = widget.initialQuery.tab;
    }
  }

  void _onSectionTapped(String sectionId) {
    // Keep one section selected — collapsing leaves an empty intermediate shell.
    if (_expandedSectionId == sectionId) {
      return;
    }
    setState(() {
      _expandedSectionId = sectionId;
    });
    GoRouter.maybeOf(
      context,
    )?.go(SettingsPageQuery(tab: sectionId).location());
  }

  void _onAccountPanelChanged(String panel) {
    GoRouter.maybeOf(context)?.go(
      SettingsPageQuery(tab: 'account', panel: panel).location(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeMode themeMode = ref.watch(appThemeModeProvider);
    final AppAccessibilityPreferences accessibility = ref.watch(
      appAccessibilityProvider,
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool showSettingsWorkspace =
        _settingsWorkspaceRequirement.isAllowed(accessPolicy) ||
        _hrSettingsWorkspaceRequirement.isAllowed(accessPolicy);
    final bool showConfiguration =
        _configTenantRequirement.isAllowed(accessPolicy) ||
        _configFacilityRequirement.isAllowed(accessPolicy);
    final bool showAccount = profileReadRequirement.isAllowed(accessPolicy);
    // When the setup workspace is visible it owns tenant/facility and access
    // entry points; Administration only keeps destinations the workspace does
    // not cover (subscriptions).
    final List<_SettingsAction> adminActions =
        (showSettingsWorkspace
                ? _subscriptionAdminActions(context, l10n)
                : _adminActions(context, l10n))
            .where((_SettingsAction action) {
              return action.requirement?.isAllowed(accessPolicy) ?? true;
            })
            .toList(growable: false);

    final List<_AccordionEntry> sections = <_AccordionEntry>[
      _AccordionEntry(
        id: 'preferences',
        icon: Icons.palette_outlined,
        title: l10n.settingsPreferencesSectionTitle,
        body: l10n.settingsPreferencesSectionBody,
        builder: (_) => Column(
          children: <Widget>[
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
                if (mode == null) return;
                unawaited(_setThemeMode(context, ref, mode));
              },
            ),
          ],
        ),
      ),
      _AccordionEntry(
        id: 'accessibility',
        icon: Icons.accessibility_new_outlined,
        title: l10n.settingsAccessibilitySectionTitle,
        body: l10n.settingsAccessibilitySectionBody,
        builder: (_) => Column(
          children: <Widget>[
            AppCheckboxField(
              title: l10n.settingsReduceMotionLabel,
              subtitle: l10n.settingsReduceMotionDescription,
              value: accessibility.reduceMotion,
              onChanged: (bool value) {
                unawaited(_setReduceMotion(context, ref, value));
              },
            ),
            SizedBox(height: Theme.of(context).spacing.md),
            AppCheckboxField(
              title: l10n.settingsBoldTextLabel,
              subtitle: l10n.settingsBoldTextDescription,
              value: accessibility.boldText,
              onChanged: (bool value) {
                unawaited(_setBoldText(context, ref, value));
              },
            ),
            SizedBox(height: Theme.of(context).spacing.lg),
            AppSelectField<AppTextScaleLevel>(
              labelText: l10n.settingsTextScaleFieldLabel,
              value: accessibility.textScaleLevel,
              options: <AppSelectOption<AppTextScaleLevel>>[
                AppSelectOption<AppTextScaleLevel>(
                  value: AppTextScaleLevel.normal,
                  label: l10n.settingsTextScaleNormal,
                ),
                AppSelectOption<AppTextScaleLevel>(
                  value: AppTextScaleLevel.large,
                  label: l10n.settingsTextScaleLarge,
                ),
                AppSelectOption<AppTextScaleLevel>(
                  value: AppTextScaleLevel.extraLarge,
                  label: l10n.settingsTextScaleExtraLarge,
                ),
              ],
              onChanged: (AppTextScaleLevel? level) {
                if (level == null) return;
                unawaited(_setTextScaleLevel(context, ref, level));
              },
            ),
          ],
        ),
      ),
      if (showAccount)
        _AccordionEntry(
          id: 'account',
          icon: Icons.shield_outlined,
          title: l10n.settingsAccountSectionTitle,
          body: l10n.settingsAccountSectionBody,
          wrapInSection: false,
          builder: (_) => SettingsAccountSection(
            initialPanel: widget.initialQuery.panel,
            onPanelChanged: _onAccountPanelChanged,
          ),
        ),
      if (adminActions.isNotEmpty)
        _AccordionEntry(
          id: 'administration',
          icon: Icons.admin_panel_settings_outlined,
          title: l10n.settingsAdministrationSectionTitle,
          body: l10n.settingsAdministrationSectionBody,
          builder: (_) => _SettingsActionList(actions: adminActions),
        ),
      if (showConfiguration)
        _AccordionEntry(
          id: 'configuration',
          icon: Icons.tune_outlined,
          title: l10n.settingsConfigurationSectionTitle,
          body: l10n.settingsConfigurationSectionBody,
          wrapInSection: false,
          builder: (_) => const SettingsConfigurationSection(),
        ),
      if (showSettingsWorkspace)
        _AccordionEntry(
          id: 'workspace',
          icon: Icons.build_outlined,
          title: l10n.settingsWorkspaceSectionTitle,
          body: l10n.settingsWorkspaceSectionBody,
          wrapInSection: false,
          builder: (_) => const SettingsWorkspaceSection(),
        ),
    ];

    final String? expandedSectionId =
        sections.any((_AccordionEntry s) => s.id == _expandedSectionId)
        ? _expandedSectionId
        : (sections.isNotEmpty ? sections.first.id : null);

    return ResponsivePage(
      maxWidth: PageMaxWidth.dashboard,
      child: SizedBox(
        width: double.infinity,
        child: _SettingsAccordion(
          sections: sections,
          expandedSectionId: expandedSectionId,
          onSectionTapped: _onSectionTapped,
          reduceMotion: accessibility.reduceMotion,
        ),
      ),
    );
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

  Future<void> _setReduceMotion(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref.read(appAccessibilityProvider.notifier).setReduceMotion(value);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
    }
  }

  Future<void> _setBoldText(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref.read(appAccessibilityProvider.notifier).setBoldText(value);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
    }
  }

  Future<void> _setTextScaleLevel(
    BuildContext context,
    WidgetRef ref,
    AppTextScaleLevel level,
  ) async {
    try {
      await ref
          .read(appAccessibilityProvider.notifier)
          .setTextScaleLevel(level);
    } catch (_) {
      if (context.mounted) {
        _showSaveError(context);
      }
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

// ---------------------------------------------------------------------------
// Accordion data model
// ---------------------------------------------------------------------------

final class _AccordionEntry {
  const _AccordionEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.builder,
    this.wrapInSection = true,
  });

  final String id;
  final IconData icon;
  final String title;
  final String body;
  final WidgetBuilder builder;

  /// When false, the builder already provides its own [AppScreenSection]
  /// wrapper (e.g. [SettingsConfigurationSection], [SettingsWorkspaceSection]).
  final bool wrapInSection;
}

// ---------------------------------------------------------------------------
// Accordion widget
// ---------------------------------------------------------------------------

class _SettingsAccordion extends StatelessWidget {
  const _SettingsAccordion({
    required this.sections,
    required this.expandedSectionId,
    required this.onSectionTapped,
    required this.reduceMotion,
  });

  final List<_AccordionEntry> sections;
  final String? expandedSectionId;
  final ValueChanged<String> onSectionTapped;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(bottom: theme.spacing.sm),
          child: AppTabStrip(
            tabs: <AppTabItem>[
              for (final _AccordionEntry section in sections)
                AppTabItem(
                  id: section.id,
                  icon: section.icon,
                  label: section.title,
                ),
            ],
            selectedId: expandedSectionId,
            onTabTapped: onSectionTapped,
          ),
        ),
        for (final _AccordionEntry section in sections)
          _AccordionPanel(
            key: ValueKey<String>(section.id),
            entry: section,
            isExpanded: expandedSectionId == section.id,
            reduceMotion: reduceMotion,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Accordion panel — animated expand/collapse
// ---------------------------------------------------------------------------

class _AccordionPanel extends StatefulWidget {
  const _AccordionPanel({
    super.key,
    required this.entry,
    required this.isExpanded,
    required this.reduceMotion,
  });

  final _AccordionEntry entry;
  final bool isExpanded;
  final bool reduceMotion;

  @override
  State<_AccordionPanel> createState() => _AccordionPanelState();
}

class _AccordionPanelState extends State<_AccordionPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _heightFactor;
  bool _hasBeenExpanded = false;

  static const Duration _animationDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _hasBeenExpanded = widget.isExpanded;
    _controller = AnimationController(
      duration: widget.reduceMotion ? Duration.zero : _animationDuration,
      vsync: this,
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _AccordionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion != oldWidget.reduceMotion) {
      _controller.duration = widget.reduceMotion
          ? Duration.zero
          : _animationDuration;
    }
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _hasBeenExpanded = true;
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasBeenExpanded) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _heightFactor,
      builder: (BuildContext context, Widget? child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _heightFactor.value,
            child: child,
          ),
        );
      },
      child: _AccordionPanelContent(entry: widget.entry),
    );
  }
}

class _AccordionPanelContent extends StatelessWidget {
  const _AccordionPanelContent({required this.entry});

  final _AccordionEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Widget content = entry.builder(context);

    final Widget sectionContent = entry.wrapInSection
        ? AppScreenSection(title: entry.title, body: entry.body, child: content)
        : content;

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.lg),
          child: sectionContent,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings action data + list widgets (unchanged)
// ---------------------------------------------------------------------------

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

List<_SettingsAction> _subscriptionAdminActions(
  BuildContext context,
  AppLocalizations l10n,
) {
  return <_SettingsAction>[
    _SettingsAction(
      icon: Icons.workspace_premium_outlined,
      title: l10n.navigationSubscriptionsLabel,
      body: l10n.settingsSubscriptionsActionBody,
      requirement: _subscriptionsRequirement,
      onTap: () => context.go(AppRoutes.subscriptions.location()),
    ),
  ];
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
    ..._subscriptionAdminActions(context, l10n),
    _SettingsAction(
      icon: Icons.manage_accounts_outlined,
      title: l10n.settingsAccessAdminActionTitle,
      body: l10n.settingsAccessAdminActionBody,
      requirement: _accessAdminRequirement,
      onTap: () => context.go(AppRoutes.accessAdmin.location()),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Access requirements
// ---------------------------------------------------------------------------

const AccessRequirement _tenantFacilitySetupRequirement =
    RouteAccessCatalog.setupEntry;

/// HR users with facility scope see department and unit setup modules only.
const AccessRequirement _hrSettingsWorkspaceRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrRead,
    AppPermissions.hrWrite,
  ],
  anyRoles: <AppRole>[AppRole.hr],
  requiresTenantContext: true,
  requiresFacilityContext: true,
);

const AccessRequirement _subscriptionsRequirement =
    RouteAccessCatalog.subscriptionsEntry;

const AccessRequirement _accessAdminRequirement =
    RouteAccessCatalog.accessAdminEntry;

/// Matches backend [SETTINGS_WORKSPACE_ROLES]: super/tenant/facility admins only.
const AccessRequirement _settingsWorkspaceRequirement = AccessRequirement(
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
  requiresTenantContext: true,
);

const AccessRequirement _configTenantRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.systemAdmin,
  ],
  anyRoles: <AppRole>[AppRole.superAdmin, AppRole.tenantAdmin],
  requiresTenantContext: true,
);

const AccessRequirement _configFacilityRequirement = AccessRequirement(
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
  requiresFacilityContext: true,
);

// ---------------------------------------------------------------------------
// Settings action list & tile widgets (unchanged)
// ---------------------------------------------------------------------------

class _SettingsActionList extends StatelessWidget {
  const _SettingsActionList({required this.actions});

  final List<_SettingsAction> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        for (var index = 0; index < actions.length; index += 1) ...<Widget>[
          _SettingsActionTile(action: actions[index]),
          if (index < actions.length - 1)
            Divider(
              height: 1,
              indent: theme.spacing.sm,
              endIndent: theme.spacing.sm,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
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
                        fontWeight: FontWeight.w500,
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
