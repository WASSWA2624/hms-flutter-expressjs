import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_action_label_scope.dart';

/// Shared collapsible titled section chrome for workspaces, dialogs, and forms.
///
/// This is the app's only reusable section component. Prefer it directly over
/// legacy wrappers ([AppFormSection], [AppSectionPanel]) when building titled
/// sections. Collapse defaults on for titled panels; pass [collapsible]: false
/// when the body must stay visible.
class AppCollapsibleSection extends StatefulWidget {
  const AppCollapsibleSection({
    this.title,
    this.titleWidget,
    this.eyebrow,
    this.subtitle,
    required this.child,
    this.description,
    this.actions = const <Widget>[],
    this.headerActions = const <Widget>[],
    this.titleIcon,
    this.collapsible = true,
    this.initiallyExpanded = true,
    this.expanded,
    this.onExpandedChanged,
    this.contentPadding,
    this.backgroundColor,
    this.borderColor,
    this.accentColor,
    this.titleColor,
    super.key,
  });

  final String? title;

  /// Optional custom title row content. When set, takes precedence over [title],
  /// [eyebrow], and [subtitle].
  final Widget? titleWidget;

  /// Optional small label above [title] in the header (e.g. "Existing room").
  final String? eyebrow;

  /// Optional secondary line under [title] in the header (not the body).
  final String? subtitle;

  final String? description;
  final List<Widget> actions;

  /// Actions rendered in the header row immediately left of the expand chevron.
  ///
  /// Use short generic labels (`Save`, `Edit`, `Delete`, `Add`, `Cancel`).
  /// On phones, header actions stay icon-only. On larger screens they inherit
  /// the ambient [AppActionLabelScope] so labels can show when space allows.
  /// Header [AppButton]s render without resting fill or borders.
  final List<Widget> headerActions;
  final Widget child;
  final IconData? titleIcon;

  /// When true (default), titled panels can collapse to the header only.
  final bool collapsible;
  final bool initiallyExpanded;

  /// When non-null, expansion is controlled by the parent.
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;

  /// Overrides default body padding (`spacing.lg` on all sides).
  final EdgeInsetsGeometry? contentPadding;

  /// Optional color overrides for status-toned sections (e.g. similarity).
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? accentColor;
  final Color? titleColor;

  @override
  State<AppCollapsibleSection> createState() => _AppCollapsibleSectionState();
}

