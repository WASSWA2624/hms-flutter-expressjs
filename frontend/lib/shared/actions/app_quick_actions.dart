import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/app_action_dialogs.dart';
import 'package:hosspi_hms/shared/actions/app_action_item.dart';
import 'package:hosspi_hms/shared/actions/app_action_lifecycle.dart';
import 'package:hosspi_hms/shared/actions/app_permission_action_item.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_permission_action.dart';
import 'package:hosspi_hms/shared/components/app_permission_async_action.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Controls how a reusable quick-actions group is framed.
enum AppQuickActionsPresentation {
  /// Action buttons only — no title chrome. Use inside existing headers.
  buttonsOnly,

  /// A lightweight title and action list for embedding in existing content.
  plain,

  /// A compact bordered section for workspace-level shortcuts.
  section,

  /// A standard detail panel for record-specific actions.
  detailPanel,
}

/// The single shared surface for action-button groups across the app.
///
/// Features own labels, eligibility, permissions, and callbacks.
/// This component owns presentation and layout: buttons are sized to their
/// content, left-aligned, and wrap onto the next row when space runs out.
class AppQuickActions extends StatelessWidget {
  const AppQuickActions({
    this.title,
    this.actions = const <AppActionItem>[],
    this.permissionActions = const <AppPermissionActionItem>[],
    this.extraActions = const <Widget>[],
    this.description,
    this.emptyState,
    this.presentation = AppQuickActionsPresentation.section,
    this.leadingIcon = Icons.bolt_outlined,
    this.spacing,
    this.runSpacing,
    this.overflowLabel,
    this.hideWhenEmpty = true,
    super.key,
  });

  final String? title;
  final String? description;
  final List<AppActionItem> actions;
  final List<AppPermissionActionItem> permissionActions;
  final List<Widget> extraActions;
  final Widget? emptyState;
  final AppQuickActionsPresentation presentation;
  final IconData? leadingIcon;
  final double? spacing;
  final double? runSpacing;
  final String? overflowLabel;
  final bool hideWhenEmpty;

  bool get _isEmpty =>
      actions.isEmpty && permissionActions.isEmpty && extraActions.isEmpty;

  /// Buttons must hug their content so rows pack from the left; a stretched
  /// button would otherwise claim the entire wrap run.
  List<AppPermissionActionItem> get _contentSizedPermissionActions {
    return <AppPermissionActionItem>[
      for (final AppPermissionActionItem action in permissionActions)
        if (!action.fullWidth) action else _withoutFullWidth(action),
    ];
  }

  static AppPermissionActionItem _withoutFullWidth(
    AppPermissionActionItem action,
  ) {
    return AppPermissionActionItem(
      requirement: action.requirement,
      label: action.label,
      icon: action.icon,
      onPressed: action.onPressed,
      mutate: action.mutate,
      onSuccess: action.onSuccess,
      variant: action.variant,
      enabled: action.enabled,
      isLoading: action.isLoading,
      hideWhenDenied: action.hideWhenDenied,
      capabilityAllowed: action.capabilityAllowed,
      blockedReason: action.blockedReason,
      tooltip: action.tooltip,
      semanticLabel: action.semanticLabel,
      placement: action.placement,
      confirmTitle: action.confirmTitle,
      confirmBody: action.confirmBody,
      confirmSubmitLabel: action.confirmSubmitLabel,
      destructive: action.destructive,
      onlineOnly: action.onlineOnly,
      showFailureFeedback: action.showFailureFeedback,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(
      actions.isEmpty || permissionActions.isEmpty,
      'Use either actions or permissionActions in one quick-actions group.',
    );
    assert(
      presentation == AppQuickActionsPresentation.buttonsOnly ||
          (title != null && title!.trim().isNotEmpty),
      'title is required unless presentation is buttonsOnly.',
    );
    if (_isEmpty && emptyState == null && hideWhenEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final double gap = spacing ?? theme.spacing.sm;
    final double rowGap = runSpacing ?? gap;
    final Widget content = _isEmpty
        ? emptyState!
        : permissionActions.isNotEmpty
        ? _PermissionActionButtons(
            actions: _contentSizedPermissionActions,
            extraActions: extraActions,
            spacing: gap,
            runSpacing: rowGap,
            overflowLabel: overflowLabel,
          )
        : _ActionButtons(
            actions: actions,
            extraActions: extraActions,
            spacing: gap,
            runSpacing: rowGap,
          );

    return switch (presentation) {
      AppQuickActionsPresentation.buttonsOnly => content,
      AppQuickActionsPresentation.plain => _PlainQuickActions(
        title: title!,
        description: description,
        child: content,
      ),
      AppQuickActionsPresentation.section => AppSectionPanel(
        title: title!,
        description: description,
        leadingIcon: leadingIcon,
        density: AppContentPanelDensity.compact,
        children: <Widget>[content],
      ),
      AppQuickActionsPresentation.detailPanel => AppWorkspaceDetailPanel(
        title: title!,
        description: description,
        titleIcon: leadingIcon,
        child: content,
      ),
    };
  }
}

class _PlainQuickActions extends StatelessWidget {
  const _PlainQuickActions({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? detail = description?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleSmall),
        if (detail != null && detail.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Text(
            detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        SizedBox(height: theme.spacing.sm),
        child,
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.actions,
    required this.extraActions,
    required this.spacing,
    required this.runSpacing,
  });

  final List<AppActionItem> actions;
  final List<Widget> extraActions;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: <Widget>[
        for (final AppActionItem action in actions) _ActionButton(action),
        ...extraActions,
      ],
    );
  }
}

class _PermissionActionButtons extends StatelessWidget {
  const _PermissionActionButtons({
    required this.actions,
    required this.extraActions,
    required this.spacing,
    required this.runSpacing,
    this.overflowLabel,
  });

  final List<AppPermissionActionItem> actions;
  final List<Widget> extraActions;
  final double spacing;
  final double runSpacing;
  final String? overflowLabel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    // Async mutate actions stay inline so loading / retry feedback remain visible.
    final List<AppPermissionActionItem> inlineActions = actions
        .where((AppPermissionActionItem a) => !a.isOverflow || a.isAsync)
        .toList(growable: false);
    final List<AppPermissionActionItem> overflowActions = actions
        .where((AppPermissionActionItem a) => a.isOverflow && !a.isAsync)
        .toList(growable: false);

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: <Widget>[
        for (final AppPermissionActionItem action in inlineActions)
          _permissionButton(action),
        if (overflowActions.isNotEmpty)
          _PermissionActionOverflowMenu(
            actions: overflowActions,
            label: overflowLabel ?? l10n.workspaceToolbarOverflowLabel,
          ),
        ...extraActions,
      ],
    );
  }

  Widget _permissionButton(AppPermissionActionItem action) {
    final AppActionMutate? mutate = action.mutate;
    if (mutate != null) {
      return AppPermissionAsyncActionButton(
        requirement: action.requirement,
        label: action.label,
        icon: action.icon,
        mutate: mutate,
        onSuccess: action.onSuccess,
        variant: action.variant,
        enabled: action.enabled,
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
        onlineOnly: action.onlineOnly,
        showFailureFeedback: action.showFailureFeedback,
      );
    }

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
        (action.onPressed != null || action.mutate != null);

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
