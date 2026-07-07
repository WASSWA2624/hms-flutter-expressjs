import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

AppWorkspaceStatus labStatusBadge(BuildContext context, String? value) {
  final String status = (value ?? '').toUpperCase();
  return AppWorkspaceStatus(
    label: labStatusLabel(context, value),
    tone: switch (status) {
      'COMPLETED' ||
      'NORMAL' ||
      'RECEIVED' ||
      'VERIFIED' => AppWorkspaceStatusTone.success,
      'CRITICAL' || 'CANCELLED' || 'REJECTED' => AppWorkspaceStatusTone.error,
      'ABNORMAL' ||
      'ORDERED' ||
      'COLLECTED' ||
      'PENDING' => AppWorkspaceStatusTone.warning,
      'IN_PROCESS' => AppWorkspaceStatusTone.info,
      _ => AppWorkspaceStatusTone.neutral,
    },
  );
}

String labStatusLabel(BuildContext context, String? value) {
  final l10n = context.l10n;
  return switch ((value ?? '').toUpperCase()) {
    'ORDERED' => l10n.labStatusOrdered,
    'COLLECTED' => l10n.labStatusCollected,
    'IN_PROCESS' => l10n.labStatusInProcess,
    'COMPLETED' => l10n.labStatusCompleted,
    'CANCELLED' => l10n.labStatusCancelled,
    'PENDING' => l10n.labStatusPending,
    'NORMAL' => l10n.labStatusNormal,
    'ABNORMAL' => l10n.labStatusAbnormal,
    'CRITICAL' => l10n.labStatusCritical,
    'LOW' => l10n.labStatusLow,
    'HIGH' => l10n.labStatusHigh,
    'VERIFIED' => l10n.labStatusVerified,
    'REJECTED' => l10n.labStatusRejected,
    'RECEIVED' => l10n.labStatusReceived,
    final String status when status.trim().isNotEmpty => _apiLabel(status),
    _ => l10n.profileUnknownValue,
  };
}

String _apiLabel(String value) {
  final String normalized = value.trim().replaceAll('_', ' ').toLowerCase();
  if (normalized.isEmpty) {
    return value;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map((String word) {
        if (word.isEmpty) {
          return word;
        }
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
