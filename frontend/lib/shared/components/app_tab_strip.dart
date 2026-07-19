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
    // Opaque merge color shared by the active tab and the toolbar so the two
    // render as one continuous surface (translucent tints would not blend
    // identically when stacked).
    final Color activeFill = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.10),
      colorScheme.surface,
    );

    final Widget tabRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (int index = 0; index < tabs.length; index += 1)
            _AppTabChip(
              label: tabs[index].label,
              count: tabs[index].count,
              countTone: tabs[index].countTone,
              isSelected: selectedId == tabs[index].id,
              isFirst: index == 0,
              activeFill: activeFill,
              onTap: () => onTabTapped(tabs[index].id),
            ),
        ],
      ),
    );

    if (!_hasToolbar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          tabRow,
          Container(height: 1, color: hairline),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      // No gap or divider between tabs and toolbar: the active tab flows
      // straight into the toolbar surface.
      children: <Widget>[
        tabRow,
        Container(
          decoration: BoxDecoration(
            color: activeFill,
            border: Border(bottom: BorderSide(color: hairline)),
          ),
          padding: EdgeInsets.symmetric(
            vertical: theme.spacing.sm,
            horizontal: theme.spacing.sm,
          ),
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

/// Chrome-style tab silhouette for the selected tab: rounded top corners and
/// bottom corners flaring outward into the toolbar. Each flare can be
/// disabled independently (e.g. the first tab keeps a straight left edge so it
/// stays flush with the toolbar's left edge).
class _FlaredTabPainter extends CustomPainter {
  const _FlaredTabPainter({
    required this.fill,
    required this.topRadius,
    required this.flareRadius,
    required this.flareLeft,
    required this.flareRight,
  });

  final Color fill;
  final double topRadius;
  final double flareRadius;
  final bool flareLeft;
  final bool flareRight;

  Path _tabPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = flareRadius;
    final double tr = topRadius;
    final Path path = Path();

    if (flareLeft) {
      path
        ..moveTo(0, h)
        // Bottom-left corner curves outward.
        ..quadraticBezierTo(r, h, r, h - r)
        ..lineTo(r, tr)
        ..quadraticBezierTo(r, 0, r + tr, 0);
    } else {
      path
        ..moveTo(0, h)
        ..lineTo(0, tr)
        ..quadraticBezierTo(0, 0, tr, 0);
    }

    if (flareRight) {
      path
        ..lineTo(w - r - tr, 0)
        ..quadraticBezierTo(w - r, 0, w - r, tr)
        ..lineTo(w - r, h - r)
        // Bottom-right corner curves outward.
        ..quadraticBezierTo(w - r, h, w, h);
    } else {
      path
        ..lineTo(w - tr, 0)
        ..quadraticBezierTo(w, 0, w, tr)
        ..lineTo(w, h);
    }

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_tabPath(size), Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_FlaredTabPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.topRadius != topRadius ||
      oldDelegate.flareRadius != flareRadius ||
      oldDelegate.flareLeft != flareLeft ||
      oldDelegate.flareRight != flareRight;
}

class _AppTabChip extends StatefulWidget {
  const _AppTabChip({
    required this.label,
    required this.isSelected,
    required this.isFirst,
    required this.onTap,
    required this.countTone,
    required this.activeFill,
    this.count,
  });

  final String label;
  final int? count;
  final AppTabCountTone countTone;
  final bool isSelected;

  /// First tab in the strip: its left edge stays straight and flush with the
  /// toolbar's left edge (no outward flare on that side).
  final bool isFirst;
  final VoidCallback onTap;

  /// Opaque fill shared with the toolbar so the selected tab and toolbar
  /// merge into one continuous surface.
  final Color activeFill;

  @override
  State<_AppTabChip> createState() => _AppTabChipState();
}

class _AppTabChipState extends State<_AppTabChip> {
  static const double _flareRadius = 8;

  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String fullLabel = widget.label.trim();
    final String semanticsLabel = widget.count == null
        ? fullLabel
        : '$fullLabel (${widget.count})';

    // Only the selected tab is filled (and flared), so it reads clearly as
    // one continuous surface with the toolbar; inactive tabs stay flat and
    // only tint on hover.
    final Color backgroundColor = widget.isSelected
        ? widget.activeFill
        : _isHovered
        ? colorScheme.onSurface.withValues(alpha: 0.06)
        : Colors.transparent;
    final Color foregroundColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final FontWeight fontWeight = widget.isSelected
        ? FontWeight.w700
        : FontWeight.w500;
    final bool flareLeft = widget.isSelected && !widget.isFirst;
    final bool flareRight = widget.isSelected;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: semanticsLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: CustomPaint(
            painter: _FlaredTabPainter(
              fill: backgroundColor,
              // Square top corners; only the bottom flares are curved.
              topRadius: 0,
              flareRadius: _flareRadius,
              flareLeft: flareLeft,
              flareRight: flareRight,
            ),
            child: Padding(
              // Horizontal padding widens by the flare so the label never
              // overlaps the curved corners.
              padding: EdgeInsets.only(
                left: theme.spacing.sm + (flareLeft ? _flareRadius : 0),
                right: theme.spacing.sm + (flareRight ? _flareRadius : 0),
                top: theme.spacing.xs + 4,
                bottom: theme.spacing.xs + 4,
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
    );
  }
}
