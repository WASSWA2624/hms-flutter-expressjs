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
      'NEGATIVE' ||
      'NON_REACTIVE' ||
      'NOT_DETECTED' ||
      'RECEIVED' ||
      'VERIFIED' => AppWorkspaceStatusTone.success,
      'CRITICAL' ||
      'CRITICAL_LOW' ||
      'CRITICAL_HIGH' ||
      'CANCELLED' ||
      'REJECTED' => AppWorkspaceStatusTone.error,
      'ABNORMAL' ||
      'HIGH' ||
      'LOW' ||
      'POSITIVE' ||
      'REACTIVE' ||
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
    'CRITICAL_LOW' => l10n.labStatusCriticalLow,
    'CRITICAL_HIGH' => l10n.labStatusCriticalHigh,
    'LOW' => l10n.labStatusLow,
    'HIGH' => l10n.labStatusHigh,
    'POSITIVE' => l10n.labStatusPositive,
    'NEGATIVE' => l10n.labStatusNegative,
    'REACTIVE' => l10n.labStatusReactive,
    'NON_REACTIVE' => l10n.labStatusNonReactive,
    'NOT_DETECTED' => l10n.labStatusNotDetected,
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
