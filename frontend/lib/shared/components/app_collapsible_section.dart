import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
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
    super.key,
  });

  final String? title;

  /// Optional custom title row content. When set, takes precedence over [title].
  final Widget? titleWidget;
  final String? description;
  final List<Widget> actions;

  /// Actions rendered in the header row (before the expand chevron).
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
    final bool hasStringTitle =
        widget.title != null && widget.title!.trim().isNotEmpty;
    final bool hasTitle = widget.titleWidget != null || hasStringTitle;
    final bool showBody = !widget.collapsible || _resolvedExpanded;
    final String? description =
        widget.description != null && widget.description!.trim().isNotEmpty
        ? widget.description
        : null;
    final bool hasActions = widget.actions.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
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
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: widget.collapsible ? _toggleExpanded : null,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: theme.spacing.xs / 2,
                          ),
                          child: Row(
                            children: <Widget>[
                              if (widget.titleIcon != null) ...<Widget>[
                                Icon(
                                  widget.titleIcon,
                                  size: theme.appTokens.listIconSize,
                                  color: colorScheme.primary,
                                ),
                                SizedBox(width: theme.spacing.sm),
                              ],
                              Expanded(
                                child: widget.titleWidget ??
                                    Text(
                                      widget.title!,
                                      style: theme.textTheme.titleMedium,
                                    ),
                              ),
                              if (widget.collapsible)
                                Icon(
                                  _resolvedExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: theme.appTokens.listIconSize,
                                  color: colorScheme.onSurfaceVariant,
                                  semanticLabel: _resolvedExpanded
                                      ? context.l10n.commonShowLessActionLabel
                                      : context.l10n.commonShowMoreActionLabel,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.headerActions.isNotEmpty) ...<Widget>[
                    SizedBox(width: theme.spacing.sm),
                    // Header actions sit outside the collapse InkWell so they
                    // do not toggle expand/collapse. Default to icon-only so
                    // controls like delete read as plain icon buttons.
                    AppActionLabelScope(
                      showLabels: false,
                      forceIconOnly: true,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: theme.spacing.xs,
                        runSpacing: theme.spacing.xs,
                        children: widget.headerActions,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showBody) const Divider(height: 1),
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
              color: colorScheme.onSurfaceVariant,
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
