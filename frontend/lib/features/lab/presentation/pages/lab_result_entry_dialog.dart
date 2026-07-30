import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/controllers/lab_workspace_controller.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_status_display.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_format.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_result_value_unit_fields.dart';
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
    super.key,
  });

  final bool canMutate;

  @override
  ConsumerState<LabResultEntryDialog> createState() =>
      _LabResultEntryDialogState();
}

class _LabResultEntryDialogState extends ConsumerState<LabResultEntryDialog> {
  List<_ResultDraft>? _drafts;
  String? _draftSignature;
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

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    final bool compact = AppBreakpoints.of(context).isMobile;
    final bool showActionLabels = AppBreakpoints.of(
      context,
    ).showsToolbarActionLabels;
    final List<_ResultDraft> saveableDrafts = drafts
        .where(_canSaveResultDraft)
        .toList(growable: false);
    final bool hasSaveableDrafts = saveableDrafts.isNotEmpty;

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
                AppAccessActionGate(
                  requirement: labReportPreviewRequirement,
                  builder: (BuildContext context, bool isAllowed) {
                    return AppReportActionButton.preview(
                      label: l10n.labPreviewReportAction,
                      enabled: isAllowed && !_isSaving,
                      onPressed: isAllowed && !_isSaving
                          ? () => _openPrintPreview(context, workflows)
                          : null,
                    );
                  },
                ),
                AppAccessActionGate(
                  requirement: labWorkspaceWriteRequirement,
                  builder: (BuildContext context, bool isAllowed) {
                    final bool canSave =
                        canMutate && isAllowed && hasSaveableDrafts;
                    return AppButton.primary(
                      label: l10n.labSaveResultsAction,
                      leadingIcon: Icons.save_outlined,
                      isLoading: _isSaving,
                      enabled: canSave,
                      onPressed: canSave
                          ? () => _saveResultsDrafts(saveableDrafts)
                          : null,
                    );
                  },
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
                  onEditSaved: _editSavedResult,
                ),
                SizedBox(height: Theme.of(context).spacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveResultsDrafts(List<_ResultDraft> drafts) async {
    await _persistDrafts(
      drafts,
      _saveValidDrafts,
      successMessage: context.l10n.labResultsVerifiedMessage,
      partialMessage: context.l10n.labBatchPartialSaveMessage,
      forFinalize: true,
      actionLabel: context.l10n.labSaveResultsAction,
    );
  }

  List<_ResultDraft> _draftsNeedingPersistBeforeSave(
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

  Future<LabBatchPersistOutcome> _saveValidDrafts(
    List<_ResultDraft> validDrafts,
  ) async {
    final List<_ResultDraft> needsSubmit = _draftsNeedingPersistBeforeSave(
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

    return _savePersistedDrafts(validDrafts);
  }

  Future<LabBatchPersistOutcome> _savePersistedDrafts(
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
      entries.add((item: freshItem, payload: draft.toSaveResultPayload()));
    }
    return ref
        .read(labWorkspaceControllerProvider.notifier)
        .saveOrderItemResults(entries);
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
    bool forFinalize = false,
  }) async {
    for (final _ResultDraft draft in drafts) {
      draft.showValidationError = false;
    }
    final List<_ResultDraft> validDrafts = <_ResultDraft>[];
    var invalidCount = 0;
    for (final _ResultDraft draft in drafts) {
      if (_validateDraftForPersist(draft, forFinalize: forFinalize)) {
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

  Future<void> _editSavedResult(_ResultDraft draft) async {
    final bool? reopened = await showAppDialog<bool>(
      context: context,
      builder: (_) => _ReopenSavedResultDialog(item: draft.item),
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
    final AppLocalizations l10n = context.l10n;
    final LabOrderSummary firstOrder = workflows.first.order;
    final List<String> encounterIds = _uniqueNonEmpty(
      workflows.map((LabOrderWorkflow workflow) => workflow.order.encounterId),
    );
    final String patientName =
        firstOrder.patientDisplayName ?? l10n.profileUnknownValue;
    final String patientNumber = (firstOrder.patientId ?? '').trim();
    final AppWorkspaceStatus status = _aggregateOrderStatus(context, workflows);
    final List<AppWorkspaceStatus> alerts = _aggregateOrderSubStatuses(
      context,
      workflows,
    );
    final String encounterValue = encounterIds.join(', ');

    return AppPatientDetails(
      patientName: patientName,
      patientNumber: patientNumber,
      patientNumberLabel: l10n.labPatientIdFieldLabel,
      copyPatientNumberTooltip: l10n.copyIdentifierAction,
      copyPatientNumberMessage: l10n.identifierCopiedMessage,
      semanticLabel: l10n.labPatientContextLabel,
      showAvatar: false,
      persistExpandPreference: false,
      initiallyExpanded: false,
      alerts: alerts,
      expandedFields: <AppWorkspacePatientContextField>[
        AppWorkspacePatientContextField(
          label: l10n.labOrderStatusFieldLabel,
          value: status.label,
          icon: status.icon ?? Icons.assignment_outlined,
          tone: status.tone,
        ),
        AppWorkspacePatientContextField(
          label: l10n.labEncounterFieldLabel,
          value: encounterValue,
          icon: Icons.badge_outlined,
          copyable: encounterIds.length == 1,
          copyTooltip: l10n.opdCopyEncounterIdAction,
          copiedMessage: l10n.opdEncounterIdCopiedMessage,
        ),
        AppWorkspacePatientContextField(
          label: l10n.labOrdersIncludedLabel,
          value: l10n.labActiveOrderCount(workflows.length),
          icon: Icons.science_outlined,
        ),
      ],
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
                  fontWeight: FontWeight.w500,
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
        fontWeight: FontWeight.w600,
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
    required this.onEditSaved,
  });

  final LabOrderWorkflow workflow;
  final List<_ResultDraft> drafts;
  final List<LabCatalogItem> catalogPanels;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onEditSaved;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final LabOrderSummary order = workflow.order;

    // Flat sections: item/panel groups only (no order meta / edit-delete chrome).
    if (drafts.isEmpty) {
      return AppWorkspaceDetailPanel(
        title: l10n.labItemsSectionTitle,
        collapsible: false,
        child: AppWorkspaceStatePanel.empty(
          title: l10n.labNoOrderItemsEntryTitle,
          body: l10n.labNoOrderItemsEntryBody,
          icon: Icons.science_outlined,
        ),
      );
    }

    return _LabResultEntryTable(
      drafts: drafts,
      catalogPanels: catalogPanels,
      canMutate: canMutate,
      patientGender: order.patientGender,
      onEditSaved: onEditSaved,
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
    required this.onEditSaved,
    this.patientGender,
    this.embeddedInPanel = false,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onEditSaved;
  final String? patientGender;
  final bool embeddedInPanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 760) {
          return _LabResultEntryCards(
            drafts: drafts,
            canMutate: canMutate,
            patientGender: patientGender,
            onEditSaved: onEditSaved,
          );
        }
        return _LabResultEntryRowsTable(
          drafts: drafts,
          canMutate: canMutate,
          patientGender: patientGender,
          onEditSaved: onEditSaved,
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
    required this.onEditSaved,
    this.patientGender,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onEditSaved;
  final String? patientGender;

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
                  : _resultRowAccentColor(theme, draft.item, draft) ??
                      theme.colorScheme.surfaceContainerLowest,
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
                    _LabResultTestCell(draft: draft),
                    SizedBox(height: theme.spacing.sm),
                    _LabReferenceRangeCell(
                      draft: draft,
                      patientGender: patientGender,
                    ),
                    SizedBox(height: theme.spacing.sm),
                    draft.item.canEnterResult
                        ? _CompactResultInput(
                            draft: draft,
                            enabled: canMutate && draft.item.canEnterResult,
                            patientGender: patientGender,
                          )
                        : _CompletedResultReadout(
                            item: draft.item,
                            patientGender: patientGender,
                            onEdit: canMutate && draft.item.canReopenResult
                                ? () => onEditSaved(draft)
                                : null,
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
    required this.onEditSaved,
    this.patientGender,
  });

  final List<_ResultDraft> drafts;
  final List<LabCatalogItem> catalogPanels;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onEditSaved;
  final String? patientGender;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_LabPanelDraftGroup> groups = _groupDraftsForDisplay(
      drafts,
      catalogPanels,
    );
    final EdgeInsetsGeometry panelPadding = EdgeInsets.symmetric(
      horizontal: theme.spacing.sm,
      vertical: theme.spacing.sm,
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
              contentPadding: panelPadding,
              child: _ResponsiveLabResultEntry(
                drafts: group.drafts,
                canMutate: canMutate,
                patientGender: patientGender,
                onEditSaved: onEditSaved,
                embeddedInPanel: true,
              ),
            )
          else
            for (final _ResultDraft draft in group.drafts) ...<Widget>[
              AppWorkspaceDetailPanel(
                title: draft.item.displayTitle,
                collapsible: true,
                contentPadding: panelPadding,
                child: _ResponsiveLabResultEntry(
                  drafts: <_ResultDraft>[draft],
                  canMutate: canMutate,
                  patientGender: patientGender,
                  onEditSaved: onEditSaved,
                  embeddedInPanel: true,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
            ],
          if (group.panelTitle != null) SizedBox(height: theme.spacing.sm),
        ],
      ],
    );
  }
}

class _LabPanelResultBlock extends ConsumerWidget {
  const _LabPanelResultBlock({
    required this.title,
    required this.child,
    this.orderId,
    this.itemIds = const <String>[],
    this.canDelete = false,
    this.contentPadding,
  });

  final String title;
  final Widget child;
  final String? orderId;
  final List<String> itemIds;
  final bool canDelete;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool showDelete =
        canDelete &&
        itemIds.isNotEmpty &&
        orderId != null &&
        orderId!.trim().isNotEmpty;

    return AppWorkspaceDetailPanel(
      title: title,
      titleIcon: Icons.inventory_2_outlined,
      collapsible: true,
      contentPadding: contentPadding,
      headerActions: showDelete
          ? <Widget>[
              AppButton(
                iconOnly: true,
                leadingIcon: Icons.delete_outline,
                label: l10n.labDeletePanelAction,
                semanticLabel: l10n.labDeletePanelAction,
                tooltip: l10n.labDeletePanelAction,
                color: theme.statusColors.danger,
                onPressed: () => _deletePanel(context, ref),
              ),
            ]
          : const <Widget>[],
      child: child,
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

class _LabResultEntryRowsTable extends StatelessWidget {
  const _LabResultEntryRowsTable({
    required this.drafts,
    required this.canMutate,
    required this.onEditSaved,
    required this.availableWidth,
    this.patientGender,
    this.embeddedInPanel = false,
  });

  final List<_ResultDraft> drafts;
  final bool canMutate;
  final ValueChanged<_ResultDraft> onEditSaved;
  final String? patientGender;
  final double availableWidth;
  final bool embeddedInPanel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final double tableWidth = availableWidth
        .clamp(900.0, double.infinity)
        .toDouble();
    final Color borderColor = colorScheme.outlineVariant;
    final TableBorder tableBorder = TableBorder(
      horizontalInside: BorderSide(color: borderColor),
      verticalInside: BorderSide(color: borderColor),
    );

    final Widget table = SizedBox(
      width: tableWidth,
      child: Table(
        border: tableBorder,
        columnWidths: const <int, TableColumnWidth>{
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.6),
          2: FlexColumnWidth(4.0),
        },
        children: <TableRow>[
          TableRow(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
            ),
            children: <Widget>[
              _LabResultTableCell.header(label: l10n.labTestsColumnLabel),
              _LabResultTableCell.header(label: l10n.labReferenceRangeLabel),
              _LabResultTableCell.header(label: l10n.labReportResultLabel),
            ],
          ),
          for (final _ResultDraft draft in drafts)
            _labResultEntryTableRow(
              context,
              draft: draft,
              canMutate: canMutate,
              patientGender: patientGender,
              onEditSaved: () => onEditSaved(draft),
            ),
        ],
      ),
    );

    final Widget scrollable = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: table,
    );

    if (embeddedInPanel) {
      return scrollable;
    }

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: scrollable,
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
      child: Align(
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }
}

class _LabResultHeaderText extends StatelessWidget {
  const _LabResultHeaderText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.1,
      ),
    );
  }
}

