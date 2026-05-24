import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

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
  List<_ResultDraft>? _drafts;
  String? _draftSignature;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _disposeDrafts() {
    if (_drafts == null) {
      return;
    }
    for (final _ResultDraft draft in _drafts!) {
      draft.removeListener(_handleDraftChanged);
      draft.dispose();
    }
    _drafts = null;
    _draftSignature = null;
  }

  void _syncDrafts(List<LabOrderWorkflow> workflows) {
    final String signature = _draftSignatureFor(workflows);
    if (_draftSignature == signature && _drafts != null) {
      return;
    }
    _disposeDrafts();
    _draftSignature = signature;
    final List<_ResultDraft> drafts = <_ResultDraft>[
      for (final LabOrderWorkflow workflow in workflows)
        for (final LabOrderItem item in workflow.order.items)
          _ResultDraft(item),
    ];
    for (final _ResultDraft draft in drafts) {
      draft.addListener(_handleDraftChanged);
    }
    _drafts = drafts;
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
    final List<LabOrderWorkflow> workflows = _selectedWorkflows(state);
    final bool isLoading = state?.isRefreshingDetail ?? false;
    final List<LabCatalogItem> catalogPanels =
        state?.catalogPanels ?? const <LabCatalogItem>[];

    if (workflows.isNotEmpty) {
      _syncDrafts(workflows);
    } else {
      _disposeDrafts();
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
          if (workflows.isNotEmpty)
            Text(
              _detailSubtitle(context, workflows),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      icon: const Icon(Icons.biotech_outlined),
      scrollable: true,
      maxWidth: 1600,
      closeEnabled: !_isSaving,
      content: _buildContent(
        context,
        isLoading: isLoading,
        workflows: workflows,
        catalogPanels: catalogPanels,
        drafts: drafts,
        canMutate: canMutate,
      ),
      actions: workflows.isEmpty || isLoading
          ? <Widget>[
              AppButton.tertiary(
                label: l10n.commonCloseActionLabel,
                enabled: !_isSaving,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]
          : <Widget>[
              AppReportActionButton.preview(
                label: l10n.labPreviewReportAction,
                enabled: !_isSaving,
                onPressed: () => _openPrintPreview(context, workflows),
              ),
              if (workflows.length == 1 &&
                  canMutate &&
                  widget.onEditOrder != null)
                AppButton.secondary(
                  label: l10n.labEditOrderAction,
                  leadingIcon: Icons.edit_outlined,
                  enabled: !_isSaving,
                  onPressed: () =>
                      widget.onEditOrder?.call(context, workflows.first),
                ),
              if (workflows.length == 1 &&
                  canMutate &&
                  widget.onDeleteOrder != null)
                AppButton.tertiary(
                  label: l10n.labDeleteOrderAction,
                  leadingIcon: Icons.delete_outline,
                  enabled: !_isSaving,
                  onPressed: () =>
                      widget.onDeleteOrder?.call(context, workflows.first),
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
                  onPressed: () => _submitResults(submittableDrafts),
                ),
            ],
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required bool isLoading,
    required List<LabOrderWorkflow> workflows,
    required List<LabCatalogItem> catalogPanels,
    required List<_ResultDraft> drafts,
    required bool canMutate,
  }) {
    final AppLocalizations l10n = context.l10n;

    if (isLoading && workflows.isEmpty) {
      return AppWorkspaceStatePanel.loading(
        title: l10n.labDetailLoadingTitle,
        body: l10n.labDetailLoadingBody,
      );
    }

    if (workflows.isEmpty) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.labNoSelectionTitle,
        body: l10n.labNoSelectionBody,
        icon: Icons.science_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_failure != null) ...<Widget>[
          AppFailureStateView(failure: _failure!),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        _LabResultContextHeader(workflows: workflows),
        SizedBox(height: Theme.of(context).spacing.md),
        if (isLoading) ...<Widget>[
          const LinearProgressIndicator(minHeight: 2),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        for (final LabOrderWorkflow workflow in workflows) ...<Widget>[
          _LabOrderResultSection(
            workflow: workflow,
            drafts: _draftsForWorkflow(drafts, workflow),
            catalogPanels: catalogPanels,
            canMutate: canMutate,
            onSaveDraft: _saveDraft,
            onVerifyItem: _verifyOrderItem,
            onRejectItem: _openRejectDialog,
            onRemoveResult: _removeDraftResult,
            onEditOrder: widget.onEditOrder == null
                ? null
                : () => widget.onEditOrder?.call(context, workflow),
            onDeleteOrder: widget.onDeleteOrder == null
                ? null
                : () => widget.onDeleteOrder?.call(context, workflow),
          ),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
      ],
    );
  }

  Future<void> _saveDraft(_ResultDraft draft) async {
    await _saveDrafts(<_ResultDraft>[draft]);
  }

  Future<void> _saveDrafts(List<_ResultDraft> drafts) async {
    final List<_ResultDraft> validDrafts = drafts
        .where(
          (_ResultDraft draft) =>
              draft.formKey.currentState?.validate() ?? true,
        )
        .toList(growable: false);
    if (validDrafts.length != drafts.length) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .saveOrderItemDrafts(
          validDrafts
              .map(
                (_ResultDraft draft) =>
                    (item: draft.item, payload: draft.toDraftPayload()),
              )
              .toList(growable: false),
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  Future<void> _submitResults(List<_ResultDraft> drafts) async {
    final List<_ResultDraft> validDrafts = drafts
        .where(
          (_ResultDraft draft) =>
              draft.formKey.currentState?.validate() ?? true,
        )
        .toList(growable: false);
    if (validDrafts.length != drafts.length) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .submitOrderItemResults(
          validDrafts
              .map(
                (_ResultDraft draft) => (
                  item: draft.item,
                  payload: draft.toPayload(includeOrderItemId: true),
                ),
              )
              .toList(growable: false),
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  Future<void> _verifyOrderItem(_ResultDraft draft) async {
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
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  Future<void> _removeDraftResult(_ResultDraft draft) async {
    if (draft.item.isCompleted) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppConfirmActionDialog(
        title: context.l10n.labRemoveDraftResultDialogTitle,
        body: context.l10n.labRemoveDraftResultDialogBody,
        submitLabel: context.l10n.labRemoveDraftResultAction,
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    if (draft.item.resultId == null || draft.item.resultId!.trim().isEmpty) {
      setState(draft.clearEntry);
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .removeOrderItemDraftResult(draft.item);
    if (!mounted) {
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
    if (failure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.labDraftRemovedMessage)),
      );
    }
  }

  Future<void> _openRejectDialog(LabOrderItem item) async {
    await showAppDialog<bool>(
      context: context,
      builder: (_) => _RejectOrderItemDialog(item: item),
    );
  }

  Future<void> _openPrintPreview(
    BuildContext context,
    List<LabOrderWorkflow> workflows,
  ) async {
    await showAppDialog<void>(
      context: context,
      builder: (_) => _LabReportPreviewDialog(workflows: workflows),
    );
  }
}

class _LabResultContextHeader extends StatelessWidget {
  const _LabResultContextHeader({required this.workflows});

  final List<LabOrderWorkflow> workflows;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final LabOrderSummary firstOrder = workflows.first.order;
    final List<String> encounterIds = _uniqueNonEmpty(
      workflows.map((LabOrderWorkflow workflow) => workflow.order.encounterId),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    firstOrder.patientDisplayName ?? l10n.profileUnknownValue,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AppWorkspaceStatusBadge(
                  status: _aggregateOrderStatus(context, workflows),
                ),
                if (workflows.any(
                  (LabOrderWorkflow workflow) =>
                      workflow.order.hasCriticalResult,
                ))
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: l10n.labStatusCritical,
                      tone: AppWorkspaceStatusTone.error,
                      icon: Icons.priority_high_outlined,
                    ),
                  ),
                if (workflows.any(
                  (LabOrderWorkflow workflow) => workflow.order.hasRejectedItem,
                ))
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: l10n.labStatusRejected,
                      tone: AppWorkspaceStatusTone.error,
                      icon: Icons.block_outlined,
                    ),
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            Wrap(
              spacing: theme.spacing.md,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                _LabContextFact(
                  label: l10n.labPatientIdFieldLabel,
                  value: firstOrder.patientId ?? l10n.profileUnknownValue,
                  copyable:
                      firstOrder.patientId != null &&
                      firstOrder.patientId!.trim().isNotEmpty,
                  copyTooltip: l10n.copyIdentifierAction,
                  copiedMessage: l10n.identifierCopiedMessage,
                ),
                if (encounterIds.isNotEmpty)
                  _LabContextFact(
                    label: l10n.labEncounterFieldLabel,
                    value: encounterIds.join(', '),
                    copyable: encounterIds.length == 1,
                    copyTooltip: l10n.opdCopyEncounterIdAction,
                    copiedMessage: l10n.opdEncounterIdCopiedMessage,
                  ),
                _LabContextFact(
                  label: l10n.labOrdersIncludedLabel,
                  value: l10n.labActiveOrderCount(workflows.length),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LabContextFact extends StatelessWidget {
  const _LabContextFact({
    required this.label,
    required this.value,
    this.copyable = false,
    this.copyTooltip,
    this.copiedMessage,
  });

  final String label;
  final String value;
  final bool copyable;
  final String? copyTooltip;
  final String? copiedMessage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.xs / 2),
          if (copyable)
            AppCopyableIdentifier(
              value: value,
              tooltip: copyTooltip,
              copiedMessage: copiedMessage,
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

List<String> _uniqueNonEmpty(Iterable<String?> values) {
  final List<String> uniqueValues = <String>[];
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty || uniqueValues.contains(normalized)) {
      continue;
    }
    uniqueValues.add(normalized);
  }
  return uniqueValues;
}

class _LabOrderResultSection extends StatelessWidget {
  const _LabOrderResultSection({
    required this.workflow,
    required this.drafts,
    required this.catalogPanels,
    required this.canMutate,
    required this.onSaveDraft,
    required this.onVerifyItem,
    required this.onRejectItem,
    required this.onRemoveResult,
    this.onEditOrder,
    this.onDeleteOrder,
  });

  final LabOrderWorkflow workflow;
  final List<_ResultDraft> drafts;
  final List<LabCatalogItem> catalogPanels;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onVerifyItem;
  final ValueChanged<LabOrderItem> onRejectItem;
  final ValueChanged<_ResultDraft> onRemoveResult;
  final VoidCallback? onEditOrder;
  final VoidCallback? onDeleteOrder;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final LabOrderSummary order = workflow.order;
    final String orderLabel = order.displayId ?? order.apiId;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${l10n.labOrderFieldLabel} $orderLabel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: theme.spacing.xs),
                      Wrap(
                        spacing: theme.spacing.xs,
                        runSpacing: theme.spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          AppWorkspaceStatusBadge(
                            status: _orderStatus(context, order.status),
                          ),
                          AppWorkspaceStatusBadge(
                            status: _entryStatus(context, order),
                          ),
                          AppWorkspaceStatusBadge(
                            status: _resultStatus(context, order),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (canMutate && (onEditOrder != null || onDeleteOrder != null))
                  Wrap(
                    spacing: theme.spacing.xs,
                    children: <Widget>[
                      if (onEditOrder != null)
                        AppIconButton(
                          icon: Icons.edit_outlined,
                          semanticLabel: l10n.labEditOrderAction,
                          tooltip: l10n.labEditOrderAction,
                          onPressed: onEditOrder,
                        ),
                      if (onDeleteOrder != null)
                        AppIconButton(
                          icon: Icons.delete_outline,
                          semanticLabel: l10n.labDeleteOrderAction,
                          tooltip: l10n.labDeleteOrderAction,
                          onPressed: onDeleteOrder,
                        ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.xs),
            Wrap(
              spacing: theme.spacing.md,
              runSpacing: theme.spacing.xs,
              children: <Widget>[
                _InlineOrderMeta(
                  icon: Icons.event_outlined,
                  text:
                      '${l10n.labOrderedAtFieldLabel}: ${_optionalDateTimeLabel(context, order.orderedAt) ?? l10n.profileUnknownValue}',
                ),
                if (order.encounterId != null &&
                    order.encounterId!.trim().isNotEmpty)
                  _InlineOrderMeta(
                    icon: Icons.medical_information_outlined,
                    text:
                        '${l10n.labEncounterFieldLabel}: ${order.encounterId!}',
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              l10n.labItemsSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            if (drafts.isEmpty)
              AppWorkspaceStatePanel.empty(
                title: l10n.labNoOrderItemsEntryTitle,
                body: l10n.labNoOrderItemsEntryBody,
                icon: Icons.science_outlined,
              )
            else
              _LabResultEntryTable(
                drafts: drafts,
                catalogPanels: catalogPanels,
                canMutate: canMutate,
                onSaveDraft: onSaveDraft,
                onVerify: onVerifyItem,
                onReject: onRejectItem,
                onRemove: onRemoveResult,
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineOrderMeta extends StatelessWidget {
  const _InlineOrderMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          icon,
          size: theme.appTokens.listIconSize * 0.72,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: theme.spacing.xs / 2),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CompactStatusRow extends StatelessWidget {
  const _CompactStatusRow({required this.item});

  final LabOrderItem item;

  @override
  Widget build(BuildContext context) {
    final List<String> statuses = _uniqueNonEmpty(<String?>[item.status]);
    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        for (final String status in statuses)
          AppWorkspaceStatusBadge(status: _statusBadge(context, status)),
      ],
    );
  }
}

class _ResponsiveLabResultEntry extends StatelessWidget {
  const _ResponsiveLabResultEntry({
    required this.drafts,
    required this.canMutate,
    required this.onSaveDraft,
    required this.onVerify,
    required this.onReject,
    required this.onRemove,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onVerify;
  final ValueChanged<LabOrderItem> onReject;
  final ValueChanged<_ResultDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 760) {
          return _LabResultEntryCards(
            drafts: drafts,
            canMutate: canMutate,
            onSaveDraft: onSaveDraft,
            onVerify: onVerify,
            onReject: onReject,
            onRemove: onRemove,
          );
        }
        return _LabResultEntryRowsTable(
          drafts: drafts,
          canMutate: canMutate,
          onSaveDraft: onSaveDraft,
          onVerify: onVerify,
          onReject: onReject,
          onRemove: onRemove,
          availableWidth: constraints.maxWidth,
        );
      },
    );
  }
}

class _LabResultEntryCards extends StatelessWidget {
  const _LabResultEntryCards({
    required this.drafts,
    required this.canMutate,
    required this.onSaveDraft,
    required this.onVerify,
    required this.onReject,
    required this.onRemove,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onVerify;
  final ValueChanged<LabOrderItem> onReject;
  final ValueChanged<_ResultDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final _ResultDraft draft in drafts) ...<Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _LabResultTestCell(item: draft.item),
                  SizedBox(height: theme.spacing.sm),
                  _LabReferenceRangeCell(item: draft.item),
                  SizedBox(height: theme.spacing.sm),
                  draft.item.canEnterResult
                      ? _CompactResultInput(
                          draft: draft,
                          enabled: canMutate && draft.item.canEnterResult,
                        )
                      : _CompletedResultReadout(item: draft.item),
                  SizedBox(height: theme.spacing.sm),
                  _LabResultFlagCell(item: draft.item, draft: draft),
                  SizedBox(height: theme.spacing.xs),
                  _LabResultActionsCell(
                    draft: draft,
                    canMutate: canMutate,
                    onSaveDraft: () => onSaveDraft(draft),
                    onVerify: () => onVerify(draft),
                    onReject: () => onReject(draft.item),
                    onRemove: () => onRemove(draft),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
      ],
    );
  }
}

class _LabResultEntryTable extends StatelessWidget {
  const _LabResultEntryTable({
    required this.drafts,
    required this.catalogPanels,
    required this.canMutate,
    required this.onSaveDraft,
    required this.onVerify,
    required this.onReject,
    required this.onRemove,
  });

  final List<_ResultDraft> drafts;
  final List<LabCatalogItem> catalogPanels;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onVerify;
  final ValueChanged<LabOrderItem> onReject;
  final ValueChanged<_ResultDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_LabPanelDraftGroup> groups = _groupDraftsForDisplay(
      drafts,
      catalogPanels,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final _LabPanelDraftGroup group in groups) ...<Widget>[
          if (group.panelTitle != null) ...<Widget>[
            _PanelGroupHeader(title: group.panelTitle!),
            SizedBox(height: theme.spacing.xs),
          ],
          _ResponsiveLabResultEntry(
            drafts: group.drafts,
            canMutate: canMutate,
            onSaveDraft: onSaveDraft,
            onVerify: onVerify,
            onReject: onReject,
            onRemove: onRemove,
          ),
          SizedBox(height: theme.spacing.sm),
        ],
      ],
    );
  }
}

class _LabResultEntryRowsTable extends StatelessWidget {
  const _LabResultEntryRowsTable({
    required this.drafts,
    required this.canMutate,
    required this.onSaveDraft,
    required this.onVerify,
    required this.onReject,
    required this.onRemove,
    required this.availableWidth,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onVerify;
  final ValueChanged<LabOrderItem> onReject;
  final ValueChanged<_ResultDraft> onRemove;
  final double availableWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final double tableWidth = availableWidth
        .clamp(860.0, double.infinity)
        .toDouble();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Table(
          border: TableBorder.all(color: theme.colorScheme.outlineVariant),
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(1.35),
            2: FlexColumnWidth(3.4),
            3: FlexColumnWidth(),
            4: FlexColumnWidth(1.45),
          },
          children: <TableRow>[
            TableRow(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.32,
                ),
              ),
              children: <Widget>[
                _LabResultTableCell.header(label: l10n.labTestsColumnLabel),
                _LabResultTableCell.header(label: l10n.labReferenceRangeLabel),
                _LabResultTableCell.header(label: l10n.labReportResultLabel),
                _LabResultTableCell.header(label: l10n.labResultFlagLabel),
                _LabResultTableCell.header(label: l10n.labActionColumnLabel),
              ],
            ),
            for (final _ResultDraft draft in drafts)
              _labResultEntryTableRow(
                context,
                draft: draft,
                canMutate: canMutate,
                onSaveDraft: () => onSaveDraft(draft),
                onVerify: () => onVerify(draft),
                onReject: () => onReject(draft.item),
                onRemove: () => onRemove(draft),
              ),
          ],
        ),
      ),
    );
  }
}

class _LabResultTableCell extends StatelessWidget {
  const _LabResultTableCell({required this.child});

  _LabResultTableCell.header({required String label})
    : child = _LabResultHeaderText(label: label);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(Theme.of(context).spacing.sm),
      child: child,
    );
  }
}

