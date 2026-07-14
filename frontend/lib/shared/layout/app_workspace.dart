import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_toolbar.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/layout/responsive_spacing.dart';

enum AppWorkspaceStatusTone { neutral, success, warning, error, info }

enum AppWorkspacePatientContextFieldStyle { tiles, inline }

@immutable
final class AppWorkspaceStatus {
  const AppWorkspaceStatus({
    required this.label,
    this.tone = AppWorkspaceStatusTone.neutral,
    this.icon,
  });

  final String label;
  final AppWorkspaceStatusTone tone;
  final IconData? icon;
}

@immutable
final class AppWorkspaceActivityItem {
  const AppWorkspaceActivityItem({
    required this.title,
    required this.subtitle,
    this.description,
    this.icon,
    this.tone = AppWorkspaceStatusTone.neutral,
  });

  final String title;
  final String subtitle;
  final String? description;
  final IconData? icon;
  final AppWorkspaceStatusTone tone;
}

@immutable
final class AppWorkspacePatientContextField {
  const AppWorkspacePatientContextField({
    required this.label,
    required this.value,
    this.icon,
    this.tone = AppWorkspaceStatusTone.neutral,
    this.copyable = false,
    this.copyTooltip,
    this.copiedMessage,
    this.copySemanticLabel,
    this.showCopyIcon = true,
    this.copyPlaceholderValues = const <String>{},
    /// When false, the field is omitted entirely (authorization / scope).
    this.authorized = true,
  });

  final String label;
  final String value;
  final IconData? icon;
  final AppWorkspaceStatusTone tone;
  final bool copyable;
  final String? copyTooltip;
  final String? copiedMessage;
  final String? copySemanticLabel;
  final bool showCopyIcon;
  final Set<String> copyPlaceholderValues;
  final bool authorized;

  /// Unauthorized fields never render, even when [value] is non-empty.
  bool get hasValue => authorized && value.trim().isNotEmpty;
}

class AppWorkspace extends StatelessWidget {
  const AppWorkspace({
    required this.title,
    required this.body,
    this.leading,
    this.leadingIcon,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    this.toolbar,
    this.filters,
    this.detail,
    this.activity,
    this.maxWidth = PageMaxWidth.dataHeavy,
    this.padding,
    this.scrollable = true,
    this.compactHeader = true,
    super.key,
  });

  final String title;
  final Widget? leading;
  final IconData? leadingIcon;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final AppWorkspaceToolbarConfig? toolbar;
  final Widget? filters;
  final Widget body;
  final Widget? detail;
  final Widget? activity;
  final PageMaxWidth maxWidth;
  final EdgeInsets? padding;
  final bool scrollable;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final double contentGap = compactHeader
        ? ResponsiveSpacing.compactContentGapFor(
            breakpoint,
            spacing: theme.spacing,
          )
        : ResponsiveSpacing.contentGapFor(breakpoint, spacing: theme.spacing);
    final EdgeInsets? resolvedPadding =
        padding ??
        (compactHeader
            ? _compactWorkspacePagePadding(breakpoint, theme)
            : null);
    final Widget? effectiveLeading =
        leading ??
        (leadingIcon == null
            ? null
            : AppWorkspaceTitleIcon(
                icon: leadingIcon!,
                semanticLabel: title,
                compact: compactHeader,
              ));
    final List<Widget> children = <Widget>[
      AppWorkspaceHeader(
        title: title,
        leading: effectiveLeading,
        primaryAction: primaryAction,
        secondaryActions: secondaryActions,
        toolbar: toolbar,
        compact: compactHeader,
      ),
    ];

    if (filters != null) {
      children
        ..add(SizedBox(height: contentGap))
        ..add(filters!);
    }

    children
      ..add(SizedBox(height: contentGap))
      ..add(
        detail == null
            ? body
            : AppWorkspaceSplitContent(primary: body, detail: detail!),
      );

    if (activity != null) {
      children
        ..add(SizedBox(height: contentGap))
        ..add(activity!);
    }

