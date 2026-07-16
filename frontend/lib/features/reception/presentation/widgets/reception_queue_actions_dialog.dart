import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
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
  bool _isStartingConsultation = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final bool terminal = isOpdQueueTerminalStatus(widget.entry.status);

    return AppDialog(
      title: Text(l10n.opdQueueActionsTitle),
      icon: const Icon(Icons.queue_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      maxWidth: 680,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          if (_isSaving) const LinearProgressIndicator(),
          AppTriageSummaryPanel(
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.opdPatientColumnLabel,
                value: widget.entry.displayTitle,
              ),
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
        ],
      ),
      actions: <Widget>[
        if (!terminal)
          AppAccessActionGate(
            requirement: receptionFrontDeskWriteRequirement,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                label: l10n.opdPrioritizeAction,
                leadingIcon: Icons.priority_high_outlined,
                enabled: isAllowed && !_isSaving,
                onPressed: !isAllowed || _isSaving
                    ? null
                    : () => _run(
                        () => ref
                            .read(opdWorkspaceControllerProvider.notifier)
                            .prioritizeQueueEntry(widget.entry, null),
                      ),
              );
            },
          ),
        if (!terminal)
          AppAccessActionGate(
            requirement: receptionFrontDeskWriteRequirement,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.secondary(
                label: l10n.opdMoveQueueAction,
                leadingIcon: Icons.sync_alt_outlined,
                enabled: isAllowed && !_isSaving,
                onPressed: !isAllowed || _isSaving ? null : _openMoveQueue,
              );
            },
          ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_isSaving,
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(false),
        ),
        if (!terminal)
          AppAccessActionGate(
            requirement: receptionFrontDeskWriteRequirement,
            builder: (BuildContext context, bool isAllowed) {
              return AppButton.primary(
                label: l10n.opdStartConsultationAction,
                leadingIcon: Icons.play_arrow_outlined,
                isLoading: _isStartingConsultation,
                enabled: isAllowed && !_isSaving,
                onPressed: !isAllowed || _isSaving
                    ? null
                    : () => _run(
                        () => ref
                            .read(opdWorkspaceControllerProvider.notifier)
                            .startOpdFromQueue(widget.entry),
                        startingConsultation: true,
                      ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _openMoveQueue() async {
    if (_isSaving) {
      return;
    }
    final bool? changed = await showQueueActionsDialog(
      context: context,
      entry: widget.entry,
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(
    Future<AppFailure?> Function() action, {
    bool startingConsultation = false,
  }) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _isStartingConsultation = startingConsultation;
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
      _isStartingConsultation = false;
    });
  }
}