TableRow _labResultEntryTableRow(
  BuildContext context, {
  required _ResultDraft draft,
  required bool canMutate,
  required VoidCallback onEditSaved,
  String? patientGender,
}) {
  final ThemeData theme = Theme.of(context);
  final LabOrderItem item = draft.item;
  final bool canEdit = canMutate && item.canEnterResult;
  final bool cancelled = _isCancelledItem(item);

  return TableRow(
    decoration: BoxDecoration(
      color: cancelled
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.22)
          : draft.showValidationError
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.28)
          : _resultRowAccentColor(theme, item, draft) ??
              theme.colorScheme.surfaceContainerLowest,
      border: cancelled || draft.showValidationError
          ? Border.all(color: theme.colorScheme.error, width: 1.5)
          : null,
    ),
    children: <Widget>[
      _LabResultTableCell(
        child: KeyedSubtree(
          key: draft.rowKey,
          child: _LabResultTestCell(draft: draft),
        ),
      ),
      _LabResultTableCell(
        child: _LabReferenceRangeCell(
          draft: draft,
          patientGender: patientGender,
        ),
      ),
      _LabResultTableCell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            item.canEnterResult
                ? _CompactResultInput(
                    draft: draft,
                    enabled: canEdit,
                    patientGender: patientGender,
                  )
                : _CompletedResultReadout(
                    item: item,
                    patientGender: patientGender,
                    onEdit: canMutate && item.canReopenResult
                        ? onEditSaved
                        : null,
                  ),
            if (draft.showValidationError && !item.canEnterResult) ...<Widget>[
              SizedBox(height: Theme.of(context).spacing.xs),
              _LabResultValidationMessage(draft: draft),
            ],
          ],
        ),
      ),
    ],
  );
}