    return ResponsivePage(
      maxWidth: maxWidth,
      padding: resolvedPadding,
      scrollable: scrollable,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class AppWorkspaceHeader extends StatelessWidget {
  const AppWorkspaceHeader({
    required this.title,
    this.leading,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    this.toolbar,
    this.compact = true,
    super.key,
  });

  final String title;
  final Widget? leading;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final AppWorkspaceToolbarConfig? toolbar;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppWorkspaceToolbarConfig? effectiveToolbar =
        toolbar ??
        (primaryAction != null || secondaryActions.isNotEmpty
            ? AppWorkspaceToolbarConfig(
                primary: primaryAction,
                secondary: secondaryActions,
                showGlobalActions: false,
              )
            : null);
    final Widget? actionBar = effectiveToolbar == null
        ? null
        : Consumer(
            builder: (BuildContext context, WidgetRef ref, _) {
              return AppWorkspaceToolbar(config: effectiveToolbar);
            },
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: compact ? theme.spacing.none : theme.spacing.sm,
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(
              child: _WorkspaceHeaderTitle(title: title, compact: compact),
            ),
            if (actionBar != null) ...<Widget>[
              SizedBox(width: theme.spacing.sm),
              Flexible(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actionBar,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppWorkspaceStatusBadge extends StatelessWidget {
  const AppWorkspaceStatusBadge({required this.status, super.key});

  final AppWorkspaceStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = _toneForegroundColor(theme, status.tone);
    final IconData icon = status.icon ?? _defaultIcon(status.tone);

    return Semantics(
      label: status.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: theme.appTokens.listIconSize, color: color),
          SizedBox(width: theme.spacing.xs),
          Flexible(
            child: Text(
              status.label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppWorkspaceTitleIcon extends StatelessWidget {
  const AppWorkspaceTitleIcon({
    required this.icon,
    required this.semanticLabel,
    this.compact = true,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double dimension = compact ? 28 : 32;
    final double iconSize = compact
        ? theme.appTokens.listIconSize
        : theme.appTokens.listIconSize + 2;

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: dimension,
          child: Center(
            child: Icon(icon, color: colorScheme.primary, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceFilterBar extends StatelessWidget {
  const AppWorkspaceFilterBar({
    this.search,
    this.filters = const <Widget>[],
    this.actions = const <Widget>[],
    this.semanticLabel,
    this.expandSearch = false,
    super.key,
  });

  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;
  final String? semanticLabel;
  final bool expandSearch;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool hasSupplementalControls =
        filters.isNotEmpty || actions.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: Semantics(
        container: true,
        label: semanticLabel,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.xs),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (hasSupplementalControls) {
                  return _CleanFilterBar(
                    search: search,
                    filters: filters,
                    actions: actions,
                    title: semanticLabel,
                  );
                }

                if (constraints.maxWidth < 480) {
                  return _MobileFilterBar(
                    search: search,
                    filters: filters,
                    actions: actions,
                  );
                }

                return _WideFilterBar(
                  expandSearch: expandSearch,
                  search: search,
                  filters: filters,
                  actions: actions,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceSplitContent extends StatelessWidget {
  const AppWorkspaceSplitContent({
    required this.primary,
    required this.detail,
    this.detailWidth = 360,
    this.sideBySideBreakpoint = AppBreakpoints.lg,
    super.key,
  });

  final Widget primary;
  final Widget detail;
  final double detailWidth;
  final double sideBySideBreakpoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < sideBySideBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              primary,
              SizedBox(height: theme.spacing.lg),
              detail,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: primary),
            SizedBox(width: theme.spacing.lg),
            SizedBox(width: detailWidth, child: detail),
          ],
        );
      },
    );
  }
}

class AppWorkspaceDetailPanel extends StatelessWidget {
  const AppWorkspaceDetailPanel({
    this.title,
    required this.child,
    this.description,
    this.actions = const <Widget>[],
    this.titleIcon,
    super.key,
  });

  final String? title;
  final String? description;
  final List<Widget> actions;
  final Widget child;
  final IconData? titleIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null && title!.trim().isNotEmpty) ...<Widget>[
            Padding(
              padding: EdgeInsets.all(theme.spacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            if (titleIcon != null) ...<Widget>[
                              Icon(
                                titleIcon,
                                size: theme.appTokens.listIconSize,
                                color: colorScheme.primary,
                              ),
                              SizedBox(width: theme.spacing.sm),
                            ],
                            Expanded(
                              child: Text(
                                title!,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        if (description != null &&
                            description!.isNotEmpty) ...<Widget>[
                          SizedBox(height: theme.spacing.xs),
                          Text(
                            description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty) ...<Widget>[
                    SizedBox(width: theme.spacing.sm),
                    Wrap(spacing: theme.spacing.xs, children: actions),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Padding(padding: EdgeInsets.all(theme.spacing.lg), child: child),
        ],
      ),
    );
  }
}

class AppWorkspacePatientContextHeader extends StatelessWidget {
  const AppWorkspacePatientContextHeader({
    required this.patientName,
    required this.patientNumber,
    this.patientNumberLabel,
    this.demographics,
    this.status,
    this.alerts = const <AppWorkspaceStatus>[],
    this.fields = const <AppWorkspacePatientContextField>[],
    this.secondaryFields = const <AppWorkspacePatientContextField>[],
    this.fieldStyle = AppWorkspacePatientContextFieldStyle.tiles,
    this.actions = const <Widget>[],
    this.onCopyPatientNumber,
    this.copyPatientNumberTooltip,
    this.copyPatientNumberMessage,
    this.copyPatientNumberSemanticLabel,
    this.showPatientNumberCopyIcon = true,
    this.showPatientName = true,
    this.showAvatar = true,
    this.demographicsWidget,
    this.semanticLabel,
    this.showActionLabels = false,
    this.mergeFieldsIntoMetaLine = false,
    super.key,
  });

  final String patientName;
  final String patientNumber;
  final String? patientNumberLabel;
  final String? demographics;
  final AppWorkspaceStatus? status;
  final List<AppWorkspaceStatus> alerts;
  final List<AppWorkspacePatientContextField> fields;
  final List<AppWorkspacePatientContextField> secondaryFields;
  final AppWorkspacePatientContextFieldStyle fieldStyle;
  final List<Widget> actions;
  final VoidCallback? onCopyPatientNumber;
  final String? copyPatientNumberTooltip;
  final String? copyPatientNumberMessage;
  final String? copyPatientNumberSemanticLabel;
  final bool showPatientNumberCopyIcon;
  final bool showPatientName;
  final bool showAvatar;
  final Widget? demographicsWidget;
  final String? semanticLabel;
  final bool showActionLabels;
  final bool mergeFieldsIntoMetaLine;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<AppWorkspacePatientContextField> visibleFields = fields
        .where((AppWorkspacePatientContextField field) => field.hasValue)
        .toList(growable: false);
    final List<AppWorkspacePatientContextField> visibleSecondaryFields =
        secondaryFields
            .where((AppWorkspacePatientContextField field) => field.hasValue)
            .toList(growable: false);
    final List<AppWorkspacePatientContextField> metaInlineFields =
        mergeFieldsIntoMetaLine
        ? visibleFields
        : const <AppWorkspacePatientContextField>[];
    final List<AppWorkspacePatientContextField> separateFields =
        mergeFieldsIntoMetaLine
        ? const <AppWorkspacePatientContextField>[]
        : visibleFields;
    final bool hasIdentityContent =
        showPatientName ||
        showAvatar ||
        patientNumber.trim().isNotEmpty ||
        (demographics?.trim().isNotEmpty ?? false) ||
        demographicsWidget != null ||
        status != null ||
        alerts.isNotEmpty;
    Widget header = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < AppBreakpoints.md;
            final Widget identity = _PatientContextIdentity(
              patientName: patientName,
              showPatientName: showPatientName,
              showAvatar: showAvatar,
              patientNumber: patientNumber,
              patientNumberLabel: patientNumberLabel,
              demographics: demographics,
              demographicsWidget: demographicsWidget,
              status: status,
              alerts: alerts,
              onCopyPatientNumber: onCopyPatientNumber,
              copyPatientNumberTooltip: copyPatientNumberTooltip,
              copyPatientNumberMessage: copyPatientNumberMessage,
              copyPatientNumberSemanticLabel: copyPatientNumberSemanticLabel,
              showPatientNumberCopyIcon: showPatientNumberCopyIcon,
              metaInlineFields: metaInlineFields,
            );
            final Widget? actionBar = actions.isEmpty
                ? null
                : _WorkspaceHeaderActions(
                    actions: actions,
                    showLabels: showActionLabels,
                  );
            final List<Widget> children = <Widget>[];

            if (hasIdentityContent) {
              children.add(
                compact || actionBar == null
                    ? identity
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(child: identity),
                          SizedBox(width: theme.spacing.md),
                          Flexible(child: actionBar),
                        ],
                      ),
              );

              if (compact && actionBar != null) {
                children
                  ..add(SizedBox(height: theme.spacing.md))
                  ..add(actionBar);
              }
            } else if (actionBar != null) {
              children.add(actionBar);
            }

            if (separateFields.isNotEmpty) {
              if (children.isNotEmpty) {
                children.add(SizedBox(height: theme.spacing.md));
              }
              children.add(
                fieldStyle == AppWorkspacePatientContextFieldStyle.inline
                    ? _PatientContextInlineFacts(fields: separateFields)
                    : _PatientContextFieldGrid(fields: separateFields),
              );
            }

            if (visibleSecondaryFields.isNotEmpty) {
              children.add(SizedBox(height: theme.spacing.sm));
              children.add(
                fieldStyle == AppWorkspacePatientContextFieldStyle.inline
                    ? _PatientContextInlineFacts(fields: visibleSecondaryFields)
                    : _PatientContextFieldGrid(fields: visibleSecondaryFields),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            );
          },
        ),
      ),
    );

    if (semanticLabel != null) {
      header = Semantics(container: true, label: semanticLabel, child: header);
    }

    return header;
  }
}

class AppWorkspaceStatePanel extends StatelessWidget {
  const AppWorkspaceStatePanel({
    required this.child,
    this.minHeight = 280,
    super.key,
  }) : _stateVariant = null,
       _stateTitle = null,
       _stateBody = null,
       _stateIcon = null,
       _stateDetail = null,
       _stateAction = null,
       _stateSemanticLabel = null,
       _stateCrossAxisAlignment = CrossAxisAlignment.center,
       _stateTextAlign = TextAlign.center;

  const AppWorkspaceStatePanel.state({
    required AppStateViewVariant variant,
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextAlign textAlign = TextAlign.center,
    this.minHeight = 280,
    super.key,
  }) : child = null,
       _stateVariant = variant,
       _stateTitle = title,
       _stateBody = body,
       _stateIcon = icon,
       _stateDetail = detail,
       _stateAction = action,
       _stateSemanticLabel = semanticLabel,
       _stateCrossAxisAlignment = crossAxisAlignment,
       _stateTextAlign = textAlign;

  const AppWorkspaceStatePanel.loading({
    required String title,
    required String body,
    String? detail,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.loading,
         title: title,
         body: body,
         detail: detail,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.empty({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.empty,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.error({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.error,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.forbidden({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.forbidden,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.offline({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.offline,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.validation({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.validation,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  const AppWorkspaceStatePanel.success({
    required String title,
    required String body,
    IconData? icon,
    String? detail,
    Widget? action,
    String? semanticLabel,
    double minHeight = 280,
    Key? key,
  }) : this.state(
         variant: AppStateViewVariant.success,
         title: title,
         body: body,
         icon: icon,
         detail: detail,
         action: action,
         semanticLabel: semanticLabel,
         minHeight: minHeight,
         key: key,
       );

  final Widget? child;
  final double minHeight;
  final AppStateViewVariant? _stateVariant;
  final String? _stateTitle;
  final String? _stateBody;
  final IconData? _stateIcon;
  final String? _stateDetail;
  final Widget? _stateAction;
  final String? _stateSemanticLabel;
  final CrossAxisAlignment _stateCrossAxisAlignment;
  final TextAlign _stateTextAlign;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Widget content =
        child ??
        AppStateView(
          variant: _stateVariant!,
          icon: _stateIcon,
          title: _stateTitle!,
          body: _stateBody!,
          detail: _stateDetail,
          action: _stateAction,
          semanticLabel: _stateSemanticLabel,
          crossAxisAlignment: _stateCrossAxisAlignment,
          textAlign: _stateTextAlign,
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: content,
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceDetailDrawer extends StatelessWidget {
  const AppWorkspaceDetailDrawer({
    required this.title,
    required this.child,
    this.description,
    this.actions = const <Widget>[],
    this.icon,
    this.semanticLabel,
    this.scrollable = true,
    this.showCloseButton = true,
    this.closeEnabled = true,
    this.maxWidth = _defaultDrawerWidth,
    super.key,
  });

  final Widget title;
  final Widget child;
  final Widget? description;
  final List<Widget> actions;
  final Widget? icon;
  final String? semanticLabel;
  final bool scrollable;
  final bool showCloseButton;
  final bool closeEnabled;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Size viewport = MediaQuery.sizeOf(context);
    final double width = viewport.width < AppBreakpoints.md
        ? viewport.width
        : maxWidth.clamp(theme.spacing.none, viewport.width).toDouble();
    final Widget content = scrollable
        ? SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: child,
          )
        : child;
    Widget drawer = Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Material(
          color: colorScheme.surface,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _WorkspaceDrawerHeader(
                    title: title,
                    description: description,
                    icon: icon,
                    showCloseButton: showCloseButton,
                    closeEnabled: closeEnabled,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(theme.spacing.lg),
                      child: content,
                    ),
                  ),
                  if (actions.isNotEmpty)
                    _WorkspaceDrawerActions(actions: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (semanticLabel != null) {
      drawer = Semantics(
        namesRoute: true,
        scopesRoute: true,
        explicitChildNodes: true,
        label: semanticLabel,
        child: drawer,
      );
    }

    return FocusTraversalGroup(child: drawer);
  }
}

class AppWorkspaceActivityList extends StatelessWidget {
  const AppWorkspaceActivityList({
    required this.items,
    this.title,
    this.description,
    this.emptyTitle,
    this.emptyBody,
    this.emptyAction,
    super.key,
  });

  final List<AppWorkspaceActivityItem> items;
  final String? title;
  final String? description;
  final String? emptyTitle;
  final String? emptyBody;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null || description != null)
            Padding(
              padding: EdgeInsets.all(theme.spacing.lg),
              child: _ActivityHeader(title: title, description: description),
            ),
          if (title != null || description != null) const Divider(height: 1),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.all(theme.spacing.lg),
              child: AppStateView(
                variant: AppStateViewVariant.empty,
                title: emptyTitle ?? '',
                body: emptyBody ?? '',
                action: emptyAction,
                crossAxisAlignment: CrossAxisAlignment.center,
                textAlign: TextAlign.center,
              ),
            )
          else
            for (var index = 0; index < items.length; index += 1) ...<Widget>[
              _ActivityRow(item: items[index]),
              if (index < items.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    );
  }
}

class _PatientContextIdentity extends StatelessWidget {
  const _PatientContextIdentity({
    required this.patientName,
    required this.showPatientName,
    required this.showAvatar,
    required this.patientNumber,
    required this.patientNumberLabel,
    required this.demographics,
    required this.demographicsWidget,
    required this.status,
    required this.alerts,
    required this.onCopyPatientNumber,
    required this.copyPatientNumberTooltip,
    required this.copyPatientNumberMessage,
    required this.copyPatientNumberSemanticLabel,
    required this.showPatientNumberCopyIcon,
    this.metaInlineFields = const <AppWorkspacePatientContextField>[],
  });

  final String patientName;
  final bool showPatientName;
  final bool showAvatar;
  final String patientNumber;
  final String? patientNumberLabel;
  final String? demographics;
  final Widget? demographicsWidget;
  final AppWorkspaceStatus? status;
  final List<AppWorkspaceStatus> alerts;
  final VoidCallback? onCopyPatientNumber;
  final String? copyPatientNumberTooltip;
  final String? copyPatientNumberMessage;
  final String? copyPatientNumberSemanticLabel;
  final bool showPatientNumberCopyIcon;
  final List<AppWorkspacePatientContextField> metaInlineFields;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showAvatar) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              border: Border.all(color: colorScheme.primary),
            ),
            child: SizedBox.square(
              dimension: 44,
              child: Icon(
                Icons.person_outline,
                color: colorScheme.onPrimaryContainer,
                size: theme.appTokens.listIconSize,
              ),
            ),
          ),
          SizedBox(width: theme.spacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showPatientName) ...<Widget>[
                Text(
                  patientName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: theme.spacing.xs),
              ],
              _PatientContextMetaLine(
                patientNumber: patientNumber,
                patientNumberLabel: patientNumberLabel,
                demographics: demographics,
                demographicsWidget: demographicsWidget,
                status: status,
                onCopyPatientNumber: onCopyPatientNumber,
                copyPatientNumberTooltip: copyPatientNumberTooltip,
                copyPatientNumberMessage: copyPatientNumberMessage,
                copyPatientNumberSemanticLabel: copyPatientNumberSemanticLabel,
                showPatientNumberCopyIcon: showPatientNumberCopyIcon,
                inlineFields: metaInlineFields,
              ),
              if (alerts.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                _PatientContextAlerts(alerts: alerts),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientContextMetaLine extends StatelessWidget {
  const _PatientContextMetaLine({
    required this.patientNumber,
    required this.patientNumberLabel,
    required this.demographics,
    required this.demographicsWidget,
    required this.status,
    required this.onCopyPatientNumber,
    required this.copyPatientNumberTooltip,
    required this.copyPatientNumberMessage,
    required this.copyPatientNumberSemanticLabel,
    required this.showPatientNumberCopyIcon,
    this.inlineFields = const <AppWorkspacePatientContextField>[],
  });

  final String patientNumber;
  final String? patientNumberLabel;
  final String? demographics;
  final Widget? demographicsWidget;
  final AppWorkspaceStatus? status;
  final VoidCallback? onCopyPatientNumber;
  final String? copyPatientNumberTooltip;
  final String? copyPatientNumberMessage;
  final String? copyPatientNumberSemanticLabel;
  final bool showPatientNumberCopyIcon;
  final List<AppWorkspacePatientContextField> inlineFields;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<Widget> items = <Widget>[
      if (patientNumber.trim().isNotEmpty)
        _PatientContextNumberToken(
          label: patientNumberLabel,
          value: patientNumber,
          onCopy: onCopyPatientNumber,
          copyTooltip: copyPatientNumberTooltip,
          copiedMessage: copyPatientNumberMessage,
          semanticLabel: copyPatientNumberSemanticLabel,
          showCopyIcon: showPatientNumberCopyIcon,
        ),
      if (demographicsWidget != null)
        demographicsWidget!
      else if (demographics != null && demographics!.trim().isNotEmpty)
        Text(
          demographics!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      if (status != null) AppWorkspaceStatusBadge(status: status!),
      for (final AppWorkspacePatientContextField field in inlineFields)
        _PatientContextInlineFact(field: field),
    ];

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}

class _PatientContextNumberToken extends StatelessWidget {
  const _PatientContextNumberToken({
    required this.value,
    this.label,
    this.onCopy,
    this.copyTooltip,
    this.copiedMessage,
    this.semanticLabel,
    this.showCopyIcon = true,
  });

  final String? label;
  final String value;
  final VoidCallback? onCopy;
  final String? copyTooltip;
  final String? copiedMessage;
  final String? semanticLabel;
  final bool showCopyIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final TextStyle? valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w800,
    );
    final String? resolvedLabel = label?.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (resolvedLabel != null && resolvedLabel.isNotEmpty) ...<Widget>[
            Flexible(
              child: Text(
                '$resolvedLabel:',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            SizedBox(width: theme.spacing.xs),
          ],
          Flexible(
            child: AppCopyableIdentifier(
              value: value,
              tooltip: copyTooltip ?? context.l10n.opdCopyPatientIdAction,
              copiedMessage:
                  copiedMessage ?? context.l10n.clinicalPatientIdCopiedMessage,
              semanticLabel: semanticLabel,
              showCopyIcon: showCopyIcon,
              textStyle: valueStyle,
              onCopied: onCopy,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientContextAlerts extends StatelessWidget {
  const _PatientContextAlerts({required this.alerts});

  final List<AppWorkspaceStatus> alerts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final AppWorkspaceStatus alert in alerts)
          AppWorkspaceStatusBadge(status: alert),
      ],
    );
  }
}

class _PatientContextInlineFacts extends StatelessWidget {
  const _PatientContextInlineFacts({required this.fields});

  final List<AppWorkspacePatientContextField> fields;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.lg,
      runSpacing: theme.spacing.sm,
      children: <Widget>[
        for (final AppWorkspacePatientContextField field in fields)
          _PatientContextInlineFact(field: field),
      ],
    );
  }
}

class _PatientContextInlineFact extends StatelessWidget {
  const _PatientContextInlineFact({required this.field});

  final AppWorkspacePatientContextField field;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final _WorkspaceToneColors colors = _toneColors(theme, field.tone);
    final Color accentColor = field.tone == AppWorkspaceStatusTone.neutral
        ? colorScheme.primary
        : colors.on;
    final TextStyle? labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final TextStyle? valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );

    return Semantics(
      label: '${field.label}: ${field.value}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (field.icon != null) ...<Widget>[
            Icon(
              field.icon,
              size: theme.appTokens.listIconSize,
              color: accentColor,
            ),
            SizedBox(width: theme.spacing.xs),
          ],
          Text('${field.label}: ', style: labelStyle),
          Flexible(
            child: field.copyable
                ? AppCopyableIdentifier(
                    value: field.value,
                    tooltip: field.copyTooltip,
                    copiedMessage: field.copiedMessage,
                    semanticLabel: field.copySemanticLabel,
                    showCopyIcon: field.showCopyIcon,
                    placeholderValues: field.copyPlaceholderValues,
                    textStyle: valueStyle,
                  )
                : Text(
                    field.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientContextFieldGrid extends StatelessWidget {
  const _PatientContextFieldGrid({required this.fields});

  final List<AppWorkspacePatientContextField> fields;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = constraints.maxWidth < AppBreakpoints.md
            ? theme.spacing.sm
            : theme.spacing.md;
        final int columns = _patientContextColumnCount(
          constraints.maxWidth,
          fields.length,
        );
        final double itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final AppWorkspacePatientContextField field in fields)
              SizedBox(
                width: itemWidth,
                child: _PatientContextFieldTile(field: field),
              ),
          ],
        );
      },
    );
  }
}

class _PatientContextFieldTile extends StatelessWidget {
  const _PatientContextFieldTile({required this.field});

  final AppWorkspacePatientContextField field;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool neutralTone = field.tone == AppWorkspaceStatusTone.neutral;
    final _WorkspaceToneColors colors = _toneColors(theme, field.tone);
    final Color borderColor = neutralTone
        ? colorScheme.outlineVariant
        : colors.border;
    final Color labelColor = neutralTone
        ? colorScheme.onSurfaceVariant
        : colors.on;
    final Color iconColor = neutralTone ? colorScheme.primary : colors.on;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: neutralTone
            ? colorScheme.surfaceContainerLowest
            : colors.container,
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (field.icon != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.xs),
                child: Icon(
                  field.icon,
                  color: iconColor,
                  size: theme.appTokens.listIconSize,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    field.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  field.copyable
                      ? AppCopyableIdentifier(
                          value: field.value,
                          tooltip: field.copyTooltip,
                          copiedMessage: field.copiedMessage,
                          semanticLabel: field.copySemanticLabel,
                          showCopyIcon: field.showCopyIcon,
                          maxLines: 2,
                          placeholderValues: field.copyPlaceholderValues,
                          textStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: neutralTone
                                ? colorScheme.onSurface
                                : colors.on,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(
                          field.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: neutralTone
                                ? colorScheme.onSurface
                                : colors.on,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDrawerHeader extends StatelessWidget {
  const _WorkspaceDrawerHeader({
    required this.title,
    required this.description,
    required this.icon,
    required this.showCloseButton,
    required this.closeEnabled,
  });

  final Widget title;
  final Widget? description;
  final Widget? icon;
  final bool showCloseButton;
  final bool closeEnabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: theme.spacing.lg,
          top: theme.spacing.md,
          bottom: theme.spacing.md,
          end: theme.spacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.xs),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: colorScheme.primary,
                    size: theme.appTokens.listIconSize,
                  ),
                  child: icon!,
                ),
              ),
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DefaultTextStyle(
                    style:
                        theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ) ??
                        TextStyle(color: colorScheme.onSurface, fontSize: 22),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  if (description != null) ...<Widget>[
                    SizedBox(height: theme.spacing.xs),
                    DefaultTextStyle(
                      style:
                          theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ) ??
                          TextStyle(color: colorScheme.onSurfaceVariant),
                      child: description!,
                    ),
                  ],
                ],
              ),
            ),
            if (showCloseButton)
              AppButton(
                iconOnly: true,
                leadingIcon: Icons.close,
                label: MaterialLocalizations.of(context).closeButtonTooltip,
                semanticLabel: MaterialLocalizations.of(
                  context,
                ).closeButtonTooltip,
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                enabled: closeEnabled,
                onPressed: closeEnabled
                    ? () {
                        Navigator.of(context).maybePop();
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDrawerActions extends StatelessWidget {
  const _WorkspaceDrawerActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.lg),
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: theme.spacing.sm,
          overflowSpacing: theme.spacing.sm,
          children: actions,
        ),
      ),
    );
  }
}

class _WorkspaceHeaderTitle extends StatelessWidget {
  const _WorkspaceHeaderTitle({required this.title, this.compact = true});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    if (breakpoint.hidesWorkspaceTitle) {
      return Semantics(
        header: true,
        label: title,
        excludeSemantics: true,
        child: const SizedBox.shrink(),
      );
    }

    final TextTheme textTheme = theme.textTheme;
    final TextStyle? titleStyle = compact
        ? switch (breakpoint) {
            AppBreakpoint.xs || AppBreakpoint.sm => textTheme.titleMedium,
            _ => textTheme.titleLarge,
          }
        : switch (breakpoint) {
            AppBreakpoint.xs ||
            AppBreakpoint.sm ||
            AppBreakpoint.md => textTheme.titleLarge,
            _ => textTheme.headlineSmall,
          };

    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _WorkspaceHeaderActions extends StatelessWidget {
  const _WorkspaceHeaderActions({
    required this.actions,
    this.showLabels = false,
  });

  final List<Widget> actions;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      alignment: WrapAlignment.end,
      children: <Widget>[
        for (final Widget action in actions)
          AppActionLabelScope(
            showLabels: showLabels,
            forceIconOnly: !showLabels,
            child: action,
          ),
      ],
    );
  }
}

class _CleanFilterBar extends StatelessWidget {
  const _CleanFilterBar({
    required this.search,
    required this.filters,
    required this.actions,
    required this.title,
  });

  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String dialogTitle = title == null || title!.trim().isEmpty
        ? 'Filters'
        : title!;
    final Widget filterButton = AppButton(
      iconOnly: true,
      leadingIcon: Icons.tune,
      label: dialogTitle,

      semanticLabel: dialogTitle,
      tooltip: dialogTitle,
      onPressed: () {
        showAppDialog<void>(
          context: context,
          builder: (_) => _WorkspaceFilterDialog(
            title: dialogTitle,
            filters: filters,
            actions: actions,
          ),
        );
      },
    );

    if (search == null) {
      return Align(alignment: Alignment.centerRight, child: filterButton);
    }

    return Row(
      children: <Widget>[
        Expanded(child: search!),
        SizedBox(width: theme.spacing.xs),
        filterButton,
      ],
    );
  }
}

class _WorkspaceFilterDialog extends StatelessWidget {
  const _WorkspaceFilterDialog({
    required this.title,
    required this.filters,
    required this.actions,
  });

  final String title;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(title),
      icon: const Icon(Icons.tune),
      scrollable: true,
      maxWidth: 640,
      content: filters.isEmpty
          ? const SizedBox.shrink()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  var index = 0;
                  index < filters.length;
                  index += 1
                ) ...<Widget>[
                  if (index > 0) SizedBox(height: theme.spacing.md),
                  filters[index],
                ],
              ],
            ),
      actions: actions,
    );
  }
}

