import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/app_global_fault_report_action.dart';
import 'package:hosspi_hms/shared/actions/app_global_housekeeping_request_action.dart';
import 'package:hosspi_hms/shared/actions/app_workspace_refresh_action.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';

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

  bool get hasActions {
    return primary != null ||
        secondary.isNotEmpty ||
        onRefresh != null ||
        showGlobalActions;
  }
}

/// Left/right action clusters with responsive overflow for module workspaces.
class AppWorkspaceToolbar extends ConsumerWidget {
  const AppWorkspaceToolbar({required this.config, super.key});

  final AppWorkspaceToolbarConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final bool showLabels = breakpoint != AppBreakpoint.xs &&
        breakpoint != AppBreakpoint.sm;

    final List<Widget> leftActions = <Widget>[
      ...config.secondary,
      if (config.primary != null) config.primary!,
    ];
    final List<Widget> rightActions = _globalActions(context);

    return AppActionLabelScope(
      showLabels: showLabels,
      forceIconOnly: !showLabels,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (!constraints.hasBoundedWidth) {
            return Wrap(
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[...leftActions, ...rightActions],
            );
          }

          final bool useOverflow = constraints.maxWidth < AppBreakpoints.md &&
              leftActions.length > 1;

          if (useOverflow) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (leftActions.length == 1) leftActions.first,
                if (leftActions.length > 1)
                  _ToolbarOverflowMenu(
                    label: config.overflowLabel ?? 'More actions',
                    actions: leftActions,
                  ),
                if (leftActions.isNotEmpty && rightActions.isNotEmpty)
                  SizedBox(width: theme.spacing.sm),
                ...rightActions,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (leftActions.isNotEmpty)
                Flexible(
                  child: Wrap(
                    spacing: theme.spacing.xs,
                    runSpacing: theme.spacing.xs,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: leftActions,
                  ),
                ),
              if (leftActions.isNotEmpty && rightActions.isNotEmpty)
                SizedBox(width: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: rightActions,
              ),
            ],
          );
        },
      ),
    );
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
          label:
              config.housekeepingRequestLabel ?? 'Request maintenance',
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

class _ToolbarOverflowMenu extends StatelessWidget {
  const _ToolbarOverflowMenu({required this.label, required this.actions});

  final String label;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: AppIconButton(
        icon: Icons.more_vert,
        semanticLabel: label,
        tooltip: label,
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (BuildContext sheetContext) {
              final ThemeData theme = Theme.of(sheetContext);
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.md),
                  child: Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    alignment: WrapAlignment.end,
                    children: actions,
                  ),
                ),
              );
            },
          );
        },
      ),
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
  );
}