class _LabResultTestCell extends StatelessWidget {
  const _LabResultTestCell({required this.draft});

  final _ResultDraft draft;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LabOrderItem item = draft.item;
    final TextStyle titleStyle =
        theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(item.displayTitle, style: titleStyle),
        if (draft.showValidationError) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          _LabResultValidationMessage(draft: draft),
        ],
      ],
    );
  }
}

class _LabReferenceRangeCell extends StatelessWidget {
  const _LabReferenceRangeCell({
    required this.draft,
    this.patientGender,
  });

  final _ResultDraft draft;
  final String? patientGender;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final LabOrderItem item = draft.item;
    final String? autoRange = resolveDisplayReferenceRange(
      item,
      patientGender: patientGender,
    );
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
            isDense: true,
            onChanged: (_) => draft.notifyChanged(),
          ),
        ],
      ],
    );
  }
}

class _CompactResultInput extends StatefulWidget {
  const _CompactResultInput({
    required this.draft,
    required this.enabled,
    this.patientGender,
  });

  final _ResultDraft draft;
  final bool enabled;
  final String? patientGender;

  @override
  State<_CompactResultInput> createState() => _CompactResultInputState();
}

class _CompactResultInputState extends State<_CompactResultInput> {
  @override
  Widget build(BuildContext context) {
    final LabOrderItem item = widget.draft.item;
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool enabled = widget.enabled;
    final AppWorkspaceStatusTone? tone = _resultInterpretationTone(
      item,
      widget.draft,
      patientGender: widget.patientGender,
    );
    final String? flagToken = _resultInterpretationFlagToken(
      item,
      widget.draft,
      patientGender: widget.patientGender,
    );

    // Keep field-affixed clear/dropdown controls icon-only so toolbar
    // showLabels scope cannot expand them into overflowing labeled pills.
    return AppActionLabelScope(
      showLabels: false,
      forceIconOnly: true,
      child: Form(
        key: widget.draft.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (item.isNumeric) ...<Widget>[
              LabResultValueUnitFields(
                valueController: widget.draft.valueController,
                unitController: widget.draft.unitController,
                item: item,
                enabled: enabled,
                onChanged: enabled
                    ? () {
                        setState(() {});
                        widget.draft.notifyChanged();
                      }
                    : null,
                valueValidator: (String? value) {
                  final String normalized = value?.trim() ?? '';
                  if (normalized.isEmpty) {
                    return null;
                  }
                  return num.tryParse(normalized) == null
                      ? l10n.labNumericRangeValidationMessage
                      : null;
                },
              ),
            ] else if (item.isQualitative && item.resultOptions.isNotEmpty)
              AppSelectField<String>.searchable(
                value: widget.draft.selectedOption,
                labelText: l10n.labResultValueLabel,
                enabled: enabled,
                isDense: true,
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
                isDense: true,
                maxLines: item.isText ? 3 : 1,
                onChanged: enabled ? (_) => widget.draft.notifyChanged() : null,
              ),
            if (tone != null &&
                flagToken != null &&
                widget.draft.hasEntry) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: labStatusLabel(context, flagToken),
                    tone: tone,
                  ),
                ),
              ),
            ],
            SizedBox(height: theme.spacing.xs),
            AppTextField(
              controller: widget.draft.notesController,
              labelText: l10n.labNotesLabel,
              enabled: enabled,
              isDense: true,
              onChanged: enabled ? (_) => widget.draft.notifyChanged() : null,
            ),
            if (widget.draft.showValidationError) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                widget.draft.hasEntry
                    ? l10n.labBatchEntryValidationMessage
                    : l10n.labResultEntryRequiredMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedResultReadout extends StatelessWidget {
  const _CompletedResultReadout({
    required this.item,
    this.patientGender,
    this.onEdit,
  });

  final LabOrderItem item;
  final String? patientGender;
  final VoidCallback? onEdit;

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

    final String? flagToken = _resultInterpretationFlagToken(
      item,
      null,
      patientGender: patientGender,
    );
    final AppWorkspaceStatusTone tone =
        _resultInterpretationTone(
          item,
          null,
          patientGender: patientGender,
        ) ??
        AppWorkspaceStatusTone.neutral;
    final Color valueColor = _resultInterpretationForeground(theme, tone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (flagToken != null &&
            tone != AppWorkspaceStatusTone.neutral) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          AppWorkspaceStatusBadge(
            status: AppWorkspaceStatus(
              label: labStatusLabel(context, flagToken),
              tone: tone,
            ),
          ),
        ],
        if (onEdit != null) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          AppButton.tertiary(
            label: l10n.labEditVerifiedResultAction,
            leadingIcon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        ],
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
    final List<LabOrderItem> printableItems = _printableReleasedReportItems(
      _allReportItems,
    );
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool printAuthorized = canPreviewLabReport(policy);
    final bool printEligible = appClinicalResultsPrintEligible(
      authorized: printAuthorized,
      hasPrintableReleasedContent: printableItems.isNotEmpty,
    );
    return AppDialog(
      title: Text(l10n.labReportPreviewTitle),
      icon: const Icon(Icons.print_outlined),
      scrollable: true,
      maxWidth: 1040,
      closeEnabled: !_isPrinting,
      content: AppClinicalResultsPreview(
        mode: AppClinicalResultsPreviewMode.modal,
        title: l10n.labReportPreviewTitle,
        status: printableItems.isEmpty
            ? AppClinicalResultStatus.unavailable
            : AppClinicalResultStatus.verified,
        isEmpty: _allReportItems.isEmpty,
        emptyTitle: l10n.labNoOrderItemsEntryTitle,
        emptyBody: l10n.labNoOrderItemsEntryBody,
        printEligible: printEligible,
        child: _LabReportPreview(
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
          enabled: printEligible && !_isPrinting,
          onPressed: printEligible ? () => _printSelectedReport() : null,
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
    final List<LabOrderItem> printableItems = _printableReleasedReportItems(
      _reportItems(widget.workflows),
    );
    _selectedOrderIds = <String>{
      for (final LabOrderWorkflow workflow in widget.workflows)
        if (workflow.order.items.any(_isPrintableReleasedReportItem))
          workflow.order.apiId,
    };
    _selectedItemIds = <String>{
      for (final LabOrderItem item in printableItems) _itemSelectionKey(item),
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
    final List<LabOrderItem> printableItems = _printableReleasedReportItems(
      _allReportItems,
    );
    if (printableItems.isEmpty) {
      return;
    }

    final Set<String> printableKeys = <String>{
      for (final LabOrderItem item in printableItems) _itemSelectionKey(item),
    };
    final Set<String> selectedPrintableKeys = _selectedItemIds.intersection(
      printableKeys,
    );
    final Set<String> itemIdsToPrint = selectedPrintableKeys.isEmpty
        ? printableKeys
        : selectedPrintableKeys;

    final List<LabOrderWorkflow> workflows = widget.workflows
        .where((LabOrderWorkflow workflow) {
          return workflow.order.items.any(
            (LabOrderItem item) =>
                itemIdsToPrint.contains(_itemSelectionKey(item)),
          );
        })
        .toList(growable: false);
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
        itemIdsToPrint,
        _visibleReportColumnKeys(),
      ),
      footerNote: l10n.labReportFooter,
      includeSignatures: true,
    );
    if (mounted) {
      setState(() => _isPrinting = false);
    }
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
            fontWeight: FontWeight.w600,
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
            return AppListTableMobileItem(
              leading: Checkbox(
                value: selectedItemIds.contains(_itemSelectionKey(item)),
                onChanged: (bool? value) {
                  onToggleItem(item, selected: value ?? false);
                },
                visualDensity: VisualDensity.compact,
              ),
              title: item.displayTitle,
              meta: <AppListTableMobileMeta>[
                AppListTableMobileMeta(
                  label: item.displayResultValue ?? l10n.labStatusPendingResults,
                  icon: _isAbnormalReportItem(item)
                      ? AppActionIcons.warning
                      : null,
                ),
              ],
              showAvatar: false,
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
        fontWeight: abnormal ? FontWeight.w600 : null,
      ),
    );
  }
}