class _LabResultHeaderText extends StatelessWidget {
  const _LabResultHeaderText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

TableRow _labResultEntryTableRow(
  BuildContext context, {
  required _ResultDraft draft,
  required bool canMutate,
  required VoidCallback onSaveDraft,
  required VoidCallback onVerify,
  required VoidCallback onReject,
  required VoidCallback onRemove,
}) {
  final ThemeData theme = Theme.of(context);
  final LabOrderItem item = draft.item;
  final bool canEdit = canMutate && item.canEnterResult;
  final bool abnormal = _isAbnormalEntry(item, draft);

  return TableRow(
    decoration: BoxDecoration(
      color: abnormal
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.14)
          : theme.colorScheme.surfaceContainerLowest,
    ),
    children: <Widget>[
      _LabResultTableCell(child: _LabResultTestCell(item: item)),
      _LabResultTableCell(child: _LabReferenceRangeCell(item: item)),
      _LabResultTableCell(
        child: item.canEnterResult
            ? _CompactResultInput(draft: draft, enabled: canEdit)
            : _CompletedResultReadout(item: item),
      ),
      _LabResultTableCell(
        child: _LabResultFlagCell(item: item, draft: draft),
      ),
      _LabResultTableCell(
        child: _LabResultActionsCell(
          draft: draft,
          canMutate: canMutate,
          onSaveDraft: onSaveDraft,
          onVerify: onVerify,
          onReject: onReject,
          onRemove: onRemove,
        ),
      ),
    ],
  );
}

