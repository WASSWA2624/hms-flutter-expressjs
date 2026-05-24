import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Full-screen lab result entry workspace opened from the lab worklist or queue.
class LabResultEntryDialog extends ConsumerStatefulWidget {
  const LabResultEntryDialog({
    required this.canMutate,
    this.onEditOrder,
    this.onDeleteOrder,
    super.key,
  });

  final bool canMutate;
  final Future<void> Function(BuildContext context, LabOrderWorkflow workflow)?
  onEditOrder;
  final Future<void> Function(BuildContext context, LabOrderWorkflow workflow)?
  onDeleteOrder;

  @override
  ConsumerState<LabResultEntryDialog> createState() =>
      _LabResultEntryDialogState();
}

class _LabResultEntryDialogState extends ConsumerState<LabResultEntryDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<_ResultDraft>? _drafts;
  String? _draftOrderId;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  void _disposeDrafts() {
    if (_drafts == null) {
      return;
    }
    for (final _ResultDraft draft in _drafts!) {
      draft.dispose();
    }
    _drafts = null;
    _draftOrderId = null;
  }

  void _syncDrafts(LabOrderWorkflow workflow) {
    final String orderId = workflow.order.apiId;
    if (_draftOrderId == orderId && _drafts != null) {
      return;
    }
    _disposeDrafts();
    _draftOrderId = orderId;
    _drafts = workflow.order.items
        .map(_ResultDraft.new)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<LabWorkspaceState>> asyncState = ref.watch(
      labWorkspaceControllerProvider,
    );
    final LabWorkspaceState? state = asyncState.asData?.value.when(
      success: (LabWorkspaceState value) => value,
      failure: (_) => null,
    );
    final LabOrderWorkflow? workflow = state?.selectedWorkflow;
    final bool isLoading = state?.isRefreshingDetail ?? false;

    if (workflow != null) {
      _syncDrafts(workflow);
    }

    final List<_ResultDraft> drafts = _drafts ?? const <_ResultDraft>[];
    final bool canMutate = widget.canMutate && !_isSaving;
    final List<_ResultDraft> submittableDrafts = drafts
        .where((_ResultDraft draft) => draft.item.canVerify && draft.hasEntry)
        .toList(growable: false);
    final List<_ResultDraft> draftableEntries = drafts
        .where(
          (_ResultDraft draft) => draft.item.canEnterResult && draft.hasEntry,
        )
        .toList(growable: false);

    return AppDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.labResultEntryDialogTitle),
          if (workflow != null)
            Text(
              l10n.labResultEntryDialogSubtitle(
                workflow.order.patientDisplayName ?? l10n.profileUnknownValue,
                workflow.order.displayId ?? workflow.order.apiId,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      icon: const Icon(Icons.biotech_outlined),
      scrollable: true,
      maxWidth: 1040,
      closeEnabled: !_isSaving,
      content: _buildContent(
        context,
        isLoading: isLoading,
        workflow: workflow,
        drafts: drafts,
        canMutate: canMutate,
      ),
      actions: workflow == null || isLoading
          ? <Widget>[
              AppButton.tertiary(
                label: l10n.commonCloseActionLabel,
                enabled: !_isSaving,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]
          : <Widget>[
              if (canMutate && widget.onEditOrder != null)
                AppButton.secondary(
                  label: l10n.labEditOrderAction,
                  leadingIcon: Icons.edit_outlined,
                  enabled: !_isSaving,
                  onPressed: () => widget.onEditOrder?.call(context, workflow),
                ),
              if (canMutate && widget.onDeleteOrder != null)
                AppButton.tertiary(
                  label: l10n.labDeleteOrderAction,
                  leadingIcon: Icons.delete_outline,
                  enabled: !_isSaving,
                  onPressed: () =>
                      widget.onDeleteOrder?.call(context, workflow),
                ),
              AppButton.tertiary(
                label: l10n.commonCloseActionLabel,
                enabled: !_isSaving,
                onPressed: () => Navigator.of(context).pop(),
              ),
              if (canMutate && draftableEntries.isNotEmpty)
                AppButton.secondary(
                  label: l10n.labSaveDraftAction,
                  leadingIcon: Icons.save_outlined,
                  isLoading: _isSaving,
                  onPressed: () => _saveDrafts(draftableEntries),
                ),
              if (canMutate && submittableDrafts.isNotEmpty)
                AppButton.primary(
                  label: l10n.labSubmitResultsAction,
                  leadingIcon: Icons.publish_outlined,
                  isLoading: _isSaving,
                  onPressed: () => _submitResults(workflow, submittableDrafts),
                ),
            ],
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool isLoading,
    required LabOrderWorkflow? workflow,
    required List<_ResultDraft> drafts,
    required bool canMutate,
  }) {
    final AppLocalizations l10n = context.l10n;

    if (isLoading && workflow == null) {
      return AppWorkspaceStatePanel.loading(
        title: l10n.labDetailLoadingTitle,
        body: l10n.labDetailLoadingBody,
      );
    }

    if (workflow == null) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.labNoSelectionTitle,
        body: l10n.labNoSelectionBody,
        icon: Icons.science_outlined,
      );
    }

    final LabOrderSummary order = workflow.order;
    final String? orderedAtLabel = _optionalDateTimeLabel(
      context,
      order.orderedAt,
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null) ...<Widget>[
            AppFailureStateView(failure: _failure!),
            SizedBox(height: Theme.of(context).spacing.md),
          ],
          AppWorkspacePatientContextHeader(
            patientName: order.patientDisplayName ?? l10n.profileUnknownValue,
            patientNumber: order.patientId ?? '',
            patientNumberLabel: l10n.labPatientIdFieldLabel,
            semanticLabel: l10n.labPatientContextLabel,
            copyPatientNumberTooltip: l10n.copyIdentifierAction,
            copyPatientNumberMessage: l10n.identifierCopiedMessage,
            showPatientNumberCopyIcon:
                order.patientId != null && order.patientId!.trim().isNotEmpty,
            status: _orderStatus(context, order.status),
            alerts: <AppWorkspaceStatus>[
              if (order.hasCriticalResult)
                AppWorkspaceStatus(
                  label: l10n.labStatusCritical,
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.priority_high_outlined,
                ),
              if (order.hasRejectedItem)
                AppWorkspaceStatus(
                  label: l10n.labStatusRejected,
                  tone: AppWorkspaceStatusTone.error,
                  icon: Icons.block_outlined,
                ),
            ],
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.labOrderFieldLabel,
                value: order.displayId ?? order.id,
                icon: Icons.tag_outlined,
                copyable: true,
                copyTooltip: l10n.copyIdentifierAction,
                copiedMessage: l10n.identifierCopiedMessage,
              ),
              if (order.encounterId != null &&
                  order.encounterId!.trim().isNotEmpty)
                AppWorkspacePatientContextField(
                  label: l10n.labEncounterFieldLabel,
                  value: order.encounterId!,
                  icon: Icons.medical_information_outlined,
                  copyable: true,
                  copyTooltip: l10n.opdCopyEncounterIdAction,
                  copiedMessage: l10n.opdEncounterIdCopiedMessage,
                ),
              if (orderedAtLabel != null)
                AppWorkspacePatientContextField(
                  label: l10n.labOrderedAtFieldLabel,
                  value: orderedAtLabel,
                  icon: Icons.event_outlined,
                ),
              AppWorkspacePatientContextField(
                label: l10n.labOrderStatusFieldLabel,
                value: _statusLabel(context, order.status),
                icon: Icons.info_outline,
              ),
              AppWorkspacePatientContextField(
                label: l10n.labTestsColumnLabel,
                value: order.testsLabel ?? l10n.profileUnknownValue,
                icon: Icons.science_outlined,
              ),
            ],
          ),
          SizedBox(height: Theme.of(context).spacing.lg),
          Text(
            l10n.labItemsSectionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
          if (drafts.isEmpty)
            AppWorkspaceStatePanel.empty(
              title: l10n.labNoOrderItemsEntryTitle,
              body: l10n.labNoOrderItemsEntryBody,
              icon: Icons.science_outlined,
              minHeight: 160,
            )
          else
            _LabResultEntryTable(
              drafts: drafts,
              canMutate: canMutate,
              onVerifyItem: (_ResultDraft draft) => _verifySingle(draft),
              onRejectItem: (LabOrderItem item) =>
                  _openRejectDialog(context, item),
            ),
          if (workflow.results.isNotEmpty) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.lg),
            Text(
              l10n.labResultsSectionTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: Theme.of(context).spacing.sm),
            _VerifiedResultsList(results: workflow.results),
          ],
        ],
      ),
    );
  }

  Future<void> _saveDrafts(List<_ResultDraft> entries) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );
    final List<({LabOrderItem item, Map<String, Object?> payload})> payloads =
        entries
            .map(
              (_ResultDraft draft) =>
                  (item: draft.item, payload: draft.toDraftPayload()),
            )
            .toList(growable: false);
    final AppFailure? failure = await controller.saveOrderItemDrafts(payloads);
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    if (failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.labDraftSavedMessage)),
      );
      return;
    }
    setState(() => _failure = failure);
  }

  Future<void> _submitResults(
    LabOrderWorkflow workflow,
    List<_ResultDraft> entries,
  ) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = entries.length == 1
        ? await controller.verifyOrderItem(
            entries.single.item.apiId,
            entries.single.toPayload(),
          )
        : await controller.verifyAllResults(
            workflow.order.apiId,
            entries
                .map(
                  (_ResultDraft draft) =>
                      draft.toPayload(includeOrderItemId: true),
                )
                .toList(growable: false),
          );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    if (failure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.labSavedMessage)));
      return;
    }
    setState(() => _failure = failure);
  }

  Future<void> _verifySingle(_ResultDraft draft) async {
    if (!(draft.formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .verifyOrderItem(draft.item.apiId, draft.toPayload());
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    if (failure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.labSavedMessage)));
      return;
    }
    setState(() => _failure = failure);
  }

  Future<void> _openRejectDialog(
    BuildContext context,
    LabOrderItem item,
  ) async {
    final bool? saved = await showAppDialog<bool>(
      context: context,
      builder: (_) => _RejectOrderItemDialog(item: item),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.labSavedMessage)));
    }
  }
}

