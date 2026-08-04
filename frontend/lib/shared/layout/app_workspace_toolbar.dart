import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_global_fault_report_action.dart';
import 'package:hosspi_hms/shared/actions/app_global_housekeeping_request_action.dart';
import 'package:hosspi_hms/shared/actions/app_workspace_refresh_action.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_menu_item_label.dart';
import 'package:hosspi_hms/shared/layout/app_toolbar_overflow_resolver.dart';
import 'package:hosspi_hms/shared/layout/app_toolbar_overflow_section.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_board_toggle.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_summary_notification.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_view_toggle.dart';

/// Declarative workspace toolbar configuration.
@immutable
final class AppWorkspaceToolbarConfig {
  const AppWorkspaceToolbarConfig({
    this.primary,
    this.secondary = const <Widget>[],
    this.onRefresh,
    this.isRefreshing = false,
    this.showGlobalActions = true,
    this.showFaultReport = true,
    this.showHousekeepingRequest = true,
    this.refreshLabel,
    this.faultReportLabel,
    this.housekeepingRequestLabel,
    this.overflowLabel,
    this.notificationsMenuLabel,
    this.notificationsMenuTooltip,
    this.summaryNotifications = const <AppWorkspaceSummaryNotification>[],
    this.maxVisibleScreenActions = 3,
    this.overflowSections,
    this.toolbarLayoutActions,
  });

  final Widget? primary;
  final List<Widget> secondary;
  final Future<void> Function()? onRefresh;
  final bool isRefreshing;
  final bool showGlobalActions;
  final bool showFaultReport;
  final bool showHousekeepingRequest;
  final String? refreshLabel;
  final String? faultReportLabel;
  final String? housekeepingRequestLabel;
  final String? overflowLabel;
  final String? notificationsMenuLabel;
  final String? notificationsMenuTooltip;
  final List<AppWorkspaceSummaryNotification> summaryNotifications;
  final int maxVisibleScreenActions;

  /// When set, toolbar actions are grouped into labeled overflow sections.
  /// Global actions should be included in their sections instead of relying on
  /// [showGlobalActions].
  final List<AppToolbarOverflowSection>? overflowSections;

  /// Optional display order for inline/overflow layout when [overflowSections]
  /// is set. Must reference the same widget instances as section actions.
  final List<Widget>? toolbarLayoutActions;

  bool get hasActions {
    return primary != null ||
        secondary.isNotEmpty ||
        _sectionActions.isNotEmpty ||
        onRefresh != null ||
        showGlobalActions;
  }

  List<Widget> get _sectionActions {
    if (overflowSections == null) {
      return const <Widget>[];
    }
    return overflowSections!
        .expand((AppToolbarOverflowSection section) => section.actions)
        .toList(growable: false);
  }
}

/// Left/right action clusters with responsive overflow for module workspaces.
class AppWorkspaceToolbar extends ConsumerWidget {
  const AppWorkspaceToolbar({required this.config, super.key});

  final AppWorkspaceToolbarConfig config;

  static const double _iconActionWidth = 72;
  static const double _labeledActionWidth = 212;
  static const double _longLabeledActionWidth = 248;
  static const double _toolbarActionEstimateWidth = 280;
  static const double _toolbarLayoutSafetyMargin = 24;
  static const double _boardToggleWidth = 280;
  static const double _viewToggleWidth = 196;
  static const double _moreButtonWidth = 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool showLabels = breakpoint.showsToolbarActionLabels;

    final List<Widget> screenActions = _screenActions(config);
    final List<Widget> globalActions = config.overflowSections != null
        ? const <Widget>[]
        : _globalActions(context);

