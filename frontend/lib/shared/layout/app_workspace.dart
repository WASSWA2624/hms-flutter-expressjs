import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/layout/responsive_page.dart';
import 'package:hosspi_hms/shared/layout/responsive_spacing.dart';

enum AppWorkspaceStatusTone { neutral, success, warning, error, info }

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

class AppWorkspace extends StatelessWidget {
  const AppWorkspace({
    required this.title,
    required this.description,
    required this.body,
    this.status,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    this.summaryCards = const <Widget>[],
    this.filters,
    this.detail,
    this.activity,
    this.maxWidth = PageMaxWidth.dataHeavy,
    this.padding,
    this.scrollable = true,
    this.compactSummaryCards = false,
    super.key,
  });

  final String title;
  final String description;
  final AppWorkspaceStatus? status;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;
  final List<Widget> summaryCards;
  final Widget? filters;
  final Widget body;
  final Widget? detail;
  final Widget? activity;
  final PageMaxWidth maxWidth;
  final EdgeInsets? padding;
  final bool scrollable;
  final bool compactSummaryCards;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final double contentGap = ResponsiveSpacing.contentGapFor(
      breakpoint,
      spacing: theme.spacing,
    );
    final List<Widget> children = <Widget>[
      AppWorkspaceHeader(
        title: title,
        description: description,
        status: status,
        primaryAction: primaryAction,
        secondaryActions: secondaryActions,
      ),
    ];

    if (summaryCards.isNotEmpty) {
      children
        ..add(SizedBox(height: contentGap))
        ..add(
          AppWorkspaceSummaryGrid(
            compact: compactSummaryCards,
            children: summaryCards,
          ),
        );
    }

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
      padding: padding,
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
    required this.description,
    this.status,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    super.key,
  });

  final String title;
  final String description;
  final AppWorkspaceStatus? status;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final List<Widget> actions = <Widget>[...secondaryActions, ?primaryAction];
    final Widget titleBlock = _WorkspaceHeaderText(
      title: title,
      description: description,
      status: status,
    );
    final Widget actionBar = _WorkspaceHeaderActions(actions: actions);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.xs),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stackHeader =
                breakpoint == AppBreakpoint.xs ||
                constraints.maxWidth < AppBreakpoints.md;

            if (stackHeader) {
              return Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(width: constraints.maxWidth, child: titleBlock),
                  if (actions.isNotEmpty) actionBar,
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(child: titleBlock),
                if (actions.isNotEmpty) ...<Widget>[
                  SizedBox(width: theme.spacing.md),
                  actionBar,
                ],
              ],
            );
          },
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
    final _WorkspaceToneColors colors = _toneColors(theme, status.tone);
    final IconData icon = status.icon ?? _defaultIcon(status.tone);

    return Semantics(
      label: status.label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.container,
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: theme.appTokens.listIconSize, color: colors.on),
              SizedBox(width: theme.spacing.xs),
              Flexible(
                child: Text(
                  status.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.on,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppWorkspaceSummaryGrid extends StatelessWidget {
  const AppWorkspaceSummaryGrid({
    required this.children,
    this.maxColumns = 4,
    this.compact = false,
    this.compactItemWidth = 218,
    super.key,
  });

  final List<Widget> children;
  final int maxColumns;
  final bool compact;
  final double compactItemWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (compact) {
          final double gap = constraints.maxWidth < AppBreakpoints.md
              ? theme.spacing.sm
              : theme.spacing.md;
          final int columns = _compactSummaryColumnCount(
            constraints.maxWidth,
            children.length,
            maxColumns,
          );
          final double itemWidth =
              (constraints.maxWidth - (gap * (columns - 1))) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: <Widget>[
              for (final Widget child in children)
                SizedBox(width: itemWidth, child: child),
            ],
          );
        }

        final int columns = _summaryColumnCount(
          constraints.maxWidth,
          maxColumns,
        );
        final double gap = constraints.maxWidth < AppBreakpoints.md
            ? theme.spacing.sm
            : theme.spacing.md;
        final double itemWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class AppWorkspaceSummaryCard extends StatelessWidget {
  const AppWorkspaceSummaryCard({
    required this.label,
    required this.value,
    this.description,
    this.status,
    this.icon,
    this.tone,
    this.onPressed,
    this.compact = false,
    super.key,
  });

  final String label;
  final String value;
  final String? description;
  final AppWorkspaceStatus? status;
  final IconData? icon;
  final AppWorkspaceStatusTone? tone;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final _WorkspaceToneColors? toneColors = tone == null
        ? null
        : _toneColors(theme, tone!);
    final Color iconColor = toneColors?.on ?? colorScheme.primary;
    final Color labelColor = toneColors?.on ?? colorScheme.onSurfaceVariant;
    final Color valueColor = toneColors?.on ?? colorScheme.onSurface;
    final Color borderColor = toneColors?.border ?? colorScheme.outlineVariant;
    final Color surfaceColor = toneColors?.container ?? colorScheme.surface;
    final bool hasDescription =
        description != null && description!.trim().isNotEmpty;
    final bool useDetailedCompact =
        compact && (hasDescription || status != null);
    final Widget cardBody = compact
        ? useDetailedCompact
              ? _DetailedCompactSummaryCardBody(
                  icon: icon,
                  label: label,
                  value: value,
                  description: description,
                  status: status,
                  iconColor: iconColor,
                  labelColor: labelColor,
                  valueColor: valueColor,
                  onPressed: onPressed,
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 46),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacing.sm,
                      vertical: theme.spacing.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        if (icon != null) ...<Widget>[
                          Icon(icon, color: iconColor, size: 18),
                          SizedBox(width: theme.spacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: labelColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: theme.spacing.sm),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: valueColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (status != null) ...<Widget>[
                          SizedBox(width: theme.spacing.xs),
                          Flexible(
                            child: AppWorkspaceStatusBadge(status: status!),
                          ),
                        ],
                        if (onPressed != null) ...<Widget>[
                          SizedBox(width: theme.spacing.xs),
                          Icon(Icons.chevron_right, color: iconColor, size: 18),
                        ],
                      ],
                    ),
                  ),
                )
        : Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.sm,
            ),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    color: iconColor,
                    size: theme.appTokens.listIconSize,
                  ),
                  SizedBox(width: theme.spacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: valueColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (description != null && description!.isNotEmpty)
                        Text(
                          description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: labelColor,
                          ),
                        ),
                    ],
                  ),
                ),
                if (status != null) ...<Widget>[
                  SizedBox(width: theme.spacing.sm),
                  AppWorkspaceStatusBadge(status: status!),
                ],
                if (onPressed != null) ...<Widget>[
                  SizedBox(width: theme.spacing.xs),
                  Icon(
                    Icons.chevron_right,
                    color: iconColor,
                    size: theme.appTokens.listIconSize,
                  ),
                ],
              ],
            ),
          );

    return Semantics(
      button: onPressed != null,
      child: Material(
        color: surfaceColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onPressed, child: cardBody),
      ),
    );
  }
}

