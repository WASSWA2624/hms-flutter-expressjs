part of 'lab_result_entry_dialog.dart';

int _activeResultItemCount(LabOrderSummary order) {
  if (order.items.isEmpty) {
    return order.itemCount - order.rejectedItemCount;
  }
  return order.items.where((item) => !item.isRejected).length;
}

int _enteredResultItemCount(LabOrderSummary order) {
  if (order.items.isEmpty) {
    return order.completedItemCount;
  }
  return order.items.where((item) => !item.isRejected && item.hasResult).length;
}

int _completedResultItemCount(LabOrderSummary order) {
  if (order.items.isEmpty) {
    return order.completedItemCount;
  }
  return order.items
      .where((item) => !item.isRejected && item.isCompleted)
      .length;
}

bool _isVerifiedOrder(LabOrderSummary order) {
  final active = _activeResultItemCount(order);
  return active > 0 && _completedResultItemCount(order) >= active;
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
  final active = _activeResultItemCount(order);
  final entered = _enteredResultItemCount(order);
  if (active == 0) {
    return labStatusBadge(context, order.status);
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
  final l10n = context.l10n;
  if (workflows.any((workflow) => workflow.order.hasCriticalResult)) {
    return AppWorkspaceStatus(
      label: l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }

  final anyRejected = workflows.any(
    (workflow) => workflow.order.hasRejectedItem,
  );
  final allVerified = workflows.every(
    (workflow) => _isVerifiedOrder(workflow.order),
  );
  final anyVerified = workflows.any(
    (workflow) => _isVerifiedOrder(workflow.order),
  );
  final allCancelled = workflows.every(
    (workflow) => (workflow.order.status ?? '').toUpperCase() == 'CANCELLED',
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

List<AppWorkspaceStatus> _aggregateOrderSubStatuses(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
) {
  final l10n = context.l10n;
  final rejectedCount = workflows.fold<int>(
    0,
    (total, workflow) => total + workflow.order.rejectedItemCount,
  );
  if (rejectedCount <= 0) {
    return const <AppWorkspaceStatus>[];
  }

  final primary = _aggregateOrderStatus(context, workflows);
  if (primary.label == l10n.labStatusRejected ||
      primary.label == l10n.labStatusPartiallyRejected) {
    return const <AppWorkspaceStatus>[];
  }

  return <AppWorkspaceStatus>[
    AppWorkspaceStatus(
      label: l10n.labRejectedItemCount(rejectedCount),
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.block_outlined,
    ),
  ];
}
