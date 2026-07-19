// Design-sample renderer for the AppTabStrip redesign.
//
// Run with:
//   flutter test test/goldens/tab_strip_samples_golden_test.dart --update-goldens
//
// This produces one PNG per sample next to this file. It is a throwaway
// gallery used to pick a design; the chosen variant will be folded into
// lib/shared/components/app_tab_strip.dart.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_tab_strip.dart';

enum _Sample { seamless, outlined, accentTop, softCard, boldTonal }

Future<void> _loadAppFonts() async {
  final String manifest = await rootBundle.loadString('FontManifest.json');
  final List<dynamic> fontEntries = json.decode(manifest) as List<dynamic>;
  for (final dynamic entry in fontEntries) {
    final Map<String, dynamic> map = entry as Map<String, dynamic>;
    final String family = (map['family'] as String).split('/').last;
    final FontLoader loader = FontLoader(family);
    for (final dynamic font in map['fonts'] as List<dynamic>) {
      final String asset = (font as Map<String, dynamic>)['asset'] as String;
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadAppFonts);

  for (final _Sample sample in _Sample.values) {
    testWidgets('renders ${sample.name} sample', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(920, 240);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey<String>('sample'),
              child: ColoredBox(
                color: AppTheme.light.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _SampledTabStrip(
                        sample: sample,
                        tabs: const <AppTabItem>[
                          AppTabItem(
                            id: 'appointments',
                            label: 'Appointments',
                            count: 12,
                            countTone: AppTabCountTone.info,
                          ),
                          AppTabItem(
                            id: 'desk',
                            label: 'Desk queue',
                            count: 5,
                            countTone: AppTabCountTone.warning,
                          ),
                          AppTabItem(
                            id: 'visits',
                            label: 'Active visits',
                            count: 3,
                            countTone: AppTabCountTone.danger,
                          ),
                          AppTabItem(id: 'closed', label: 'Closed'),
                        ],
                        selectedId: 'desk',
                        onTabTapped: (_) {},
                        secondaryActions: <Widget>[
                          AppTabToolbarAction(
                            label: 'Refresh',
                            icon: Icons.refresh,
                            onPressed: () {},
                          ),
                          AppTabToolbarAction(
                            label: 'Export',
                            icon: Icons.file_download_outlined,
                            onPressed: () {},
                          ),
                        ],
                        primaryAction: AppTabToolbarPrimary(
                          label: 'New appointment',
                          icon: Icons.add,
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Content area below the strip…',
                        style: AppTheme.light.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final int index = _Sample.values.indexOf(sample) + 1;
      await expectLater(
        find.byKey(const ValueKey<String>('sample')),
        matchesGoldenFile('tab_strip_sample_${index}_${sample.name}.png'),
      );
    });
  }
}

/// Chrome-style tab: rounded top corners, bottom corners flaring OUTWARD.
class _FlaredTabPainter extends CustomPainter {
  const _FlaredTabPainter({
    required this.fill,
    required this.topRadius,
    required this.flareRadius,
    this.outline,
    this.topAccent,
  });

  final Color fill;
  final double topRadius;
  final double flareRadius;
  final Color? outline;
  final Color? topAccent;

  Path _tabPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = flareRadius;
    final double tr = topRadius;
    return Path()
      ..moveTo(0, h)
      ..quadraticBezierTo(r, h, r, h - r)
      ..lineTo(r, tr)
      ..quadraticBezierTo(r, 0, r + tr, 0)
      ..lineTo(w - r - tr, 0)
      ..quadraticBezierTo(w - r, 0, w - r, tr)
      ..lineTo(w - r, h - r)
      ..quadraticBezierTo(w - r, h, w, h)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _tabPath(size);
    canvas.drawPath(path, Paint()..color = fill);
    if (outline != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = outline!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    if (topAccent != null) {
      final double r = flareRadius;
      final double tr = topRadius;
      final Path accent = Path()
        ..moveTo(r, tr)
        ..quadraticBezierTo(r, 0, r + tr, 0)
        ..lineTo(size.width - r - tr, 0)
        ..quadraticBezierTo(size.width - r, 0, size.width - r, tr);
      canvas.drawPath(
        accent,
        Paint()
          ..color = topAccent!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_FlaredTabPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.outline != outline ||
      oldDelegate.topAccent != topAccent ||
      oldDelegate.topRadius != topRadius ||
      oldDelegate.flareRadius != flareRadius;
}

class _SampledTabStrip extends StatelessWidget {
  const _SampledTabStrip({
    required this.tabs,
    required this.selectedId,
    required this.onTabTapped,
    required this.sample,
    this.primaryAction,
    this.secondaryActions = const <Widget>[],
  });

  final List<AppTabItem> tabs;
  final String? selectedId;
  final ValueChanged<String> onTabTapped;
  final _Sample sample;
  final Widget? primaryAction;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color hairline = scheme.outlineVariant.withValues(alpha: 0.4);

    final double tintAlpha = sample == _Sample.boldTonal ? 0.14 : 0.10;
    // Opaque merge color shared by the active tab and the toolbar.
    final Color activeFill = Color.alphaBlend(
      scheme.primary.withValues(alpha: tintAlpha),
      scheme.surface,
    );
    final Color? outline = sample == _Sample.outlined ? hairline : null;
    final double topRadius = sample == _Sample.softCard
        ? theme.radius.md
        : theme.radius.sm;
    final double flareRadius = sample == _Sample.softCard ? 12 : 8;

    final Widget tabRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final AppTabItem tab in tabs)
            _FlaredTabChip(
              label: tab.label,
              count: tab.count,
              countTone: tab.countTone,
              isSelected: selectedId == tab.id,
              onTap: () => onTabTapped(tab.id),
              activeFill: activeFill,
              outline: outline,
              topAccent: sample == _Sample.accentTop ? scheme.primary : null,
              topRadius: topRadius,
              flareRadius: flareRadius,
            ),
        ],
      ),
    );

    final BorderRadius? toolbarRadius = sample == _Sample.softCard
        ? BorderRadius.vertical(bottom: Radius.circular(theme.radius.md))
        : null;

    final Widget toolbar = Container(
      decoration: BoxDecoration(
        color: activeFill,
        borderRadius: toolbarRadius,
        border: sample == _Sample.outlined
            ? Border(
                left: BorderSide(color: hairline),
                right: BorderSide(color: hairline),
                bottom: BorderSide(color: hairline),
              )
            : (toolbarRadius == null
                  ? Border(bottom: BorderSide(color: hairline))
                  : null),
        boxShadow:
            sample == _Sample.boldTonal || sample == _Sample.softCard
            ? <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.06),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ]
            : null,
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      // No gap and no hairline between tabs and toolbar: they merge.
      children: <Widget>[tabRow, toolbar],
    );
  }
}

