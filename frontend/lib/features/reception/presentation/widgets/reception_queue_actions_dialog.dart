import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/pages/opd_workspace_page.dart'
    show QueueActionsDialog;
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';

Future<bool?> showReceptionQueueActionsDialog({
  required BuildContext context,
  required OpdQueueEntry entry,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReceptionQueueActionsDialog(entry: entry),
  );
}

class ReceptionQueueActionsDialog extends ConsumerStatefulWidget {
  const ReceptionQueueActionsDialog({required this.entry, super.key});

  final OpdQueueEntry entry;

  @override
  ConsumerState<ReceptionQueueActionsDialog> createState() =>
      _ReceptionQueueActionsDialogState();
}

class _ReceptionQueueActionsDialogState
    extends ConsumerState<ReceptionQueueActionsDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final bool terminal = _isTerminalStatus(widget.entry.status);

    return AppDialog(
      title: Text(widget.entry.displayTitle),
      icon: const Icon(Icons.queue_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 860,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppTriageSummaryPanel(
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.opdStatusColumnLabel,
                value: opdStageDisplayLabel(l10n, widget.entry.status ?? ''),
              ),
              AppInfoTileData(
                label: l10n.opdVisitTypeColumnLabel,
                value: widget.entry.appointmentId == null
                    ? l10n.opdQueueSummaryLabel
                    : l10n.opdAppointmentPatientModeLabel,
              ),
              AppInfoTileData(
                label: l10n.opdProviderColumnLabel,
                value:
                    widget.entry.providerDisplayName ??
                    l10n.profileUnknownValue,
              ),
              AppInfoTileData(
                label: l10n.opdTimeColumnLabel,
                value: widget.entry.queuedAt == null
                    ? l10n.profileUnknownValue
                    : AppFormatters.dateTime(widget.entry.queuedAt!, locale),
              ),
            ],
            emptyValue: l10n.profileUnknownValue,
          ),
          AppActionSection(
            title: l10n.opdActionsColumnLabel,
            minItemWidth: 170,
            maxColumns: 4,
            permissionActions: _actions(context, terminal),
          ),
        ],
      ),
    );
  }

  List<AppPermissionActionItem> _actions(BuildContext context, bool terminal) {
    final AppLocalizations l10n = context.l10n;
    final String inactiveReason = l10n.opdInactiveEncounterActionReason;

    AppPermissionActionItem action({
      required AccessRequirement requirement,
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
      AppButtonVariant variant = AppButtonVariant.secondary,
      bool enabled = true,
      String? tooltip,
    }) {
      final bool isEnabled = enabled && !_isSaving && onPressed != null;
      return AppPermissionActionItem(
        requirement: requirement,
        label: label,
        icon: icon,
        fullWidth: true,
        variant: variant,
        enabled: isEnabled,
        tooltip: isEnabled ? null : tooltip ?? inactiveReason,
        onPressed: isEnabled ? onPressed : null,
      );
    }

    return <AppPermissionActionItem>[
      action(
        requirement: receptionFrontDeskWriteRequirement,
        label: l10n.opdStartConsultationAction,
        icon: Icons.play_arrow_outlined,
        variant: AppButtonVariant.primary,
        enabled: !terminal,
        onPressed: () => _run(
          () => ref
              .read(opdWorkspaceControllerProvider.notifier)
              .startOpdFromQueue(widget.entry),
        ),
      ),
      action(
        requirement: receptionFrontDeskWriteRequirement,
        label: l10n.opdPrioritizeAction,
        icon: Icons.priority_high_outlined,
        enabled: !terminal,
        onPressed: () => _run(
          () => ref
              .read(opdWorkspaceControllerProvider.notifier)
              .prioritizeQueueEntry(widget.entry, null),
        ),
      ),
      action(
        requirement: receptionFrontDeskWriteRequirement,
        label: l10n.opdMoveQueueAction,
        icon: Icons.sync_alt_outlined,
        enabled: !terminal,
        onPressed: _openMoveQueue,
      ),
    ];
  }

  Future<void> _openMoveQueue() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QueueActionsDialog(entry: widget.entry),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(Future<AppFailure?> Function() action) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await action();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  bool _isTerminalStatus(String? status) {
    return switch ((status ?? '').toUpperCase()) {
      'COMPLETED' ||
      'CANCELLED' ||
      'NO_SHOW' ||
      'DISCHARGED' ||
      'ADMITTED' ||
      'CLOSED' => true,
      _ => false,
    };
  }
}