class _LabResultTestCell extends StatelessWidget {
  const _LabResultTestCell({required this.item});

  final LabOrderItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.displayTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        _CompactStatusRow(item: item),
      ],
    );
  }
}

class _LabReferenceRangeCell extends StatelessWidget {
  const _LabReferenceRangeCell({required this.item});

  final LabOrderItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      item.displayReferenceRange ?? context.l10n.profileUnknownValue,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _LabResultFlagCell extends StatelessWidget {
  const _LabResultFlagCell({required this.item, required this.draft});

  final LabOrderItem item;
  final _ResultDraft draft;

  @override
  Widget build(BuildContext context) {
    final bool abnormal = _isAbnormalEntry(item, draft);
    return AppWorkspaceStatusBadge(
      status: AppWorkspaceStatus(
        label: _resultFlagLabel(context, item, draft),
        tone: abnormal
            ? AppWorkspaceStatusTone.error
            : AppWorkspaceStatusTone.neutral,
        icon: abnormal ? Icons.warning_amber_outlined : Icons.check_outlined,
      ),
    );
  }
}

class _LabResultActionsCell extends StatelessWidget {
  const _LabResultActionsCell({
    required this.draft,
    required this.canMutate,
    required this.onSaveDraft,
    required this.onVerify,
    required this.onReject,
    required this.onRemove,
  });