    return AppActionLabelScope(
      showLabels: showLabels,
      forceIconOnly: !showLabels,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (!constraints.hasBoundedWidth) {
            return _ToolbarActionRow(
              spacing: theme.spacing.xs,
              providerContainer: ProviderScope.containerOf(context),
              inlineActions: <Widget>[...screenActions, ...globalActions],
            );
          }

          return _AdaptiveToolbarLayout(
            maxWidth: constraints.maxWidth,
            screenActions: screenActions,
            globalActions: globalActions,
            pinnedInlinePrimary: config.primary,
            maxVisibleScreenActions: config.maxVisibleScreenActions,
            showLabels: showLabels,
            spacing: theme.spacing.xs,
            overflowLabel: config.overflowLabel ?? 'More actions',
            summaryNotifications: config.summaryNotifications,
            notificationsMenuLabel: config.notificationsMenuLabel,
            notificationsMenuTooltip: config.notificationsMenuTooltip,
            overflowSections: config.overflowSections,
            providerContainer: ProviderScope.containerOf(context),
          );
        },
      ),
    );
  }

  static List<Widget> _screenActions(AppWorkspaceToolbarConfig config) {
    if (config.toolbarLayoutActions != null) {
      return config.toolbarLayoutActions!;
    }
    if (config.overflowSections != null) {
      return config._sectionActions;
    }
    return <Widget>[
      ...config.secondary,
      if (config.primary != null) config.primary!,
    ];
  }

  static _ToolbarLayout _resolveLayout({
    required double maxWidth,
    required List<Widget> screenActions,
    required List<Widget> globalActions,
    required Widget? pinnedInlinePrimary,
    required int maxVisibleScreenActions,
    required bool showLabels,
    required double spacing,
  }) {
    if (!showLabels) {
      final List<Widget> overflowScreen = screenActions
          .where((Widget action) => !identical(action, pinnedInlinePrimary))
          .toList(growable: false);
      return _ToolbarLayout(
        inlineActions: pinnedInlinePrimary == null
            ? const <Widget>[]
            : <Widget>[pinnedInlinePrimary],
        overflowActions: <Widget>[...overflowScreen, ...globalActions],
      );
    }

    List<Widget> inlineScreen = screenActions
        .take(maxVisibleScreenActions.clamp(0, screenActions.length))
        .toList();
    final List<Widget> overflowScreen = screenActions
        .skip(inlineScreen.length)
        .toList();
    List<Widget> inlineGlobal = List<Widget>.from(globalActions);
    final List<Widget> overflowGlobal = <Widget>[];

    while (!_fits(
      inlineScreen: inlineScreen,
      inlineGlobal: inlineGlobal,
      overflowCount: overflowScreen.length + overflowGlobal.length,
      maxWidth: maxWidth,
      showLabels: showLabels,
      spacing: spacing,
    )) {
      if (inlineGlobal.isNotEmpty) {
        overflowGlobal.insert(0, inlineGlobal.removeLast());
        continue;
      }
      if (_evictLastInlineScreenAction(
        inlineScreen,
        overflowScreen,
        pinnedInlinePrimary,
      )) {
        continue;
      }
      break;
    }

    if (!_fits(
      inlineScreen: inlineScreen,
      inlineGlobal: inlineGlobal,
      overflowCount: overflowScreen.length + overflowGlobal.length,
      maxWidth: maxWidth,
      showLabels: showLabels,
      spacing: spacing,
    )) {
      overflowScreen
        ..clear()
        ..addAll(
          screenActions.where(
            (Widget action) => !_isPinnedPrimary(action, pinnedInlinePrimary),
          ),
        );
      overflowGlobal
        ..clear()
        ..addAll(globalActions);
      inlineScreen = pinnedInlinePrimary == null
          ? <Widget>[]
          : <Widget>[pinnedInlinePrimary];
      inlineGlobal = <Widget>[];
    }

    return _ToolbarLayout(
      inlineActions: <Widget>[...inlineScreen, ...inlineGlobal],
      overflowActions: <Widget>[...overflowScreen, ...overflowGlobal],
    );
  }

  static bool _fits({
    required List<Widget> inlineScreen,
    required List<Widget> inlineGlobal,
    required int overflowCount,
    required double maxWidth,
    required bool showLabels,
    required double spacing,
  }) {
    final List<Widget> inlineActions = <Widget>[
      ...inlineScreen,
      ...inlineGlobal,
    ];
    var width = _rowWidth(
      inlineActions,
      showLabels: showLabels,
      spacing: spacing,
    );
    if (overflowCount > 0) {
      width += spacing + _moreButtonWidth;
    }
    return width <= maxWidth - _toolbarLayoutSafetyMargin;
  }

  static double _rowWidth(
    List<Widget> actions, {
    required bool showLabels,
    required double spacing,
  }) {
    if (actions.isEmpty) {
      return 0;
    }

    var total = 0.0;
    for (var index = 0; index < actions.length; index += 1) {
      if (index > 0) {
        total += spacing;
      }
      total += _estimateActionWidth(actions[index], showLabels: showLabels);
    }
    return total;
  }

  static bool _isPinnedPrimary(Widget action, Widget? pinnedInlinePrimary) {
    return pinnedInlinePrimary != null &&
        identical(action, pinnedInlinePrimary);
  }

  static bool _evictLastInlineScreenAction(
    List<Widget> inlineScreen,
    List<Widget> overflowScreen,
    Widget? pinnedInlinePrimary,
  ) {
    for (var index = inlineScreen.length - 1; index >= 0; index -= 1) {
      if (_isPinnedPrimary(inlineScreen[index], pinnedInlinePrimary)) {
        continue;
      }
      overflowScreen.insert(0, inlineScreen.removeAt(index));
      return true;
    }
    return false;
  }

  static int _indexOfLastEvictableInlineAction(
    List<Widget> inlineActions,
    Widget? pinnedInlinePrimary,
  ) {
    for (var index = inlineActions.length - 1; index >= 0; index -= 1) {
      if (_isPinnedPrimary(inlineActions[index], pinnedInlinePrimary)) {
        continue;
      }
      return index;
    }
    return -1;
  }

  static double _estimateActionWidth(
    Widget action, {
    required bool showLabels,
  }) {
    if (action is AppWorkspaceBoardToggle<Object>) {
      return showLabels ? _boardToggleWidth : 96;
    }
    if (action is AppWorkspaceViewToggle) {
      return showLabels ? _viewToggleWidth : _iconActionWidth;
    }
    if (action is AppGlobalFaultReportAction ||
        action is AppGlobalHousekeepingRequestAction) {
      return showLabels ? _longLabeledActionWidth : _iconActionWidth;
    }
    if (action is AppWorkspaceRefreshAction) {
      return showLabels ? _labeledActionWidth : _iconActionWidth;
    }
    return showLabels ? _toolbarActionEstimateWidth : _iconActionWidth;
  }

  List<Widget> _globalActions(BuildContext context) {
    if (!config.showGlobalActions) {
      return const <Widget>[];
    }

    final List<Widget> actions = <Widget>[];
    if (config.onRefresh != null) {
      actions.add(
        AppWorkspaceRefreshAction(
          label: config.refreshLabel ?? 'Refresh',
          isLoading: config.isRefreshing,
          onPressed: () {
            unawaited(config.onRefresh?.call());
          },
        ),
      );
    }
    if (config.showHousekeepingRequest) {
      actions.add(
        AppGlobalHousekeepingRequestAction(
          label: config.housekeepingRequestLabel ?? 'Request maintenance',
        ),
      );
    }
    if (config.showFaultReport) {
      actions.add(
        AppGlobalFaultReportAction(
          label: config.faultReportLabel ?? 'Report equipment fault',
        ),
      );
    }
    return actions;
  }
}