class _DetailedCompactSummaryCardBody extends StatelessWidget {
  const _DetailedCompactSummaryCardBody({
    required this.label,
    required this.value,
    required this.iconColor,
    required this.labelColor,
    required this.valueColor,
    required this.onPressed,
    this.description,
    this.status,
    this.icon,
  });

  final String label;
  final String value;
  final String? description;
  final AppWorkspaceStatus? status;
  final IconData? icon;
  final Color iconColor;
  final Color labelColor;
  final Color valueColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.all(theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 34,
                    child: Center(
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: theme.appTokens.listIconSize,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onPressed != null) ...<Widget>[
                SizedBox(width: theme.spacing.xs),
                Icon(
                  Icons.chevron_right,
                  color: iconColor,
                  size: theme.appTokens.listIconSize,
                ),
              ],
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (description != null &&
              description!.trim().isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            Text(
              description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
            ),
          ],
          if (status != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            _CompactSummaryStatusLine(
              status: status!,
              fallbackColor: colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactSummaryStatusLine extends StatelessWidget {
  const _CompactSummaryStatusLine({
    required this.status,
    required this.fallbackColor,
  });

  final AppWorkspaceStatus status;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final _WorkspaceToneColors colors = _toneColors(theme, status.tone);

    return Row(
      children: <Widget>[
        Icon(
          status.icon ?? _defaultIcon(status.tone),
          color: colors.on,
          size: 16,
        ),
        SizedBox(width: theme.spacing.xs),
        Expanded(
          child: Text(
            status.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.on == Colors.transparent
                  ? fallbackColor
                  : colors.on,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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
    required this.title,
    required this.child,
    this.description,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget child;

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
          Padding(
            padding: EdgeInsets.all(theme.spacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: theme.textTheme.titleMedium),
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
          Padding(padding: EdgeInsets.all(theme.spacing.lg), child: child),
        ],
      ),
    );
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
              Tooltip(
                message: MaterialLocalizations.of(context).closeButtonTooltip,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: closeEnabled
                      ? () {
                          Navigator.of(context).maybePop();
                        }
                      : null,
                  icon: const Icon(Icons.close),
                ),
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

class _WorkspaceHeaderText extends StatelessWidget {
  const _WorkspaceHeaderText({
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final AppWorkspaceStatus? status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final AppBreakpoint breakpoint = AppBreakpoints.of(context);
    final TextStyle? titleStyle = switch (breakpoint) {
      AppBreakpoint.xs ||
      AppBreakpoint.sm ||
      AppBreakpoint.md => textTheme.titleLarge,
      _ => textTheme.headlineSmall,
    };
    final TextStyle? descriptionStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool narrow = constraints.maxWidth < AppBreakpoints.sm;
        final double descriptionWidth = narrow
            ? constraints.maxWidth
            : (constraints.maxWidth * 0.62).clamp(240, 520).toDouble();

        return Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (description.isNotEmpty)
              SizedBox(
                width: descriptionWidth,
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: descriptionStyle,
                ),
              ),
            if (status != null) AppWorkspaceStatusBadge(status: status!),
          ],
        );
      },
    );
  }
}

class _WorkspaceHeaderActions extends StatelessWidget {
  const _WorkspaceHeaderActions({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      alignment: WrapAlignment.end,
      children: actions,
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

int _summaryColumnCount(double width, int maxColumns) {
  final int breakpointColumns = switch (width) {
    >= 1080 => 4,
    >= 760 => 3,
    >= 480 => 2,
    _ => 1,
  };

  return breakpointColumns.clamp(1, maxColumns).toInt();
}

int _compactSummaryColumnCount(double width, int childCount, int maxColumns) {
  final int effectiveMaxColumns = math.min(childCount, maxColumns);
  if (effectiveMaxColumns <= 0) {
    return 1;
  }

  final int breakpointColumns = switch (width) {
    >= 920 => 4,
    >= 700 => 3,
    >= 480 => 2,
    _ => 1,
  };

  return breakpointColumns.clamp(1, effectiveMaxColumns).toInt();
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
