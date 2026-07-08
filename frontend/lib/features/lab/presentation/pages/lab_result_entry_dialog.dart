import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_status_display.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

part 'lab_result_entry_status.dart';

const String _labReportFlagFilterKey = 'flag';
const String _labReportSelectionFilterKey = 'selection';
const int _maxVisibleLabReportPreviewItems = 120;

/// Full-screen lab result entry workspace opened from the lab worklist or queue.
class LabResultEntryDialog extends ConsumerStatefulWidget {
  const LabResultEntryDialog({
    required this.canMutate,
    this.onEditOrder,
    this.onCreateAdditionalOrder,
    this.onDeleteOrder,
    super.key,
  });

  final bool canMutate;
  final Future<void> Function(BuildContext context, LabOrderWorkflow workflow)?
  onEditOrder;
  final Future<void> Function(BuildContext context, LabOrderWorkflow workflow)?
  onCreateAdditionalOrder;
  final Future<void> Function(BuildContext context, LabOrderWorkflow workflow)?
  onDeleteOrder;

  @override
  ConsumerState<LabResultEntryDialog> createState() =>
      _LabResultEntryDialogState();
}

class _LabResultEntryDialogState extends ConsumerState<LabResultEntryDialog> {
  List<_ResultDraft>? _drafts;
  String? _draftSignature;
  final Set<String> _selectedItemIds = <String>{};
  bool _selectionInitialized = false;
  AppFailure? _failure;
  int? _batchValidationIssueCount;
  String? _labActionFailureMessage;
  bool _isSaving = false;

  @override
  void dispose() {
    _disposeDrafts();
    super.dispose();
  }

  void _handleDraftChanged() {
    if (mounted) {
      setState(() {
        _batchValidationIssueCount = null;
        _labActionFailureMessage = null;
      });
    }
  }

  void _clearLabActionFeedback() {
    _batchValidationIssueCount = null;
    _labActionFailureMessage = null;
    _failure = null;
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
    if (_drafts == null) {
      _createDrafts(workflows);
      _draftSignature = signature;
      return;
    }
    _patchDraftsFromWorkflows(workflows);
    _draftSignature = signature;
  }

  void _createDrafts(List<LabOrderWorkflow> workflows) {
    _disposeDrafts();
    final List<_ResultDraft> drafts = <_ResultDraft>[
      for (final LabOrderWorkflow workflow in workflows)
        for (final LabOrderItem item in workflow.order.items)
          _ResultDraft(item),
    ];
    for (final _ResultDraft draft in drafts) {
      draft.addListener(_handleDraftChanged);
    }
    _drafts = drafts;
    _syncSelection(drafts);
  }

  void _patchDraftsFromWorkflows(
    List<LabOrderWorkflow> workflows, {
    Set<String>? affectedItemIds,
  }) {
    final List<_ResultDraft>? drafts = _drafts;
    if (drafts == null) {
      _createDrafts(workflows);
      return;
    }

    final Map<String, LabOrderItem> itemsById = <String, LabOrderItem>{
      for (final LabOrderWorkflow workflow in workflows)
        for (final LabOrderItem item in workflow.order.items) item.apiId: item,
    };
    final Set<String> nextItemIds = itemsById.keys.toSet();
    final Set<String> existingItemIds = drafts
        .map((_ResultDraft draft) => draft.item.apiId)
        .toSet();

    drafts.removeWhere(
      (_ResultDraft draft) => !nextItemIds.contains(draft.item.apiId),
    );

    for (final _ResultDraft draft in drafts) {
      final LabOrderItem? updatedItem = itemsById[draft.item.apiId];
      if (updatedItem == null) {
        continue;
      }
      if (affectedItemIds != null &&
          !affectedItemIds.contains(draft.item.apiId)) {
        continue;
      }
      draft.applyServerItem(
        updatedItem,
        preserveUserEntry: draft.hasChangedEntry,
      );
    }

    for (final String itemId in nextItemIds.difference(existingItemIds)) {
      final LabOrderItem? item = itemsById[itemId];
      if (item == null) {
        continue;
      }
      final _ResultDraft draft = _ResultDraft(item);
      draft.addListener(_handleDraftChanged);
      drafts.add(draft);
    }

    _syncSelection(drafts);
  }

  void _applyWorkflowUpdates({Set<String>? affectedItemIds}) {
    final LabWorkspaceState? state = ref
        .read(labWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (LabWorkspaceState value) => value,
          failure: (_) => null,
        );
    final List<LabOrderWorkflow> workflows = _selectedWorkflows(state);
    if (workflows.isEmpty) {
      return;
    }
    _patchDraftsFromWorkflows(workflows, affectedItemIds: affectedItemIds);
    _draftSignature = _draftSignatureFor(workflows);
  }

  void _syncSelection(List<_ResultDraft> drafts) {
    final Set<String> validIds = drafts
        .map((_ResultDraft draft) => draft.item.apiId)
        .toSet();
    _selectedItemIds.removeWhere((String id) => !validIds.contains(id));
    if (!_selectionInitialized && drafts.isNotEmpty) {
      _selectionInitialized = true;
      _selectedItemIds.addAll(
        drafts
            .where(_isBulkSelectable)
            .map((_ResultDraft draft) => draft.item.apiId),
      );
    }
  }

  void _toggleItemSelection(String itemId, {required bool selected}) {
    setState(() {
      if (selected) {
        _selectedItemIds.add(itemId);
      } else {
        _selectedItemIds.remove(itemId);
      }
    });
  }

  void _selectAllItems(List<_ResultDraft> drafts) {
    setState(() {
      _selectedItemIds
        ..clear()
        ..addAll(
          drafts
              .where(_isBulkSelectable)
              .map((_ResultDraft draft) => draft.item.apiId),
        );
    });
  }

  void _clearItemSelection() {
    if (_selectedItemIds.isEmpty) {
      return;
    }
    setState(_selectedItemIds.clear);
  }

