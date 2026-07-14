import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/actions/app_action_item.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_info_tile.dart';
import 'package:hosspi_hms/shared/components/app_permission_action.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Renders a consistent responsive row/wrap of app actions.
class AppActionList extends StatelessWidget {
  const AppActionList({
    required this.actions,
    this.extraActions = const <Widget>[],
    this.spacing,
    this.runSpacing,
    this.minItemWidth,
    this.maxColumns = 4,
    super.key,
  });

  final List<AppActionItem> actions;
  final List<Widget> extraActions;
  final double? spacing;
  final double? runSpacing;
  final double? minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = spacing ?? theme.spacing.sm;
    final double rowGap = runSpacing ?? gap;
    final List<Widget> children = <Widget>[
      for (final AppActionItem action in actions) _ActionButton(action),
      ...extraActions,
    ];

    if (minItemWidth != null) {
      return AppResponsiveWrap(
        minItemWidth: minItemWidth!,
        maxColumns: maxColumns,
        spacing: gap,
        runSpacing: rowGap,
        children: children,
      );
    }

    return Wrap(spacing: gap, runSpacing: rowGap, children: children);
  }
}

/// Standard detail-panel container for module action bars.
class AppActionPanel extends StatelessWidget {
  const AppActionPanel({
    required this.title,
    required this.actions,
    this.description,
    this.extraActions = const <Widget>[],
    this.spacing,
    this.runSpacing,
    this.minItemWidth,
    this.maxColumns = 4,
    this.titleIcon,
    super.key,
  });

  final String title;
  final String? description;
  final List<AppActionItem> actions;
  final List<Widget> extraActions;
  final double? spacing;
  final double? runSpacing;
  final double? minItemWidth;
  final int maxColumns;
  final IconData? titleIcon;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      description: description,
      titleIcon: titleIcon,
      child: AppActionList(
        actions: actions,
        extraActions: extraActions,
        spacing: spacing,
        runSpacing: runSpacing,
        minItemWidth: minItemWidth,
        maxColumns: maxColumns,
      ),
    );
  }
}

/// Renders a consistent responsive row/wrap of permission-gated actions.
///
/// Actions with [AppActionPlacement.overflow] collapse into a contextual
/// "More actions" menu. Confirmation and destructive styling are honored.
class AppPermissionActionList extends StatelessWidget {
  const AppPermissionActionList({
    required this.actions,
    this.extraActions = const <Widget>[],
    this.spacing,
    this.runSpacing,
    this.minItemWidth,
    this.maxColumns = 3,
    this.overflowLabel,
    super.key,
  });

  final List<AppPermissionActionItem> actions;
  final List<Widget> extraActions;
  final double? spacing;
  final double? runSpacing;
  final double? minItemWidth;
  final int maxColumns;

  /// Localized label for the overflow menu trigger. Defaults to
  /// [AppLocalizations.workspaceToolbarOverflowLabel].
  final String? overflowLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<AppPermissionActionItem> inlineActions = actions
        .where((AppPermissionActionItem a) => !a.isOverflow)
        .toList(growable: false);
    final List<AppPermissionActionItem> overflowActions = actions
        .where((AppPermissionActionItem a) => a.isOverflow)
        .toList(growable: false);

    final List<Widget> children = <Widget>[
      for (final AppPermissionActionItem action in inlineActions)
        _permissionButton(action),
      if (overflowActions.isNotEmpty)
        _PermissionActionOverflowMenu(
          actions: overflowActions,
          label: overflowLabel ?? l10n.workspaceToolbarOverflowLabel,
        ),
      ...extraActions,
    ];

    if (minItemWidth != null) {
      return AppResponsiveWrap(
        minItemWidth: minItemWidth!,
        maxColumns: maxColumns,
        spacing: spacing ?? theme.spacing.sm,
        runSpacing: runSpacing ?? spacing ?? theme.spacing.sm,
        children: children
            .map(
              (Widget child) => SizedBox(width: double.infinity, child: child),
            )
            .toList(growable: false),
      );
    }

    return Wrap(
      spacing: spacing ?? theme.spacing.xs,
      runSpacing: runSpacing ?? theme.spacing.xs,
      children: children,
    );
  }

  Widget _permissionButton(AppPermissionActionItem action) {
    return AppPermissionActionButton(
      requirement: action.requirement,
      label: action.label,
      icon: action.icon,
      variant: action.variant,
      enabled: action.enabled,
      isLoading: action.isLoading,
      fullWidth: action.fullWidth,
      hideWhenDenied: action.hideWhenDenied,
      capabilityAllowed: action.capabilityAllowed,
      blockedReason: action.blockedReason,
      semanticLabel: action.semanticLabel,
      tooltip: action.tooltip,
      confirmTitle: action.confirmTitle,
      confirmBody: action.confirmBody,
      confirmSubmitLabel: action.confirmSubmitLabel,
      destructive: action.destructive,
      onPressed: action.onPressed,
    );
  }
}

/// Permission-aware detail-panel container for module action bars.
class AppPermissionActionPanel extends StatelessWidget {
  const AppPermissionActionPanel({
    required this.title,
    required this.actions,
    this.description,
    this.extraActions = const <Widget>[],
    this.spacing,
    this.runSpacing,
    this.minItemWidth,
    this.maxColumns = 3,
    this.titleIcon,
    this.overflowLabel,
    super.key,
  });