final class _ToolbarLayout {
  const _ToolbarLayout({
    required this.inlineActions,
    required this.overflowActions,
  });

  final List<Widget> inlineActions;
  final List<Widget> overflowActions;
}

class _AdaptiveToolbarLayout extends StatefulWidget {
  const _AdaptiveToolbarLayout({
    required this.maxWidth,
    required this.screenActions,
    required this.globalActions,
    required this.pinnedInlinePrimary,
    required this.maxVisibleScreenActions,
    required this.showLabels,
    required this.spacing,
    required this.overflowLabel,
    required this.summaryNotifications,
    required this.notificationsMenuLabel,
    required this.notificationsMenuTooltip,
    required this.overflowSections,
    required this.providerContainer,
  });

  final double maxWidth;
  final List<Widget> screenActions;
  final List<Widget> globalActions;
  final Widget? pinnedInlinePrimary;
  final int maxVisibleScreenActions;
  final bool showLabels;
  final double spacing;
  final String overflowLabel;
  final List<AppWorkspaceSummaryNotification> summaryNotifications;
  final String? notificationsMenuLabel;
  final String? notificationsMenuTooltip;
  final List<AppToolbarOverflowSection>? overflowSections;
  final ProviderContainer providerContainer;

  @override
  State<_AdaptiveToolbarLayout> createState() => _AdaptiveToolbarLayoutState();
}

