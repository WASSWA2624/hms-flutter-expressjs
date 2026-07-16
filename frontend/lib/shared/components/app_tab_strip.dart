import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Semantic tone for tab count superscripts.
enum AppTabCountTone { info, warning, danger }

@immutable
final class AppTabItem {
  const AppTabItem({
    required this.id,
    required this.label,
    this.count,
    this.countTone = AppTabCountTone.info,
    this.icon,
  });

  final String id;
  final String label;
  final int? count;

  /// Color of the count superscript when [count] is non-null.
  final AppTabCountTone countTone;

  /// Retained for call-site compatibility; not rendered in the tab chrome.
  final IconData? icon;
}

/// Section tabs with an optional dense action toolbar directly underneath.
///
/// The toolbar is omitted when both [primaryAction] and [secondaryActions] are
/// empty.
class AppTabStrip extends StatelessWidget {
  const AppTabStrip({
    required this.tabs,
    required this.selectedId,
    required this.onTabTapped,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
    super.key,
  });

  final List<AppTabItem> tabs;
  final String? selectedId;
  final ValueChanged<String> onTabTapped;

  /// Right-aligned primary CTA rendered inside the toolbar row.
  final Widget? primaryAction;

  /// Left-aligned flat toolbar actions (no background).
  final List<Widget> secondaryActions;

  bool get _hasToolbar => primaryAction != null || secondaryActions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color hairline = colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: hairline)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final AppTabItem tab in tabs)
                  _AppTabChip(
                    label: tab.label,
                    count: tab.count,
                    countTone: tab.countTone,
                    isSelected: selectedId == tab.id,
                    onTap: () => onTabTapped(tab.id),
                  ),
              ],
            ),
          ),
        ),
        if (_hasToolbar)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: hairline)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
              child: Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: <Widget>[
                  Wrap(
                    spacing: theme.spacing.xs,
                    runSpacing: theme.spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: secondaryActions,
                  ),
                  ?primaryAction,
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Dense flat toolbar action (icon + label, no fill).
class AppTabToolbarAction extends StatelessWidget {
  const AppTabToolbarAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.isLoading = false,
    this.tooltip,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final bool isLoading;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String fullLabel = label.trim();
    final bool canPress = enabled && !isLoading && onPressed != null;

    final Widget button = TextButton(
      onPressed: canPress ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
        minimumSize: Size(theme.spacing.none, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else if (icon != null) ...<Widget>[
            Icon(icon, size: 16),
            SizedBox(width: theme.spacing.xs),
          ],
          Text(
            fullLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final Widget semantic = Semantics(
      button: true,
      enabled: canPress,
      label: semanticLabel ?? fullLabel,
      child: button,
    );

    return Tooltip(message: tooltip ?? fullLabel, child: semantic);
  }
}

/// Flat primary CTA for the tab toolbar (no elevation / 3D fill).
class AppTabToolbarPrimary extends StatelessWidget {
  const AppTabToolbarPrimary({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.isLoading = false,
    this.tooltip,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final bool isLoading;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String fullLabel = label.trim();
    final bool canPress = enabled && !isLoading && onPressed != null;

    final Widget button = TextButton(
      onPressed: canPress ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
        minimumSize: Size(theme.spacing.none, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radius.sm),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          else if (icon != null) ...<Widget>[
            Icon(icon, size: 16),
            SizedBox(width: theme.spacing.xs),
          ],
          Text(
            fullLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    final Widget semantic = Semantics(
      button: true,
      enabled: canPress,
      label: semanticLabel ?? fullLabel,
      child: button,
    );

    return Tooltip(message: tooltip ?? fullLabel, child: semantic);
  }
}

Color _countToneColor(ThemeData theme, AppTabCountTone tone) {
  final AppStatusColors status = theme.statusColors;
  return switch (tone) {
    AppTabCountTone.info => status.info,
    AppTabCountTone.warning => status.warning,
    AppTabCountTone.danger => status.danger,
  };
}

class _AppTabChip extends StatefulWidget {
  const _AppTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.countTone,
    this.count,
  });

  final String label;
  final int? count;
  final AppTabCountTone countTone;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_AppTabChip> createState() => _AppTabChipState();
}

class _AppTabChipState extends State<_AppTabChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String fullLabel = widget.label.trim();
    final String semanticsLabel = widget.count == null
        ? fullLabel
        : '$fullLabel (${widget.count})';

    final Color backgroundColor = widget.isSelected
        ? colorScheme.primary.withValues(alpha: 0.10)
        : _isHovered
        ? colorScheme.onSurface.withValues(alpha: 0.06)
        : colorScheme.onSurface.withValues(alpha: 0.03);
    final Color foregroundColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final FontWeight fontWeight = widget.isSelected
        ? FontWeight.w700
        : FontWeight.w500;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: semanticsLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            right: theme.spacing.xs,
            bottom: theme.spacing.xs / 2,
            top: theme.spacing.xs / 2,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(theme.radius.sm),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(theme.radius.sm),
              hoverColor: colorScheme.onSurface.withValues(alpha: 0.04),
              splashColor: colorScheme.primary.withValues(alpha: 0.08),
              onTap: widget.onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs + 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        fullLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: fontWeight,
                        ),
                      ),
                    ),
                    if (widget.count != null)
                      Transform.translate(
                        offset: const Offset(1, -4),
                        child: Text(
                          '${widget.count}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _countToneColor(theme, widget.countTone),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            height: 1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