class _AppCollapsibleSectionState extends State<AppCollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  bool get _isControlled => widget.expanded != null;

  bool get _resolvedExpanded => widget.expanded ?? _expanded;

  void _toggleExpanded() {
    final bool next = !_resolvedExpanded;
    if (_isControlled) {
      widget.onExpandedChanged?.call(next);
      return;
    }
    setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  @override
  void didUpdateWidget(covariant AppCollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isControlled &&
        oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        widget.expanded == null) {
      _expanded = widget.initiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color container = widget.backgroundColor ?? colorScheme.surface;
    final Color border = widget.borderColor ?? colorScheme.outlineVariant;
    final Color accent = widget.accentColor ?? colorScheme.primary;
    final Color onContainer = widget.titleColor ?? colorScheme.onSurface;
    final Color chevron =
        widget.titleColor ?? colorScheme.onSurfaceVariant;
    final Color secondaryText =
        widget.titleColor ?? colorScheme.onSurfaceVariant;
    final bool hasStringTitle =
        widget.title != null && widget.title!.trim().isNotEmpty;
    final String? eyebrow = widget.eyebrow?.trim().isNotEmpty == true
        ? widget.eyebrow!.trim()
        : null;
    final String? subtitle = widget.subtitle?.trim().isNotEmpty == true
        ? widget.subtitle!.trim()
        : null;
    final bool hasTitle =
        widget.titleWidget != null ||
        hasStringTitle ||
        eyebrow != null ||
        subtitle != null;
    final bool showBody = !widget.collapsible || _resolvedExpanded;
    final String? description =
        widget.description != null && widget.description!.trim().isNotEmpty
        ? widget.description
        : null;
    final bool hasActions = widget.actions.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: container,
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (hasTitle) ...<Widget>[
            Padding(
              // Minimal header: just enough inset so title/icon miss the border.
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.sm,
                vertical: theme.spacing.xs,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: widget.collapsible ? _toggleExpanded : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: theme.spacing.xs / 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (widget.titleIcon != null) ...<Widget>[
                          Padding(
                            padding: EdgeInsets.only(top: theme.spacing.xs / 2),
                            child: Icon(
                              widget.titleIcon,
                              size: theme.appTokens.listIconSize,
                              color: accent,
                            ),
                          ),
                          SizedBox(width: theme.spacing.sm),
                        ],
                        Expanded(
                          child: widget.titleWidget ??
                              _AppCollapsibleHeaderTitle(
                                eyebrow: eyebrow,
                                title: hasStringTitle ? widget.title : null,
                                subtitle: subtitle,
                                titleColor: onContainer,
                                secondaryColor: secondaryText,
                              ),
                        ),
                        if (widget.headerActions.isNotEmpty) ...<Widget>[
                          SizedBox(width: theme.spacing.sm),
                          // Keep header actions tappable without toggling.
                          Builder(
                            builder: (BuildContext context) {
                              final bool compact =
                                  AppBreakpoints.of(context).isMobile;
                              final AppActionLabelScope? ambient =
                                  AppActionLabelScope.maybeOf(context);
                              return AppActionLabelScope(
                                showLabels: compact
                                    ? false
                                    : (ambient?.showLabels ?? true),
                                forceIconOnly: compact,
                                plainChrome: true,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: theme.spacing.xs,
                                  runSpacing: theme.spacing.xs,
                                  children: widget.headerActions,
                                ),
                              );
                            },
                          ),
                        ],
                        if (widget.collapsible) ...<Widget>[
                          SizedBox(width: theme.spacing.xs),
                          Padding(
                            padding: EdgeInsets.only(top: theme.spacing.xs / 2),
                            child: Icon(
                              _resolvedExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: theme.appTokens.listIconSize,
                              color: chevron,
                              semanticLabel: _resolvedExpanded
                                  ? context.l10n.commonShowLessActionLabel
                                  : context.l10n.commonShowMoreActionLabel,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showBody)
              Divider(height: 1, color: border.withValues(alpha: 0.55)),
          ],
          if (showBody)
            Padding(
              padding:
                  widget.contentPadding ?? EdgeInsets.all(theme.spacing.lg),
              child: _buildBody(
                theme: theme,
                colorScheme: colorScheme,
                description: description,
                hasActions: hasActions,
                secondaryText: secondaryText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String? description,
    required bool hasActions,
    required Color secondaryText,
  }) {
    if (!hasActions && description == null) {
      return widget.child;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasActions)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: theme.spacing.xs,
              runSpacing: theme.spacing.xs,
              children: widget.actions,
            ),
          ),
        if (description != null) ...<Widget>[
          if (hasActions) SizedBox(height: theme.spacing.sm),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: secondaryText,
            ),
          ),
        ],
        if (hasActions || description != null)
          SizedBox(height: theme.spacing.md),
        widget.child,
      ],
    );
  }
}

class _AppCollapsibleHeaderTitle extends StatelessWidget {
  const _AppCollapsibleHeaderTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.secondaryColor,
  });

  final String? eyebrow;
  final String? title;
  final String? subtitle;
  final Color titleColor;
  final Color secondaryColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (eyebrow != null)
          Text(
            eyebrow!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: secondaryColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (title != null) ...<Widget>[
          if (eyebrow != null) SizedBox(height: theme.spacing.xs / 2),
          Text(
            title!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ],
        if (subtitle != null) ...<Widget>[
          if (eyebrow != null || title != null)
            SizedBox(height: theme.spacing.xs / 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: secondaryColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Spaces titled [AppCollapsibleSection] blocks in detail dialogs.
///
/// Detail modal bodies should be a [Column] of these sections (not one outer
/// section wrapping custom chrome).
List<Widget> appCollapsibleSectionSpacing(
  BuildContext context,
  List<Widget> sections,
) {
  final double spacing = Theme.of(context).spacing.md;
  return <Widget>[
    for (var index = 0; index < sections.length; index += 1) ...<Widget>[
      if (index > 0) SizedBox(height: spacing),
      sections[index],
    ],
  ];
}