  final String title;
  final String? description;
  final List<AppPermissionActionItem> actions;
  final List<Widget> extraActions;
  final double? spacing;
  final double? runSpacing;
  final double? minItemWidth;
  final int maxColumns;
  final IconData? titleIcon;
  final String? overflowLabel;

  @override
  Widget build(BuildContext context) {
    return AppWorkspaceDetailPanel(
      title: title,
      description: description,
      titleIcon: titleIcon,
      child: AppPermissionActionList(
        actions: actions,
        extraActions: extraActions,
        spacing: spacing,
        runSpacing: runSpacing,
        minItemWidth: minItemWidth,
        maxColumns: maxColumns,
        overflowLabel: overflowLabel,
      ),
    );
  }
}

/// Standard titled action section for dialogs and detail content.
class AppActionSection extends StatelessWidget {
  const AppActionSection({
    required this.title,
    this.actions = const <AppActionItem>[],
    this.permissionActions = const <AppPermissionActionItem>[],
    this.extraActions = const <Widget>[],
    this.minItemWidth,
    this.maxColumns = 3,
    this.overflowLabel,
    super.key,
  });

  final String title;
  final List<AppActionItem> actions;
  final List<AppPermissionActionItem> permissionActions;
  final List<Widget> extraActions;
  final double? minItemWidth;
  final int maxColumns;
  final String? overflowLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget actionList = permissionActions.isEmpty
        ? AppActionList(
            actions: actions,
            extraActions: extraActions,
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
          )
        : AppPermissionActionList(
            actions: permissionActions,
            extraActions: extraActions,
            minItemWidth: minItemWidth,
            maxColumns: maxColumns,
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            overflowLabel: overflowLabel,
          );

    return AppSectionPanel(title: title, children: <Widget>[actionList]);
  }
}

class _PermissionActionOverflowMenu extends StatelessWidget {
  const _PermissionActionOverflowMenu({
    required this.actions,
    required this.label,
  });

  final List<AppPermissionActionItem> actions;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
            return AppButton.secondary(
              label: label,
              leadingIcon: Icons.more_horiz,
              semanticLabel: label,
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
            );
          },
      menuChildren: <Widget>[
        for (final AppPermissionActionItem action in actions)
          _PermissionOverflowMenuItem(action: action),
      ],
    );
  }
}

class _PermissionOverflowMenuItem extends StatelessWidget {
  const _PermissionOverflowMenuItem({required this.action});

  final AppPermissionActionItem action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool canPress =
        action.enabled &&
        action.capabilityAllowed &&
        !action.isLoading &&
        action.onPressed != null;

    return AppAccessActionGate(
      requirement: action.requirement,
      hideWhenDenied: action.hideWhenDenied,
      builder: (BuildContext context, bool isAllowed) {
        final bool enabled = canPress && isAllowed;
        final String tooltip = enabled
            ? (action.tooltip ?? action.label)
            : (action.blockedReason ?? action.tooltip ?? action.label);

        return Tooltip(
          message: tooltip,
          child: MenuItemButton(
            leadingIcon: Icon(
              action.icon,
              color: action.destructive && enabled ? colorScheme.error : null,
            ),
            onPressed: enabled
                ? () => _activateOverflowAction(context, action)
                : null,
            child: Text(
              action.label,
              style: action.destructive && enabled
                  ? TextStyle(color: colorScheme.error)
                  : null,
            ),
          ),
        );
      },
    );
  }

  void _activateOverflowAction(
    BuildContext context,
    AppPermissionActionItem action,
  ) {
    final VoidCallback? onPressed = action.onPressed;
    if (onPressed == null) {
      return;
    }
    if (!action.requiresConfirmation) {
      onPressed();
      return;
    }

    showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppConfirmActionDialog(
          title: action.confirmTitle!,
          body: action.confirmBody!,
          submitLabel: action.confirmSubmitLabel ?? action.label,
          destructive: action.destructive,
          icon: Icon(action.icon),
        );
      },
    ).then((bool? confirmed) {
      if (confirmed == true) {
        onPressed();
      }
    });
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.action);

  final AppActionItem action;

  @override
  Widget build(BuildContext context) {
    return switch (action.variant) {
      AppActionVariant.primary => AppButton.primary(
        label: action.label,
        leadingIcon: action.leadingIcon,
        enabled: action.enabled,
        isLoading: action.isLoading,
        tooltip: action.tooltip,
        semanticLabel: action.semanticLabel,
        onPressed: action.onPressed,
      ),
      AppActionVariant.secondary => AppButton.secondary(
        label: action.label,
        leadingIcon: action.leadingIcon,
        enabled: action.enabled,
        isLoading: action.isLoading,
        tooltip: action.tooltip,
        semanticLabel: action.semanticLabel,
        onPressed: action.onPressed,
      ),
      AppActionVariant.tertiary => AppButton.tertiary(
        label: action.label,
        leadingIcon: action.leadingIcon,
        enabled: action.enabled,
        isLoading: action.isLoading,
        tooltip: action.tooltip,
        semanticLabel: action.semanticLabel,
        onPressed: action.onPressed,
      ),
    };
  }
}