  List<_ResultDraft> _selectedDrafts(List<_ResultDraft> drafts) {
    if (_selectedItemIds.isEmpty) {
      return const <_ResultDraft>[];
    }
    return drafts
        .where(
          (_ResultDraft draft) => _selectedItemIds.contains(draft.item.apiId),
        )
        .toList(growable: false);
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
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
    final bool compact = MediaQuery.sizeOf(context).width < 600;
    final bool showActionLabels = AppBreakpoints.of(
      context,
    ).showsToolbarActionLabels;
    final Color destructiveActionColor = theme.statusColors.danger;

    return AppActionLabelScope(
      showLabels: showActionLabels,
      forceIconOnly: !showActionLabels,
      child: AppDialog(
        title: Text(l10n.labResultEntryDialogTitle),
        icon: const Icon(Icons.biotech_outlined),
        scrollable: true,
        maxWidth: compact ? double.infinity : 1600,
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
            ? const <Widget>[]
            : <Widget>[
                AppReportActionButton.preview(
                  label: l10n.labPreviewReportAction,
                  enabled: !_isSaving,
                  onPressed: () => _openPrintPreview(context, workflows),
                ),
                if (workflows.length == 1 &&
                    canMutate &&
                    widget.onCreateAdditionalOrder != null)
                  AppButton.secondary(
                    label: l10n.labCreateAction,
                    leadingIcon: Icons.add_circle_outline,
                    enabled: !_isSaving,
                    onPressed: () => widget.onCreateAdditionalOrder?.call(
                      context,
                      workflows.first,
                    ),
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
                    color: destructiveActionColor,
                    enabled: !_isSaving,
                    onPressed: () =>
                        widget.onDeleteOrder?.call(context, workflows.first),
                  ),
              ],
      ),
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

    final List<_ResultDraft> selectedDrafts = _selectedDrafts(drafts);
    final List<_ResultDraft> saveTargets = _selectedSaveTargets(selectedDrafts);
    final List<_ResultDraft> submitTargets = _selectedSubmitTargets(
      selectedDrafts,
    );
    final List<_ResultDraft> verifyTargets = _selectedVerifyTargets(
      selectedDrafts,
    );
    final List<_ResultDraft> draftableEntries = saveTargets
        .where(_canSaveDraft)
        .toList(growable: false);
    final List<_ResultDraft> submittableDrafts = submitTargets
        .where(_canSubmitDraft)
        .toList(growable: false);
    final List<_ResultDraft> verifiableDrafts = verifyTargets
        .where(_canVerifyDraft)
        .toList(growable: false);
    final List<_ResultDraft> removableDrafts = selectedDrafts
        .where((draft) => _canRemoveResult(draft.item, draft))
        .toList(growable: false);
    final List<LabOrderItem> rejectableItems = selectedDrafts
        .map((_ResultDraft draft) => draft.item)
        .where((LabOrderItem item) => item.canReject)
        .toList(growable: false);
    final int selectableCount = drafts.where(_isBulkSelectable).length;
    final bool hasBulkActions =
        canMutate &&
        selectableCount > 0 &&
        (draftableEntries.isNotEmpty ||
            submitTargets.isNotEmpty ||
            verifyTargets.isNotEmpty ||
            removableDrafts.isNotEmpty ||
            rejectableItems.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_batchValidationIssueCount != null) ...<Widget>[
          AppFormInformationBanner(
            title: l10n.labBatchValidationSummaryMessage(
              _batchValidationIssueCount!,
            ),
            message: l10n.labBatchValidationSummaryHint,
            variant: AppFormInformationVariant.error,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        if (_labActionFailureMessage != null) ...<Widget>[
          AppFormInformationBanner.message(
            message: _labActionFailureMessage!,
            variant: AppFormInformationVariant.error,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        if (_failure != null) ...<Widget>[
          AppFormInformationBanner.failure(
            context: context,
            failure: _failure!,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        _LabResultContextHeader(workflows: workflows),
        SizedBox(height: Theme.of(context).spacing.md),
        if (hasBulkActions) ...<Widget>[
          _LabBulkResultActionsBar(
            draftableEntries: draftableEntries,
            submittableDrafts: submittableDrafts,
            verifiableDrafts: verifiableDrafts,
            removableDrafts: removableDrafts,
            rejectableItems: rejectableItems,
            selectedCount: _selectedItemIds.length,
            selectableCount: selectableCount,
            isSaving: _isSaving,
            onSaveDrafts: _saveDrafts,
            onSubmitDrafts: _submitDrafts,
            onVerifyDrafts: _verifyDrafts,
            saveTargets: saveTargets,
            submitTargets: submitTargets,
            verifyTargets: verifyTargets,
            onRemoveDrafts: _removeDraftResults,
            onRejectItems: _openRejectDialog,
            onSelectAll: () => _selectAllItems(drafts),
            onClearSelection: _clearItemSelection,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        if (isLoading) ...<Widget>[
          const LinearProgressIndicator(minHeight: 2),
          SizedBox(height: Theme.of(context).spacing.md),
        ],
        if (_isSaving) ...<Widget>[
          _LabApplyingChangesBanner(
            message: l10n.labApplyingResultChangesMessage,
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
        ],
        AbsorbPointer(
          absorbing: _isSaving,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final LabOrderWorkflow workflow in workflows) ...<Widget>[
                _LabOrderResultSection(
                  workflow: workflow,
                  drafts: _draftsForWorkflow(drafts, workflow),
                  catalogPanels: catalogPanels,
                  canMutate: canMutate,
                  selectedItemIds: _selectedItemIds,
                  onToggleItemSelection: canMutate
                      ? _toggleItemSelection
                      : null,
                  onSaveDraft: _saveDraft,
                  onSubmitItem: _submitDraft,
                  onVerifyItem: _verifyOrderItem,
                  onEditVerified: _editVerifiedResult,
                  onRejectItem: (LabOrderItem item) =>
                      _openRejectDialog(<LabOrderItem>[item]),
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
          ),
        ),
      ],
    );
  }

  Future<void> _saveDraft(_ResultDraft draft) async {
    await _persistDrafts(
      <_ResultDraft>[draft],
      (List<_ResultDraft> validDrafts) => ref
          .read(labWorkspaceControllerProvider.notifier)
          .saveOrderItemDrafts(
            validDrafts
                .map(
                  (_ResultDraft draft) =>
                      (item: draft.item, payload: draft.toDraftPayload()),
                )
                .toList(growable: false),
          ),
      successMessage: context.l10n.labDraftSavedMessage,
      partialMessage: context.l10n.labBatchPartialSaveMessage,
      actionLabel: context.l10n.labSaveDraftAction,
    );
  }

  Future<void> _submitDraft(_ResultDraft draft) async {
    await _persistDrafts(
      <_ResultDraft>[draft],
      _submitAndVerifyValidDrafts,
      successMessage: context.l10n.labResultsVerifiedMessage,
      partialMessage: context.l10n.labBatchPartialVerifyMessage,
      actionLabel: context.l10n.labSubmitResultAction,
      forVerify: true,
    );
  }

  Future<void> _saveDrafts(List<_ResultDraft> drafts) async {
    await _persistDrafts(
      drafts,
      (List<_ResultDraft> validDrafts) => ref
          .read(labWorkspaceControllerProvider.notifier)
          .saveOrderItemDrafts(
            validDrafts
                .map(
                  (_ResultDraft draft) =>
                      (item: draft.item, payload: draft.toDraftPayload()),
                )
                .toList(growable: false),
          ),
      successMessage: context.l10n.labDraftSavedMessage,
      partialMessage: context.l10n.labBatchPartialSaveMessage,
      actionLabel: context.l10n.labSaveAllDraftsAction,
    );
  }

  Future<void> _submitDrafts(List<_ResultDraft> drafts) async {
    await _persistDrafts(
      drafts,
      _submitAndVerifyValidDrafts,
      successMessage: context.l10n.labResultsVerifiedMessage,
      partialMessage: context.l10n.labBatchPartialVerifyMessage,
      forVerify: true,
      actionLabel: context.l10n.labSubmitAllResultsAction,
    );
  }

  Future<void> _verifyDrafts(List<_ResultDraft> drafts) async {
    await _persistDrafts(
      drafts,
      _verifyValidDrafts,
      successMessage: context.l10n.labResultsVerifiedMessage,
      partialMessage: context.l10n.labBatchPartialVerifyMessage,
      forVerify: true,
      actionLabel: context.l10n.labVerifyAllAction,
    );
  }

  List<_ResultDraft> _draftsNeedingPersistBeforeVerify(
    List<_ResultDraft> validDrafts,
  ) {
    return validDrafts
        .where(
          (_ResultDraft draft) =>
              draft.hasEntry &&
              draft.item.canEnterResult &&
              (!_hasSavedResult(draft.item) || draft.hasChangedEntry),
        )
        .toList(growable: false);
  }

  Future<LabBatchPersistOutcome> _submitAndVerifyValidDrafts(
    List<_ResultDraft> validDrafts,
  ) async {
    final List<_ResultDraft> needsSubmit = _draftsNeedingPersistBeforeVerify(
      validDrafts,
    );
    if (needsSubmit.isNotEmpty) {
      final LabBatchPersistOutcome submitOutcome = await ref
          .read(labWorkspaceControllerProvider.notifier)
          .submitOrderItemDrafts(
            needsSubmit
                .map(
                  (_ResultDraft draft) =>
                      (item: draft.item, payload: draft.toSubmittedPayload()),
                )
                .toList(growable: false),
          );
      if (submitOutcome.savedCount == 0) {
        return submitOutcome;
      }
    }

    return _verifyPersistedDrafts(validDrafts);
  }

  Future<LabBatchPersistOutcome> _verifyValidDrafts(
    List<_ResultDraft> validDrafts,
  ) async {
    final List<_ResultDraft> needsSubmit = _draftsNeedingPersistBeforeVerify(
      validDrafts,
    );
    if (needsSubmit.isNotEmpty) {
      final LabBatchPersistOutcome submitOutcome = await ref
          .read(labWorkspaceControllerProvider.notifier)
          .submitOrderItemDrafts(
            needsSubmit
                .map(
                  (_ResultDraft draft) =>
                      (item: draft.item, payload: draft.toSubmittedPayload()),
                )
                .toList(growable: false),
          );
      if (submitOutcome.savedCount == 0) {
        return submitOutcome;
      }
    }

    return _verifyPersistedDrafts(validDrafts);
  }

  Future<LabBatchPersistOutcome> _verifyPersistedDrafts(
    List<_ResultDraft> validDrafts,
  ) async {
    final List<({LabOrderItem item, Map<String, Object?> payload})> entries =
        <({LabOrderItem item, Map<String, Object?> payload})>[];
    for (final _ResultDraft draft in validDrafts) {
      final LabOrderItem? freshItem = _freshItemForDraft(draft);
      if (freshItem == null) {
        return LabBatchPersistOutcome(
          lastFailure: AppFailure.validation(code: 'lab.result.item_not_found'),
          failedItemIds: <String>[draft.item.apiId],
        );
      }
      entries.add((item: freshItem, payload: draft.toVerifiedPayload()));
    }
    return ref
        .read(labWorkspaceControllerProvider.notifier)
        .submitOrderItemResults(entries);
  }

  LabOrderItem? _freshItemForDraft(_ResultDraft draft) {
    final LabWorkspaceState? state = ref
        .read(labWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (LabWorkspaceState value) => value,
          failure: (_) => null,
        );
    if (state == null) {
      return null;
    }
    for (final LabOrderWorkflow workflow in _selectedWorkflows(state)) {
      for (final LabOrderItem item in workflow.order.items) {
        if (item.apiId == draft.item.apiId) {
          return item;
        }
      }
    }
    return null;
  }

  Future<void> _persistDrafts(
    List<_ResultDraft> drafts,
    Future<LabBatchPersistOutcome> Function(List<_ResultDraft> validDrafts)
    persist, {
    required String successMessage,
    required String Function(int savedCount, int skippedCount) partialMessage,
    required String actionLabel,
    bool forVerify = false,
  }) async {
    for (final _ResultDraft draft in drafts) {
      draft.showValidationError = false;
    }
    final List<_ResultDraft> validDrafts = <_ResultDraft>[];
    var invalidCount = 0;
    for (final _ResultDraft draft in drafts) {
      if (_validateDraftForPersist(draft, forVerify: forVerify)) {
        validDrafts.add(draft);
      } else {
        invalidCount += 1;
      }
    }
    if (validDrafts.isEmpty) {
      setState(() {
        _clearLabActionFeedback();
        _batchValidationIssueCount = invalidCount;
      });
      _scrollToFirstInvalidDraft(drafts);
      return;
    }
    setState(() {
      _isSaving = true;
      _clearLabActionFeedback();
    });
    final LabBatchPersistOutcome outcome = await persist(validDrafts);
    if (!mounted) {
      return;
    }
    final int savedCount = outcome.savedCount;
    final int skippedCount = outcome.skippedCount + invalidCount;
    if (savedCount > 0) {
      _applyWorkflowUpdates(
        affectedItemIds: validDrafts
            .map((_ResultDraft draft) => draft.item.apiId)
            .toSet(),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      if (savedCount == 0) {
        _failure = null;
        _labActionFailureMessage = _labBatchActionFailureMessage(
          outcome.lastFailure,
          actionLabel: actionLabel,
          invalidCount: invalidCount,
          skippedCount: skippedCount,
        );
        if (invalidCount > 0) {
          _batchValidationIssueCount = invalidCount;
        } else {
          _markFailedDrafts(drafts, outcome.failedItemIds);
        }
      } else if (outcome.lastFailure != null) {
        _failure = outcome.lastFailure;
        _labActionFailureMessage = null;
        if (invalidCount > 0) {
          _batchValidationIssueCount = invalidCount;
        } else {
          _markFailedDrafts(drafts, outcome.failedItemIds);
        }
      } else {
        _failure = null;
        _labActionFailureMessage = null;
      }
    });
    if (!mounted) {
      return;
    }
    if (savedCount > 0 && skippedCount > 0) {
      _showSuccessMessage(partialMessage(savedCount, skippedCount));
    } else if (savedCount > 0 && outcome.lastFailure == null) {
      _showSuccessMessage(successMessage);
    } else if (invalidCount > 0 || outcome.failedItemIds.isNotEmpty) {
      _scrollToFirstInvalidDraft(drafts);
    }
  }

  void _markFailedDrafts(
    List<_ResultDraft> drafts,
    List<String> failedItemIds,
  ) {
    if (failedItemIds.isEmpty) {
      return;
    }
    final Set<String> failedIds = failedItemIds.toSet();
    for (final _ResultDraft draft in drafts) {
      if (failedIds.contains(draft.item.apiId)) {
        draft.showValidationError = true;
      }
    }
    _batchValidationIssueCount = failedIds.length;
  }

  String _labBatchActionFailureMessage(
    AppFailure? failure, {
    required String actionLabel,
    required int invalidCount,
    required int skippedCount,
  }) {
    final AppLocalizations l10n = context.l10n;
    if (invalidCount > 0) {
      return l10n.labBatchValidationSummaryMessage(invalidCount);
    }
    if (failure == null) {
      return l10n.labBatchActionFailedMessage(actionLabel);
    }
    return switch (failure.code) {
      'errors.lab_workflow.invalid_transition' =>
        l10n.labBatchInvalidTransitionMessage,
      'lab.result.item_not_found' => l10n.labBatchItemNotFoundMessage,
      'lab.result.order_not_selected' => l10n.labBatchOrderNotSelectedMessage,
      _
          when failure.category == AppFailureCategory.validation &&
              failure.validationFields.isNotEmpty =>
        l10n.labBatchActionFailedDetailMessage(
          actionLabel,
          l10n.failureMessage(failure),
        ),
      _ when failure.category == AppFailureCategory.validation =>
        l10n.labBatchActionValidationMessage(actionLabel),
      _ => l10n.labBatchActionFailedDetailMessage(
        actionLabel,
        l10n.failureMessage(failure),
      ),
    };
  }

  Future<void> _verifyOrderItem(_ResultDraft draft) async {
    await _persistDrafts(
      <_ResultDraft>[draft],
      _verifyValidDrafts,
      successMessage: context.l10n.labResultsVerifiedMessage,
      partialMessage: context.l10n.labBatchPartialVerifyMessage,
      forVerify: true,
      actionLabel: context.l10n.labVerifyResultAction,
    );
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
    if (failure == null) {
      _applyWorkflowUpdates(affectedItemIds: <String>{draft.item.apiId});
      draft.clearEntry();
    }
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

  Future<void> _removeDraftResults(List<_ResultDraft> drafts) async {
    final List<_ResultDraft> removableDrafts = drafts
        .where((draft) => _canRemoveResult(draft.item, draft))
        .toList(growable: false);
    if (removableDrafts.isEmpty) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppConfirmActionDialog(
        title: context.l10n.labRemoveAllDraftsDialogTitle,
        body: context.l10n.labRemoveAllDraftsDialogBody,
        submitLabel: context.l10n.labRemoveAllDraftsAction,
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final List<_ResultDraft> unsavedDrafts = removableDrafts
        .where((_ResultDraft draft) => !_hasSavedResult(draft.item))
        .toList(growable: false);
    final List<_ResultDraft> savedDrafts = removableDrafts
        .where((_ResultDraft draft) => _hasSavedResult(draft.item))
        .toList(growable: false);

    if (savedDrafts.isEmpty) {
      setState(() {
        for (final _ResultDraft draft in unsavedDrafts) {
          draft.clearEntry();
        }
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    AppFailure? failure;
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );
    for (final _ResultDraft draft in savedDrafts) {
      failure = await controller.removeOrderItemDraftResult(draft.item);
      if (failure != null) {
        break;
      }
    }
    if (!mounted) {
      return;
    }
    if (failure == null) {
      _applyWorkflowUpdates(
        affectedItemIds: savedDrafts
            .map((_ResultDraft draft) => draft.item.apiId)
            .toSet(),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (failure == null) {
        for (final _ResultDraft draft in unsavedDrafts) {
          draft.clearEntry();
        }
        for (final _ResultDraft draft in savedDrafts) {
          draft.clearEntry();
        }
      }
      _failure = failure;
      _isSaving = false;
    });
  }

  Future<void> _openRejectDialog(List<LabOrderItem> items) async {
    await showAppDialog<bool>(
      context: context,
      builder: (_) => _RejectOrderItemDialog(items: items),
    );
  }

  Future<void> _editVerifiedResult(_ResultDraft draft) async {
    final bool? reopened = await showAppDialog<bool>(
      context: context,
      builder: (_) => _ReopenVerifiedResultDialog(item: draft.item),
    );
    if (reopened != true || !mounted) {
      return;
    }
    setState(() {
      _isSaving = true;
      _clearLabActionFeedback();
    });
    _applyWorkflowUpdates(affectedItemIds: <String>{draft.item.apiId});
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
    });
    _showSuccessMessage(context.l10n.labVerifiedResultReopenedMessage);
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
        child: Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _LabContextInlineFact(
              label: l10n.labPatientSearchLabel,
              value: firstOrder.patientDisplayName ?? l10n.profileUnknownValue,
            ),
            _LabContextInlineFact(
              label: l10n.labPatientIdFieldLabel,
              value: firstOrder.patientId ?? l10n.profileUnknownValue,
              copyable:
                  firstOrder.patientId != null &&
                  firstOrder.patientId!.trim().isNotEmpty,
              copyTooltip: l10n.copyIdentifierAction,
              copiedMessage: l10n.identifierCopiedMessage,
            ),
            if (encounterIds.isNotEmpty)
              _LabContextInlineFact(
                label: l10n.labEncounterFieldLabel,
                value: encounterIds.join(', '),
                copyable: encounterIds.length == 1,
                copyTooltip: l10n.opdCopyEncounterIdAction,
                copiedMessage: l10n.opdEncounterIdCopiedMessage,
              ),
            _LabContextInlineFact(
              label: l10n.labOrdersIncludedLabel,
              value: l10n.labActiveOrderCount(workflows.length),
            ),
            AppWorkspaceStatusBadge(
              status: _aggregateOrderStatus(context, workflows),
            ),
            ..._aggregateOrderSubBadges(context, workflows),
          ],
        ),
      ),
    );
  }
}

class _LabBulkResultActionsBar extends StatelessWidget {
  const _LabBulkResultActionsBar({
    required this.draftableEntries,
    required this.submittableDrafts,
    required this.verifiableDrafts,
    required this.saveTargets,
    required this.submitTargets,
    required this.verifyTargets,
    required this.removableDrafts,
    required this.rejectableItems,
    required this.selectedCount,
    required this.selectableCount,
    required this.isSaving,
    required this.onSaveDrafts,
    required this.onSubmitDrafts,
    required this.onVerifyDrafts,
    required this.onRemoveDrafts,
    required this.onRejectItems,
    required this.onSelectAll,
    required this.onClearSelection,
  });

  final List<_ResultDraft> draftableEntries;
  final List<_ResultDraft> submittableDrafts;
  final List<_ResultDraft> verifiableDrafts;
  final List<_ResultDraft> saveTargets;
  final List<_ResultDraft> submitTargets;
  final List<_ResultDraft> verifyTargets;
  final List<_ResultDraft> removableDrafts;
  final List<LabOrderItem> rejectableItems;
  final int selectedCount;
  final int selectableCount;
  final bool isSaving;
  final ValueChanged<List<_ResultDraft>> onSaveDrafts;
  final ValueChanged<List<_ResultDraft>> onSubmitDrafts;
  final ValueChanged<List<_ResultDraft>> onVerifyDrafts;
  final ValueChanged<List<_ResultDraft>> onRemoveDrafts;
  final ValueChanged<List<LabOrderItem>> onRejectItems;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                l10n.labBulkResultActionsTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (selectableCount > 1)
                Text(
                  l10n.labSelectedTestCount(selectedCount, selectableCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (selectableCount > 1) ...<Widget>[
                AppButton.tertiary(
                  label: l10n.labSelectAllTestsAction,
                  enabled: !isSaving && selectedCount < selectableCount,
                  onPressed: onSelectAll,
                ),
                AppButton.tertiary(
                  label: l10n.labClearSelectionAction,
                  enabled: !isSaving && selectedCount > 0,
                  onPressed: onClearSelection,
                ),
              ],
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (draftableEntries.isNotEmpty)
                AppButton.secondary(
                  label: l10n.labSaveAllDraftsAction,
                  leadingIcon: Icons.save_outlined,
                  isLoading: isSaving,
                  onPressed: () => onSaveDrafts(draftableEntries),
                ),
              if (submittableDrafts.isNotEmpty)
                AppButton.secondary(
                  label: l10n.labSubmitAllResultsAction,
                  leadingIcon: Icons.outbox_outlined,
                  isLoading: isSaving,
                  onPressed: () => onSubmitDrafts(submittableDrafts),
                ),
              if (verifiableDrafts.isNotEmpty)
                AppButton.primary(
                  label: l10n.labVerifyAllAction,
                  leadingIcon: Icons.verified_outlined,
                  isLoading: isSaving,
                  onPressed: () => onVerifyDrafts(verifiableDrafts),
                ),
              if (removableDrafts.isNotEmpty)
                AppButton.tertiary(
                  label: l10n.labRemoveAllDraftsAction,
                  leadingIcon: Icons.delete_sweep_outlined,
                  isLoading: isSaving,
                  onPressed: () => onRemoveDrafts(removableDrafts),
                ),
              if (rejectableItems.isNotEmpty)
                AppButton.tertiary(
                  label: l10n.labRejectAllTestsAction,
                  leadingIcon: Icons.block_outlined,
                  isLoading: isSaving,
                  onPressed: () => onRejectItems(rejectableItems),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabApplyingChangesBanner extends StatelessWidget {
  const _LabApplyingChangesBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        border: Border.all(color: theme.colorScheme.primary),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabResultValidationMessage extends StatelessWidget {
  const _LabResultValidationMessage({required this.draft});

  final _ResultDraft draft;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return Text(
      draft.hasEntry
          ? l10n.labBatchEntryValidationMessage
          : l10n.labResultEntryRequiredMessage,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LabContextInlineFact extends StatelessWidget {
  const _LabContextInlineFact({
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
    final TextStyle labelStyle = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    final TextStyle valueStyle = theme.textTheme.bodyMedium!.copyWith(
      fontWeight: FontWeight.w700,
    );

    if (copyable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('$label: ', style: labelStyle),
          AppCopyableIdentifier(
            value: value,
            tooltip: copyTooltip,
            copiedMessage: copiedMessage,
            textStyle: valueStyle,
          ),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '$label: ', style: labelStyle),
          TextSpan(text: value, style: valueStyle),
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
    required this.selectedItemIds,
    required this.onSaveDraft,
    required this.onSubmitItem,
    required this.onVerifyItem,
    required this.onEditVerified,
    required this.onRejectItem,
    required this.onRemoveResult,
    this.onToggleItemSelection,
    this.onEditOrder,
    this.onDeleteOrder,
  });

  final LabOrderWorkflow workflow;
  final List<_ResultDraft> drafts;
  final List<LabCatalogItem> catalogPanels;
  final bool canMutate;
  final Set<String> selectedItemIds;
  final void Function(String itemId, {required bool selected})?
  onToggleItemSelection;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onSubmitItem;
  final ValueChanged<_ResultDraft> onVerifyItem;
  final ValueChanged<_ResultDraft> onEditVerified;
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
                  child: Text(
                    '${l10n.labOrderFieldLabel} $orderLabel',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (canMutate && (onEditOrder != null || onDeleteOrder != null))
                  Wrap(
                    spacing: theme.spacing.xs,
                    children: <Widget>[
                      if (onEditOrder != null)
                        AppButton(
                          leadingIcon: Icons.edit_outlined,
                          label: l10n.labEditOrderAction,
                          semanticLabel: l10n.labEditOrderAction,
                          tooltip: l10n.labEditOrderAction,
                          onPressed: onEditOrder,
                        ),
                      if (onDeleteOrder != null)
                        AppButton(
                          icon: Icons.delete_outline,
                          label: l10n.labDeleteOrderAction,
                          semanticLabel: l10n.labDeleteOrderAction,
                          tooltip: l10n.labDeleteOrderAction,
                          color: theme.statusColors.danger,
                          onPressed: onDeleteOrder,
                        ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.xs),
            _InlineOrderMeta(
              icon: Icons.event_outlined,
              text:
                  '${l10n.labOrderedAtFieldLabel}: ${_optionalDateTimeLabel(context, order.orderedAt) ?? l10n.profileUnknownValue}',
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
                selectedItemIds: selectedItemIds,
                onToggleItemSelection: onToggleItemSelection,
                onSaveDraft: onSaveDraft,
                onSubmit: onSubmitItem,
                onVerify: onVerifyItem,
                onEditVerified: onEditVerified,
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

bool _isCancelledItem(LabOrderItem item) {
  return item.isRejected ||
      (item.status ?? '').trim().toUpperCase() == 'CANCELLED';
}

class _ResponsiveLabResultEntry extends StatelessWidget {
  const _ResponsiveLabResultEntry({
    required this.drafts,
    required this.canMutate,
    required this.selectedItemIds,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onVerify,
    required this.onEditVerified,
    required this.onReject,
    required this.onRemove,
    this.onToggleItemSelection,
    this.embeddedInPanel = false,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final Set<String> selectedItemIds;
  final void Function(String itemId, {required bool selected})?
  onToggleItemSelection;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onSubmit;
  final ValueChanged<_ResultDraft> onVerify;
  final ValueChanged<_ResultDraft> onEditVerified;
  final ValueChanged<LabOrderItem> onReject;
  final ValueChanged<_ResultDraft> onRemove;
  final bool embeddedInPanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 760) {
          return _LabResultEntryCards(
            drafts: drafts,
            canMutate: canMutate,
            selectedItemIds: selectedItemIds,
            onToggleItemSelection: onToggleItemSelection,
            onSaveDraft: onSaveDraft,
            onSubmit: onSubmit,
            onVerify: onVerify,
            onEditVerified: onEditVerified,
            onReject: onReject,
            onRemove: onRemove,
          );
        }
        return _LabResultEntryRowsTable(
          drafts: drafts,
          canMutate: canMutate,
          selectedItemIds: selectedItemIds,
          onToggleItemSelection: onToggleItemSelection,
          onSaveDraft: onSaveDraft,
          onSubmit: onSubmit,
          onVerify: onVerify,
          onEditVerified: onEditVerified,
          onReject: onReject,
          onRemove: onRemove,
          availableWidth: constraints.maxWidth,
          embeddedInPanel: embeddedInPanel,
        );
      },
    );
  }
}

class _LabResultEntryCards extends StatelessWidget {
  const _LabResultEntryCards({
    required this.drafts,
    required this.canMutate,
    required this.selectedItemIds,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onVerify,
    required this.onEditVerified,
    required this.onReject,
    required this.onRemove,
    this.onToggleItemSelection,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final Set<String> selectedItemIds;
  final void Function(String itemId, {required bool selected})?
  onToggleItemSelection;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onSubmit;
  final ValueChanged<_ResultDraft> onVerify;
  final ValueChanged<_ResultDraft> onEditVerified;
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
              color: _isCancelledItem(draft.item)
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.22)
                  : draft.showValidationError
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.28)
                  : _isAbnormalEntry(draft.item, draft)
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.14)
                  : theme.colorScheme.surfaceContainerLowest,
              border: Border.all(
                color: _isCancelledItem(draft.item) || draft.showValidationError
                    ? theme.colorScheme.error
                    : theme.colorScheme.outlineVariant,
                width: _isCancelledItem(draft.item) || draft.showValidationError
                    ? 1.5
                    : 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: KeyedSubtree(
                key: draft.rowKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _LabResultTestCell(
                      draft: draft,
                      showSelection: canMutate && onToggleItemSelection != null,
                      isSelected: selectedItemIds.contains(draft.item.apiId),
                      selectionEnabled: _isBulkSelectable(draft),
                      onSelectionChanged: onToggleItemSelection == null
                          ? null
                          : (bool? value) => onToggleItemSelection!(
                              draft.item.apiId,
                              selected: value ?? false,
                            ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    _LabReferenceRangeCell(draft: draft),
                    SizedBox(height: theme.spacing.sm),
                    draft.item.canEnterResult
                        ? _CompactResultInput(
                            draft: draft,
                            enabled: canMutate && draft.item.canEnterResult,
                          )
                        : _CompletedResultReadout(item: draft.item),
                    SizedBox(height: theme.spacing.sm),
                    _LabResultFlagCell(
                      item: draft.item,
                      draft: draft,
                      canMutate: canMutate,
                    ),
                    SizedBox(height: theme.spacing.xs),
                    _LabResultActionsCell(
                      draft: draft,
                      canMutate: canMutate,
                      onSaveDraft: () => onSaveDraft(draft),
                      onSubmit: () => onSubmit(draft),
                      onVerify: () => onVerify(draft),
                      onEditVerified: () => onEditVerified(draft),
                      onReject: () => onReject(draft.item),
                      onRemove: () => onRemove(draft),
                    ),
                  ],
                ),
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
    required this.selectedItemIds,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onVerify,
    required this.onEditVerified,
    required this.onReject,
    required this.onRemove,
    this.onToggleItemSelection,
  });

  final List<_ResultDraft> drafts;
  final List<LabCatalogItem> catalogPanels;
  final bool canMutate;
  final Set<String> selectedItemIds;
  final void Function(String itemId, {required bool selected})?
  onToggleItemSelection;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onSubmit;
  final ValueChanged<_ResultDraft> onVerify;
  final ValueChanged<_ResultDraft> onEditVerified;
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
          if (group.panelTitle != null)
            _LabPanelResultBlock(
              title: group.panelTitle!,
              canDelete: canMutate,
              orderId: group.drafts.isNotEmpty
                  ? group.drafts.first.item.labOrderId
                  : null,
              itemIds: group.drafts
                  .map((_ResultDraft draft) => draft.item.apiId)
                  .toList(growable: false),
              child: _ResponsiveLabResultEntry(
                drafts: group.drafts,
                canMutate: canMutate,
                selectedItemIds: selectedItemIds,
                onToggleItemSelection: onToggleItemSelection,
                onSaveDraft: onSaveDraft,
                onSubmit: onSubmit,
                onVerify: onVerify,
                onEditVerified: onEditVerified,
                onReject: onReject,
                onRemove: onRemove,
                embeddedInPanel: true,
              ),
            )
          else
            _ResponsiveLabResultEntry(
              drafts: group.drafts,
              canMutate: canMutate,
              selectedItemIds: selectedItemIds,
              onToggleItemSelection: onToggleItemSelection,
              onSaveDraft: onSaveDraft,
              onSubmit: onSubmit,
              onVerify: onVerify,
              onEditVerified: onEditVerified,
              onReject: onReject,
              onRemove: onRemove,
            ),
          SizedBox(height: theme.spacing.sm),
        ],
      ],
    );
  }
}

class _LabPanelResultBlock extends StatelessWidget {
  const _LabPanelResultBlock({
    required this.title,
    required this.child,
    this.orderId,
    this.itemIds = const <String>[],
    this.canDelete = false,
  });

  final String title;
  final Widget child;
  final String? orderId;
  final List<String> itemIds;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PanelGroupHeader(
            title: title,
            canDelete: canDelete,
            orderId: orderId,
            itemIds: itemIds,
          ),
          child,
        ],
      ),
    );
  }
}

class _LabResultEntryRowsTable extends StatelessWidget {
  const _LabResultEntryRowsTable({
    required this.drafts,
    required this.canMutate,
    required this.selectedItemIds,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onVerify,
    required this.onEditVerified,
    required this.onReject,
    required this.onRemove,
    required this.availableWidth,
    this.onToggleItemSelection,
    this.embeddedInPanel = false,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final Set<String> selectedItemIds;
  final void Function(String itemId, {required bool selected})?
  onToggleItemSelection;
  final ValueChanged<_ResultDraft> onSaveDraft;
  final ValueChanged<_ResultDraft> onSubmit;
  final ValueChanged<_ResultDraft> onVerify;
  final ValueChanged<_ResultDraft> onEditVerified;
  final ValueChanged<LabOrderItem> onReject;
  final ValueChanged<_ResultDraft> onRemove;
  final double availableWidth;
  final bool embeddedInPanel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final double tableWidth = availableWidth
        .clamp(860.0, double.infinity)
        .toDouble();
    final Color borderColor = theme.colorScheme.outlineVariant;
    final TableBorder tableBorder = embeddedInPanel
        ? TableBorder(
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
            horizontalInside: BorderSide(color: borderColor),
            verticalInside: BorderSide(color: borderColor),
          )
        : TableBorder.all(color: borderColor);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Table(
          border: tableBorder,
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
                isSelected: selectedItemIds.contains(draft.item.apiId),
                showSelection: canMutate && onToggleItemSelection != null,
                selectionEnabled: _isBulkSelectable(draft),
                onSelectionChanged: onToggleItemSelection == null
                    ? null
                    : (bool? value) => onToggleItemSelection!(
                        draft.item.apiId,
                        selected: value ?? false,
                      ),
                onSaveDraft: () => onSaveDraft(draft),
                onSubmit: () => onSubmit(draft),
                onVerify: () => onVerify(draft),
                onEditVerified: () => onEditVerified(draft),
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
  required bool isSelected,
  required bool showSelection,
  required bool selectionEnabled,
  required VoidCallback onSaveDraft,
  required VoidCallback onSubmit,
  required VoidCallback onVerify,
  required VoidCallback onEditVerified,
  required VoidCallback onReject,
  required VoidCallback onRemove,
  ValueChanged<bool?>? onSelectionChanged,
}) {
  final ThemeData theme = Theme.of(context);
  final LabOrderItem item = draft.item;
  final bool canEdit = canMutate && item.canEnterResult;
  final bool abnormal = _isAbnormalEntry(item, draft);
  final bool cancelled = _isCancelledItem(item);

  return TableRow(
    decoration: BoxDecoration(
      color: cancelled
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.22)
          : draft.showValidationError
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.28)
          : abnormal
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.14)
          : theme.colorScheme.surfaceContainerLowest,
      border: cancelled || draft.showValidationError
          ? Border.all(color: theme.colorScheme.error, width: 1.5)
          : null,
    ),
    children: <Widget>[
      _LabResultTableCell(
        child: KeyedSubtree(
          key: draft.rowKey,
          child: _LabResultTestCell(
            draft: draft,
            showSelection: showSelection,
            isSelected: isSelected,
            selectionEnabled: selectionEnabled,
            onSelectionChanged: onSelectionChanged,
          ),
        ),
      ),
      _LabResultTableCell(child: _LabReferenceRangeCell(draft: draft)),
      _LabResultTableCell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            item.canEnterResult
                ? _CompactResultInput(draft: draft, enabled: canEdit)
                : _CompletedResultReadout(item: item),
            if (draft.showValidationError && !item.canEnterResult) ...<Widget>[
              SizedBox(height: Theme.of(context).spacing.xs),
              _LabResultValidationMessage(draft: draft),
            ],
          ],
        ),
      ),
      _LabResultTableCell(
        child: _LabResultFlagCell(
          item: item,
          draft: draft,
          canMutate: canMutate,
        ),
      ),
      _LabResultTableCell(
        child: _LabResultActionsCell(
          draft: draft,
          canMutate: canMutate,
          onSaveDraft: onSaveDraft,
          onSubmit: onSubmit,
          onVerify: onVerify,
          onEditVerified: onEditVerified,
          onReject: onReject,
          onRemove: onRemove,
        ),
      ),
    ],
  );
}

class _LabResultTestCell extends StatelessWidget {
  const _LabResultTestCell({
    required this.draft,
    this.showSelection = false,
    this.isSelected = false,
    this.selectionEnabled = false,
    this.onSelectionChanged,
  });

  final _ResultDraft draft;
  final bool showSelection;
  final bool isSelected;
  final bool selectionEnabled;
  final ValueChanged<bool?>? onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LabOrderItem item = draft.item;
    final TextStyle titleStyle =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800) ??
        const TextStyle(fontWeight: FontWeight.w800);
    final double firstLineHeight =
        (titleStyle.fontSize ?? 14) * (titleStyle.height ?? 1.2);
    final Widget titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(item.displayTitle, style: titleStyle),
        if (draft.showValidationError) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          _LabResultValidationMessage(draft: draft),
        ],
      ],
    );

    if (!showSelection) {
      return titleColumn;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: firstLineHeight,
          child: Align(
            child: Checkbox(
              value: isSelected,
              onChanged: selectionEnabled ? onSelectionChanged : null,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.xs),
        Expanded(child: titleColumn),
      ],
    );
  }
}