class _ReportPreviewFlagCell extends StatelessWidget {
  const _ReportPreviewFlagCell({required this.item});

  final LabOrderItem item;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String label = _resolveItemResultFlagLabel(context, item);
    final AppClinicalResultFlag flag = _clinicalResultFlagForLabItem(item);
    final AppClinicalResultFlagDisplay display =
        AppClinicalResultFlagDisplay.resolve(l10n, flag, customLabel: label);
    return AppStatusBadge(
      label: display.label,
      tone: display.tone,
      icon: display.icon,
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
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
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

  Map<String, Object?> toSaveResultPayload({bool includeOrderItemId = false}) {
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

class _ReopenSavedResultDialog extends ConsumerStatefulWidget {
  const _ReopenSavedResultDialog({required this.item});

  final LabOrderItem item;

  @override
  ConsumerState<_ReopenSavedResultDialog> createState() =>
      _ReopenSavedResultDialogState();
}

class _ReopenSavedResultDialogState
    extends ConsumerState<_ReopenSavedResultDialog> {
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
                fontWeight: FontWeight.w600,
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
                  fontWeight: FontWeight.w500,
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
        LabResultValueUnitFields(
          valueController: _valueController,
          unitController: _unitController,
          item: _item,
          enabled: !_isSaving,
          valueRequired: true,
          onChanged: () => setState(() {}),
          valueValidator: (String? value) {
            final String normalized = value?.trim() ?? '';
            if (normalized.isEmpty) {
              return l10n.validationRequired;
            }
            return num.tryParse(normalized) == null
                ? l10n.labNumericRangeValidationMessage
                : null;
          },
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
          isDense: true,
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
        isDense: true,
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

  Map<String, Object?> _buildSaveResultPayload() {
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

    final AppFailure? verifyFailure = await controller.saveOrderItemResult(
      _item.apiId,
      _buildSaveResultPayload(),
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

bool _isAbnormalStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'CRITICAL' ||
    'CRITICAL_LOW' ||
    'CRITICAL_HIGH' ||
    'ABNORMAL' ||
    'LOW' ||
    'HIGH' => true,
    _ => false,
  };
}

bool _isAbnormalEntry(
  LabOrderItem item,
  _ResultDraft draft, {
  String? patientGender,
}) {
  final String? token = _resultInterpretationFlagToken(
    item,
    draft,
    patientGender: patientGender,
  );
  return _isAbnormalStatus(token);
}

String? _computedNumericFlagToken(
  LabOrderItem item,
  String valueText, {
  String? patientGender,
}) {
  final String normalized = valueText.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final num? value = num.tryParse(normalized);
  if (value == null) {
    return null;
  }

  final LabReferenceRange? range = resolveLabReferenceRangeForPatient(
    item.referenceRanges,
    patientGender: patientGender,
  );
  if (range == null) {
    return null;
  }

  final num? criticalMin = num.tryParse(
    (range.criticalMinValue ?? '').trim(),
  );
  final num? criticalMax = num.tryParse(
    (range.criticalMaxValue ?? '').trim(),
  );
  if (criticalMin != null && value <= criticalMin) {
    return 'CRITICAL';
  }
  if (criticalMax != null && value >= criticalMax) {
    return 'CRITICAL';
  }

  final num? normalMin = num.tryParse((range.normalMinValue ?? '').trim());
  final num? normalMax = num.tryParse((range.normalMaxValue ?? '').trim());
  if (normalMin != null && value < normalMin) {
    return 'LOW';
  }
  if (normalMax != null && value > normalMax) {
    return 'HIGH';
  }
  if (normalMin != null || normalMax != null) {
    return 'NORMAL';
  }
  return null;
}

String? _resultInterpretationFlagToken(
  LabOrderItem item,
  _ResultDraft? draft, {
  String? patientGender,
}) {
  if (draft != null && draft.interpretationOverride) {
    final String overrideFlag = draft.resultFlagOverrideController.text.trim();
    if (overrideFlag.isNotEmpty) {
      return overrideFlag.toUpperCase();
    }
  } else if (item.interpretationOverride) {
    final String overrideFlag = (item.resultFlagOverride ?? '').trim();
    if (overrideFlag.isNotEmpty) {
      return overrideFlag.toUpperCase();
    }
  }

  if (item.isRejected) {
    return 'CANCELLED';
  }

  if (draft != null && draft.hasChangedEntry) {
    if (item.isQualitative) {
      final String? optionFlag = _selectedResultOptionFlag(item, draft);
      if (optionFlag != null && optionFlag.trim().isNotEmpty) {
        return optionFlag.trim().toUpperCase();
      }
    }
    if (item.isNumeric) {
      final String? computed = _computedNumericFlagToken(
        item,
        draft.valueController.text,
        patientGender: patientGender,
      );
      if (computed != null) {
        return computed;
      }
    }
  }

  final String? explicitFlag = item.resultFlag?.trim();
  if (explicitFlag != null && explicitFlag.isNotEmpty) {
    return explicitFlag.toUpperCase();
  }

  final String? optionFlag = draft != null
      ? _selectedResultOptionFlag(item, draft)
      : _storedQualitativeOptionFlag(item);
  if (optionFlag != null && optionFlag.trim().isNotEmpty) {
    return optionFlag.trim().toUpperCase();
  }

  final String valueText = draft != null
      ? draft.valueController.text
      : (item.resultValue ?? '');
  if (valueText.trim().isNotEmpty) {
    final String? computed = _computedNumericFlagToken(
      item,
      valueText,
      patientGender: patientGender,
    );
    if (computed != null) {
      return computed;
    }
  }

  final String? status = item.effectiveResultStatus?.trim();
  if (status != null && status.isNotEmpty) {
    return status.toUpperCase();
  }
  return null;
}

AppWorkspaceStatusTone? _resultInterpretationTone(
  LabOrderItem item,
  _ResultDraft? draft, {
  String? patientGender,
}) {
  final bool hasValue = draft != null
      ? draft.hasEntry
      : ((item.displayResultValue ?? '').trim().isNotEmpty);
  if (!hasValue) {
    return null;
  }

  final String? token = _resultInterpretationFlagToken(
    item,
    draft,
    patientGender: patientGender,
  );
  if (token == null || token.isEmpty) {
    return null;
  }

  return switch (token) {
    'CRITICAL' || 'CRITICAL_LOW' || 'CRITICAL_HIGH' =>
      AppWorkspaceStatusTone.error,
    'HIGH' || 'ABNORMAL' || 'POSITIVE' || 'REACTIVE' =>
      AppWorkspaceStatusTone.error,
    'LOW' => AppWorkspaceStatusTone.warning,
    'NORMAL' || 'NEGATIVE' || 'NON_REACTIVE' || 'NOT_DETECTED' =>
      AppWorkspaceStatusTone.success,
    _ => null,
  };
}

Color _resultInterpretationForeground(
  ThemeData theme,
  AppWorkspaceStatusTone tone,
) {
  final AppStatusColors statusColors = theme.statusColors;
  return switch (tone) {
    AppWorkspaceStatusTone.neutral => theme.colorScheme.onSurface,
    AppWorkspaceStatusTone.success => statusColors.success,
    AppWorkspaceStatusTone.warning => statusColors.warning,
    AppWorkspaceStatusTone.error => statusColors.error,
    AppWorkspaceStatusTone.info => statusColors.info,
  };
}

Color? _resultRowAccentColor(
  ThemeData theme,
  LabOrderItem item,
  _ResultDraft draft, {
  String? patientGender,
}) {
  final AppWorkspaceStatusTone? tone = _resultInterpretationTone(
    item,
    draft,
    patientGender: patientGender,
  );
  if (tone == null) {
    return null;
  }
  final AppStatusColors statusColors = theme.statusColors;
  return switch (tone) {
    AppWorkspaceStatusTone.success =>
      statusColors.successContainer.withValues(alpha: 0.18),
    AppWorkspaceStatusTone.warning =>
      statusColors.warningContainer.withValues(alpha: 0.22),
    AppWorkspaceStatusTone.info =>
      statusColors.infoContainer.withValues(alpha: 0.18),
    AppWorkspaceStatusTone.error =>
      theme.colorScheme.errorContainer.withValues(alpha: 0.18),
    AppWorkspaceStatusTone.neutral => null,
  };
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

bool _hasSavedResult(LabOrderItem item) {
  return item.resultId != null && item.resultId!.trim().isNotEmpty;
}

bool _canSaveResultDraft(_ResultDraft draft) {
  return draft.item.canEnterResult &&
      (draft.hasEntry || _hasSavedResult(draft.item));
}

bool _validateDraftForPersist(_ResultDraft draft, {required bool forFinalize}) {
  if (forFinalize && _hasSavedResult(draft.item) && !draft.hasChangedEntry) {
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

String? resolveDisplayReferenceRange(
  LabOrderItem item, {
  String? patientGender,
}) {
  return resolveLabOrderItemDisplayReferenceRange(
    item,
    patientGender: patientGender,
  );
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

  // Numeric status is determined by the backend interpretation engine on release.
  if (item.isNumeric) {
    return 'PENDING';
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

bool _isPrintableReleasedReportItem(LabOrderItem item) {
  return item.isCompleted && item.hasResult && !item.isRejected;
}

List<LabOrderItem> _printableReleasedReportItems(List<LabOrderItem> items) {
  return items.where(_isPrintableReleasedReportItem).toList(growable: false);
}

AppClinicalResultFlag _clinicalResultFlagForLabItem(LabOrderItem item) {
  final String token =
      (_computedNumericFlagToken(item, item.resultValue ?? '') ??
              item.resultFlag ??
              item.effectiveResultStatus ??
              '')
          .trim()
          .toUpperCase();
  return switch (token) {
    'CRITICAL' => AppClinicalResultFlag.critical,
    'ABNORMAL' || 'HIGH' || 'LOW' => AppClinicalResultFlag.abnormal,
    'NORMAL' ||
    'NEGATIVE' ||
    'NON_REACTIVE' ||
    'POSITIVE' => AppClinicalResultFlag.normal,
    _ => AppClinicalResultFlag.unknown,
  };
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

String? _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' · ');
  return joined.isEmpty ? null : joined;
}