  final _ResultDraft draft;
  final bool canMutate;
  final VoidCallback onSaveDraft;
  final VoidCallback onVerify;
  final VoidCallback onReject;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final LabOrderItem item = draft.item;
    final bool canRemove = canMutate && _canRemoveResult(item, draft);
    final String resultStatus = (item.effectiveResultStatus ?? '')
        .trim()
        .toUpperCase();
    final bool savesPendingDraft =
        item.resultId == null ||
        resultStatus.isEmpty ||
        resultStatus == 'PENDING';
    final List<Widget> actions = <Widget>[
      if (canMutate && item.canEnterResult && draft.hasEntry)
        AppButton.tertiary(
          label: savesPendingDraft
              ? l10n.labSaveDraftAction
              : l10n.commonSaveActionLabel,
          leadingIcon: Icons.save_outlined,
          onPressed: onSaveDraft,
        ),
      if (canMutate && item.canVerify && draft.hasEntry)
        AppButton.secondary(
          label: l10n.labVerifyResultAction,
          leadingIcon: Icons.verified_outlined,
          onPressed: onVerify,
        ),
      if (canRemove)
        AppButton.tertiary(
          label: l10n.labRemoveDraftResultAction,
          leadingIcon: Icons.delete_sweep_outlined,
          onPressed: onRemove,
        ),
      if (canMutate && item.canReject)
        AppButton.tertiary(
          label: l10n.labRejectOrderItemAction,
          leadingIcon: Icons.block_outlined,
          onPressed: onReject,
        ),
    ];

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: actions,
    );
  }
}

class _PanelGroupHeader extends StatelessWidget {
  const _PanelGroupHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              size: theme.appTokens.listIconSize * 0.82,
            ),
            SizedBox(width: theme.spacing.xs),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
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
    final LabOrderItem item = widget.draft.item;
    final AppLocalizations l10n = context.l10n;
    final bool enabled = widget.enabled;

    return Form(
      key: widget.draft.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (item.isNumeric) ...<Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stackFields = constraints.maxWidth < 300;
                final Widget valueField = AppTextField(
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
                );
                final Widget unitField = _ResultUnitInput(
                  item: item,
                  controller: widget.draft.unitController,
                  enabled: enabled,
                  onChanged: () {
                    setState(() {});
                    widget.draft.notifyChanged();
                  },
                );

                if (stackFields) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      valueField,
                      SizedBox(height: Theme.of(context).spacing.xs),
                      unitField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 6, child: valueField),
                    SizedBox(width: Theme.of(context).spacing.sm),
                    Expanded(flex: 5, child: unitField),
                  ],
                );
              },
            ),
          ] else if (item.isQualitative && item.resultOptions.isNotEmpty)
            AppSelectField<String>.searchable(
              value: widget.draft.selectedOption,
              labelText: l10n.labResultValueLabel,
              enabled: enabled,
              options: <AppSelectOption<String>>[
                for (final LabResultOption option in item.resultOptions)
                  AppSelectOption<String>(
                    value: option.value ?? option.label ?? option.id,
                    label: option.displayLabel,
                    leadingIcon: const Icon(Icons.checklist_outlined),
                    searchText:
                        '${option.id} ${option.label ?? ''} ${option.value ?? ''} ${option.status ?? ''} ${option.resultFlag ?? ''}',
                  ),
              ],
              onChanged: enabled
                  ? (String? value) {
                      setState(() => widget.draft.selectedOption = value);
                      widget.draft.notifyChanged();
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
          ),
        ],
      ),
    );
  }
}

