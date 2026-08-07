import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';

/// Load lifecycle for an in-place module report dialog body.
enum ModuleReportingLoadState { loading, ready, empty, error, unavailable }

/// Snapshot of rows (and optional metadata) for a module report dialog.
@immutable
final class ModuleReportingReportSnapshot {
  const ModuleReportingReportSnapshot({
    required this.state,
    this.columns = const <String>[],
    this.rows = const <Map<String, Object?>>[],
    this.summary,
    this.breakdown,
    this.failureMessage,
    this.title,
    this.subtitle,
  });

  const ModuleReportingReportSnapshot.loading({
    this.title,
    this.subtitle,
  }) : state = ModuleReportingLoadState.loading,
       columns = const <String>[],
       rows = const <Map<String, Object?>>[],
       summary = null,
       breakdown = null,
       failureMessage = null;

  const ModuleReportingReportSnapshot.unavailable({
    this.title,
    this.subtitle,
    this.failureMessage,
  }) : state = ModuleReportingLoadState.unavailable,
       columns = const <String>[],
       rows = const <Map<String, Object?>>[],
       summary = null,
       breakdown = null;

  const ModuleReportingReportSnapshot.error({
    required this.failureMessage,
    this.title,
    this.subtitle,
  }) : state = ModuleReportingLoadState.error,
       columns = const <String>[],
       rows = const <Map<String, Object?>>[],
       summary = null,
       breakdown = null;

  factory ModuleReportingReportSnapshot.ready({
    required List<String> columns,
    required List<Map<String, Object?>> rows,
    Map<String, Object?>? summary,
    Map<String, Object?>? breakdown,
    String? title,
    String? subtitle,
  }) {
    final List<Map<String, Object?>> normalizedRows =
        List<Map<String, Object?>>.unmodifiable(rows);
    if (normalizedRows.isEmpty) {
      return ModuleReportingReportSnapshot(
        state: ModuleReportingLoadState.empty,
        columns: List<String>.unmodifiable(columns),
        rows: normalizedRows,
        summary: summary,
        breakdown: breakdown,
        title: title,
        subtitle: subtitle,
      );
    }
    return ModuleReportingReportSnapshot(
      state: ModuleReportingLoadState.ready,
      columns: List<String>.unmodifiable(columns),
      rows: normalizedRows,
      summary: summary,
      breakdown: breakdown,
      title: title,
      subtitle: subtitle,
    );
  }

  final ModuleReportingLoadState state;
  final List<String> columns;
  final List<Map<String, Object?>> rows;
  final Map<String, Object?>? summary;
  final Map<String, Object?>? breakdown;
  final String? failureMessage;
  final String? title;
  final String? subtitle;

  bool get hasRows => rows.isNotEmpty;

  /// Flat export-friendly rows when [hasRows] is true.
  List<Map<String, Object?>> get exportRows => rows;
}

/// Supplies live (or honest-empty) data for [ModuleReportingReportDialog].
abstract class ModuleReportingDataProvider {
  Future<ModuleReportingReportSnapshot> load({
    required ModuleReportingReport report,
    required DateTime from,
    required DateTime to,
    required ModuleReportingPeriodPreset preset,
  });
}
