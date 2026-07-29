import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

/// Semantic tone for tab count superscripts.
enum AppTabCountTone { info, warning, danger }

/// Visual weight for [AppTabStrip].
///
/// [standard] is the primary desk chrome (flared selected tab).
/// [nested] is a lighter underline strip for sub-tabs under a desk section.
enum AppTabStripVariant { standard, nested }

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

  /// Optional leading icon shown beside the tab label.
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
    this.variant = AppTabStripVariant.standard,
    super.key,
  });

  final List<AppTabItem> tabs;
  final String? selectedId;
  final ValueChanged<String> onTabTapped;

  /// Right-aligned primary CTA rendered inside the toolbar row.
  final Widget? primaryAction;

  /// Left-aligned flat toolbar actions (no background).
  final List<Widget> secondaryActions;

  /// Use [AppTabStripVariant.nested] for subordinate category tabs.
  final AppTabStripVariant variant;

  bool get _hasToolbar => primaryAction != null || secondaryActions.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color hairline = colorScheme.outlineVariant.withValues(alpha: 0.4);
    final bool nested = variant == AppTabStripVariant.nested;
    // Opaque merge color shared by the active tab and the toolbar so the two
    // render as one continuous surface (translucent tints would not blend
    // identically when stacked). Nested strips stay flat (no flared fill).
    final Color activeFill = nested
        ? colorScheme.surface
        : Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.10),
            colorScheme.surface,
          );

    final Widget tabRow = _AppTabOverflowRow(
      tabs: tabs,
      selectedId: selectedId,
      onTabTapped: onTabTapped,
      activeFill: activeFill,
      variant: variant,
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

/// Tab chips that fit in the available width, with a more menu for the rest.
class _AppTabOverflowRow extends StatelessWidget {
  const _AppTabOverflowRow({
    required this.tabs,
    required this.selectedId,
    required this.onTabTapped,
    required this.activeFill,
    required this.variant,
  });

  static const double _moreButtonWidth = 48;
  static const String _moreLabel = 'More tabs';

  final List<AppTabItem> tabs;
  final String? selectedId;
  final ValueChanged<String> onTabTapped;
  final Color activeFill;
  final AppTabStripVariant variant;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final _TabPartition partition = _partitionTabs(
          tabs: tabs,
          selectedId: selectedId,
          maxWidth: maxWidth,
          theme: theme,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          nested: variant == AppTabStripVariant.nested,
        );

        return Row(
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  for (
                    int visiblePos = 0;
                    visiblePos < partition.visibleIndices.length;
                    visiblePos += 1
                  )
                    _AppTabChip(
                      label: tabs[partition.visibleIndices[visiblePos]].label,
                      icon: tabs[partition.visibleIndices[visiblePos]].icon,
                      count: tabs[partition.visibleIndices[visiblePos]].count,
                      countTone:
                          tabs[partition.visibleIndices[visiblePos]].countTone,
                      isSelected:
                          selectedId ==
                          tabs[partition.visibleIndices[visiblePos]].id,
                      isFirst: visiblePos == 0,
                      activeFill: activeFill,
                      variant: variant,
                      onTap: () => onTabTapped(
                        tabs[partition.visibleIndices[visiblePos]].id,
                      ),
                    ),
                ],
              ),
            ),
            if (partition.overflowIndices.isNotEmpty)
              MenuAnchor(
                style: MenuStyle(
                  visualDensity: VisualDensity.compact,
                  alignment: AlignmentDirectional.bottomEnd,
                  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                    EdgeInsets.all(theme.spacing.xs),
                  ),
                ),
                builder:
                    (
                      BuildContext context,
                      MenuController controller,
                      Widget? child,
                    ) {
                      return KeyedSubtree(
                        key: const ValueKey<String>('tabOverflowMore'),
                        child: AppButton.popupMenuTrigger(
                          context: context,
                          icon: Icons.more_vert,
                          semanticLabel: _moreLabel,
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                        ),
                      );
                    },
                menuChildren: <Widget>[
                  for (final int index in partition.overflowIndices)
                    MenuItemButton(
                      onPressed: () => onTabTapped(tabs[index].id),
                      leadingIcon: tabs[index].icon == null
                          ? null
                          : Icon(tabs[index].icon, size: 18),
                      trailingIcon: selectedId == tabs[index].id
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      child: Text(
                        tabs[index].count == null
                            ? tabs[index].label
                            : '${tabs[index].label} (${tabs[index].count})',
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

final class _TabPartition {
  const _TabPartition({
    required this.visibleIndices,
    required this.overflowIndices,
  });

  final List<int> visibleIndices;
  final List<int> overflowIndices;
}

_TabPartition _partitionTabs({
  required List<AppTabItem> tabs,
  required String? selectedId,
  required double maxWidth,
  required ThemeData theme,
  required TextDirection textDirection,
  required TextScaler textScaler,
  bool nested = false,
}) {
  if (tabs.isEmpty) {
    return const _TabPartition(
      visibleIndices: <int>[],
      overflowIndices: <int>[],
    );
  }

  final List<double> widths = <double>[
    for (int i = 0; i < tabs.length; i += 1)
      _estimateTabWidth(
        tab: tabs[i],
        theme: theme,
        textDirection: textDirection,
        textScaler: textScaler,
        nested: nested,
        isSelected: tabs[i].id == selectedId,
        isFirst: i == 0,
      ),
  ];
  final double totalWidth = widths.fold<double>(0, (double a, double b) => a + b);
  if (totalWidth <= maxWidth) {
    return _TabPartition(
      visibleIndices: List<int>.generate(tabs.length, (int i) => i),
      overflowIndices: const <int>[],
    );
  }

  final double budget = (maxWidth - _AppTabOverflowRow._moreButtonWidth).clamp(
    0.0,
    maxWidth,
  );
  final List<int> visible = <int>[];
  double used = 0;
  for (int i = 0; i < tabs.length; i += 1) {
    if (used + widths[i] <= budget) {
      visible.add(i);
      used += widths[i];
    } else {
      break;
    }
  }

  final int selectedIndex = tabs.indexWhere(
    (AppTabItem tab) => tab.id == selectedId,
  );
  if (selectedIndex >= 0 && !visible.contains(selectedIndex)) {
    while (visible.isNotEmpty && used + widths[selectedIndex] > budget) {
      used -= widths[visible.removeLast()];
    }
    if (used + widths[selectedIndex] <= budget || visible.isEmpty) {
      visible
        ..add(selectedIndex)
        ..sort();
    }
  }

  final Set<int> visibleSet = visible.toSet();
  return _TabPartition(
    visibleIndices: visible,
    overflowIndices: <int>[
      for (int i = 0; i < tabs.length; i += 1)
        if (!visibleSet.contains(i)) i,
    ],
  );
}

double _estimateTabWidth({
  required AppTabItem tab,
  required ThemeData theme,
  required TextDirection textDirection,
  required TextScaler textScaler,
  bool nested = false,
  bool isSelected = false,
  bool isFirst = false,
}) {
  // Match _AppTabChip horizontal padding, including selected flare insets.
  const double flareRadius = 8;
  double width = theme.spacing.sm * 2;
  if (!nested && isSelected) {
    if (!isFirst) {
      width += flareRadius;
    }
    width += flareRadius;
  }
  if (tab.icon != null) {
    width += (nested ? 16.0 : 18.0) + theme.spacing.xs;
  }

  final TextPainter labelPainter = TextPainter(
    text: TextSpan(
      text: tab.label.trim(),
      style: (nested ? theme.textTheme.labelMedium : theme.textTheme.labelLarge)
          ?.copyWith(fontWeight: FontWeight.w400),
    ),
    maxLines: 1,
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout();
  width += labelPainter.width;

  if (tab.count != null) {
    final TextPainter countPainter = TextPainter(
      text: TextSpan(
        text: '${tab.count}',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: _tabCountFontSize,
          height: 1,
        ),
      ),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    width += 1 + countPainter.width;
  }

  // Font metrics can be a couple of pixels wider than TextPainter estimates.
  return width + 4;
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
    final bool showLabel = _showToolbarLabel(context, hasIcon: icon != null);

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
          if (isLoading || icon != null) ...<Widget>[
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: Padding(
                  padding: const EdgeInsets.all(1),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Icon(icon, size: 16),
            if (showLabel) SizedBox(width: theme.spacing.xs),
          ],
          if (showLabel)
            Text(
              fullLabel,
              // Regular weight keeps toolbar actions visually lighter than the
              // tab labels above.
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w400,
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
    final bool showLabel = _showToolbarLabel(context, hasIcon: icon != null);

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
          if (isLoading) ...<Widget>[
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            if (showLabel) SizedBox(width: theme.spacing.xs),
          ] else if (icon != null) ...<Widget>[
            Icon(icon, size: 16),
            if (showLabel) SizedBox(width: theme.spacing.xs),
          ],
          if (showLabel)
            Text(
              fullLabel,
              // Medium weight: below the tab labels (w500/w700) in emphasis
              // while still standing out from the flat toolbar actions (w400).
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w400,
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

/// Icon-only toolbar chrome on compact widths; keep the label when there is no
/// icon so the control remains usable.
bool _showToolbarLabel(BuildContext context, {required bool hasIcon}) {
  if (!hasIcon) {
    return true;
  }
  return AppBreakpoints.of(context).showsToolbarActionLabels;
}

/// Tab count superscript size. Kept above tiny caption scale so queue
/// totals stay readable without competing with the tab label.
const double _tabCountFontSize = 12;

Color _countToneColor(ThemeData theme, AppTabCountTone tone) {
  final AppStatusColors status = theme.statusColors;
  return switch (tone) {
    AppTabCountTone.info => status.info,
    AppTabCountTone.warning => status.warning,
    AppTabCountTone.danger => status.danger,
  };
}

TextStyle? _tabCountStyle(ThemeData theme, AppTabCountTone tone) {
  return theme.textTheme.labelSmall?.copyWith(
    color: _countToneColor(theme, tone),
    fontWeight: FontWeight.w600,
    fontSize: _tabCountFontSize,
    height: 1,
  );
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
    required this.variant,
    this.icon,
    this.count,
  });

  final String label;
  final IconData? icon;
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

  final AppTabStripVariant variant;

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
    final bool nested = widget.variant == AppTabStripVariant.nested;

    if (nested) {
      return _buildNestedChip(
        context: context,
        theme: theme,
        colorScheme: colorScheme,
        fullLabel: fullLabel,
        semanticsLabel: semanticsLabel,
      );
    }

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
    // One tier heavier than the toolbar buttons (w400 actions / w500
    // primary) so the tab labels read as the dominant level of the strip.
    // The bundled font ships 400/500/700 only, so stick to those weights.
    final FontWeight fontWeight = widget.isSelected
        ? FontWeight.w600
        : FontWeight.w400;
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
                children: <Widget>[
                  if (widget.icon != null) ...<Widget>[
                    Icon(
                      widget.icon,
                      size: 18,
                      color: foregroundColor,
                    ),
                    SizedBox(width: theme.spacing.xs),
                  ],
                  Text(
                    fullLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: fontWeight,
                    ),
                  ),
                  if (widget.count != null)
                    Transform.translate(
                      offset: const Offset(1, -5),
                      child: Text(
                        '${widget.count}',
                        style: _tabCountStyle(theme, widget.countTone),
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

  Widget _buildNestedChip({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String fullLabel,
    required String semanticsLabel,
  }) {
    final Color foregroundColor = widget.isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final FontWeight fontWeight = widget.isSelected
        ? FontWeight.w500
        : FontWeight.w400;
    final Color hoverFill = _isHovered
        ? colorScheme.onSurface.withValues(alpha: 0.04)
        : Colors.transparent;

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: hoverFill,
              border: Border(
                bottom: BorderSide(
                  color: widget.isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: widget.isSelected ? 2 : 1,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.sm,
                vertical: theme.spacing.xs + 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (widget.icon != null) ...<Widget>[
                    Icon(widget.icon, size: 16, color: foregroundColor),
                    SizedBox(width: theme.spacing.xs),
                  ],
                  Text(
                    fullLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foregroundColor,
                      fontWeight: fontWeight,
                    ),
                  ),
                  if (widget.count != null)
                    Transform.translate(
                      offset: const Offset(1, -5),
                      child: Text(
                        '${widget.count}',
                        style: _tabCountStyle(theme, widget.countTone),
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