class _MobileFilterBar extends StatelessWidget {
  const _MobileFilterBar({
    required this.search,
    required this.filters,
    required this.actions,
  });

  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget? searchWidget = search;
    final List<Widget> children = <Widget>[
      ?searchWidget,
      ...filters,
      if (actions.isNotEmpty) _WorkspaceHeaderActions(actions: actions),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < children.length; index += 1) ...<Widget>[
          if (index > 0) SizedBox(height: theme.spacing.sm),
          children[index],
        ],
      ],
    );
  }
}

class _WideFilterBar extends StatelessWidget {
  const _WideFilterBar({
    required this.expandSearch,
    required this.search,
    required this.filters,
    required this.actions,
  });

  final bool expandSearch;
  final Widget? search;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget? searchWidget = search;

    if (expandSearch) {
      return Row(
        children: <Widget>[
          if (searchWidget != null) Expanded(child: searchWidget),
          for (final Widget filter in filters) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            SizedBox(width: _filterWidth, child: filter),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            _WorkspaceHeaderActions(actions: actions),
          ],
        ],
      );
    }

    final List<Widget> children = <Widget>[
      if (searchWidget != null)
        SizedBox(width: _searchWidth, child: searchWidget),
      for (final Widget filter in filters)
        SizedBox(width: _filterWidth, child: filter),
      ...actions,
    ];

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.title, required this.description});

  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null && title!.isNotEmpty)
          Text(title!, style: theme.textTheme.titleMedium),
        if (description != null && description!.isNotEmpty) ...<Widget>[
          if (title != null && title!.isNotEmpty)
            SizedBox(height: theme.spacing.xs),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final AppWorkspaceActivityItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final _WorkspaceToneColors colors = _toneColors(theme, item.tone);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            item.icon ?? _defaultIcon(item.tone),
            color: colors.on,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.title, style: theme.textTheme.titleSmall),
                SizedBox(height: theme.spacing.xs),
                Text(
                  item.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.description != null &&
                    item.description!.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  Text(item.description!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
final class _WorkspaceToneColors {
  const _WorkspaceToneColors({
    required this.container,
    required this.on,
    required this.border,
  });

  final Color container;
  final Color on;
  final Color border;
}

int _patientContextColumnCount(double width, int childCount) {
  if (childCount <= 0) {
    return 1;
  }

  final int breakpointColumns = switch (width) {
    >= 980 => 4,
    >= 720 => 3,
    >= 460 => 2,
    _ => 1,
  };

  return math.min(childCount, breakpointColumns).clamp(1, childCount).toInt();
}

IconData _defaultIcon(AppWorkspaceStatusTone tone) {
  return switch (tone) {
    AppWorkspaceStatusTone.neutral => Icons.radio_button_unchecked,
    AppWorkspaceStatusTone.success => Icons.check_circle_outline,
    AppWorkspaceStatusTone.warning => Icons.warning_amber_outlined,
    AppWorkspaceStatusTone.error => Icons.error_outline,
    AppWorkspaceStatusTone.info => Icons.info_outline,
  };
}

Color _toneForegroundColor(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  final AppStatusColors statusColors = theme.statusColors;

  return switch (tone) {
    AppWorkspaceStatusTone.neutral => colorScheme.onSurfaceVariant,
    AppWorkspaceStatusTone.success => statusColors.success,
    AppWorkspaceStatusTone.warning => statusColors.warning,
    AppWorkspaceStatusTone.error => statusColors.error,
    AppWorkspaceStatusTone.info => statusColors.info,
  };
}

_WorkspaceToneColors _toneColors(ThemeData theme, AppWorkspaceStatusTone tone) {
  final ColorScheme colorScheme = theme.colorScheme;
  final AppStatusColors statusColors = theme.statusColors;

  return switch (tone) {
    AppWorkspaceStatusTone.neutral => _WorkspaceToneColors(
      container: colorScheme.surfaceContainerHighest,
      on: colorScheme.onSurfaceVariant,
      border: colorScheme.outlineVariant,
    ),
    AppWorkspaceStatusTone.success => _WorkspaceToneColors(
      container: statusColors.successContainer,
      on: statusColors.onSuccessContainer,
      border: statusColors.success,
    ),
    AppWorkspaceStatusTone.warning => _WorkspaceToneColors(
      container: statusColors.warningContainer,
      on: statusColors.onWarningContainer,
      border: statusColors.warning,
    ),
    AppWorkspaceStatusTone.error => _WorkspaceToneColors(
      container: statusColors.errorContainer,
      on: statusColors.onErrorContainer,
      border: statusColors.error,
    ),
    AppWorkspaceStatusTone.info => _WorkspaceToneColors(
      container: statusColors.infoContainer,
      on: statusColors.onInfoContainer,
      border: statusColors.info,
    ),
  };
}

Future<T?> showAppWorkspaceActionDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  List<Widget> actions = const <Widget>[],
  Widget? icon,
  String? semanticLabel,
  bool barrierDismissible = false,
  bool scrollable = true,
  bool showCloseButton = true,
  bool closeEnabled = true,
  double maxWidth = 600,
  RouteSettings? routeSettings,
}) {
  return showAppDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    routeSettings: routeSettings,
    builder: (_) => AppDialog(
      title: title,
      content: content,
      actions: actions,
      icon: icon,
      semanticLabel: semanticLabel,
      scrollable: scrollable,
      showCloseButton: showCloseButton,
      closeEnabled: closeEnabled,
      maxWidth: maxWidth,
    ),
  );
}

