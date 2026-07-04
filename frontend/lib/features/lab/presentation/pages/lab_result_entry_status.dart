part of 'lab_result_entry_dialog.dart';

int _activeResultItemCount(LabOrderSummary order) {
  if (order.items.isEmpty) {
    return order.itemCount - order.rejectedItemCount;
  }
  return order.items.where((LabOrderItem item) => !item.isRejected).length;
}

int _enteredResultItemCount(LabOrderSummary order) {
  if (order.items.isEmpty) {
    return order.completedItemCount;
  }
  return order.items
      .where((LabOrderItem item) => !item.isRejected && item.hasResult)
      .length;
}

int _completedResultItemCount(LabOrderSummary order) {
  if (order.items.isEmpty) {
    return order.completedItemCount;
  }
  return order.items
      .where((LabOrderItem item) => !item.isRejected && item.isCompleted)
      .length;
}

bool _isVerifiedOrder(LabOrderSummary order) {
  final int active = _activeResultItemCount(order);
  return active > 0 && _completedResultItemCount(order) >= active;
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
        return '${word.substring(0, 1).toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

AppWorkspaceStatus _statusBadge(BuildContext context, String? value) {
  final String status = (value ?? '').toUpperCase();
  return AppWorkspaceStatus(
    label: _statusLabel(context, value),
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

String _statusLabel(BuildContext context, String? value) {
  final AppLocalizations l10n = context.l10n;
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

AppWorkspaceStatus _entryStatus(BuildContext context, LabOrderSummary order) {
  if (order.hasCriticalResult) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }
  if (order.hasRejectedItem) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusRejected,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  final int active = _activeResultItemCount(order);
  final int entered = _enteredResultItemCount(order);
  if (active == 0) {
    return _statusBadge(context, order.status);
  }
  if (entered == 0) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusOrdered,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.assignment_outlined,
    );
  }
  if (entered < active) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusPartiallyEntered,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.pending_actions_outlined,
    );
  }
  return AppWorkspaceStatus(
    label: context.l10n.labStatusFilled,
    tone: AppWorkspaceStatusTone.success,
    icon: Icons.task_alt_outlined,
  );
}

AppWorkspaceStatus _aggregateOrderStatus(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
) {
  final AppLocalizations l10n = context.l10n;
  if (workflows.any(
    (LabOrderWorkflow workflow) => workflow.order.hasCriticalResult,
  )) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }

  final bool anyRejected = workflows.any(
    (LabOrderWorkflow workflow) => workflow.order.hasRejectedItem,
  );
  final bool allVerified = workflows.every(
    (LabOrderWorkflow workflow) => _isVerifiedOrder(workflow.order),
  );
  final bool anyVerified = workflows.any(
    (LabOrderWorkflow workflow) => _isVerifiedOrder(workflow.order),
  );
  final bool allCancelled = workflows.every(
    (LabOrderWorkflow workflow) =>
        (workflow.order.status ?? '').toUpperCase() == 'CANCELLED',
  );

  if (allCancelled) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCancelled,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (anyRejected && !anyVerified) {
    return AppWorkspaceStatus(
      label: l10n.labStatusRejected,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (anyRejected && anyVerified) {
    return AppWorkspaceStatus(
      label: l10n.labStatusPartiallyRejected,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.block_outlined,
    );
  }
  if (allVerified) {
    return AppWorkspaceStatus(
      label: l10n.labStatusVerified,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }
  if (anyVerified) {
    return AppWorkspaceStatus(
      label: l10n.labStatusPartiallyVerified,
      tone: AppWorkspaceStatusTone.info,
      icon: Icons.verified_outlined,
    );
  }

  return _entryStatus(context, workflows.first.order);
}

List<AppWorkspaceStatusBadge> _aggregateOrderSubBadges(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
) {
  final AppLocalizations l10n = context.l10n;
  final int rejectedCount = workflows.fold<int>(
    0,
    (int total, LabOrderWorkflow workflow) =>
        total + workflow.order.rejectedItemCount,
  );
  if (rejectedCount <= 0) {
    return const <AppWorkspaceStatusBadge>[];
  }

  final AppWorkspaceStatus primary = _aggregateOrderStatus(context, workflows);
  if (primary.label == l10n.labStatusRejected ||
      primary.label == l10n.labStatusPartiallyRejected) {
    return const <AppWorkspaceStatusBadge>[];
  }

  return <AppWorkspaceStatusBadge>[
    AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: l10n.labRejectedItemCount(rejectedCount),
        tone: AppWorkspaceStatusTone.error,
        icon: Icons.block_outlined,
      ),
    ),
  ];
}

AppWorkspaceStatus _orderSummaryStatus(
  BuildContext context,
  LabOrderSummary order,
) {
  final AppLocalizations l10n = context.l10n;
  if (order.hasCriticalResult) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }
  if ((order.status ?? '').toUpperCase() == 'CANCELLED') {
    return AppWorkspaceStatus(
      label: l10n.labStatusCancelled,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }

  final bool verified = _isVerifiedOrder(order);
  final bool rejected = order.hasRejectedItem;
  if (rejected && !verified) {
    return AppWorkspaceStatus(
      label: l10n.labStatusRejected,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    );
  }
  if (rejected && verified) {
    return AppWorkspaceStatus(
      label: l10n.labStatusPartiallyRejected,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.block_outlined,
    );
  }
  if (verified) {
    return AppWorkspaceStatus(
      label: l10n.labStatusVerified,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }

  return _entryStatus(context, order);
}

List<AppWorkspaceStatusBadge> _orderSummarySubBadges(
  BuildContext context,
  LabOrderSummary order,
) {
  final AppLocalizations l10n = context.l10n;
  if (order.rejectedItemCount <= 0) {
    return const <AppWorkspaceStatusBadge>[];
  }

  final AppWorkspaceStatus primary = _orderSummaryStatus(context, order);
  if (primary.label == l10n.labStatusRejected ||
      primary.label == l10n.labStatusPartiallyRejected) {
    return const <AppWorkspaceStatusBadge>[];
  }

  return <AppWorkspaceStatusBadge>[
    AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: l10n.labRejectedItemCount(order.rejectedItemCount),
        tone: AppWorkspaceStatusTone.error,
        icon: Icons.block_outlined,
      ),
    ),
  ];
}

List<LabWorkflowTimelineItem> _deduplicatedTimeline(
  List<LabWorkflowTimelineItem> timeline,
) {
  final Map<String, LabWorkflowTimelineItem> unique =
      <String, LabWorkflowTimelineItem>{};
  for (final LabWorkflowTimelineItem step in timeline) {
    final String label = (step.label ?? step.type ?? step.id).trim();
    final String key = '${(step.type ?? '').trim().toLowerCase()}|$label'
        .toLowerCase();
    final LabWorkflowTimelineItem? existing = unique[key];
    if (existing == null) {
      unique[key] = step;
      continue;
    }
    final DateTime? existingAt = existing.occurredAt;
    final DateTime? nextAt = step.occurredAt;
    if (nextAt != null && (existingAt == null || nextAt.isAfter(existingAt))) {
      unique[key] = step;
    }
  }
  return unique.values.toList(growable: false);
}
