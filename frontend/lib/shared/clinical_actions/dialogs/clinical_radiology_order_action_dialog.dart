import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_radiology_catalog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_radiology_request_catalog_dialog.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class ClinicalRadiologyOrderActionDialog extends StatefulWidget {
  const ClinicalRadiologyOrderActionDialog({
    required this.referenceData,
    required this.onSubmit,
    this.initialRequests = const <ClinicalActionRadiologyRequest>[],
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final List<ClinicalActionRadiologyRequest> initialRequests;
  final Future<AppFailure?> Function({
    required List<ClinicalActionRadiologyRequest> requests,
    ClinicalRequestBillingSubmit? billing,
  })
  onSubmit;

  @override
  State<ClinicalRadiologyOrderActionDialog> createState() =>
      _RadiologyOrderDialogState();
}

final class _PendingRadiologyRequest {
  const _PendingRadiologyRequest({
    required this.option,
    this.clinicalNote,
    this.bodyRegion,
    this.laterality,
    this.priority,
    this.modality,
  });

  final ClinicalActionCatalogOption option;
  final String? clinicalNote;
  final String? bodyRegion;
  final String? laterality;
  final String? priority;
  final String? modality;

  String get id => option.apiId;

  ClinicalRadiologyCatalogSelection get selection =>
      ClinicalRadiologyCatalogSelection(
        option: option,
        clinicalNote: clinicalNote,
        bodyRegion: bodyRegion,
        laterality: laterality,
        priority: priority,
        modality: modality,
      );
}

class _RadiologyOrderDialogState
    extends State<ClinicalRadiologyOrderActionDialog> {
  final List<_PendingRadiologyRequest> _requests = <_PendingRadiologyRequest>[];
  int? _editingIndex;
  bool _isSaving = false;
  AppFailure? _failure;
  ClinicalRequestBillingSubmit? _billingSubmit;

  @override
  void initState() {
    super.initState();
    _requests.addAll(_initialPendingRequests());
  }

  List<_PendingRadiologyRequest> _initialPendingRequests() {
    final List<_PendingRadiologyRequest> pending = <_PendingRadiologyRequest>[];
    for (final ClinicalActionRadiologyRequest request
        in widget.initialRequests) {
      final ClinicalActionCatalogOption? option = _catalogOptionForRequest(
        request,
      );
      if (option == null) {
        continue;
      }
      pending.add(
        _PendingRadiologyRequest(
          option: option,
          clinicalNote: request.clinicalNote,
          bodyRegion: request.bodyRegion,
          laterality: request.laterality,
          priority: request.priority,
          modality: request.modality,
        ),
      );
    }
    return pending;
  }

  ClinicalActionCatalogOption? _catalogOptionForRequest(
    ClinicalActionRadiologyRequest request,
  ) {
    final String id = request.radiologyTestId.trim();
    if (id.isEmpty) {
      return null;
    }
    for (final ClinicalActionCatalogOption option
        in widget.referenceData.radiologyTests) {
      if (option.apiId == id || option.id == id || option.publicId == id) {
        return option;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalRequestBillingLineItem> lineItems =
        clinicalRequestBillingLineItems(
          options: _requests
              .map((_PendingRadiologyRequest request) => request.option)
              .toList(growable: false),
        );

    return AppDialog(
      title: Text(l10n.clinicalRequestRadiologyAction),
      icon: const Icon(Icons.biotech_outlined),
      maxWidth: 560,
      closeEnabled: !_isSaving,
      content: SizedBox(
        height: (MediaQuery.sizeOf(context).height * 0.5).clamp(360.0, 520.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            Text(
              l10n.clinicalRequestMainPanelHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.md),
            ClinicalRequestFlowToolbar(
              enabled: !_isSaving,
              addItemsLabel: l10n.clinicalRadiologyAddStudyAction,
              onAddItems: _openCatalogPicker,
              onReviewBilling: _requests.isEmpty ? null : _openBillingDialog,
            ),
            SizedBox(height: theme.spacing.md),
            ClinicalRequestFlowSummaryBar(
              itemCount: _requests.length,
              lineItems: lineItems,
              billing: _billingSubmit,
            ),
            SizedBox(height: theme.spacing.md),
            Expanded(child: _buildSelectedPanel(context)),
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
          label: l10n.clinicalRequestRadiologyAction,
          isLoading: _isSaving,
          enabled: !_isSaving && _requests.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildSelectedPanel(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Text(
              l10n.clinicalRadiologyRequestSelectedTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: _requests.isEmpty
                ? Center(child: Text(l10n.clinicalRadiologyRequestNoSelection))
                : ListView.separated(
                    itemCount: _requests.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _RadiologySelectedRequestRow(
                        request: _requests[index],
                        isEditing: _editingIndex == index,
                        isSaving: _isSaving,
                        onEdit: () => _editRequest(index),
                        onDelete: () => _deleteRequest(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCatalogPicker() async {
    final int? editingIndex = _editingIndex;
    final _PendingRadiologyRequest? editingRequest =
        editingIndex != null &&
            editingIndex >= 0 &&
            editingIndex < _requests.length
        ? _requests[editingIndex]
        : null;

    await showClinicalRadiologyRequestCatalogDialog(
      context: context,
      referenceData: widget.referenceData,
      editingSelection: editingRequest?.selection,
      isDuplicate: (ClinicalActionCatalogOption option) =>
          _isDuplicateSelection(option, editingIndex),
      onAdd: (ClinicalRadiologyCatalogSelection selection) {
        _addOrUpdateRequest(selection, editingIndex);
      },
    );
  }

  Future<void> _openBillingDialog() async {
    final ClinicalRequestBillingSubmit? billing =
        await showClinicalRequestBillingDialog(
          context: context,
          lineItems: clinicalRequestBillingLineItems(
            options: _requests
                .map((_PendingRadiologyRequest request) => request.option)
                .toList(growable: false),
          ),
          initialBilling: _billingSubmit,
          enabled: !_isSaving,
        );
    if (!mounted || billing == null) {
      return;
    }
    setState(() => _billingSubmit = billing);
  }

  void _addOrUpdateRequest(
    ClinicalRadiologyCatalogSelection selection,
    int? editingIndex,
  ) {
    final _PendingRadiologyRequest request = _PendingRadiologyRequest(
      option: selection.option,
      clinicalNote: selection.clinicalNote,
      bodyRegion: selection.bodyRegion,
      laterality: selection.laterality,
      priority: selection.priority,
      modality: selection.modality,
    );

    setState(() {
      _failure = null;
      if (editingIndex != null &&
          editingIndex >= 0 &&
          editingIndex < _requests.length) {
        _requests[editingIndex] = request;
        _editingIndex = null;
        return;
      }
      _requests.add(request);
    });
  }

  void _editRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    setState(() {
      _editingIndex = index;
      _failure = null;
    });
    unawaited(_openCatalogPicker());
  }

  void _deleteRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    setState(() {
      _requests.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
      } else if (_editingIndex case final int editingIndex
          when editingIndex > index) {
        _editingIndex = editingIndex - 1;
      }
      _failure = null;
    });
  }

  bool _isDuplicateSelection(
    ClinicalActionCatalogOption option,
    int? editingIndex,
  ) {
    for (var index = 0; index < _requests.length; index += 1) {
      if (index == editingIndex) {
        continue;
      }
      if (_requests[index].id == option.apiId) {
        return true;
      }
    }
    return false;
  }

  Future<void> _submit() async {
    if (_requests.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      requests: <ClinicalActionRadiologyRequest>[
        for (final _PendingRadiologyRequest request in _requests)
          ClinicalActionRadiologyRequest(
            radiologyTestId: request.id,
            clinicalNote: request.clinicalNote,
            bodyRegion: request.bodyRegion,
            laterality: request.laterality,
            priority: request.priority,
            modality: request.modality,
          ),
      ],
      billing: _billingSubmit,
    );
    _finishSubmit(failure);
  }

  void _finishSubmit(AppFailure? failure) {
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

class _RadiologySelectedRequestRow extends StatelessWidget {
  const _RadiologySelectedRequestRow({
    required this.request,
    required this.isEditing,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final _PendingRadiologyRequest request;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String subtitle = clinicalActionJoinDisplay(<String?>[
      clinicalRadiologyModalityDisplayLabel(
        l10n,
        request.modality ?? clinicalRadiologyOptionModality(request.option),
      ),
      request.bodyRegion ?? clinicalRadiologyOptionBodyRegion(request.option),
      clinicalRadiologyLateralityLabel(l10n, request.laterality),
      request.priority == null
          ? null
          : clinicalActionApiLabel(request.priority!),
      request.option.status,
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEditing
            ? colorScheme.primaryContainer.withValues(alpha: 0.38)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              clinicalRadiologyCatalogIcon(request.option),
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    request.option.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (clinicalActionHasText(request.clinicalNote))
                    Text(
                      request.clinicalNote!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  Text(
                    clinicalRequestCatalogPriceLabel(context, request.option),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.clinicalRadiologyEditSelectionAction,
              onPressed: isSaving ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: l10n.clinicalRadiologyDeleteSelectionAction,
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
