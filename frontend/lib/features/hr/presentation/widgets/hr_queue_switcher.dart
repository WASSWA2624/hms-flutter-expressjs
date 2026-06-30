import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

/// Work-queue tabs for the HR work-queue dialog — labeled on md+, icon-only on compact.
class HrQueueSwitcher extends ConsumerWidget {
  const HrQueueSwitcher({
    required this.selectedQueue,
    this.enabled = true,
    super.key,
  });

  final HrQueue selectedQueue;
  final bool enabled;

  static const List<HrQueue> workspaceQueues = <HrQueue>[
    HrQueue.leaveRequests,
    HrQueue.swapRequests,
    HrQueue.rosterDrafts,
    HrQueue.unassignedShifts,
    HrQueue.payrollDrafts,
  ];

  static List<HrQueue> visibleQueues(HrQueue selected) {
    if (selected == HrQueue.overdueShifts &&
        !workspaceQueues.contains(HrQueue.overdueShifts)) {
      return <HrQueue>[...workspaceQueues, HrQueue.overdueShifts];
    }
    return workspaceQueues;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool showLabels =
        AppBreakpoints.of(context).index >= AppBreakpoint.md.index;
    final HrWorkspaceController controller = ref.read(
      hrWorkspaceControllerProvider.notifier,
    );

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final HrQueue queue in visibleQueues(selectedQueue))
          _QueueTab(
            queue: queue,
            label: hrQueueLabel(l10n, queue),
            icon: hrQueueIcon(queue),
            selected: selectedQueue == queue,
            showLabel: showLabels,
            enabled: enabled && selectedQueue != queue,
            onPressed: () => controller.applyQueue(queue),
          ),
      ],
    );
  }
}

class _QueueTab extends StatelessWidget {
  const _QueueTab({
    required this.queue,
    required this.label,
    required this.icon,
    required this.selected,
    required this.showLabel,
    required this.enabled,
    required this.onPressed,
  });

  final HrQueue queue;
  final String label;
  final IconData icon;
  final bool selected;
  final bool showLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final Widget button = showLabel
        ? AppButton.secondary(
            label: label,
            leadingIcon: icon,
            semanticLabel: label,
            tooltip: label,
            enabled: enabled,
            onPressed: enabled ? onPressed : null,
          )
        : AppButton(
            iconOnly: true,
            leadingIcon: icon,
            label: label,
            semanticLabel: label,
            tooltip: label,
            enabled: enabled,
            onPressed: enabled ? onPressed : null,
          );

    if (!selected) {
      return button;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(theme.spacing.xs),
      ),
      child: button,
    );
  }
}

String hrQueueLabel(AppLocalizations l10n, HrQueue queue) {
  return switch (queue) {
    HrQueue.leaveRequests => l10n.hrQueueLeaveRequests,
    HrQueue.swapRequests => l10n.hrQueueSwapRequests,
    HrQueue.rosterDrafts => l10n.hrQueueRosterDrafts,
    HrQueue.unassignedShifts => l10n.hrQueueUnassignedShifts,
    HrQueue.payrollDrafts => l10n.hrQueuePayrollDrafts,
    HrQueue.overdueShifts => l10n.hrQueueOverdueShifts,
  };
}

IconData hrQueueIcon(HrQueue queue) {
  return switch (queue) {
    HrQueue.leaveRequests => Icons.event_busy_outlined,
    HrQueue.swapRequests => Icons.swap_horiz_outlined,
    HrQueue.rosterDrafts => Icons.calendar_month_outlined,
    HrQueue.unassignedShifts => Icons.pending_actions_outlined,
    HrQueue.payrollDrafts => Icons.payments_outlined,
    HrQueue.overdueShifts => Icons.warning_amber_outlined,
  };
}