class _ResultUnitInput extends StatelessWidget {
  const _ResultUnitInput({
    required this.item,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final LabOrderItem item;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (item.unitOptions.isEmpty) {
      return AppTextField(
        controller: controller,
        labelText: l10n.labResultUnitLabel,
        enabled: enabled,
      );
    }

    return AppSelectField<String>.searchable(
      value: controller.text.trim().isEmpty ? null : controller.text.trim(),
      labelText: l10n.labResultUnitLabel,
      enabled: enabled,
      options: <AppSelectOption<String>>[
        for (final LabUnitOption option in item.unitOptions)
          AppSelectOption<String>(
            value: option.unit ?? option.label ?? option.id,
            label: option.displayLabel,
            leadingIcon: const Icon(Icons.straighten_outlined),
            searchText:
                '${option.id} ${option.label ?? ''} ${option.unit ?? ''}',
          ),
      ],
      onChanged: (String? value) {
        controller.text = value ?? '';
        onChanged();
      },
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

class _LabReportPreviewDialog extends ConsumerStatefulWidget {
  const _LabReportPreviewDialog({required this.workflows});

  final List<LabOrderWorkflow> workflows;

  @override
  ConsumerState<_LabReportPreviewDialog> createState() =>
      _LabReportPreviewDialogState();
}

class _LabReportPreviewDialogState
    extends ConsumerState<_LabReportPreviewDialog> {
  late Set<String> _selectedOrderIds;
  late Set<String> _selectedItemIds;
  bool _showOrderDetails = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _resetSelection();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<LabOrderWorkflow> selectedWorkflows =
        _selectedWorkflowsForPreview();
    return AppDialog(
      title: Text(l10n.labReportPreviewTitle),
      icon: const Icon(Icons.print_outlined),
      scrollable: true,
      maxWidth: 1040,
      closeEnabled: !_isPrinting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.labReportSelectionTitle,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
          _selectionControls(context),
          SizedBox(height: Theme.of(context).spacing.md),
          AppReportPreviewPanel(
            title: l10n.labReportPreviewTitle,
            selectable: true,
            child: selectedWorkflows.isEmpty
                ? AppWorkspaceStatePanel.empty(
                    title: l10n.labReportNoSelectionLabel,
                    body: l10n.labNoOrderItemsEntryBody,
                    icon: Icons.print_disabled_outlined,
                  )
                : _LabReportPreview(
                    workflows: selectedWorkflows,
                    selectedItemIds: _selectedItemIds,
                    showOrderDetails: _showOrderDetails,
                  ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.labResetReportSelectionAction,
          enabled: !_isPrinting,
          onPressed: () => setState(_resetSelection),
        ),
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          enabled: !_isPrinting,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppReportActionButton.print(
          label: l10n.labPrintReportAction,
          isLoading: _isPrinting,
          enabled: selectedWorkflows.isNotEmpty,
          onPressed: selectedWorkflows.isEmpty
              ? null
              : () => _printSelectedReport(),
        ),
      ],
    );
  }

  Widget _selectionControls(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: SwitchListTile(
            value: _showOrderDetails,
            dense: true,
            title: Text('${l10n.labReportOrderLabel} details'),
            subtitle: Text(
              _showOrderDetails
                  ? 'Include compact order identifiers and dates.'
                  : 'Print selected tests without order headers.',
            ),
            onChanged: (bool value) {
              setState(() => _showOrderDetails = value);
            },
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        for (final LabOrderWorkflow workflow in widget.workflows)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: <Widget>[
                CheckboxListTile(
                  value: _selectedOrderIds.contains(workflow.order.apiId),
                  title: Text(
                    '${l10n.labOrderFieldLabel} ${workflow.order.displayId ?? workflow.order.apiId}',
                  ),
                  subtitle: Text(
                    _joinDisplay(<String?>[
                          _optionalDateTimeLabel(
                            context,
                            workflow.order.orderedAt,
                          ),
                          _statusLabel(context, workflow.order.status),
                        ]) ??
                        l10n.profileUnknownValue,
                  ),
                  onChanged: (bool? value) {
                    setState(() {
                      final bool selected = value ?? false;
                      final String orderKey = workflow.order.apiId;
                      if (selected) {
                        _selectedOrderIds.add(orderKey);
                        for (final LabOrderItem item in workflow.order.items) {
                          _selectedItemIds.add(_itemSelectionKey(item));
                        }
                      } else {
                        _selectedOrderIds.remove(orderKey);
                        for (final LabOrderItem item in workflow.order.items) {
                          _selectedItemIds.remove(_itemSelectionKey(item));
                        }
                      }
                    });
                  },
                ),
                for (final LabOrderItem item in workflow.order.items)
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: theme.spacing.lg,
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      value: _selectedItemIds.contains(_itemSelectionKey(item)),
                      title: Text(item.displayTitle),
                      subtitle: Text(
                        item.displayReferenceRange ?? l10n.profileUnknownValue,
                      ),
                      onChanged: (bool? value) {
                        setState(() {
                          final String itemKey = _itemSelectionKey(item);
                          if (value ?? false) {
                            _selectedItemIds.add(itemKey);
                            _selectedOrderIds.add(workflow.order.apiId);
                          } else {
                            _selectedItemIds.remove(itemKey);
                            if (!workflow.order.items.any(
                              (LabOrderItem candidate) => _selectedItemIds
                                  .contains(_itemSelectionKey(candidate)),
                            )) {
                              _selectedOrderIds.remove(workflow.order.apiId);
                            }
                          }
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _resetSelection() {
    _selectedOrderIds = widget.workflows
        .map((LabOrderWorkflow workflow) => workflow.order.apiId)
        .toSet();
    _selectedItemIds = <String>{
      for (final LabOrderWorkflow workflow in widget.workflows)
        for (final LabOrderItem item in workflow.order.items)
          _itemSelectionKey(item),
    };
  }

  List<LabOrderWorkflow> _selectedWorkflowsForPreview() {
    return widget.workflows
        .where((LabOrderWorkflow workflow) {
          return _selectedOrderIds.contains(workflow.order.apiId) &&
              workflow.order.items.any(
                (LabOrderItem item) =>
                    _selectedItemIds.contains(_itemSelectionKey(item)),
              );
        })
        .toList(growable: false);
  }

  Future<void> _printSelectedReport() async {
    final AppLocalizations l10n = context.l10n;
    final List<LabOrderWorkflow> workflows = _selectedWorkflowsForPreview();
    if (workflows.isEmpty) {
      return;
    }
    setState(() => _isPrinting = true);
    await printFormTemplateDocument(
      ref: ref,
      context: context,
      title: l10n.labReportTitle,
      metadata: _reportMetadata(context, workflows),
      pages: _reportPages(
        context,
        workflows,
        _selectedItemIds,
        showOrderDetails: _showOrderDetails,
      ),
      footerNote: l10n.labReportFooter,
    );
    if (mounted) {
      setState(() => _isPrinting = false);
    }
  }
}

class _LabReportPreview extends StatelessWidget {
  const _LabReportPreview({
    required this.workflows,
    required this.selectedItemIds,
    required this.showOrderDetails,
  });

  final List<LabOrderWorkflow> workflows;
  final Set<String> selectedItemIds;
  final bool showOrderDetails;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final LabOrderSummary firstOrder = workflows.first.order;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.labReportTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            _PreviewMeta(
              label: l10n.labReportPatientLabel,
              value: firstOrder.patientDisplayName ?? l10n.profileUnknownValue,
            ),
            if (firstOrder.patientId != null)
              _PreviewMeta(
                label: l10n.labPatientIdFieldLabel,
                value: firstOrder.patientId!,
              ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (showOrderDetails)
          for (final LabOrderWorkflow workflow in workflows) ...<Widget>[
            Text(
              '${l10n.labOrderFieldLabel} ${workflow.order.displayId ?? workflow.order.apiId}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: theme.spacing.xs),
            _PreviewResultsTable(
              items: workflow.order.items
                  .where(
                    (LabOrderItem item) =>
                        selectedItemIds.contains(_itemSelectionKey(item)),
                  )
                  .toList(growable: false),
            ),
            SizedBox(height: theme.spacing.md),
          ]
        else ...<Widget>[
          _PreviewResultsTable(
            items: _selectedReportItems(workflows, selectedItemIds),
          ),
          SizedBox(height: theme.spacing.md),
        ],
        Text(
          l10n.labReportSignatureLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PreviewMeta extends StatelessWidget {
  const _PreviewMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      '$label: $value',
      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _PreviewResultsTable extends StatelessWidget {
  const _PreviewResultsTable({required this.items});

  final List<LabOrderItem> items;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    if (items.isEmpty) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.labNoOrderItemsEntryTitle,
        body: l10n.labNoOrderItemsEntryBody,
        icon: Icons.science_outlined,
      );
    }
    return Table(
      border: TableBorder.all(color: theme.colorScheme.outlineVariant),
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(1.5),
      },
      children: <TableRow>[
        TableRow(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          children: <Widget>[
            _PreviewCell(text: l10n.labTestsColumnLabel, isHeader: true),
            _PreviewCell(text: l10n.labReferenceRangeLabel, isHeader: true),
            _PreviewCell(text: l10n.labReportResultLabel, isHeader: true),
            _PreviewCell(text: l10n.labResultFlagLabel, isHeader: true),
          ],
        ),
        for (final LabOrderItem item in items)
          TableRow(
            children: <Widget>[
              _PreviewCell(text: item.displayTitle),
              _PreviewCell(
                text: item.displayReferenceRange ?? l10n.profileUnknownValue,
              ),
              _PreviewCell(
                text: item.displayResultValue ?? l10n.labStatusPendingResults,
              ),
              _PreviewCell(
                text: _statusLabel(
                  context,
                  item.resultFlag ?? item.effectiveResultStatus,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({required this.text, this.isHeader = false});

  final String text;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(theme.spacing.xs),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: isHeader ? FontWeight.w800 : null,
        ),
      ),
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
  VoidCallback? _onChanged;
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

  void addListener(VoidCallback listener) {
    _onChanged = listener;
    valueController.addListener(listener);
    unitController.addListener(listener);
    textController.addListener(listener);
    notesController.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    valueController.removeListener(listener);
    unitController.removeListener(listener);
    textController.removeListener(listener);
    notesController.removeListener(listener);
    if (_onChanged == listener) {
      _onChanged = null;
    }
  }

  void notifyChanged() {
    _onChanged?.call();
  }

  void clearEntry() {
    valueController.clear();
    textController.clear();
    notesController.clear();
    selectedOption = null;
    notifyChanged();
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
            AppSelectField<String>.searchable(
              value: _reason,
              labelText: l10n.labRejectReasonLabel,
              enabled: !_isSaving,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              options: <AppSelectOption<String>>[
                AppSelectOption<String>(
                  value: l10n.labRejectReasonNotPerformedHere,
                  label: l10n.labRejectReasonNotPerformedHere,
                  leadingIcon: const Icon(Icons.location_off_outlined),
                ),
                AppSelectOption<String>(
                  value: l10n.labRejectReasonInsufficientInfo,
                  label: l10n.labRejectReasonInsufficientInfo,
                  leadingIcon: const Icon(Icons.info_outline),
                ),
                AppSelectOption<String>(
                  value: l10n.labRejectReasonInvalidRequest,
                  label: l10n.labRejectReasonInvalidRequest,
                  leadingIcon: const Icon(Icons.report_problem_outlined),
                ),
                AppSelectOption<String>(
                  value: l10n.labRejectReasonOther,
                  label: l10n.labRejectReasonOther,
                  leadingIcon: const Icon(Icons.more_horiz),
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

String _resultFlagLabel(
  BuildContext context,
  LabOrderItem item,
  _ResultDraft draft,
) {
  final AppLocalizations l10n = context.l10n;
  final String? explicitFlag = item.resultFlag;
  if (explicitFlag != null && explicitFlag.trim().isNotEmpty) {
    return _statusLabel(context, explicitFlag);
  }

  if (item.isQualitative) {
    final String? optionFlag = _selectedResultOptionFlag(item, draft);
    if (optionFlag != null && optionFlag.trim().isNotEmpty) {
      return _statusLabel(context, optionFlag);
    }
  }

  if (item.isNumeric && draft.hasEntry && item.referenceRanges.isNotEmpty) {
    final num? parsed = num.tryParse(draft.valueController.text.trim());
    if (parsed != null) {
      final LabReferenceRange range = item.referenceRanges.first;
      final num? min = num.tryParse(range.normalMinValue ?? '');
      final num? max = num.tryParse(range.normalMaxValue ?? '');
      if (min != null && parsed < min) {
        return l10n.labStatusLow;
      }
      if (max != null && parsed > max) {
        return l10n.labStatusHigh;
      }
      return l10n.labStatusNormal;
    }
  }

  return _statusLabel(context, item.effectiveResultStatus);
}

String? _selectedResultOptionFlag(LabOrderItem item, _ResultDraft draft) {
  final String selected = draft.selectedOption?.trim() ?? '';
  if (selected.isEmpty) {
    return null;
  }
  for (final LabResultOption option in item.resultOptions) {
    final Set<String> optionValues = <String>{
      option.value ?? '',
      option.label ?? '',
      option.id,
    }..removeWhere((String value) => value.trim().isEmpty);
    if (!optionValues.contains(selected)) {
      continue;
    }
    return option.resultFlag ?? option.status;
  }
  return null;
}

bool _canRemoveResult(LabOrderItem item, _ResultDraft draft) {
  if (item.isCompleted || item.isRejected) {
    return false;
  }
  if (item.resultId != null && item.resultId!.trim().isNotEmpty) {
    return true;
  }
  return draft.hasEntry;
}

AppWorkspaceStatus _orderStatus(BuildContext context, String? value) {
  return _statusBadge(context, value);
}

AppWorkspaceStatus _aggregateOrderStatus(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
) {
  if (workflows.any(
    (LabOrderWorkflow workflow) => workflow.order.hasCriticalResult,
  )) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusCritical,
      tone: AppWorkspaceStatusTone.error,
      icon: Icons.priority_high_outlined,
    );
  }
  if (workflows.every(
    (LabOrderWorkflow workflow) => _isVerifiedOrder(workflow.order),
  )) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusVerified,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }
  return _statusBadge(context, workflows.first.order.status);
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

AppWorkspaceStatus _resultStatus(BuildContext context, LabOrderSummary order) {
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
  if (_isVerifiedOrder(order)) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusVerified,
      tone: AppWorkspaceStatusTone.success,
      icon: Icons.verified_outlined,
    );
  }
  final int active = _activeResultItemCount(order);
  final int completed = _completedResultItemCount(order);
  if (active == 0 || completed == 0) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusPendingResults,
      tone: AppWorkspaceStatusTone.warning,
      icon: Icons.hourglass_empty_outlined,
    );
  }
  if (completed < active) {
    return AppWorkspaceStatus(
      label: context.l10n.labStatusPartiallyFilled,
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

List<LabOrderWorkflow> _selectedWorkflows(LabWorkspaceState? state) {
  final List<LabOrderWorkflow> selected =
      state?.selectedWorkflows ?? const <LabOrderWorkflow>[];
  if (selected.isNotEmpty) {
    return selected;
  }
  final LabOrderWorkflow? workflow = state?.selectedWorkflow;
  if (workflow == null) {
    return const <LabOrderWorkflow>[];
  }
  return <LabOrderWorkflow>[workflow];
}

String _detailSubtitle(BuildContext context, List<LabOrderWorkflow> workflows) {
  final AppLocalizations l10n = context.l10n;
  final LabOrderSummary order = workflows.first.order;
  if (workflows.length == 1) {
    return l10n.labResultEntryDialogSubtitle(
      order.patientDisplayName ?? l10n.profileUnknownValue,
      order.displayId ?? order.apiId,
    );
  }
  return _joinDisplay(<String?>[
        order.patientDisplayName ?? l10n.profileUnknownValue,
        l10n.labActiveOrderCount(workflows.length),
      ]) ??
      l10n.profileUnknownValue;
}

String _draftSignatureFor(List<LabOrderWorkflow> workflows) {
  return workflows
      .map((LabOrderWorkflow workflow) {
        final String itemSignature = workflow.order.items
            .map((LabOrderItem item) {
              return <String?>[
                item.apiId,
                item.status,
                item.resultStatus,
                item.resultId,
                item.resultValue,
                item.resultText,
                item.resultUnit,
                item.resultFlag,
                item.updatedAt?.toIso8601String(),
              ].join(':');
            })
            .join(',');
        return '${workflow.order.apiId}[$itemSignature]';
      })
      .join('|');
}

List<_ResultDraft> _draftsForWorkflow(
  List<_ResultDraft> drafts,
  LabOrderWorkflow workflow,
) {
  final Set<String> itemIds = workflow.order.items
      .map((LabOrderItem item) => item.apiId)
      .toSet();
  return drafts
      .where((_ResultDraft draft) => itemIds.contains(draft.item.apiId))
      .toList(growable: false);
}

List<_LabPanelDraftGroup> _groupDraftsForDisplay(
  List<_ResultDraft> drafts,
  List<LabCatalogItem> catalogPanels,
) {
  final List<_LabPanelDraftGroup> groups = <_LabPanelDraftGroup>[];
  final List<_ResultDraft> remaining = <_ResultDraft>[...drafts];
  final Map<String, List<_ResultDraft>> explicitGroups =
      <String, List<_ResultDraft>>{};
  final Map<String, String> explicitTitles = <String, String>{};

  for (final _ResultDraft draft in drafts) {
    final String? key = draft.item.panelKey;
    if (key == null) {
      continue;
    }
    explicitGroups.putIfAbsent(key, () => <_ResultDraft>[]).add(draft);
    explicitTitles[key] = draft.item.panelTitle ?? key;
  }
  for (final MapEntry<String, List<_ResultDraft>> entry
      in explicitGroups.entries) {
    entry.value.sort(_compareDraftsByPanelOrder);
    groups.add(
      _LabPanelDraftGroup(
        panelTitle: explicitTitles[entry.key],
        drafts: entry.value,
      ),
    );
    remaining.removeWhere((_ResultDraft draft) => entry.value.contains(draft));
  }

  final List<LabCatalogItem> panelCandidates = catalogPanels
      .where(
        (LabCatalogItem panel) => panel.isPanel && panel.panelItems.length > 1,
      )
      .toList(growable: false);
  final Set<String> assignedTestIds = <String>{};
  for (final LabCatalogItem panel in panelCandidates) {
    final List<String> childIds = panel.panelItems
        .map((LabPanelItem item) => item.labTestId?.trim() ?? '')
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (childIds.isEmpty || childIds.any(assignedTestIds.contains)) {
      continue;
    }
    final List<_ResultDraft> panelDrafts = <_ResultDraft>[];
    bool completeMatch = true;
    for (final String childId in childIds) {
      final List<_ResultDraft> matches = remaining
          .where((_ResultDraft draft) => draft.item.labTestId == childId)
          .toList(growable: false);
      if (matches.length != 1) {
        completeMatch = false;
        break;
      }
      panelDrafts.add(matches.first);
    }
    if (!completeMatch || panelDrafts.length < 2) {
      continue;
    }
    panelDrafts.sort((a, b) {
      final int aSort = _panelItemSort(panel, a.item.labTestId);
      final int bSort = _panelItemSort(panel, b.item.labTestId);
      return aSort.compareTo(bSort);
    });
    groups.add(
      _LabPanelDraftGroup(panelTitle: panel.displayTitle, drafts: panelDrafts),
    );
    for (final _ResultDraft draft in panelDrafts) {
      remaining.remove(draft);
      if (draft.item.labTestId != null) {
        assignedTestIds.add(draft.item.labTestId!);
      }
    }
  }

  for (final _ResultDraft draft in remaining) {
    groups.add(_LabPanelDraftGroup(drafts: <_ResultDraft>[draft]));
  }
  return groups;
}

int _compareDraftsByPanelOrder(_ResultDraft left, _ResultDraft right) {
  final int panelComparison = (left.item.panelSortOrder ?? 0).compareTo(
    right.item.panelSortOrder ?? 0,
  );
  if (panelComparison != 0) {
    return panelComparison;
  }
  final int itemComparison = (left.item.panelItemSortOrder ?? 0).compareTo(
    right.item.panelItemSortOrder ?? 0,
  );
  if (itemComparison != 0) {
    return itemComparison;
  }
  return left.item.displayTitle.compareTo(right.item.displayTitle);
}

int _panelItemSort(LabCatalogItem panel, String? labTestId) {
  for (final LabPanelItem item in panel.panelItems) {
    if (item.labTestId == labTestId) {
      return item.sortOrder;
    }
  }
  return 0;
}

final class _LabPanelDraftGroup {
  const _LabPanelDraftGroup({required this.drafts, this.panelTitle});

  final String? panelTitle;
  final List<_ResultDraft> drafts;
}

List<PrintFormMetadataItem> _reportMetadata(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
) {
  final AppLocalizations l10n = context.l10n;
  final LabOrderSummary firstOrder = workflows.first.order;
  final List<String> encounterIds = _uniqueNonEmpty(
    workflows.map((LabOrderWorkflow workflow) => workflow.order.encounterId),
  );
  return <PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.labReportPatientLabel,
      value: firstOrder.patientDisplayName ?? l10n.profileUnknownValue,
    ),
    if (firstOrder.patientId != null)
      PrintFormMetadataItem(
        label: l10n.labPatientIdFieldLabel,
        value: firstOrder.patientId!,
      ),
    if (encounterIds.length == 1)
      PrintFormMetadataItem(
        label: l10n.labEncounterFieldLabel,
        value: encounterIds.single,
      ),
  ];
}

List<PrintFormPage> _reportPages(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
  Set<String> selectedItemIds, {
  required bool showOrderDetails,
}) {
  final AppLocalizations l10n = context.l10n;
  return <PrintFormPage>[
    PrintFormPage(
      title: l10n.labReportTitle,
      bodyHtml: _labReportHtml(
        context,
        workflows,
        selectedItemIds,
        showOrderDetails: showOrderDetails,
      ),
    ),
  ];
}

String _labReportHtml(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
  Set<String> selectedItemIds, {
  required bool showOrderDetails,
}) {
  final String body = showOrderDetails
      ? workflows.map((LabOrderWorkflow workflow) {
          final List<LabOrderItem> items = workflow.order.items
              .where(
                (LabOrderItem item) =>
                    selectedItemIds.contains(_itemSelectionKey(item)),
              )
              .toList(growable: false);
          return _labReportOrderHtml(context, workflow, items);
        }).join()
      : _labReportTableHtml(
          context,
          _selectedReportItems(workflows, selectedItemIds),
        );
  return '''
${_labReportPrintStyle()}
<div class="lab-report-compact">
  $body
  ${_labReportSignatureHtml(context)}
</div>
''';
}

String _labReportOrderHtml(
  BuildContext context,
  LabOrderWorkflow workflow,
  List<LabOrderItem> items,
) {
  final AppLocalizations l10n = context.l10n;
  final LabOrderSummary order = workflow.order;
  final String details = PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
    PrintFormMetadataItem(
      label: l10n.labReportOrderLabel,
      value: order.displayId ?? order.apiId,
    ),
    if (_optionalDateTimeLabel(context, order.orderedAt) != null)
      PrintFormMetadataItem(
        label: l10n.labOrderedAtFieldLabel,
        value: _optionalDateTimeLabel(context, order.orderedAt)!,
      ),
    PrintFormMetadataItem(
      label: l10n.labOrderStatusFieldLabel,
      value: _statusLabel(context, order.status),
    ),
  ]);
  final String table = _labReportTableHtml(context, items);
  return '''
<section class="lab-report-order">
  <h2>${PrintFormTemplate.escape('${l10n.labOrderFieldLabel} ${order.displayId ?? order.apiId}')}</h2>
  $details
  $table
</section>
''';
}

String _labReportTableHtml(BuildContext context, List<LabOrderItem> items) {
  final AppLocalizations l10n = context.l10n;
  final String table = PrintFormTemplate.table(
    headers: <String>[
      l10n.labTestsColumnLabel,
      l10n.labReferenceRangeLabel,
      l10n.labReportResultLabel,
      l10n.labResultFlagLabel,
    ],
    rows: <List<String>>[
      for (final LabOrderItem item in items)
        <String>[
          item.displayTitle,
          item.displayReferenceRange ?? l10n.profileUnknownValue,
          item.displayResultValue ?? l10n.labStatusPendingResults,
          _statusLabel(context, item.resultFlag ?? item.effectiveResultStatus),
        ],
    ],
    emptyText: l10n.labNoOrderItemsEntryTitle,
  );
  return '<div class="lab-report-tests">$table</div>';
}

String _labReportSignatureHtml(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return '''
<div class="print-template-signatures">
  <div class="print-template-signature">${PrintFormTemplate.escape(l10n.labReportVerifiedLabel)}</div>
  <div class="print-template-signature">${PrintFormTemplate.escape(l10n.labReportSignatureLabel)}</div>
</div>
''';
}

String _labReportPrintStyle() {
  return '''
<style>
  .lab-report-compact .print-template-kv {
    grid-template-columns: repeat(3, minmax(0, 1fr));
    gap: 1.5mm;
    margin-bottom: 2.5mm;
  }
  .lab-report-compact .print-template-kv-item {
    padding: 1.5mm;
  }
  .lab-report-order {
    margin: 0 0 4mm;
  }
  .lab-report-order h2 {
    font-size: 12px;
    line-height: 1.2;
    margin: 0 0 2mm;
  }
  .lab-report-tests .print-template-table th,
  .lab-report-tests .print-template-table td {
    padding: 1.6mm;
  }
  .lab-report-tests .print-template-table th:nth-child(1),
  .lab-report-tests .print-template-table td:nth-child(1) {
    width: 36%;
  }
  .lab-report-tests .print-template-table th:nth-child(2),
  .lab-report-tests .print-template-table td:nth-child(2) {
    width: 30%;
  }
  .lab-report-tests .print-template-table th:nth-child(3),
  .lab-report-tests .print-template-table td:nth-child(3) {
    width: 22%;
  }
  .lab-report-compact .print-template-signatures {
    break-inside: avoid;
    page-break-inside: avoid;
    margin-top: 12mm;
  }
</style>
''';
}

String _itemSelectionKey(LabOrderItem item) {
  return _joinDisplay(<String?>[item.labOrderId, item.apiId]) ?? item.apiId;
}

List<LabOrderItem> _selectedReportItems(
  List<LabOrderWorkflow> workflows,
  Set<String> selectedItemIds,
) {
  return <LabOrderItem>[
    for (final LabOrderWorkflow workflow in workflows)
      for (final LabOrderItem item in workflow.order.items)
        if (selectedItemIds.contains(_itemSelectionKey(item))) item,
  ];
}

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