class _LabResultEntryTable extends StatelessWidget {
  const _LabResultEntryTable({
    required this.drafts,
    required this.canMutate,
    required this.onVerifyItem,
    required this.onRejectItem,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final Future<void> Function(_ResultDraft draft) onVerifyItem;
  final Future<void> Function(LabOrderItem item) onRejectItem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool wide = MediaQuery.sizeOf(context).width >= 720;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(theme.radius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (wide)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.md,
                vertical: theme.spacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Text(
                      l10n.labTestsColumnLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      l10n.labTestStatusColumnLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      l10n.labReferenceRangeColumnLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      l10n.labResultInputColumnLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          for (var index = 0; index < drafts.length; index += 1) ...<Widget>[
            _LabResultEntryTableRow(
              draft: drafts[index],
              canMutate: canMutate,
              onVerify: () => onVerifyItem(drafts[index]),
              onReject: () => onRejectItem(drafts[index].item),
            ),
            if (index < drafts.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _LabResultEntryTableRow extends StatelessWidget {
  const _LabResultEntryTableRow({
    required this.draft,
    required this.canMutate,
    required this.onVerify,
    required this.onReject,
  });

  final _ResultDraft draft;
  final bool canMutate;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final LabOrderItem item = draft.item;
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    final bool highlightAbnormal = _isAbnormalEntry(item, draft);
    final Color? highlightColor = highlightAbnormal
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.35)
        : null;
    final AppWorkspaceStatus status = item.isRejected
        ? AppWorkspaceStatus(
            label: l10n.labStatusRejected,
            tone: AppWorkspaceStatusTone.error,
            icon: Icons.block_outlined,
          )
        : _statusBadge(context, item.effectiveResultStatus ?? item.status);

    final Widget testCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.displayTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (item.testCode != null && item.testCode!.trim().isNotEmpty)
          Text(
            '${l10n.labTestCodeLabel}: ${item.testCode}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        Text(
          _joinDisplay(<String?>[
                item.specimenType == null
                    ? null
                    : '${l10n.labSpecimenTypeLabel}: ${item.specimenType}',
                item.category == null
                    ? null
                    : '${l10n.labCategoryLabel}: ${item.category}',
                item.unit ?? item.unit,
              ]) ??
              l10n.profileUnknownValue,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final Widget referenceCell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.displayReferenceRange ?? l10n.profileUnknownValue,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: highlightAbnormal ? FontWeight.w700 : null,
            color: highlightAbnormal
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface,
          ),
        ),
        if (item.unit != null && item.unit!.trim().isNotEmpty)
          Text(
            item.unit!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );

    final Widget resultCell = item.isCompleted
        ? _CompletedResultReadout(item: item)
        : item.canEnterResult
        ? _CompactResultInput(draft: draft, enabled: canMutate)
        : _CompletedResultReadout(item: item);

    final Widget actions = Wrap(
      spacing: theme.spacing.xs,
      children: <Widget>[
        if (canMutate && item.canVerify && draft.hasEntry)
          AppButton.secondary(
            label: l10n.labVerifyResultAction,
            leadingIcon: Icons.verified_outlined,
            onPressed: onVerify,
          ),
        if (canMutate && item.canReject)
          AppIconButton(
            icon: Icons.block_outlined,
            semanticLabel: l10n.labRejectOrderItemAction,
            tooltip: l10n.labRejectOrderItemAction,
            onPressed: onReject,
          ),
      ],
    );

    return ColoredBox(
      color: highlightColor ?? Colors.transparent,
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 3, child: testCell),
                  Expanded(
                    flex: 2,
                    child: AppWorkspaceStatusBadge(status: status),
                  ),
                  Expanded(flex: 2, child: referenceCell),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        resultCell,
                        SizedBox(height: theme.spacing.sm),
                        actions,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  testCell,
                  SizedBox(height: theme.spacing.sm),
                  AppWorkspaceStatusBadge(status: status),
                  SizedBox(height: theme.spacing.sm),
                  referenceCell,
                  SizedBox(height: theme.spacing.sm),
                  resultCell,
                  SizedBox(height: theme.spacing.sm),
                  actions,
                ],
              ),
      ),
    );
  }
}

