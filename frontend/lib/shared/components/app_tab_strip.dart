import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Maximum characters shown on toolbar action button labels.
const int kAppTabToolbarLabelMaxLength = 10;

/// Shortens toolbar action [label] to [kAppTabToolbarLabelMaxLength] characters.
String appTabToolbarLabel(String label) {
  final String trimmed = label.trim();
  if (trimmed.length <= kAppTabToolbarLabelMaxLength) {
    return trimmed;
  }
  return trimmed.substring(0, kAppTabToolbarLabelMaxLength);
}

@immutable
final class AppTabItem {
  const AppTabItem({
    required this.id,
    required this.label,
    this.count,
    this.icon,
  });

  final String id;
  final String label;
  final int? count;

  /// Retained for call-site compatibility; not rendered in the tab chrome.
  final IconData? icon;
}

/// Section tabs with an optional dense action toolbar directly underneath.
///
/// Layout:
/// ```
/// [ Tab ] [ Tab ] [ Tab ]     ← conspicuous active tab + optional counts
/// Refresh  Assign     [CTA]   ← flat secondary actions + primary on the right
/// ```
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

  bool get _hasToolbar =>
      primaryAction != null || secondaryActions.isNotEmpty;

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
              padding: EdgeInsets.symmetric(vertical: theme.spacing.xs / 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Wrap(
                      spacing: theme.spacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: secondaryActions,
                    ),
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
    final String shortLabel = appTabToolbarLabel(fullLabel);
    final bool canPress = enabled && !isLoading && onPressed != null;

    final Widget button = TextButton(
      onPressed: canPress ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onSurfaceVariant,
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
        minimumSize: Size(theme.spacing.none, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            SizedBox(width: theme.spacing.xs / 2),
          ],
          Text(
            shortLabel,
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

    final String? tip = tooltip ?? (shortLabel != fullLabel ? fullLabel : null);
    if (tip == null) {
      return semantic;
    }
    return Tooltip(message: tip, child: semantic);
  }
}

/// Dense filled primary CTA for the tab toolbar.
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
    final String shortLabel = appTabToolbarLabel(fullLabel);
    final bool canPress = enabled && !isLoading && onPressed != null;

    final Widget button = FilledButton(
      onPressed: canPress ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.onSurface.withValues(alpha: 0.12),
        disabledForegroundColor: colorScheme.onSurface.withValues(alpha: 0.38),
        padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radius.sm),
        ),
        textStyle: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
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
                color: colorScheme.onPrimary,
              ),
            )
          else if (icon != null) ...<Widget>[
            Icon(icon, size: 16),
            SizedBox(width: theme.spacing.xs / 2),
          ],
          Text(shortLabel),
        ],
      ),
    );

    final Widget semantic = Semantics(
      button: true,
      enabled: canPress,
      label: semanticLabel ?? fullLabel,
      child: button,
    );

    final String? tip = tooltip ?? (shortLabel != fullLabel ? fullLabel : null);
    if (tip == null) {
      return semantic;
    }
    return Tooltip(message: tip, child: semantic);
  }
}

class _AppTabChip extends StatefulWidget {
  const _AppTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
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
        ? colorScheme.primary.withValues(alpha: 0.12)
        : _isHovered
        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
        : Colors.transparent;
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
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(theme.radius.sm),
            border: Border(
              bottom: BorderSide(
                color: widget.isSelected
                    ? colorScheme.primary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(theme.radius.sm),
              onTap: widget.onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      fullLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foregroundColor,
                        fontWeight: fontWeight,
                      ),
                    ),
                    if (widget.count != null) ...<Widget>[
                      SizedBox(width: theme.spacing.xs / 2),
                      Text(
                        '${widget.count}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.8,
                                ),
                          fontWeight: fontWeight,
                        ),
                      ),
                    ],
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