class _AdaptiveToolbarLayoutState extends State<_AdaptiveToolbarLayout> {
  final GlobalKey _rowKey = GlobalKey();
  late _ToolbarLayout _layout;

  @override
  void initState() {
    super.initState();
    _resetLayout();
    WidgetsBinding.instance.addPostFrameCallback(_measureOverflow);
  }

  @override
  void didUpdateWidget(covariant _AdaptiveToolbarLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.showLabels != widget.showLabels ||
        oldWidget.spacing != widget.spacing ||
        oldWidget.maxVisibleScreenActions != widget.maxVisibleScreenActions ||
        oldWidget.pinnedInlinePrimary != widget.pinnedInlinePrimary ||
        !_listEquals(oldWidget.screenActions, widget.screenActions) ||
        !_listEquals(oldWidget.globalActions, widget.globalActions)) {
      _resetLayout();
      WidgetsBinding.instance.addPostFrameCallback(_measureOverflow);
    }
  }

  void _resetLayout() {
    _layout = AppWorkspaceToolbar._resolveLayout(
      maxWidth: widget.maxWidth,
      screenActions: widget.screenActions,
      globalActions: widget.globalActions,
      pinnedInlinePrimary: widget.pinnedInlinePrimary,
      maxVisibleScreenActions: widget.maxVisibleScreenActions,
      showLabels: widget.showLabels,
      spacing: widget.spacing,
    );
  }

  void _measureOverflow(_) {
    if (!mounted) {
      return;
    }

    final double estimatedWidth =
        AppWorkspaceToolbar._rowWidth(
          _layout.inlineActions,
          showLabels: widget.showLabels,
          spacing: widget.spacing,
        ) +
        (_layout.overflowActions.isNotEmpty
            ? widget.spacing + AppWorkspaceToolbar._moreButtonWidth
            : 0);

    if (estimatedWidth <=
            widget.maxWidth - AppWorkspaceToolbar._toolbarLayoutSafetyMargin ||
        _layout.inlineActions.isEmpty) {
      return;
    }

    final int evictIndex =
        AppWorkspaceToolbar._indexOfLastEvictableInlineAction(
          _layout.inlineActions,
          widget.pinnedInlinePrimary,
        );
    if (evictIndex < 0) {
      return;
    }

    setState(() {
      final List<Widget> inlineActions = List<Widget>.from(
        _layout.inlineActions,
      );
      final List<Widget> overflowActions = List<Widget>.from(
        _layout.overflowActions,
      );
      overflowActions.insert(0, inlineActions.removeAt(evictIndex));
      _layout = _ToolbarLayout(
        inlineActions: inlineActions,
        overflowActions: overflowActions,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback(_measureOverflow);
  }

  bool _listEquals(List<Widget> left, List<Widget> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (!identical(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return _ToolbarActionRow(
      key: _rowKey,
      spacing: widget.spacing,
      inlineActions: _layout.inlineActions,
      overflowActions: _layout.overflowActions,
      overflowLabel: widget.overflowLabel,
      summaryNotifications: widget.summaryNotifications,
      notificationsMenuLabel: widget.notificationsMenuLabel,
      notificationsMenuTooltip: widget.notificationsMenuTooltip,
      overflowSections: widget.overflowSections,
      providerContainer: widget.providerContainer,
    );
  }
}

class _ToolbarActionRow extends StatelessWidget {
  const _ToolbarActionRow({
    super.key,
    required this.spacing,
    required this.inlineActions,
    required this.providerContainer,
    this.overflowActions = const <Widget>[],
    this.overflowLabel,
    this.summaryNotifications = const <AppWorkspaceSummaryNotification>[],
    this.notificationsMenuLabel,
    this.notificationsMenuTooltip,
    this.overflowSections,
  });

  final double spacing;
  final List<Widget> inlineActions;
  final List<Widget> overflowActions;
  final String? overflowLabel;
  final List<AppWorkspaceSummaryNotification> summaryNotifications;
  final String? notificationsMenuLabel;
  final String? notificationsMenuTooltip;
  final List<AppToolbarOverflowSection>? overflowSections;
  final ProviderContainer providerContainer;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];

    for (var index = 0; index < inlineActions.length; index += 1) {
      if (index > 0) {
        children.add(SizedBox(width: spacing));
      }
      children.add(inlineActions[index]);
    }

    final List<AppWorkspaceSummaryNotification> visibleNotifications =
        visibleWorkspaceSummaryNotifications(summaryNotifications);

    if (overflowActions.isNotEmpty || visibleNotifications.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(SizedBox(width: spacing));
      }
      children.add(
        _ToolbarOverflowMenu(
          label: overflowLabel ?? 'More actions',
          actions: overflowActions,
          summaryNotifications: visibleNotifications,
          notificationsMenuLabel: notificationsMenuLabel,
          notificationsMenuTooltip: notificationsMenuTooltip,
          overflowSections: overflowSections,
          container: providerContainer,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _ToolbarOverflowMenu extends ConsumerWidget {
  const _ToolbarOverflowMenu({
    required this.label,
    required this.actions,
    required this.container,
    this.summaryNotifications = const <AppWorkspaceSummaryNotification>[],
    this.notificationsMenuLabel,
    this.notificationsMenuTooltip,
    this.overflowSections,
  });

  final String label;
  final List<Widget> actions;
  final ProviderContainer container;
  final List<AppWorkspaceSummaryNotification> summaryNotifications;
  final String? notificationsMenuLabel;
  final String? notificationsMenuTooltip;
  final List<AppToolbarOverflowSection>? overflowSections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String notificationsLabel = notificationsMenuLabel ?? 'Notifications';

    final List<AppWorkspaceSummaryNotification> visibleNotifications =
        visibleWorkspaceSummaryNotifications(summaryNotifications);

    final bool hasOverflowContent = overflowSections != null
        ? _sectionedOverflowHasContent(
            ref,
            overflowSections!,
            actions,
            visibleNotifications,
          )
        : resolveToolbarOverflowEntries(actions, ref).isNotEmpty ||
              visibleNotifications.isNotEmpty;

    if (!hasOverflowContent) {
      return const SizedBox.shrink();
    }

    final int attentionTotal = totalWorkspaceSummaryNotificationCount(
      summaryNotifications,
    );
    final String triggerLabel = attentionTotal > 0
        ? context.l10n.workspaceToolbarOverflowAttentionTooltip(attentionTotal)
        : label;
    final MenuStyle menuStyle = _toolbarMenuStyle(theme, colorScheme);
    final MenuStyle submenuStyle = _toolbarSubmenuStyle(theme, colorScheme);
    final List<Widget> menuChildren = overflowSections != null
        ? _buildSectionedMenuChildren(
            context: context,
            ref: ref,
            theme: theme,
            sections: overflowSections!,
            overflowActions: actions,
            visibleNotifications: visibleNotifications,
            notificationsLabel: notificationsLabel,
            notificationsTooltip: notificationsMenuTooltip,
            submenuStyle: submenuStyle,
          )
        : _buildFlatMenuChildren(
            context: context,
            ref: ref,
            theme: theme,
            entries: resolveToolbarOverflowEntries(actions, ref),
            visibleNotifications: visibleNotifications,
            notificationsLabel: notificationsLabel,
            notificationsTooltip: notificationsMenuTooltip,
            submenuStyle: submenuStyle,
          );

    return UncontrolledProviderScope(
      container: container,
      child: MenuAnchor(
        style: menuStyle,
        alignmentOffset: Offset(0, theme.spacing.xs),
        crossAxisUnconstrained: false,
        menuChildren: menuChildren,
        builder:
            (BuildContext context, MenuController controller, Widget? child) {
              return AppButton.popupMenuTrigger(
                context: context,
                icon: Icons.more_vert,
                semanticLabel: triggerLabel,
                attentionCount: attentionTotal,
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
              );
            },
      ),
    );
  }

  bool _sectionedOverflowHasContent(
    WidgetRef ref,
    List<AppToolbarOverflowSection> sections,
    List<Widget> overflowActions,
    List<AppWorkspaceSummaryNotification> visibleNotifications,
  ) {
    final Set<Widget> overflowSet = Set<Widget>.from(overflowActions);
    for (final AppToolbarOverflowSection section in sections) {
      if (section.showsNotifications && visibleNotifications.isNotEmpty) {
        return true;
      }
      for (final Widget action in section.actions) {
        if (!overflowSet.contains(action)) {
          continue;
        }
        if (!isToolbarOverflowActionVisible(action, ref)) {
          continue;
        }
        if (resolveToolbarOverflowEntry(action, ref) != null) {
          return true;
        }
      }
    }
    return false;
  }

  List<Widget> _buildFlatMenuChildren({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required List<AppToolbarOverflowEntry> entries,
    required List<AppWorkspaceSummaryNotification> visibleNotifications,
    required String notificationsLabel,
    required String? notificationsTooltip,
    required MenuStyle submenuStyle,
  }) {
    return <Widget>[
      for (final AppToolbarOverflowEntry entry in entries)
        _overflowMenuItem(
          context: context,
          theme: theme,
          entry: entry,
          ref: ref,
        ),
      if (visibleNotifications.isNotEmpty)
        _ToolbarNotificationsSubmenu(
          label: notificationsLabel,
          tooltip: notificationsTooltip,
          aggregateCount: totalWorkspaceSummaryNotificationCount(
            summaryNotifications,
          ),
          notifications: visibleNotifications,
          submenuStyle: submenuStyle,
          buttonStyle: _overflowMenuItemStyle(theme),
          itemStyle: ({required bool selected}) =>
              _overflowMenuItemStyle(theme, selected: selected),
        ),
    ];
  }

  List<Widget> _buildSectionedMenuChildren({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeData theme,
    required List<AppToolbarOverflowSection> sections,
    required List<Widget> overflowActions,
    required List<AppWorkspaceSummaryNotification> visibleNotifications,
    required String notificationsLabel,
    required String? notificationsTooltip,
    required MenuStyle submenuStyle,
  }) {
    final Set<Widget> overflowSet = Set<Widget>.from(overflowActions);
    final List<Widget> sectionBlocks = <Widget>[];

    for (final AppToolbarOverflowSection section in sections) {
      final List<Widget> sectionChildren = <Widget>[];

      if (section.headerLabel != null) {
        sectionChildren.add(_sectionHeader(theme, section.headerLabel!));
      }

      for (final Widget action in section.actions) {
        if (!overflowSet.contains(action)) {
          continue;
        }
        if (!isToolbarOverflowActionVisible(action, ref)) {
          continue;
        }
        final AppToolbarOverflowEntry? entry = resolveToolbarOverflowEntry(
          action,
          ref,
        );
        if (entry == null) {
          continue;
        }
        sectionChildren.add(
          _overflowMenuItem(
            context: context,
            theme: theme,
            entry: entry,
            ref: ref,
          ),
        );
      }

      if (section.showsNotifications && visibleNotifications.isNotEmpty) {
        sectionChildren.add(
          _ToolbarNotificationsSubmenu(
            label: notificationsLabel,
            tooltip: notificationsTooltip,
            aggregateCount: totalWorkspaceSummaryNotificationCount(
              summaryNotifications,
            ),
            notifications: visibleNotifications,
            submenuStyle: submenuStyle,
            buttonStyle: _overflowMenuItemStyle(theme),
            itemStyle: ({required bool selected}) =>
                _overflowMenuItemStyle(theme, selected: selected),
          ),
        );
      }

      final bool hasHeaderOnly =
          sectionChildren.length == 1 && section.headerLabel != null;
      if (sectionChildren.isEmpty || hasHeaderOnly) {
        continue;
      }

      sectionBlocks.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sectionChildren,
        ),
      );
    }

    if (sectionBlocks.isEmpty) {
      return const <Widget>[];
    }

    final List<Widget> menuChildren = <Widget>[];
    for (var index = 0; index < sectionBlocks.length; index += 1) {
      if (index > 0) {
        menuChildren.add(const Divider(height: 1));
      }
      menuChildren.add(sectionBlocks[index]);
    }
    return menuChildren;
  }

  Widget _overflowMenuItem({
    required BuildContext context,
    required ThemeData theme,
    required AppToolbarOverflowEntry entry,
    required WidgetRef ref,
  }) {
    return MenuItemButton(
      onPressed: entry.enabled
          ? () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                entry.onSelected?.call(context, ref);
              });
            }
          : null,
      style: _overflowMenuItemStyle(theme),
      child: AppMenuItemLabel(icon: entry.icon, label: entry.label),
    );
  }

  Widget _sectionHeader(ThemeData theme, String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.sm,
        theme.spacing.xs,
        theme.spacing.sm,
        theme.spacing.xs,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  MenuStyle _toolbarMenuStyle(ThemeData theme, ColorScheme colorScheme) {
    return MenuStyle(
      minimumSize: WidgetStateProperty.all(const Size(240, 0)),
      maximumSize: WidgetStateProperty.all(const Size(320, double.infinity)),
      backgroundColor: WidgetStateProperty.all(colorScheme.surface),
      surfaceTintColor: WidgetStateProperty.all(colorScheme.surfaceTint),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          side: theme.borders.side(),
          borderRadius: BorderRadius.circular(theme.radius.sm),
        ),
      ),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: theme.spacing.xs),
      ),
    );
  }

  MenuStyle _toolbarSubmenuStyle(ThemeData theme, ColorScheme colorScheme) {
    return MenuStyle(
      minimumSize: WidgetStateProperty.all(const Size(240, 0)),
      maximumSize: WidgetStateProperty.all(const Size(320, double.infinity)),
      backgroundColor: WidgetStateProperty.all(colorScheme.surface),
      surfaceTintColor: WidgetStateProperty.all(colorScheme.surfaceTint),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          side: theme.borders.side(),
          borderRadius: BorderRadius.circular(theme.radius.sm),
        ),
      ),
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(vertical: theme.spacing.xs),
      ),
      alignment: AlignmentDirectional.centerEnd,
    );
  }

  ButtonStyle _overflowMenuItemStyle(ThemeData theme, {bool selected = false}) {
    final ColorScheme colorScheme = theme.colorScheme;

    return ButtonStyle(
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(horizontal: theme.spacing.sm),
      ),
      minimumSize: WidgetStateProperty.all(const Size(0, 48)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        if (selected) {
          return colorScheme.secondaryContainer;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colorScheme.surfaceContainerHighest;
        }
        return null;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide?>((
        Set<WidgetState> states,
      ) {
        if (!states.contains(WidgetState.focused)) {
          return null;
        }
        return theme.borders.side(color: colorScheme.primary.withValues(alpha: 0.72), width: 1.25,);
      }),
    );
  }
}

