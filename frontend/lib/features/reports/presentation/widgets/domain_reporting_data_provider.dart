import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

/// Pass-through dataset preview provider for non-pharmacy domain catalogs.
final class DomainReportingDataProvider implements ModuleReportingDataProvider {
  const DomainReportingDataProvider(this._repository);

  final ReportsRepository _repository;

  @override
  Future<ModuleReportingReportSnapshot> load({
    required ModuleReportingReport report,
    required DateTime from,
    required DateTime to,
    required ModuleReportingPeriodPreset preset,
  }) async {
    if (!report.hasBackend) {
      return ModuleReportingReportSnapshot.unavailable(title: report.label);
    }

    final Result<ReportDatasetPreview> result = await _repository.previewDataset(
      datasetKey: report.datasetKey!,
      from: from,
      to: to,
      datePreset: _datePresetFor(preset),
    );

    return result.when(
      success: (ReportDatasetPreview preview) {
        return ModuleReportingReportSnapshot.ready(
          columns: List<String>.from(preview.columns),
          rows: List<Map<String, Object?>>.from(preview.rows),
          summary: preview.summary,
          breakdown: preview.breakdown,
          title: report.label,
          subtitle: previewSubtitleOrNull(preview.subtitle),
        );
      },
      failure: (AppFailure failure) {
        return ModuleReportingReportSnapshot.error(
          failureMessage: failure.detailMessage?.trim().isNotEmpty == true
              ? failure.detailMessage
              : failure.messageKey,
          title: report.label,
        );
      },
    );
  }
}

String? previewSubtitleOrNull(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String? _datePresetFor(ModuleReportingPeriodPreset preset) {
  return switch (preset) {
    ModuleReportingPeriodPreset.today => 'today',
    ModuleReportingPeriodPreset.lastWeek => 'last_7_days',
    ModuleReportingPeriodPreset.lastMonth => 'last_30_days',
    ModuleReportingPeriodPreset.custom => 'custom',
    ModuleReportingPeriodPreset.last3Months ||
    ModuleReportingPeriodPreset.last6Months ||
    ModuleReportingPeriodPreset.last12Months ||
    ModuleReportingPeriodPreset.last24Months =>
      'custom',
  };
}