Future<T?> showAppWorkspaceDetailDrawer<T>({
  required BuildContext context,
  required Widget title,
  required Widget child,
  Widget? description,
  List<Widget> actions = const <Widget>[],
  Widget? icon,
  String? semanticLabel,
  String? barrierLabel,
  bool barrierDismissible = true,
  bool scrollable = true,
  bool showCloseButton = true,
  bool closeEnabled = true,
  double maxWidth = _defaultDrawerWidth,
  RouteSettings? routeSettings,
}) async {
  final FocusNode? previousFocus = FocusManager.instance.primaryFocus;
  final String resolvedBarrierLabel =
      barrierLabel ??
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final T? result = await showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: resolvedBarrierLabel,
    routeSettings: routeSettings,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return AppWorkspaceDetailDrawer(
            title: title,
            description: description,
            actions: actions,
            icon: icon,
            semanticLabel: semanticLabel,
            scrollable: scrollable,
            showCloseButton: showCloseButton,
            closeEnabled: closeEnabled,
            maxWidth: maxWidth,
            child: child,
          );
        },
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final TextDirection textDirection = Directionality.of(context);
          final double beginOffset = textDirection == TextDirection.rtl
              ? -1
              : 1;
          final Animation<Offset> position = animation.drive(
            Tween<Offset>(
              begin: Offset(beginOffset, 0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)),
          );

          return SlideTransition(position: position, child: child);
        },
  );

  if (previousFocus case final FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? previousContext = node.context;
      if (previousContext != null &&
          previousContext.mounted &&
          node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  return result;
}

const double _searchWidth = 280;
const double _filterWidth = 220;
const double _defaultDrawerWidth = 480;

EdgeInsets _compactWorkspacePagePadding(
  AppBreakpoint breakpoint,
  ThemeData theme,
) {
  final double horizontal = ResponsiveSpacing.pagePaddingValueFor(
    breakpoint,
    designTokens: theme.appTokens,
  );
  final double top = switch (breakpoint) {
    AppBreakpoint.xs || AppBreakpoint.sm => theme.spacing.xs,
    _ => theme.spacing.sm,
  };
  final double bottom = switch (breakpoint) {
    AppBreakpoint.xs || AppBreakpoint.sm => theme.spacing.sm,
    AppBreakpoint.md || AppBreakpoint.lg => theme.spacing.md,
    _ => theme.spacing.md,
  };

  return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
}