class _ToolbarNotificationsSubmenu extends StatelessWidget {
  const _ToolbarNotificationsSubmenu({
    required this.label,
    required this.aggregateCount,
    required this.notifications,
    required this.submenuStyle,
    required this.buttonStyle,
    required this.itemStyle,
    this.tooltip,
  });

  final String label;
  final String? tooltip;
  final int aggregateCount;
  final List<AppWorkspaceSummaryNotification> notifications;
  final MenuStyle submenuStyle;
  final ButtonStyle buttonStyle;
  final ButtonStyle Function({required bool selected}) itemStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return MenuAnchor(
      style: submenuStyle,
      alignmentOffset: const Offset(-1, 0),
      crossAxisUnconstrained: false,
      menuChildren: <Widget>[
        for (final AppWorkspaceSummaryNotification notification
            in notifications)
          MenuItemButton(
            style: itemStyle(selected: notification.isSelected),
            onPressed: notification.onSelected,
            child: AppMenuItemLabel(
              icon: notification.icon,
              label: notification.label,
              iconTone: notification.tone,
              trailing: AppMenuCountBadge(
                count: notification.count,
                tone: notification.tone,
              ),
            ),
          ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return Tooltip(
              message: tooltip ?? label,
              child: TextButton(
                style: buttonStyle,
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: AppMenuItemLabel(
                        icon: Icons.notifications_outlined,
                        label: label,
                        trailing: AppMenuCountBadge(
                          count: aggregateCount,
                          tone: AppWorkspaceStatusTone.info,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: theme.appTokens.listIconSize,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }
}

/// Standard localized labels for workspace toolbars.
AppWorkspaceToolbarConfig appWorkspaceToolbarWithLabels(
  AppLocalizations l10n, {
  Widget? primary,
  List<Widget> secondary = const <Widget>[],
  Future<void> Function()? onRefresh,
  bool isRefreshing = false,
  bool showGlobalActions = true,
  bool showFaultReport = true,
  bool showHousekeepingRequest = true,
  List<AppWorkspaceSummaryNotification> summaryNotifications =
      const <AppWorkspaceSummaryNotification>[],
  int maxVisibleScreenActions = 3,
  List<AppToolbarOverflowSection>? overflowSections,
  List<Widget>? toolbarLayoutActions,
}) {
  return AppWorkspaceToolbarConfig(
    primary: primary,
    secondary: secondary,
    onRefresh: onRefresh,
    isRefreshing: isRefreshing,
    showGlobalActions: showGlobalActions,
    showFaultReport: showFaultReport,
    showHousekeepingRequest: showHousekeepingRequest,
    refreshLabel: l10n.commonRefreshActionLabel,
    faultReportLabel: l10n.workspaceGlobalFaultReportAction,
    housekeepingRequestLabel: l10n.workspaceGlobalHousekeepingRequestAction,
    overflowLabel: l10n.workspaceToolbarOverflowLabel,
    notificationsMenuLabel: l10n.workspaceNotificationsMenuLabel,
    notificationsMenuTooltip: l10n.workspaceNotificationsToolbarTooltip,
    summaryNotifications: summaryNotifications,
    maxVisibleScreenActions: maxVisibleScreenActions,
    overflowSections: overflowSections,
    toolbarLayoutActions: toolbarLayoutActions,
  );
}
