import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_font_family.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

typedef DashboardTrendPointLabelBuilder =
    String Function(DashboardTrendPointData point, {bool compact});

class DashboardTrendChartPainter extends CustomPainter {
  const DashboardTrendChartPainter({
    required this.points,
    required this.barColor,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.textStyle,
    required this.labelBuilder,
  });

  final List<DashboardTrendPointData> points;
  final Color barColor;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final TextStyle? textStyle;
  final DashboardTrendPointLabelBuilder labelBuilder;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) {
      return;
    }

    final double chartHeight = math.max(0, size.height - 26);
    final double maxValue = math.max(
      1,
      points
          .map((DashboardTrendPointData point) => point.value.toDouble())
          .reduce(math.max),
    );
    final Paint gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final Paint barPaint = Paint()..color = barColor;
    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint dotPaint = Paint()..color = lineColor;
    final double slotWidth = size.width / points.length;
    final double barWidth = math.max(6, math.min(22, slotWidth * 0.42));
    final Path path = Path();

    for (int i = 0; i <= 3; i += 1) {
      final double y = chartHeight * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int index = 0; index < points.length; index += 1) {
      final DashboardTrendPointData point = points[index];
      final double centerX = slotWidth * index + (slotWidth / 2);
      final double normalized = point.value.toDouble() / maxValue;
      final double y = chartHeight - (chartHeight * normalized);
      final Rect barRect = Rect.fromLTWH(
        centerX - (barWidth / 2),
        y,
        barWidth,
        chartHeight - y,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(8)),
        barPaint,
      );

      if (index == 0) {
        path.moveTo(centerX, y);
      } else {
        path.lineTo(centerX, y);
      }
      canvas.drawCircle(Offset(centerX, y), 3.5, dotPaint);

      if (points.length <= 7) {
        final TextPainter painter = TextPainter(
          text: TextSpan(
            text: labelBuilder(point, compact: true),
            style:
                textStyle?.copyWith(color: labelColor) ??
                AppFontFamily.style(color: labelColor, fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: slotWidth);
        painter.paint(
          canvas,
          Offset(centerX - (painter.width / 2), chartHeight + 8),
        );
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant DashboardTrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.barColor != barColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class DashboardDonutChartPainter extends CustomPainter {
  const DashboardDonutChartPainter({
    required this.segments,
    required this.total,
    required this.fallbackColor,
    required this.trackColor,
  });

  final List<DashboardDistributionSegmentData> segments;
  final num total;
  final Color fallbackColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius - 10);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    paint.color = trackColor;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, paint);

    if (total <= 0 || segments.isEmpty) {
      return;
    }

    double start = -math.pi / 2;
    for (int index = 0; index < segments.length; index += 1) {
      final DashboardDistributionSegmentData segment = segments[index];
      final double sweep = (segment.value / total) * math.pi * 2;
      paint.color =
          _segmentColorFromHex(segment.colorHex) ??
          _fallbackSegmentColor(fallbackColor, index);
      canvas.drawArc(rect, start, math.max(0.02, sweep), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DashboardDonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.total != total ||
        oldDelegate.fallbackColor != fallbackColor ||
        oldDelegate.trackColor != trackColor;
  }
}

Color? _segmentColorFromHex(String? value) {
  final String normalized = (value ?? '').trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) {
    return null;
  }
  final int? parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
}

Color _fallbackSegmentColor(Color seed, int index) {
  final HSLColor hsl = HSLColor.fromColor(seed);
  final double hue = (hsl.hue + (index * 42)) % 360;
  return hsl
      .withHue(hue)
      .withSaturation(math.min(0.86, hsl.saturation + 0.18))
      .toColor();
}