class _LabReferenceRangeCell extends StatelessWidget {
  const _LabReferenceRangeCell({required this.draft});

  final _ResultDraft draft;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final LabOrderItem item = draft.item;
    final String? autoRange = item.displayReferenceRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          autoRange ?? l10n.profileUnknownValue,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (draft.interpretationOverride) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          AppTextField(
            controller: draft.referenceRangeOverrideController,
            labelText: l10n.labReferenceRangeOverrideLabel,
            enabled: draft.enabled,
            onChanged: (_) => draft.notifyChanged(),
          ),
        ],
      ],
    );
  }
}

class _LabResultFlagCell extends StatelessWidget {
  const _LabResultFlagCell({
    required this.item,
    required this.draft,
    required this.canMutate,
  });

  final LabOrderItem item;
  final _ResultDraft draft;
  final bool canMutate;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool abnormal = _isAbnormalEntry(item, draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: _resolveItemResultFlagLabel(context, item, draft: draft),
            tone: abnormal
                ? AppWorkspaceStatusTone.error
                : AppWorkspaceStatusTone.neutral,
            icon: abnormal
                ? Icons.warning_amber_outlined
                : Icons.check_outlined,
          ),
        ),
        if (canMutate && draft.enabled) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                l10n.labInterpretationOverrideLabel,
                style: theme.textTheme.bodySmall,
              ),
              value: draft.interpretationOverride,
              onChanged: (bool? value) {
                draft.interpretationOverride = value ?? false;
                draft.notifyChanged();
              },
            ),
          ),
          if (draft.interpretationOverride)
            AppTextField(
              controller: draft.resultFlagOverrideController,
              labelText: l10n.labResultFlagOverrideLabel,
              enabled: draft.enabled,
              onChanged: (_) => draft.notifyChanged(),
            ),
        ],
      ],
    );
  }
}

