import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';

/// Shared four-section dashboard shell used by every role.
///
/// Order: summary badges → quick actions → critical shortcuts → charts.
class HomeDashboardScaffold extends StatelessWidget {
  const HomeDashboardScaffold({
    required this.profile,
    required this.spacing,
    required this.summaryBadges,
    required this.quickActions,
    required this.criticalShortcuts,
    required this.charts,
    super.key,
  });

  final HomeDashboardProfile profile;
  final AppSpacingTokens spacing;
  final Widget summaryBadges;
  final Widget quickActions;
  final Widget criticalShortcuts;
  final Widget charts;

  @override
  Widget build(BuildContext context) {
    final List<Widget> sections = <Widget>[];

    void addSection(Widget section) {
      if (_isShrink(section)) {
        return;
      }
      if (sections.isNotEmpty) {
        sections.add(SizedBox(height: spacing.md));
      }
      sections.add(section);
    }

    if (profile.showMetricsSection) {
      addSection(summaryBadges);
    }
    if (!profile.suppressHomeQuickActions) {
      addSection(quickActions);
    }
    addSection(criticalShortcuts);
    if (profile.showCharts) {
      addSection(charts);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  bool _isShrink(Widget widget) {
    return widget is SizedBox &&
        widget.width == 0.0 &&
        widget.height == 0.0 &&
        widget.child == null;
  }
}
