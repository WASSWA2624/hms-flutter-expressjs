import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// At-a-glance Status column: phase + result flag (e.g. Partially Ready - Abnormal).
AppWorkspaceStatus labWorklistGlanceStatus(
  BuildContext context,
  LabOrderSummary order,
) {
  final AppLocalizations l10n = context.l10n;
  final String raw = (order.status ?? '').toUpperCase();
  final bool hasCriticalResult = order.items.any((LabOrderItem item) {
    final String status = (item.effectiveResultStatus ?? '').toUpperCase();
    return status == 'CRITICAL' ||
        status == 'CRITICAL_LOW' ||
        status == 'CRITICAL_HIGH';
  });
  final bool hasAbnormalResult = order.items.any((LabOrderItem item) {
    return (item.effectiveResultStatus ?? '').toUpperCase() == 'ABNORMAL';
  });
  final int activeItems = _worklistActiveResultItemCount(order);
  final int enteredItems = _worklistEnteredResultItemCount(order);
  final bool isPartiallyReady =
      activeItems > 0 && enteredItems > 0 && enteredItems < activeItems;

  // Patient groups roll critical/abnormal into status CRITICAL.
  if (raw == 'CRITICAL' || hasCriticalResult) {
    return AppWorkspaceStatus(
      label: isPartiallyReady
          ? l10n.labWorklistStatusPartiallyReadyCritical
          : l10n.labWorklistStatusReadyCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }
  if (hasAbnormalResult) {
    return AppWorkspaceStatus(
      label: isPartiallyReady
          ? l10n.labWorklistStatusPartiallyReadyAbnormal
          : l10n.labWorklistStatusReadyAbnormal,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.warning_amber_outlined,
    );
  }
  if (raw == 'CANCELLED') {
    return AppWorkspaceStatus(
      label: l10n.labWorklistStatusCancelled,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (raw == 'REJECTED' ||
      raw == 'REJECTED_SAMPLE' ||
      order.hasRejectedItem) {
    return AppWorkspaceStatus(
      label: l10n.labWorklistStatusRejected,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (raw == 'COMPLETED' ||
      (activeItems > 0 && order.completedItemCount >= activeItems)) {
    return AppWorkspaceStatus(
      label: l10n.labWorklistStatusCompleted,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.task_alt_outlined,
    );
  }
  if (activeItems > 0 && enteredItems >= activeItems) {
    return AppWorkspaceStatus(
      label: l10n.labWorklistStatusReadyFilled,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.fact_check_outlined,
    );
  }
  if (enteredItems > 0 ||
      order.inProcessItemCount > 0 ||
      raw == 'IN_PROCESS') {
    if (raw == 'IN_PROCESS' && enteredItems == 0) {
      return AppWorkspaceStatus(
        label: l10n.labWorklistStatusPendingInProcess,
        tone: AppWorkspaceStatusTone.info,
        icon: Icons.hourglass_top_outlined,
      );
    }
    return AppWorkspaceStatus(
      label: l10n.labWorklistStatusPendingPartial,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.pending_actions_outlined,
    );
  }
  if (raw == 'COLLECTED') {
    return AppWorkspaceStatus(
      label: l10n.labWorklistStatusPendingCollected,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.science_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: l10n.labWorklistStatusPendingOrdered,
    tone: AppWorkspaceStatusTone.warning,
    icon: Icons.assignment_outlined,
  );
}

int _worklistActiveResultItemCount(LabOrderSummary order) {
  if (order.items.isNotEmpty) {
    return order.items.where((LabOrderItem item) => !item.isRejected).length;
  }
  final int active = order.itemCount - order.rejectedItemCount;
  return active < 0 ? 0 : active;
}

int _worklistEnteredResultItemCount(LabOrderSummary order) {
  if (order.items.isNotEmpty) {
    return order.items
        .where((LabOrderItem item) => !item.isRejected && item.hasResult)
        .length;
  }
  final int statusCount = order.completedItemCount + order.inProcessItemCount;
  return statusCount;
}

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