class _LabResultActionsCell extends ConsumerWidget {
  const _LabResultActionsCell({
    required this.draft,
    required this.canMutate,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onVerify,
    required this.onEditVerified,
    required this.onReject,
    required this.onRemove,
  });

  final _ResultDraft draft;
  final bool canMutate;
  final VoidCallback onSaveDraft;
  final VoidCallback onSubmit;
  final VoidCallback onVerify;
  final VoidCallback onEditVerified;
  final VoidCallback onReject;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final LabOrderItem item = draft.item;
    final bool canRemove = canMutate && _canRemoveResult(item, draft);
    final bool isCancelled =
        (item.status ?? '').trim().toUpperCase() == 'CANCELLED';
    final bool isPanelChild =
        item.panelKey != null && item.panelKey!.trim().isNotEmpty;
    final bool canDelete =
        canMutate &&
        !isPanelChild &&
        item.labOrderId != null &&
        item.labOrderId!.trim().isNotEmpty;
    final String resultStatus = (item.effectiveResultStatus ?? '')
        .trim()
        .toUpperCase();
    final bool savesPendingDraft =
        item.resultId == null ||
        resultStatus.isEmpty ||
        resultStatus == 'PENDING';
    final List<Widget> actions = <Widget>[
      if (canMutate && isCancelled)
        AppButton.secondary(
          label: l10n.labRestoreOrderItemAction,
          leadingIcon: Icons.restore_outlined,
          onPressed: () => _restore(context, ref),
        ),
      if (canMutate && item.canReopenResult)
        AppButton.tertiary(
          label: l10n.labEditVerifiedResultAction,
          leadingIcon: Icons.edit_outlined,
          onPressed: onEditVerified,
        ),
      if (canMutate && item.canEnterResult && draft.hasEntry)
        AppButton.tertiary(
          label: savesPendingDraft
              ? l10n.labSaveDraftAction
              : l10n.commonSaveActionLabel,
          leadingIcon: Icons.save_outlined,
          onPressed: onSaveDraft,
        ),
      if (canMutate && _canSubmitDraft(draft))
        AppButton.tertiary(
          label: l10n.labSubmitResultAction,
          leadingIcon: Icons.outbox_outlined,
          onPressed: onSubmit,
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
      if (canDelete)
        AppButton.tertiary(
          label: l10n.labDeleteOrderItemAction,
          leadingIcon: Icons.delete_outline,
          onPressed: () => _delete(context, ref),
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

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final LabOrderItem item = draft.item;
    await showAppDialog<bool>(
      context: context,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.labRestoreOrderItemDialogTitle,
        body: l10n.labRestoreOrderItemDialogBody(item.displayTitle),
        submitLabel: l10n.labRestoreOrderItemAction,
        icon: const Icon(Icons.restore_outlined),
        onConfirm: () => ref
            .read(labWorkspaceControllerProvider.notifier)
            .restoreOrderItem(item.apiId, const <String, Object?>{}),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final LabOrderItem item = draft.item;
    final String? orderId = item.labOrderId;
    if (orderId == null || orderId.trim().isEmpty) {
      return;
    }
    await showAppDialog<bool>(
      context: context,
      builder: (_) => _DeleteOrderItemDialog(item: item),
    );
  }
}

class _PanelGroupHeader extends ConsumerWidget {
  const _PanelGroupHeader({
    required this.title,
    this.orderId,
    this.itemIds = const <String>[],
    this.canDelete = false,
  });

  final String title;
  final String? orderId;
  final List<String> itemIds;
  final bool canDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool showDelete =
        canDelete &&
        itemIds.isNotEmpty &&
        orderId != null &&
        orderId!.trim().isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.32),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
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
            if (showDelete)
              AppButton(
                leadingIcon: Icons.delete_outline,
                label: l10n.labDeletePanelAction,
                semanticLabel: l10n.labDeletePanelAction,
                tooltip: l10n.labDeletePanelAction,
                color: theme.statusColors.danger,
                onPressed: () => _deletePanel(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePanel(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final String? targetOrderId = orderId;
    if (targetOrderId == null || itemIds.isEmpty) {
      return;
    }
    await showAppDialog<bool>(
      context: context,
      builder: (_) => AppConfirmActionDialog(
        title: l10n.labDeletePanelDialogTitle,
        body: l10n.labDeletePanelDialogBody(title),
        submitLabel: l10n.labDeletePanelAction,
        icon: const Icon(Icons.delete_outline),
        onConfirm: () =>
            ref.read(labWorkspaceControllerProvider.notifier).deleteOrderItems(
              targetOrderId,
              <String, Object?>{'order_item_ids': itemIds},
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
                  onChanged: enabled
                      ? (_) => widget.draft.notifyChanged()
                      : null,
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
              onChanged: enabled ? (_) => widget.draft.notifyChanged() : null,
            ),
          AppTextField(
            controller: widget.draft.notesController,
            labelText: l10n.labNotesLabel,
            enabled: enabled,
            onChanged: enabled ? (_) => widget.draft.notifyChanged() : null,
          ),
          if (widget.draft.showValidationError) ...<Widget>[
            SizedBox(height: Theme.of(context).spacing.xs),
            Text(
              widget.draft.hasEntry
                  ? l10n.labBatchEntryValidationMessage
                  : l10n.labResultEntryRequiredMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

    final bool abnormal = _isAbnormalStatus(
      _computedNumericFlagToken(item, item.resultValue ?? '') ??
          item.resultFlag ??
          item.effectiveResultStatus,
    );

    return Text(
      value,
      style: theme.textTheme.titleSmall?.copyWith(
        color: abnormal ? theme.colorScheme.error : null,
        fontWeight: FontWeight.w700,
      ),
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
  static const String _selectColumnKey = 'select';
  static const String _testsColumnKey = 'tests';
  static const String _referenceRangeColumnKey = 'reference_range';
  static const String _resultColumnKey = 'result';
  static const String _flagColumnKey = 'flag';

  late Set<String> _selectedOrderIds;
  late Set<String> _selectedItemIds;
  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<LabOrderItem>
  _columnVisibilityController;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<LabOrderItem>(
          storageKey: 'lab_report_preview_columns',
        );
    _resetSelection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  List<LabOrderItem> get _allReportItems => _reportItems(widget.workflows);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool hasSelectedItems = _selectedItemIds.isNotEmpty;
    final bool canPrint =
        hasSelectedItems && _visibleReportColumnKeys().isNotEmpty;
    return AppDialog(
      title: Text(l10n.labReportPreviewTitle),
      icon: const Icon(Icons.print_outlined),
      scrollable: true,
      maxWidth: 1040,
      closeEnabled: !_isPrinting,
      content: AppReportPreviewPanel(
        selectable: true,
        child: _allReportItems.isEmpty
            ? AppWorkspaceStatePanel.empty(
                title: l10n.labNoOrderItemsEntryTitle,
                body: l10n.labNoOrderItemsEntryBody,
                icon: Icons.print_disabled_outlined,
              )
            : _LabReportPreview(
                workflows: widget.workflows,
                items: _allReportItems,
                selectedItemIds: _selectedItemIds,
                searchController: _searchController,
                filterValue: _filterValue,
                hasActiveFilters: _filterValue.isActive,
                filterGroups: _reportPreviewFilterGroups(l10n),
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _filterValue = value);
                },
                columnVisibilityController: _columnVisibilityController,
                columns: _reportPreviewColumns(context),
                columnChoices: _reportPreviewColumnChoices(context),
                onToggleItem: _toggleReportItem,
              ),
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.labResetReportSelectionAction,
          leadingIcon: Icons.restart_alt_outlined,
          enabled: !_isPrinting,
          onPressed: () => setState(_resetSelection),
        ),
        AppReportActionButton.print(
          label: l10n.labPrintReportAction,
          isLoading: _isPrinting,
          enabled: canPrint,
          onPressed: canPrint ? () => _printSelectedReport() : null,
        ),
      ],
    );
  }

  List<AppListTableColumn<LabOrderItem>> _reportPreviewColumns(
    BuildContext context,
  ) {
    return <AppListTableColumn<LabOrderItem>>[
      _reportSelectionColumn(context),
      ..._reportPreviewDataColumns(context),
    ];
  }

  List<AppListTableColumn<LabOrderItem>> _reportPreviewColumnChoices(
    BuildContext context,
  ) {
    return _reportPreviewDataColumns(context);
  }

  List<AppListTableColumn<LabOrderItem>> _reportPreviewDataColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    return <AppListTableColumn<LabOrderItem>>[
      AppListTableColumn<LabOrderItem>(
        id: _testsColumnKey,
        label: l10n.labTestsColumnLabel,
        sortComparator: (LabOrderItem left, LabOrderItem right) {
          return appListTableCompareText(left.displayTitle, right.displayTitle);
        },
        cellBuilder: (BuildContext context, LabOrderItem item) {
          return Text(item.displayTitle);
        },
      ),
      AppListTableColumn<LabOrderItem>(
        id: _referenceRangeColumnKey,
        label: l10n.labReferenceRangeLabel,
        sortComparator: (LabOrderItem left, LabOrderItem right) {
          return appListTableCompareText(
            left.displayReferenceRange,
            right.displayReferenceRange,
          );
        },
        cellBuilder: (BuildContext context, LabOrderItem item) {
          return Text(
            item.displayReferenceRange ?? context.l10n.profileUnknownValue,
          );
        },
      ),
      AppListTableColumn<LabOrderItem>(
        id: _resultColumnKey,
        label: l10n.labReportResultLabel,
        sortComparator: (LabOrderItem left, LabOrderItem right) {
          return appListTableCompareText(
            left.displayResultValue,
            right.displayResultValue,
          );
        },
        cellBuilder: (BuildContext context, LabOrderItem item) {
          return _ReportPreviewResultCell(item: item);
        },
      ),
      AppListTableColumn<LabOrderItem>(
        id: _flagColumnKey,
        label: l10n.labResultFlagLabel,
        sortComparator: (LabOrderItem left, LabOrderItem right) {
          return appListTableCompareText(
            _resolveItemResultFlagLabel(context, left),
            _resolveItemResultFlagLabel(context, right),
          );
        },
        cellBuilder: (BuildContext context, LabOrderItem item) {
          return _ReportPreviewFlagCell(item: item);
        },
      ),
    ];
  }

  AppListTableColumn<LabOrderItem> _reportSelectionColumn(
    BuildContext context,
  ) {
    return AppListTableColumn<LabOrderItem>(
      id: _selectColumnKey,
      label: '',
      alwaysVisible: true,
      headerBuilder: (BuildContext context) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (BuildContext context, TextEditingValue value, Widget? _) {
            final List<LabOrderItem> filteredItems = _visibleReportItems(
              value.text,
            );
            final bool allSelected =
                filteredItems.isNotEmpty &&
                filteredItems.every(
                  (LabOrderItem item) =>
                      _selectedItemIds.contains(_itemSelectionKey(item)),
                );
            final bool someSelected = filteredItems.any(
              (LabOrderItem item) =>
                  _selectedItemIds.contains(_itemSelectionKey(item)),
            );
            return Checkbox(
              tristate: true,
              value: allSelected
                  ? true
                  : someSelected
                  ? null
                  : false,
              onChanged: filteredItems.isEmpty
                  ? null
                  : (bool? checked) {
                      _toggleFilteredReportItems(
                        filteredItems,
                        selected: checked ?? false,
                      );
                    },
              visualDensity: VisualDensity.compact,
            );
          },
        );
      },
      cellBuilder: (BuildContext context, LabOrderItem item) {
        return Checkbox(
          value: _selectedItemIds.contains(_itemSelectionKey(item)),
          onChanged: (bool? value) {
            _toggleReportItem(item, selected: value ?? false);
          },
          visualDensity: VisualDensity.compact,
        );
      },
    );
  }

  List<LabOrderItem> _visibleReportItems(String query) {
    return _allReportItems
        .where(
          (LabOrderItem item) =>
              _matchesReportItemFilter(
                context,
                item,
                _filterValue,
                _selectedItemIds,
              ) &&
              _matchesReportItemSearch(context, item, query),
        )
        .toList(growable: false);
  }

  List<AppSearchBarFilterGroup> _reportPreviewFilterGroups(
    AppLocalizations l10n,
  ) {
    return <AppSearchBarFilterGroup>[
      AppSearchBarFilterGroup(
        key: _labReportFlagFilterKey,
        label: l10n.labReportFlagFilterLabel,
        allLabel: l10n.labReportAllFlagsLabel,
        choices: _reportFlagFilterChoices(l10n),
      ),
      AppSearchBarFilterGroup(
        key: _labReportSelectionFilterKey,
        label: l10n.labReportSelectionFilterLabel,
        allLabel: l10n.labReportSelectionAllLabel,
        choices: <AppSearchBarFilterChoice>[
          AppSearchBarFilterChoice(
            value: 'selected',
            label: l10n.labReportSelectionSelectedLabel,
          ),
          AppSearchBarFilterChoice(
            value: 'unselected',
            label: l10n.labReportSelectionUnselectedLabel,
          ),
        ],
      ),
    ];
  }

  List<AppSearchBarFilterChoice> _reportFlagFilterChoices(
    AppLocalizations l10n,
  ) {
    return <AppSearchBarFilterChoice>[
      AppSearchBarFilterChoice(value: 'NORMAL', label: l10n.labStatusNormal),
      AppSearchBarFilterChoice(
        value: 'ABNORMAL',
        label: l10n.labStatusAbnormal,
      ),
      AppSearchBarFilterChoice(
        value: 'CRITICAL',
        label: l10n.labStatusCritical,
      ),
      AppSearchBarFilterChoice(value: 'PENDING', label: l10n.labStatusPending),
      AppSearchBarFilterChoice(
        value: 'CANCELLED',
        label: l10n.labStatusCancelled,
      ),
      AppSearchBarFilterChoice(
        value: 'NEGATIVE',
        label: l10n.labNegativeOption,
      ),
    ];
  }

  void _toggleFilteredReportItems(
    List<LabOrderItem> items, {
    required bool selected,
  }) {
    setState(() {
      for (final LabOrderItem item in items) {
        final String itemKey = _itemSelectionKey(item);
        LabOrderWorkflow? owningWorkflow;
        for (final LabOrderWorkflow workflow in widget.workflows) {
          if (workflow.order.items.any(
            (LabOrderItem orderItem) => _itemSelectionKey(orderItem) == itemKey,
          )) {
            owningWorkflow = workflow;
            break;
          }
        }
        if (selected) {
          _selectedItemIds.add(itemKey);
          if (owningWorkflow != null) {
            _selectedOrderIds.add(owningWorkflow.order.apiId);
          }
        } else {
          _selectedItemIds.remove(itemKey);
          if (owningWorkflow != null &&
              !owningWorkflow.order.items.any(
                (LabOrderItem candidate) =>
                    _selectedItemIds.contains(_itemSelectionKey(candidate)),
              )) {
            _selectedOrderIds.remove(owningWorkflow.order.apiId);
          }
        }
      }
    });
  }

  void _toggleReportItem(LabOrderItem item, {required bool selected}) {
    _toggleFilteredReportItems(<LabOrderItem>[item], selected: selected);
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

  List<String> _visibleReportColumnKeys() {
    return _columnVisibilityController.visibleColumns
        .map((AppListTableColumn<LabOrderItem> column) => column.key)
        .where((String key) => key != _selectColumnKey)
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
      patientContext: _reportPatientContext(context, workflows),
      contextReference: _reportContextReference(context, workflows),
      pages: _reportPages(
        context,
        workflows,
        _selectedItemIds,
        _visibleReportColumnKeys(),
      ),
      footerNote: l10n.labReportFooter,
      includeSignatures: true,
    );
    if (mounted) {
      setState(() => _isPrinting = false);
    }
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
}

class _LabReportPreview extends StatelessWidget {
  const _LabReportPreview({
    required this.workflows,
    required this.items,
    required this.selectedItemIds,
    required this.searchController,
    required this.filterValue,
    required this.hasActiveFilters,
    required this.filterGroups,
    required this.onFilterChanged,
    required this.columnVisibilityController,
    required this.columns,
    required this.columnChoices,
    required this.onToggleItem,
  });

  final List<LabOrderWorkflow> workflows;
  final List<LabOrderItem> items;
  final Set<String> selectedItemIds;
  final TextEditingController searchController;
  final AppSearchBarFilterValue filterValue;
  final bool hasActiveFilters;
  final List<AppSearchBarFilterGroup> filterGroups;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;
  final AppListTableColumnVisibilityController<LabOrderItem>
  columnVisibilityController;
  final List<AppListTableColumn<LabOrderItem>> columns;
  final List<AppListTableColumn<LabOrderItem>> columnChoices;
  final void Function(LabOrderItem item, {required bool selected}) onToggleItem;

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
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.sm,
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
        AppListTable<LabOrderItem>(
          items: items,
          maxVisibleItems: _maxVisibleLabReportPreviewItems,
          columns: columns,
          columnChoices: columnChoices,
          columnVisibilityController: columnVisibilityController,
          columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
          columnVisibilityTitle: l10n.labReportTableColumnsTitle,
          columnVisibilityApplyLabel: l10n.labApplyColumnsAction,
          columnVisibilityResetLabel: l10n.labResetColumnsAction,
          displayMode: AppListTableDisplayMode.table,
          shrinkWrap: true,
          search: AppListTableSearch<LabOrderItem>(
            controller: searchController,
            semanticLabel: l10n.labReportSearchLabel,
            hintText: l10n.labReportSearchHint,
            matcher: (LabOrderItem item, String query) {
              return _matchesReportItemSearch(context, item, query) &&
                  _matchesReportItemFilter(
                    context,
                    item,
                    filterValue,
                    selectedItemIds,
                  );
            },
            showAdvancedFilterButton: true,
            advancedFilterButtonLabel: l10n.labReportFiltersLabel,
            advancedFilterTitle: l10n.labReportFiltersLabel,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.opdClearFiltersAction,
            filterGroups: filterGroups,
            filterValue: filterValue,
            hasActiveFilters: hasActiveFilters,
            onFilterChanged: onFilterChanged,
          ),
          rowColorBuilder: (BuildContext context, LabOrderItem item) {
            final bool selected = selectedItemIds.contains(
              _itemSelectionKey(item),
            );
            if (!selected) {
              return theme.colorScheme.surfaceContainerLow.withValues(
                alpha: 0.35,
              );
            }
            if (_isAbnormalReportItem(item)) {
              return theme.colorScheme.errorContainer.withValues(alpha: 0.28);
            }
            return null;
          },
          mobileItemBuilder: (BuildContext context, LabOrderItem item) {
            return AppListItemRow(
              title: item.displayTitle,
              subtitle: item.displayResultValue ?? l10n.labStatusPendingResults,
              details: <Widget>[_ReportPreviewFlagCell(item: item)],
              leading: Checkbox(
                value: selectedItemIds.contains(_itemSelectionKey(item)),
                onChanged: (bool? value) {
                  onToggleItem(item, selected: value ?? false);
                },
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        ),
        SizedBox(height: theme.spacing.md),
        Wrap(
          spacing: theme.spacing.lg,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            Text(
              l10n.printFormPrintedByLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              l10n.printFormVerifiedByLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReportPreviewResultCell extends StatelessWidget {
  const _ReportPreviewResultCell({required this.item});

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

    final bool abnormal = _isAbnormalReportItem(item);
    return Text(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: abnormal ? theme.colorScheme.error : null,
        fontWeight: abnormal ? FontWeight.w700 : null,
      ),
    );
  }
}

class _ReportPreviewFlagCell extends StatelessWidget {
  const _ReportPreviewFlagCell({required this.item});

  final LabOrderItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = _resolveItemResultFlagLabel(context, item);
    final bool abnormal = _isAbnormalReportItem(item);
    return Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: abnormal ? theme.colorScheme.error : null,
        fontWeight: abnormal ? FontWeight.w700 : null,
      ),
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
    final ColorScheme colorScheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
      referenceRangeOverrideController = TextEditingController(
        text: item.referenceRangeOverride ?? item.referenceRangeSummary ?? '',
      ),
      resultFlagOverrideController = TextEditingController(
        text: item.resultFlagOverride ?? item.resultFlag ?? '',
      ),
      selectedOption = item.resultText ?? item.resultValue,
      interpretationOverride = item.interpretationOverride;

  LabOrderItem item;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalKey rowKey = GlobalKey();
  final TextEditingController valueController;
  final TextEditingController unitController;
  final TextEditingController textController;
  final TextEditingController notesController;
  final TextEditingController referenceRangeOverrideController;
  final TextEditingController resultFlagOverrideController;
  VoidCallback? _onChanged;
  String? selectedOption;
  bool interpretationOverride;
  bool showValidationError = false;

  bool get enabled => item.canEnterResult;

  bool get hasEntry {
    if (item.isNumeric) {
      return valueController.text.trim().isNotEmpty;
    }
    if (item.isQualitative && item.resultOptions.isNotEmpty) {
      return (selectedOption ?? '').trim().isNotEmpty;
    }
    return textController.text.trim().isNotEmpty;
  }

  bool get hasChangedEntry {
    if (!_hasSavedResult(item)) {
      return hasEntry;
    }
    if (item.isNumeric) {
      return valueController.text.trim() != (item.resultValue ?? '').trim() ||
          unitController.text.trim() !=
              (item.resultUnit ?? item.unit ?? '').trim();
    }
    if (item.isQualitative && item.resultOptions.isNotEmpty) {
      return (selectedOption ?? '').trim() !=
          (item.resultText ?? item.resultValue ?? '').trim();
    }
    return textController.text.trim() != (item.resultText ?? '').trim();
  }

  void addListener(VoidCallback listener) {
    _onChanged = listener;
    valueController.addListener(listener);
    unitController.addListener(listener);
    textController.addListener(listener);
    notesController.addListener(listener);
    referenceRangeOverrideController.addListener(listener);
    resultFlagOverrideController.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    valueController.removeListener(listener);
    unitController.removeListener(listener);
    textController.removeListener(listener);
    notesController.removeListener(listener);
    referenceRangeOverrideController.removeListener(listener);
    resultFlagOverrideController.removeListener(listener);
    if (_onChanged == listener) {
      _onChanged = null;
    }
  }

  void notifyChanged() {
    _onChanged?.call();
  }

  void clearEntry() {
    valueController.clear();
    unitController.clear();
    textController.clear();
    notesController.clear();
    selectedOption = null;
    notifyChanged();
  }

  void applyServerItem(
    LabOrderItem serverItem, {
    required bool preserveUserEntry,
  }) {
    item = serverItem;
    showValidationError = false;
    if (preserveUserEntry) {
      return;
    }
    _syncControllersFromItem(serverItem);
  }

  void _syncControllersFromItem(LabOrderItem serverItem) {
    _setControllerText(valueController, serverItem.resultValue ?? '');
    _setControllerText(
      unitController,
      serverItem.resultUnit ?? serverItem.unit ?? '',
    );
    _setControllerText(textController, serverItem.resultText ?? '');
    selectedOption = serverItem.resultText ?? serverItem.resultValue;
    interpretationOverride = serverItem.interpretationOverride;
    _setControllerText(
      referenceRangeOverrideController,
      serverItem.referenceRangeOverride ??
          serverItem.referenceRangeSummary ??
          '',
    );
    _setControllerText(
      resultFlagOverrideController,
      serverItem.resultFlagOverride ?? serverItem.resultFlag ?? '',
    );
  }

  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) {
      return;
    }
    controller.text = text;
  }

  void dispose() {
    valueController.dispose();
    unitController.dispose();
    textController.dispose();
    notesController.dispose();
    referenceRangeOverrideController.dispose();
    resultFlagOverrideController.dispose();
  }

  Map<String, Object?> _interpretationPayload() {
    if (!interpretationOverride) {
      return const <String, Object?>{'interpretation_override': false};
    }
    return <String, Object?>{
      'interpretation_override': true,
      'reference_range_override': referenceRangeOverrideController.text.trim(),
      'result_flag_override': resultFlagOverrideController.text.trim(),
    };
  }

  Map<String, Object?> toPayload({
    bool includeOrderItemId = false,
    bool includeResultId = false,
    String? status,
  }) {
    final String value = valueController.text.trim();
    final String unit = unitController.text.trim();
    final String text = textController.text.trim();
    final bool hasOption = selectedOption?.trim().isNotEmpty ?? false;
    final String? option = hasOption ? selectedOption!.trim() : null;
    final String? resultId = includeResultId && _hasSavedResult(item)
        ? item.resultId
        : null;
    final Map<String, Object?> payload = <String, Object?>{
      if (includeOrderItemId) 'order_item_id': item.apiId,
      'result_id': ?resultId,
      'status': ?status,
      'reported_at': DateTime.now().toUtc().toIso8601String(),
      if (notesController.text.trim().isNotEmpty)
        'notes': notesController.text.trim(),
      ..._interpretationPayload(),
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

  Map<String, Object?> toSubmittedPayload() {
    final Map<String, Object?> payload = toPayload(
      status: _submittedResultStatus(item, this),
    );
    payload.remove('notes');
    return payload;
  }

  Map<String, Object?> toVerifiedPayload({bool includeOrderItemId = false}) {
    return toPayload(
      includeOrderItemId: includeOrderItemId,
      includeResultId: true,
      status: _submittedResultStatus(item, this),
    );
  }

  Map<String, Object?> toDraftPayload() {
    final Map<String, Object?> payload = toPayload();
    payload.remove('reported_at');
    payload.remove('notes');
    payload.remove('status');
    return payload;
  }
}

class _ReopenVerifiedResultDialog extends ConsumerStatefulWidget {
  const _ReopenVerifiedResultDialog({required this.item});

  final LabOrderItem item;

  @override
  ConsumerState<_ReopenVerifiedResultDialog> createState() =>
      _ReopenVerifiedResultDialogState();
}

class _ReopenVerifiedResultDialogState
    extends ConsumerState<_ReopenVerifiedResultDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _unitController;
  late final TextEditingController _textController;
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  String? _selectedOption;
  bool _valueError = false;
  AppFailure? _failure;
  bool _isSaving = false;

  LabOrderItem get _item => widget.item;

  bool get _usesOptions =>
      _item.isQualitative && _item.resultOptions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(text: _item.resultValue ?? '');
    _unitController = TextEditingController(
      text: _item.resultUnit ?? _item.unit ?? '',
    );
    _textController = TextEditingController(text: _item.resultText ?? '');
    _selectedOption = _item.resultText ?? _item.resultValue;
    _reasonController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    _textController.dispose();
    _reasonController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.labReopenVerifiedResultDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              l10n.labReopenVerifiedResultDialogBody,
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              _item.displayTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_item.displayReferenceRange != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                _item.displayReferenceRange!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            ..._buildValueEditor(l10n),
            if (_valueError) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                l10n.labResultEntryRequiredMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            AppTextField(
              controller: _reasonController,
              labelText: l10n.labReopenVerifiedReasonLabel,
              isRequired: true,
              enabled: !_isSaving,
              maxLines: 2,
              validator: AppValidators.minLength(
                2,
                l10n.validationRequired,
                allowEmpty: false,
                trim: true,
              ),
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
          label: l10n.labEditVerifiedResultAction,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  List<Widget> _buildValueEditor(AppLocalizations l10n) {
    if (_item.isNumeric) {
      return <Widget>[
        AppTextField(
          controller: _valueController,
          labelText: l10n.labResultValueLabel,
          isRequired: true,
          enabled: !_isSaving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (String? value) {
            final String normalized = value?.trim() ?? '';
            if (normalized.isEmpty) {
              return l10n.validationRequired;
            }
            return num.tryParse(normalized) == null
                ? l10n.labNumericRangeValidationMessage
                : null;
          },
        ),
        SizedBox(height: Theme.of(context).spacing.xs),
        _ResultUnitInput(
          item: _item,
          controller: _unitController,
          enabled: !_isSaving,
          onChanged: () => setState(() {}),
        ),
      ];
    }
    if (_usesOptions) {
      return <Widget>[
        AppSelectField<String>.searchable(
          value: _selectedOption,
          labelText: l10n.labResultValueLabel,
          isRequired: true,
          enabled: !_isSaving,
          options: <AppSelectOption<String>>[
            for (final LabResultOption option in _item.resultOptions)
              AppSelectOption<String>(
                value: option.value ?? option.label ?? option.id,
                label: option.displayLabel,
                leadingIcon: const Icon(Icons.checklist_outlined),
                searchText:
                    '${option.id} ${option.label ?? ''} ${option.value ?? ''} ${option.status ?? ''} ${option.resultFlag ?? ''}',
              ),
          ],
          onChanged: _isSaving
              ? null
              : (String? value) {
                  setState(() {
                    _selectedOption = value;
                    _valueError = false;
                  });
                },
        ),
      ];
    }
    return <Widget>[
      AppTextField(
        controller: _textController,
        labelText: _item.isQualitative
            ? l10n.labResultValueLabel
            : l10n.labResultTextLabel,
        isRequired: true,
        enabled: !_isSaving,
        maxLines: _item.isText ? 3 : 1,
        validator: AppValidators.minLength(
          1,
          l10n.validationRequired,
          allowEmpty: false,
          trim: true,
        ),
      ),
    ];
  }

  bool _hasValueEntry() {
    if (_item.isNumeric) {
      return _valueController.text.trim().isNotEmpty;
    }
    if (_usesOptions) {
      return _selectedOption?.trim().isNotEmpty ?? false;
    }
    return _textController.text.trim().isNotEmpty;
  }

  Map<String, Object?> _buildVerifyPayload() {
    final Map<String, Object?> payload = <String, Object?>{
      'reported_at': DateTime.now().toUtc().toIso8601String(),
      if (_notesController.text.trim().isNotEmpty)
        'notes': _notesController.text.trim(),
    };
    if (_item.isNumeric) {
      payload['result_value'] = _valueController.text.trim();
      final String unit = _unitController.text.trim();
      if (unit.isNotEmpty) {
        payload['result_unit'] = unit;
      }
      return payload;
    }
    if (_usesOptions) {
      payload['result_text'] = _selectedOption?.trim();
      return payload;
    }
    payload['result_text'] = _textController.text.trim();
    return payload;
  }

  Future<void> _submit() async {
    final bool formValid = _formKey.currentState?.validate() ?? false;
    final bool hasValue = _hasValueEntry();
    if (!hasValue && _usesOptions) {
      setState(() => _valueError = true);
    }
    if (!formValid || !hasValue) {
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
      _valueError = false;
    });

    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );

    final AppFailure? reopenFailure = await controller
        .reopenOrderItemResult(_item.apiId, <String, Object?>{
          'reason': _reasonController.text.trim(),
          if (_notesController.text.trim().isNotEmpty)
            'notes': _notesController.text.trim(),
        });
    if (!mounted) {
      return;
    }
    if (reopenFailure != null) {
      setState(() {
        _failure = reopenFailure;
        _isSaving = false;
      });
      return;
    }

    final AppFailure? verifyFailure = await controller.verifyOrderItem(
      _item.apiId,
      _buildVerifyPayload(),
    );
    if (!mounted) {
      return;
    }
    if (verifyFailure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = verifyFailure;
      _isSaving = false;
    });
  }
}

class _RejectOrderItemDialog extends ConsumerStatefulWidget {
  const _RejectOrderItemDialog({required this.items});

  final List<LabOrderItem> items;

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
      title: Text(
        widget.items.length == 1
            ? l10n.labRejectOrderItemDialogTitle
            : 'Reject ${widget.items.length} tests',
      ),
      icon: const Icon(Icons.block_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
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
          label: widget.items.length == 1
              ? l10n.labRejectOrderItemAction
              : 'Reject all tests',
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
    AppFailure? failure;
    final LabWorkspaceController controller = ref.read(
      labWorkspaceControllerProvider.notifier,
    );
    for (final LabOrderItem item in widget.items) {
      failure = await controller.rejectOrderItem(item.apiId, <String, Object?>{
        'reason': reason,
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
      });
      if (failure != null) {
        break;
      }
    }
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

class _DeleteOrderItemDialog extends ConsumerStatefulWidget {
  const _DeleteOrderItemDialog({required this.item});

  final LabOrderItem item;

  @override
  ConsumerState<_DeleteOrderItemDialog> createState() =>
      _DeleteOrderItemDialogState();
}

class _DeleteOrderItemDialogState
    extends ConsumerState<_DeleteOrderItemDialog> {
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
      title: Text(l10n.labDeleteOrderItemDialogTitle),
      icon: const Icon(Icons.delete_outline),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.labDeleteOrderItemDialogBody(widget.item.displayTitle)),
            SizedBox(height: Theme.of(context).spacing.sm),
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
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
          label: l10n.labDeleteOrderItemAction,
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
    final String? orderId = widget.item.labOrderId;
    if (orderId == null || orderId.trim().isEmpty) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(labWorkspaceControllerProvider.notifier)
        .deleteOrderItems(orderId, <String, Object?>{
          'order_item_ids': <String>[widget.item.apiId],
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
  if (draft.interpretationOverride) {
    final String overrideFlag = draft.resultFlagOverrideController.text
        .trim()
        .toUpperCase();
    if (overrideFlag.isNotEmpty) {
      return _isAbnormalStatus(overrideFlag);
    }
  }
  if (!draft.hasChangedEntry && _isAbnormalStatus(item.effectiveResultStatus)) {
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

String? _computedNumericFlagToken(LabOrderItem item, String valueText) {
  if (!item.isNumeric || item.referenceRanges.isEmpty) {
    return null;
  }
  final num? parsed = num.tryParse(valueText.trim());
  if (parsed == null) {
    return null;
  }
  final LabReferenceRange range = item.referenceRanges.first;
  final num? criticalMin = num.tryParse(range.criticalMinValue ?? '');
  final num? criticalMax = num.tryParse(range.criticalMaxValue ?? '');
  final num? normalMin = num.tryParse(range.normalMinValue ?? '');
  final num? normalMax = num.tryParse(range.normalMaxValue ?? '');
  if (criticalMin != null && parsed < criticalMin) {
    return 'CRITICAL';
  }
  if (criticalMax != null && parsed > criticalMax) {
    return 'CRITICAL';
  }
  if (normalMin != null && parsed < normalMin) {
    return 'LOW';
  }
  if (normalMax != null && parsed > normalMax) {
    return 'HIGH';
  }
  return 'NORMAL';
}

String? _storedQualitativeOptionFlag(LabOrderItem item) {
  final String selected = (item.resultText ?? item.resultValue ?? '').trim();
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

String _resolveItemResultFlagLabel(
  BuildContext context,
  LabOrderItem item, {
  _ResultDraft? draft,
}) {
  if (draft != null && draft.interpretationOverride) {
    final String overrideFlag = draft.resultFlagOverrideController.text.trim();
    if (overrideFlag.isNotEmpty) {
      return labStatusLabel(context, overrideFlag);
    }
  } else if (item.interpretationOverride) {
    final String overrideFlag = item.resultFlagOverride ?? '';
    if (overrideFlag.trim().isNotEmpty) {
      return labStatusLabel(context, overrideFlag);
    }
  }

  if (item.isRejected) {
    return labStatusLabel(context, 'CANCELLED');
  }

  final String? explicitFlag = item.resultFlag;
  if (explicitFlag != null && explicitFlag.trim().isNotEmpty) {
    return labStatusLabel(context, explicitFlag);
  }

  final String? optionFlag = draft != null
      ? _selectedResultOptionFlag(item, draft)
      : _storedQualitativeOptionFlag(item);
  if (optionFlag != null && optionFlag.trim().isNotEmpty) {
    return labStatusLabel(context, optionFlag);
  }

  final String valueText = draft != null
      ? draft.valueController.text
      : (item.resultValue ?? '');
  if (valueText.trim().isNotEmpty) {
    final String? computed = _computedNumericFlagToken(item, valueText);
    if (computed != null) {
      return labStatusLabel(context, computed);
    }
  }

  return labStatusLabel(context, item.effectiveResultStatus);
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

bool _hasSavedResult(LabOrderItem item) {
  return item.resultId != null && item.resultId!.trim().isNotEmpty;
}

bool _canSaveDraft(_ResultDraft draft) {
  return draft.item.canEnterResult && draft.hasEntry;
}

List<_ResultDraft> _selectedSaveTargets(List<_ResultDraft> selected) {
  return selected
      .where(
        (_ResultDraft draft) =>
            draft.item.canEnterResult && !draft.item.isRejected,
      )
      .toList(growable: false);
}

List<_ResultDraft> _selectedSubmitTargets(List<_ResultDraft> selected) {
  return selected
      .where(
        (_ResultDraft draft) =>
            draft.item.canEnterResult &&
            !draft.item.isCompleted &&
            !draft.item.isRejected,
      )
      .toList(growable: false);
}

List<_ResultDraft> _selectedVerifyTargets(List<_ResultDraft> selected) {
  return selected
      .where(
        (_ResultDraft draft) => draft.item.canVerify && !draft.item.isRejected,
      )
      .toList(growable: false);
}

bool _canSubmitDraft(_ResultDraft draft) {
  return draft.item.canEnterResult && !draft.item.isCompleted && draft.hasEntry;
}

bool _canVerifyDraft(_ResultDraft draft) {
  return draft.item.canVerify &&
      (draft.hasEntry || _hasSavedResult(draft.item));
}

bool _validateDraftForPersist(_ResultDraft draft, {required bool forVerify}) {
  if (forVerify && _hasSavedResult(draft.item) && !draft.hasChangedEntry) {
    draft.showValidationError = false;
    return true;
  }
  if (!draft.hasEntry) {
    draft.showValidationError = true;
    return false;
  }
  if (!draft.item.canEnterResult) {
    draft.showValidationError = false;
    return _hasSavedResult(draft.item);
  }
  final bool isValid = draft.formKey.currentState?.validate() ?? true;
  draft.showValidationError = !isValid;
  return isValid;
}

void _scrollToFirstInvalidDraft(List<_ResultDraft> drafts) {
  _ResultDraft? invalidDraft;
  for (final _ResultDraft draft in drafts) {
    if (draft.showValidationError) {
      invalidDraft = draft;
      break;
    }
  }
  if (invalidDraft == null) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final BuildContext? context = invalidDraft!.rowKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.15,
    );
  });
}

bool _isBulkSelectable(_ResultDraft draft) {
  return _canSaveDraft(draft) ||
      _canSubmitDraft(draft) ||
      _canVerifyDraft(draft) ||
      _canRemoveResult(draft.item, draft) ||
      draft.item.canReject;
}

String _submittedResultStatus(LabOrderItem item, _ResultDraft draft) {
  final String? explicitStatus = _resultStatusFromToken(
    item.resultFlag ?? item.resultStatus,
  );
  if (explicitStatus != null && !draft.hasChangedEntry) {
    return explicitStatus;
  }

  if (item.isQualitative) {
    final String? optionFlag = _selectedResultOptionFlag(item, draft);
    final String? optionStatus = _resultStatusFromToken(optionFlag);
    if (optionStatus != null) {
      return optionStatus;
    }
  }

  if (item.isNumeric && item.referenceRanges.isNotEmpty) {
    final num? parsed = num.tryParse(draft.valueController.text.trim());
    if (parsed != null) {
      final LabReferenceRange range = item.referenceRanges.first;
      final num? criticalMin = num.tryParse(range.criticalMinValue ?? '');
      final num? criticalMax = num.tryParse(range.criticalMaxValue ?? '');
      final num? normalMin = num.tryParse(range.normalMinValue ?? '');
      final num? normalMax = num.tryParse(range.normalMaxValue ?? '');
      if (criticalMin != null && parsed < criticalMin) {
        return 'CRITICAL';
      }
      if (criticalMax != null && parsed > criticalMax) {
        return 'CRITICAL';
      }
      if (normalMin != null && parsed < normalMin) {
        return 'ABNORMAL';
      }
      if (normalMax != null && parsed > normalMax) {
        return 'ABNORMAL';
      }
    }
  }

  if (_isAbnormalEntry(item, draft)) {
    return 'ABNORMAL';
  }
  return 'NORMAL';
}

String? _resultStatusFromToken(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'CRITICAL' || 'CRITICAL_LOW' || 'CRITICAL_HIGH' => 'CRITICAL',
    'ABNORMAL' || 'HIGH' || 'LOW' || 'POSITIVE' || 'REACTIVE' => 'ABNORMAL',
    'NORMAL' || 'NEGATIVE' || 'NON_REACTIVE' || 'NOT_DETECTED' => 'NORMAL',
    _ => null,
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

PrintFormPatientContext _reportPatientContext(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
) {
  final AppLocalizations l10n = context.l10n;
  final LabOrderSummary firstOrder = workflows.first.order;
  final List<String> encounterIds = _uniqueNonEmpty(
    workflows.map((LabOrderWorkflow workflow) => workflow.order.encounterId),
  );
  return buildPrintFormPatientContext(
    l10n,
    patientName: firstOrder.patientDisplayName ?? l10n.profileUnknownValue,
    patientId: firstOrder.patientId,
    encounterId: encounterIds.length == 1 ? encounterIds.single : null,
    patientNameLabel: l10n.labReportPatientLabel,
    patientIdLabel: l10n.labPatientIdFieldLabel,
    encounterIdLabel: l10n.labEncounterFieldLabel,
  );
}

PrintFormContextReference? _reportContextReference(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
) {
  final AppLocalizations l10n = context.l10n;
  final List<String> orderIds = _uniqueNonEmpty(
    workflows.map(
      (LabOrderWorkflow workflow) =>
          workflow.order.displayId ?? workflow.order.apiId,
    ),
  );
  if (orderIds.isEmpty) {
    return null;
  }
  return PrintFormContextReference(
    label: l10n.labOrderFieldLabel,
    value: orderIds.length == 1 ? orderIds.single : orderIds.join(', '),
  );
}

List<PrintFormPage> _reportPages(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
  Set<String> selectedItemIds,
  List<String> visibleColumnKeys,
) {
  final AppLocalizations l10n = context.l10n;
  return <PrintFormPage>[
    PrintFormPage(
      title: l10n.labReportTitle,
      bodyHtml: _labReportHtml(
        context,
        workflows,
        selectedItemIds,
        visibleColumnKeys,
      ),
    ),
  ];
}

String _labReportHtml(
  BuildContext context,
  List<LabOrderWorkflow> workflows,
  Set<String> selectedItemIds,
  List<String> visibleColumnKeys,
) {
  final String table = _labReportTableHtml(
    context,
    _selectedReportItems(workflows, selectedItemIds),
    visibleColumnKeys,
  );
  return '''
${_labReportPrintStyle()}
<div class="lab-report-compact">
  $table
</div>
''';
}

String _labReportTableHtml(
  BuildContext context,
  List<LabOrderItem> items,
  List<String> visibleColumnKeys,
) {
  final AppLocalizations l10n = context.l10n;
  if (visibleColumnKeys.isEmpty) {
    return '<p class="print-template-empty">${PrintFormTemplate.escape(l10n.labNoOrderItemsEntryTitle)}</p>';
  }
  if (items.isEmpty) {
    return '<p class="print-template-empty">${PrintFormTemplate.escape(l10n.labNoOrderItemsEntryTitle)}</p>';
  }

  final List<String> headers = <String>[
    for (final String key in visibleColumnKeys)
      _labReportColumnHeader(context, key),
  ];
  final List<List<String>> rows = <List<String>>[
    for (final LabOrderItem item in items)
      <String>[
        for (final String key in visibleColumnKeys)
          _labReportColumnValue(context, item, key),
      ],
  ];

  final String table = PrintFormTemplate.table(
    headers: headers,
    rows: rows,
    emptyText: l10n.labNoOrderItemsEntryTitle,
  );

  final String styledRows = items.asMap().entries.map((
    MapEntry<int, LabOrderItem> entry,
  ) {
    if (!_isAbnormalReportItem(entry.value)) {
      return '';
    }
    final int rowIndex = entry.key + 1;
    return '''
.lab-report-tests .print-template-table tbody tr:nth-child($rowIndex) td {
  color: #b3261e;
  font-weight: 700;
}
''';
  }).join();

  return '''
<style>$styledRows</style>
<div class="lab-report-tests">$table</div>
''';
}

String _labReportColumnHeader(BuildContext context, String key) {
  final AppLocalizations l10n = context.l10n;
  return switch (key) {
    'tests' => l10n.labTestsColumnLabel,
    'reference_range' => l10n.labReferenceRangeLabel,
    'result' => l10n.labReportResultLabel,
    'flag' => l10n.labResultFlagLabel,
    _ => key,
  };
}

String _labReportColumnValue(
  BuildContext context,
  LabOrderItem item,
  String key,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (key) {
    'tests' => item.displayTitle,
    'reference_range' => item.displayReferenceRange ?? l10n.profileUnknownValue,
    'result' => item.displayResultValue ?? l10n.labStatusPendingResults,
    'flag' => _resolveItemResultFlagLabel(context, item),
    _ => '',
  };
}

String _labReportPrintStyle() {
  return '''
<style>
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
</style>
''';
}

String _itemSelectionKey(LabOrderItem item) {
  return _joinDisplay(<String?>[item.labOrderId, item.apiId]) ?? item.apiId;
}

List<LabOrderItem> _reportItems(List<LabOrderWorkflow> workflows) {
  return <LabOrderItem>[
    for (final LabOrderWorkflow workflow in workflows)
      for (final LabOrderItem item in workflow.order.items) item,
  ];
}

bool _matchesReportItemSearch(
  BuildContext context,
  LabOrderItem item,
  String query,
) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  final Iterable<String> values = <String>[
    item.displayTitle,
    item.displayReferenceRange ?? '',
    _reportItemDisplayResult(context, item),
    _resolveItemResultFlagLabel(context, item),
  ].map((String value) => value.trim().toLowerCase());
  return values.any((String value) => value.contains(normalized));
}

String _reportItemDisplayResult(BuildContext context, LabOrderItem item) {
  final AppLocalizations l10n = context.l10n;
  final String? value = item.displayResultValue;
  if (value == null || value.trim().isEmpty) {
    return l10n.labStatusPendingResults;
  }
  return value;
}

bool _matchesReportItemFilter(
  BuildContext context,
  LabOrderItem item,
  AppSearchBarFilterValue filterValue,
  Set<String> selectedItemIds,
) {
  if (!filterValue.isActive) {
    return true;
  }

  final String? flagFilter = filterValue.option(_labReportFlagFilterKey);
  if (flagFilter != null &&
      !_matchesReportItemFlagFilter(context, item, flagFilter)) {
    return false;
  }

  final String? selectionFilter = filterValue.option(
    _labReportSelectionFilterKey,
  );
  if (selectionFilter != null) {
    final bool isSelected = selectedItemIds.contains(_itemSelectionKey(item));
    return switch (selectionFilter) {
      'selected' => isSelected,
      'unselected' => !isSelected,
      _ => true,
    };
  }

  return true;
}

bool _matchesReportItemFlagFilter(
  BuildContext context,
  LabOrderItem item,
  String flagFilter,
) {
  final String token = _resolveReportItemFlagToken(context, item);
  if (token == flagFilter) {
    return true;
  }
  if (flagFilter == 'ABNORMAL') {
    return <String>{'ABNORMAL', 'HIGH', 'LOW'}.contains(token);
  }
  if (flagFilter == 'NEGATIVE') {
    if (token == 'NEGATIVE' || token == 'NON_REACTIVE') {
      return true;
    }
    final String label = _resolveItemResultFlagLabel(
      context,
      item,
    ).trim().toLowerCase();
    return label == context.l10n.labNegativeOption.trim().toLowerCase();
  }
  return false;
}

String _resolveReportItemFlagToken(BuildContext context, LabOrderItem item) {
  if (item.isRejected || _isCancelledItem(item)) {
    return 'CANCELLED';
  }

  final String? explicitFlag = item.resultFlag?.trim().toUpperCase();
  if (explicitFlag != null && explicitFlag.isNotEmpty) {
    return explicitFlag;
  }

  final String? optionFlag = _storedQualitativeOptionFlag(
    item,
  )?.trim().toUpperCase();
  if (optionFlag != null && optionFlag.isNotEmpty) {
    return optionFlag;
  }

  final String valueText = item.resultValue?.trim() ?? '';
  if (valueText.isNotEmpty) {
    final String? computed = _computedNumericFlagToken(item, valueText);
    if (computed != null && computed.trim().isNotEmpty) {
      return computed.trim().toUpperCase();
    }
  }

  final String? displayResult = item.displayResultValue?.trim();
  if (displayResult == null || displayResult.isEmpty) {
    return 'PENDING';
  }

  final String? status = item.effectiveResultStatus?.trim().toUpperCase();
  if (status != null && status.isNotEmpty) {
    return status;
  }

  return 'PENDING';
}

bool _isAbnormalReportItem(LabOrderItem item) {
  final String? flagToken =
      _computedNumericFlagToken(item, item.resultValue ?? '') ??
      item.resultFlag ??
      item.effectiveResultStatus;
  return _isAbnormalStatus(flagToken);
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

String? _optionalDateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) {
    return null;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' · ');
  return joined.isEmpty ? null : joined;
}
