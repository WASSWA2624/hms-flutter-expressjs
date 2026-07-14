import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_report_section.dart';

/// Authoritative section availability for print/export pickers.
@immutable
final class ReportSectionAvailability {
  const ReportSectionAvailability({
    required this.id,
    required this.count,
    this.authorized = true,
    this.alwaysAvailable = false,
    this.disabledReason,
  });

  final Object id;
  final int count;
  final bool authorized;
  final bool alwaysAvailable;
  final String? disabledReason;

  bool get hasData => count > 0 || alwaysAvailable;

  bool get enabled => authorized && hasData;
}

/// Computes default selection: empty/unauthorized sections are unselected.
Set<Object> resolveDefaultReportSectionSelection(
  Iterable<ReportSectionAvailability> sections,
) {
  return <Object>{
    for (final ReportSectionAvailability section in sections)
      if (section.enabled) section.id,
  };
}

/// Applies empty/unauthorized disable rules onto presentation tiles.
List<AppReportSectionData> buildReportSectionTiles({
  required Iterable<ReportSectionAvailability> sections,
  required String Function(Object id) titleFor,
  required IconData Function(Object id) iconFor,
  String? emptyDisabledReason,
  String? unauthorizedDisabledReason,
}) {
  return sections
      .map((ReportSectionAvailability section) {
        final String? reason = !section.authorized
            ? unauthorizedDisabledReason
            : (!section.hasData ? emptyDisabledReason : section.disabledReason);
        return AppReportSectionData(
          id: section.id,
          title: titleFor(section.id),
          icon: iconFor(section.id),
          count: section.count,
          enabled: section.enabled,
          disabledReason: reason,
        );
      })
      .toList(growable: false);
}

/// Narrows selected IDs to currently enabled sections.
Set<Object> sanitizeReportSectionSelection({
  required Set<Object> selectedIds,
  required Iterable<ReportSectionAvailability> sections,
  bool requireAtLeastOne = true,
}) {
  final Set<Object> enabledIds = <Object>{
    for (final ReportSectionAvailability section in sections)
      if (section.enabled) section.id,
  };
  final Set<Object> next = selectedIds.where(enabledIds.contains).toSet();
  if (requireAtLeastOne && next.isEmpty && enabledIds.isNotEmpty) {
    next.add(enabledIds.first);
  }
  return next;
}
