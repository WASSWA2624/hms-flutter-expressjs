import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/accessibility/app_accessibility_controller.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/settings/presentation/settings_access.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_accessibility_section.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_account_section.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_administration_section.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_configuration_section.dart';
import 'package:hosspi_hms/features/settings/presentation/widgets/settings_preferences_section.dart';
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
    final bool reduceMotion = ref.watch(
      appAccessibilityProvider.select(
        (prefs) => prefs.reduceMotion,
      ),
    );
    final AppAccessPolicy accessPolicy = ref.watch(appAccessPolicyProvider);
    final bool showSettingsWorkspace = settingsWorkspaceSectionVisible(
      accessPolicy,
    );
    final bool showConfiguration =
        settingsConfigurationSectionVisible(accessPolicy);
    final bool showPreferences =
        SettingsPreferencesAtomPermissions.tab.isAllowed(accessPolicy);
    final bool showAccount =
        SettingsAccountAtomPermissions.tab.isAllowed(accessPolicy);
    final bool showAccessibility =
        SettingsAccessibilityAtomPermissions.tab.isAllowed(accessPolicy);
    final bool showAdministration = settingsAdministrationSectionVisible(
      accessPolicy,
      settingsWorkspaceVisible: showSettingsWorkspace,
    );

    final List<_AccordionEntry> sections = <_AccordionEntry>[
      if (showPreferences)
        _AccordionEntry(
          id: 'preferences',
          icon: Icons.palette_outlined,
          title: l10n.settingsPreferencesSectionTitle,
          body: l10n.settingsPreferencesSectionBody,
          wrapInSection: false,
          builder: (_) => const SettingsPreferencesSection(),
        ),
      if (showAccessibility)
        _AccordionEntry(
          id: 'accessibility',
          icon: Icons.accessibility_new_outlined,
          title: l10n.settingsAccessibilitySectionTitle,
          body: l10n.settingsAccessibilitySectionBody,
          wrapInSection: false,
          builder: (_) => const SettingsAccessibilitySection(),
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
      if (showAdministration)
        _AccordionEntry(
          id: 'administration',
          icon: Icons.admin_panel_settings_outlined,
          title: l10n.settingsAdministrationSectionTitle,
          body: l10n.settingsAdministrationSectionBody,
          wrapInSection: false,
          builder: (_) => SettingsAdministrationSection(
            settingsWorkspaceVisible: showSettingsWorkspace,
          ),
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
          reduceMotion: reduceMotion,
        ),
      ),
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

  /// When false, the builder already provides its own [AppCollapsibleSection]
  /// (or equivalent framed chrome) and should not be wrapped again
  /// (e.g. [SettingsConfigurationSection], [SettingsWorkspaceSection]).
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
        ? AppCollapsibleSection(
            title: entry.title,
            description: entry.body,
            child: content,
          )
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
