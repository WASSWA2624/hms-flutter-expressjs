import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Shared display helpers for the ICU workspace, used by the patient board,
/// bed board, and detail panels. Keeps formatting consistent and avoids
/// duplicating tone/label logic across extracted widgets.

String apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String joinDisplay(Iterable<String?> values) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
}

String icuPatientLocationLabel(
  AppLocalizations l10n,
  IcuPatientSummary item,
) {
  final String location = item.locationLabel.trim();
  return location.isEmpty ? l10n.icuBoardFilterNoBedLabel : location;
}

String dateLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return '';
  }
  return AppFormatters.mediumDate(value, Localizations.localeOf(context));
}

String dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return '';
  }
  return AppFormatters.dateTime(value, Localizations.localeOf(context));
}

AppWorkspaceStatus icuStatus(IcuPatientSummary item) {
  final String value =
      item.icuStatus ?? item.stage ?? item.admissionStatus ?? '';
  return AppWorkspaceStatus(label: apiLabel(value), tone: statusTone(value));
}

AppWorkspaceStatus alertStatus(AppLocalizations l10n, IcuPatientSummary item) {
  final String severity = item.criticalSeverity ?? '';
  return AppWorkspaceStatus(
    label: item.hasCriticalAlert ? apiLabel(severity) : l10n.icuNoAlertLabel,
    tone: item.hasCriticalAlert
        ? severityTone(severity)
        : AppWorkspaceStatusTone.success,
  );
}

AppWorkspaceStatusTone statusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'ACTIVE' ||
    'ADMITTED_IN_BED' ||
    'IN_PROGRESS' => AppWorkspaceStatusTone.info,
    'DISCHARGE_PLANNED' ||
    'TRANSFER_REQUESTED' ||
    'TRANSFER_IN_PROGRESS' ||
    'REQUESTED' ||
    'APPROVED' => AppWorkspaceStatusTone.warning,
    'ENDED' || 'DISCHARGED' || 'COMPLETED' => AppWorkspaceStatusTone.success,
    'CANCELLED' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone severityTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'CRITICAL' || 'HIGH' => AppWorkspaceStatusTone.error,
    'MEDIUM' => AppWorkspaceStatusTone.warning,
    'LOW' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

AppWorkspaceStatusTone vitalTone(IcuVitalSign item) {
  final num? numericValue = num.tryParse(item.value ?? '');
  return switch (item.vitalType) {
    'OXYGEN_SATURATION' when numericValue != null && numericValue < 92 =>
      AppWorkspaceStatusTone.error,
    'HEART_RATE'
        when numericValue != null &&
            (numericValue < 50 || numericValue > 120) =>
      AppWorkspaceStatusTone.warning,
    'RESPIRATORY_RATE'
        when numericValue != null && (numericValue < 10 || numericValue > 28) =>
      AppWorkspaceStatusTone.warning,
    'TEMPERATURE'
        when numericValue != null && (numericValue < 35 || numericValue > 39) =>
      AppWorkspaceStatusTone.warning,
    _ => AppWorkspaceStatusTone.info,
  };
}

AppWorkspaceStatusTone bedStatusTone(String? value) {
  return switch ((value ?? '').toUpperCase()) {
    'AVAILABLE' => AppWorkspaceStatusTone.success,
    'OCCUPIED' => AppWorkspaceStatusTone.info,
    'RESERVED' => AppWorkspaceStatusTone.warning,
    'CLEANING' || 'MAINTENANCE' => AppWorkspaceStatusTone.warning,
    'BLOCKED' || 'OUT_OF_SERVICE' => AppWorkspaceStatusTone.error,
    _ => AppWorkspaceStatusTone.neutral,
  };
}