class _CompactResultInput extends StatefulWidget {
  const _CompactResultInput({required this.draft, required this.enabled});

  final _ResultDraft draft;
  final bool enabled;

  @override
  State<_CompactResultInput> createState() => _CompactResultInputState();
}

class _CompactResultInputState extends State<_CompactResultInput> {
  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;
    final AppLocalizations l10n = context.l10n;
    final LabOrderItem item = widget.draft.item;

    return Form(
      key: widget.draft.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (item.isNumeric) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: widget.draft.valueController,
                    labelText: l10n.labResultValueLabel,
                    enabled: enabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (String? value) {
                      final String normalized = value?.trim() ?? '';
                      if (normalized.isEmpty) {
                        return null;
                      }
                      return num.tryParse(normalized) == null
                          ? l10n.labNumericRangeValidationMessage
                          : null;
                    },
                  ),
                ),
                SizedBox(width: Theme.of(context).spacing.sm),
                Expanded(
                  child: item.unitOptions.isEmpty
                      ? AppTextField(
                          controller: widget.draft.unitController,
                          labelText: l10n.labResultUnitLabel,
                          enabled: enabled,
                        )
                      : AppSelectField<String>(
                          value: widget.draft.unitController.text.trim().isEmpty
                              ? null
                              : widget.draft.unitController.text.trim(),
                          labelText: l10n.labResultUnitLabel,
                          enabled: enabled,
                          options: <AppSelectOption<String>>[
                            for (final LabUnitOption option in item.unitOptions)
                              AppSelectOption<String>(
                                value: option.unit ?? option.label ?? option.id,
                                label: option.displayLabel,
                              ),
                          ],
                          onChanged: (String? value) {
                            widget.draft.unitController.text = value ?? '';
                          },
                        ),
                ),
              ],
            ),
          ] else if (item.isQualitative && item.resultOptions.isNotEmpty)
            AppSelectField<String>(
              value: widget.draft.selectedOption,
              labelText: l10n.labResultValueLabel,
              enabled: enabled,
              options: <AppSelectOption<String>>[
                for (final LabResultOption option in item.resultOptions)
                  AppSelectOption<String>(
                    value: option.value ?? option.label ?? option.id,
                    label: option.displayLabel,
                  ),
              ],
              onChanged: enabled
                  ? (String? value) {
                      setState(() => widget.draft.selectedOption = value);
                    }
                  : null,
            )
          else
            AppTextField(
              controller: widget.draft.textController,
              labelText: item.isQualitative
                  ? l10n.labResultValueLabel
                  : l10n.labResultTextLabel,
              enabled: enabled,
              maxLines: item.isText ? 3 : 1,
            ),
          AppTextField(
            controller: widget.draft.notesController,
            labelText: l10n.labNotesLabel,
            enabled: enabled,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _CompletedResultReadout extends StatelessWidget {
  const _CompletedResultReadout({required this.item});

  final LabOrderItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final String? value = item.displayResultValue;

    if (value == null || value.trim().isEmpty) {
      return Text(
        l10n.labStatusPendingResults,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final bool abnormal = _isAbnormalStatus(item.effectiveResultStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: abnormal ? theme.colorScheme.error : null,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (item.resultFlag != null && item.resultFlag!.trim().isNotEmpty)
          Text(
            '${l10n.labResultFlagLabel}: ${_statusLabel(context, item.resultFlag)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: abnormal
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _VerifiedResultsList extends StatelessWidget {
  const _VerifiedResultsList({required this.results});

  final List<LabResult> results;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        for (final LabResult result in results)
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: Theme.of(context).spacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        result.displayTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _joinDisplay(<String?>[
                              result.displayValue,
                              result.referenceRangeSummary == null
                                  ? null
                                  : '${l10n.labReferenceRangeLabel}: ${result.referenceRangeSummary}',
                            ]) ??
                            l10n.profileUnknownValue,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppWorkspaceStatusBadge(
                  status: _statusBadge(context, result.status),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

final class _ResultDraft {
  _ResultDraft(this.item)
    : valueController = TextEditingController(text: item.resultValue ?? ''),
      unitController = TextEditingController(
        text: item.resultUnit ?? item.unit ?? '',
      ),
      textController = TextEditingController(text: item.resultText ?? ''),
      notesController = TextEditingController(),
      selectedOption = item.resultText ?? item.resultValue;

  final LabOrderItem item;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController valueController;
  final TextEditingController unitController;
  final TextEditingController textController;
  final TextEditingController notesController;
  String? selectedOption;

  bool get hasEntry {
    if (item.isNumeric) {
      return valueController.text.trim().isNotEmpty;
    }
    if (item.isQualitative && item.resultOptions.isNotEmpty) {
      return (selectedOption ?? '').trim().isNotEmpty;
    }
    return textController.text.trim().isNotEmpty;
  }

  void dispose() {
    valueController.dispose();
    unitController.dispose();
    textController.dispose();
    notesController.dispose();
  }

  Map<String, Object?> toPayload({bool includeOrderItemId = false}) {
    final String value = valueController.text.trim();
    final String unit = unitController.text.trim();
    final String text = textController.text.trim();
    final bool hasOption = selectedOption?.trim().isNotEmpty ?? false;
    final String? option = hasOption ? selectedOption!.trim() : null;
    final Map<String, Object?> payload = <String, Object?>{
      if (includeOrderItemId) 'order_item_id': item.apiId,
      'reported_at': DateTime.now().toIso8601String(),
      if (notesController.text.trim().isNotEmpty)
        'notes': notesController.text.trim(),
    };

    if (item.isNumeric) {
      payload['result_value'] = value;
      if (unit.isNotEmpty) {
        payload['result_unit'] = unit;
      }
      return payload;
    }
    if (item.isQualitative) {
      payload['result_text'] = option ?? text;
      return payload;
    }
    payload['result_text'] = text;
    return payload;
  }

  Map<String, Object?> toDraftPayload() {
    final Map<String, Object?> payload = toPayload();
    payload.remove('reported_at');
    payload.remove('notes');
    return payload;
  }
}

class _RejectOrderItemDialog extends ConsumerStatefulWidget {
  const _RejectOrderItemDialog({required this.item});

  final LabOrderItem item;

  @override
  ConsumerState<_RejectOrderItemDialog> createState() =>
      _RejectOrderItemDialogState();
}

class _RejectOrderItemDialogState
    extends ConsumerState<_RejectOrderItemDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late final TextEditingController _customReasonController;
  String? _reason;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _customReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labRejectOrderItemDialogTitle),
      icon: const Icon(Icons.block_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _reason,
              labelText: l10n.labRejectReasonLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: l10n.labRejectReasonNotPerformedHere,
                  label: l10n.labRejectReasonNotPerformedHere,
                ),
                AppSelectOption<String>(
                  value: l10n.labRejectReasonInsufficientInfo,
                  label: l10n.labRejectReasonInsufficientInfo,
                ),
                AppSelectOption<String>(
                  value: l10n.labRejectReasonInvalidRequest,
                  label: l10n.labRejectReasonInvalidRequest,
                ),
                AppSelectOption<String>(
                  value: l10n.labRejectReasonOther,
                  label: l10n.labRejectReasonOther,
                ),
              ],
              onChanged: (String? value) => setState(() => _reason = value),
            ),
            if (_reason == l10n.labRejectReasonOther)
              AppTextField(
                controller: _customReasonController,
                labelText: l10n.labRejectCustomReasonLabel,
                enabled: !_isSaving,
                validator: AppValidators.requiredText(l10n.validationRequired),
              ),
            AppTextField(
              controller: _notesController,
              labelText: l10n.labNotesLabel,
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.labRejectOrderItemAction,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String reason = _reason == l10n.labRejectReasonOther
        ? _customReasonController.text.trim()
        : _reason!.trim();
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .rejectOrderItem(widget.item.apiId, <String, Object?>{
          'reason': reason,
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
        });
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
}

bool _isAbnormalStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'CRITICAL' || 'ABNORMAL' || 'LOW' || 'HIGH' => true,
    _ => false,
  };
}

bool _isAbnormalEntry(LabOrderItem item, _ResultDraft draft) {
  if (_isAbnormalStatus(item.effectiveResultStatus)) {
    return true;
  }
  if (!item.isNumeric || item.referenceRanges.isEmpty) {
    return false;
  }
  final num? parsed = num.tryParse(draft.valueController.text.trim());
  if (parsed == null) {
    return false;
  }
  final LabReferenceRange range = item.referenceRanges.first;
  final num? min = num.tryParse(range.normalMinValue ?? '');
  final num? max = num.tryParse(range.normalMaxValue ?? '');
  if (min != null && parsed < min) {
    return true;
  }
  if (max != null && parsed > max) {
    return true;
  }
  return false;
}

AppWorkspaceStatus _orderStatus(BuildContext context, String? value) {
  return _statusBadge(context, value);
}

AppWorkspaceStatus _statusBadge(BuildContext context, String? value) {
  final String status = (value ?? '').toUpperCase();
  return AppWorkspaceStatus(
    label: _statusLabel(context, value),
    tone: switch (status) {
      'COMPLETED' || 'NORMAL' || 'RECEIVED' => AppWorkspaceStatusTone.success,
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

String? _optionalDateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
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

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' · ');
  return joined.isEmpty ? null : joined;
}
