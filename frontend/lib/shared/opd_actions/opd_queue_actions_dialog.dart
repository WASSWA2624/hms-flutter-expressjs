import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Shared queue move / prioritize / start actions for OPD and Reception.
Future<bool?> showQueueActionsDialog({
  required BuildContext context,
  required OpdQueueEntry entry,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => QueueActionsDialog(entry: entry),
  );
}

bool isOpdQueueTerminalStatus(String? status) {
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

enum _QueueFooterAction { prioritize, start, move }

class QueueActionsDialog extends ConsumerStatefulWidget {
  const QueueActionsDialog({required this.entry, super.key});

  final OpdQueueEntry entry;

  @override
  ConsumerState<QueueActionsDialog> createState() => _QueueActionsDialogState();
}

class _QueueActionsDialogState extends ConsumerState<QueueActionsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  String? _status;
  String? _providerId;
  bool _isLoadingProviders = false;
  _QueueFooterAction? _activeAction;
  AppFailure? _failure;

  bool get _isSaving => _activeAction != null;
  bool get _isBusy => _isSaving || _isLoadingProviders;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _status = widget.entry.status;
    _providerId = widget.entry.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final bool terminal = isOpdQueueTerminalStatus(widget.entry.status);

    return AppDialog(
      title: Text(l10n.opdQueueActionsTitle),
      icon: const Icon(Icons.queue_outlined),
      scrollable: true,
      closeEnabled: !_isBusy,
      maxWidth: 680,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            if (_isLoadingProviders) const LinearProgressIndicator(),
            AppTriageSummaryPanel(
              items: <AppInfoTileData>[
                AppInfoTileData(
                  label: l10n.opdQueueStatusLabel,
                  value: opdStageDisplayLabel(
                    l10n,
                    _status ?? widget.entry.status,
                  ),
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
            AppSelectField<String>(
              value: _status,
              labelText: l10n.opdFieldRequiredLabel(l10n.opdQueueStatusLabel),
              enabled: !terminal && !_isBusy,
              onChanged: (String? value) => setState(() => _status = value),
              options: <AppSelectOption<String>>[
                for (final String value in _queueStatuses)
                  AppSelectOption<String>(
                    value: value,
                    label: AppDisplay.apiLabel(value),
                  ),
              ],
            ),
            AppSelectField<String>.searchable(
              value: _providerId,
              options: opdProviderSelectOptions(
                providers: _providerOptions,
                schedules: const <OpdProviderSchedule>[],
              ),
              labelText: l10n.opdFieldOptionalLabel(l10n.opdSearchProviderLabel),
              helperText: _providerOptions.isEmpty && !_isLoadingProviders
                  ? l10n.opdNoProvidersHelper
                  : l10n.opdSearchProviderHelper,
              semanticLabel: l10n.opdFieldOptionalLabel(
                l10n.opdSearchProviderLabel,
              ),
              enabled: !_isBusy,
              isLoading: _isLoadingProviders,
              onChanged: (String? value) {
                setState(() {
                  _providerId = value;
                });
              },
            ),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.opdFieldOptionalLabel(l10n.opdReasonLabel),
              enabled: !_isBusy,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (!terminal)
          AppButton.secondary(
            label: l10n.opdPrioritizeAction,
            leadingIcon: Icons.priority_high_outlined,
            enabled: !_isBusy,
            isLoading: _activeAction == _QueueFooterAction.prioritize,
            onPressed: _isBusy
                ? null
                : () => _runInModal(
                    _QueueFooterAction.prioritize,
                    () => ref
                        .read(opdWorkspaceControllerProvider.notifier)
                        .prioritizeQueueEntry(
                          widget.entry,
                          _reasonController.text.trim(),
                        ),
                  ),
          ),
        if (!terminal)
          AppButton.secondary(
            label: l10n.opdStartConsultationAction,
            leadingIcon: Icons.play_arrow_outlined,
            enabled: !_isBusy,
            isLoading: _activeAction == _QueueFooterAction.start,
            onPressed: _isBusy
                ? null
                : () => _runInModal(
                    _QueueFooterAction.start,
                    () => ref
                        .read(opdWorkspaceControllerProvider.notifier)
                        .startOpdFromQueue(widget.entry),
                  ),
          ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_isBusy,
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
        ),
        if (!terminal)
          AppButton.primary(
            label: l10n.opdMoveQueueAction,
            leadingIcon: Icons.sync_alt_outlined,
            enabled: !_isBusy,
            isLoading: _activeAction == _QueueFooterAction.move,
            onPressed: _isBusy ? null : _submitMove,
          ),
      ],
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
      _failure = null;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = dedupeOpdProviderOptions(providers);
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingProviders = false;
        });
      },
    );
  }

  Future<void> _submitMove() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _runInModal(
      _QueueFooterAction.move,
      () => ref.read(opdWorkspaceControllerProvider.notifier).moveQueueEntry(
        widget.entry,
        <String, Object?>{
          'status': _status,
          'provider_user_id': _providerId,
        },
      ),
    );
  }

  Future<void> _runInModal(
    _QueueFooterAction action,
    Future<AppFailure?> Function() run,
  ) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _activeAction = action;
      _failure = null;
    });
    final AppFailure? failure = await run();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _activeAction = null;
    });
  }
}

const List<String> _queueStatuses = <String>[
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
  'NO_SHOW',
];
