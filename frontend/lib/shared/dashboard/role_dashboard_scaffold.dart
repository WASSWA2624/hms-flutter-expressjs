import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';

/// Shared four-section dashboard shell used by every role.
///
/// Order: summary badges → quick actions → priority worklist → charts.
class RoleDashboardScaffold extends StatelessWidget {
  const RoleDashboardScaffold({
    required this.layout,
    required this.spacing,
    required this.summaryBadges,
    required this.quickActions,
    required this.priorityPanel,
    required this.charts,
    this.leadingPanel,
    super.key,
  });

  final RoleDashboardLayout layout;
  final AppSpacingTokens spacing;
  final Widget summaryBadges;
  final Widget quickActions;
  final Widget priorityPanel;
  final Widget charts;
  final Widget? leadingPanel;

  @override
  Widget build(BuildContext context) {
    final List<Widget> sections = <Widget>[];

    void addSection(Widget section) {
      if (_isShrink(section)) {
        return;
      }
      if (sections.isNotEmpty) {
        sections.add(SizedBox(height: spacing.xl));
      }
      sections.add(section);
    }

    if (layout.alertsBeforeMetrics &&
        leadingPanel != null &&
        !_isShrink(leadingPanel!)) {
      addSection(leadingPanel!);
    }

    if (layout.showMetrics && !_isShrink(summaryBadges)) {
      addSection(summaryBadges);
    }
    if (layout.showQuickActions) {
      addSection(quickActions);
    }
    if (layout.showPriority) {
      addSection(priorityPanel);
    }
    if (layout.showCharts) {
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