class _FlaredTabChip extends StatefulWidget {
  const _FlaredTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.countTone,
    required this.activeFill,
    required this.topRadius,
    required this.flareRadius,
    this.count,
    this.outline,
    this.topAccent,
  });

  final String label;
  final int? count;
  final AppTabCountTone countTone;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeFill;
  final Color? outline;
  final Color? topAccent;
  final double topRadius;
  final double flareRadius;

  @override
  State<_FlaredTabChip> createState() => _FlaredTabChipState();
}

class _FlaredTabChipState extends State<_FlaredTabChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String fullLabel = widget.label.trim();

    final Color fill = widget.isSelected
        ? widget.activeFill
        : _isHovered
        ? scheme.onSurface.withValues(alpha: 0.06)
        : scheme.onSurface.withValues(alpha: 0.03);
    final Color foreground = widget.isSelected
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.count == null ? fullLabel : '$fullLabel (${widget.count})',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            // Minimal space kept ON TOP only; bottom sits flush on toolbar.
            margin: EdgeInsets.only(top: theme.spacing.xs / 2),
            child: CustomPaint(
              painter: _FlaredTabPainter(
                fill: fill,
                topRadius: widget.topRadius,
                flareRadius: widget.flareRadius,
                outline: widget.isSelected ? widget.outline : null,
                topAccent: widget.isSelected ? widget.topAccent : null,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm + widget.flareRadius,
                  vertical: theme.spacing.xs + 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      fullLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
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

  Color _countToneColor(ThemeData theme, AppTabCountTone tone) {
    final AppStatusColors status = theme.statusColors;
    return switch (tone) {
      AppTabCountTone.info => status.info,
      AppTabCountTone.warning => status.warning,
      AppTabCountTone.danger => status.danger,
    };
  }
}
