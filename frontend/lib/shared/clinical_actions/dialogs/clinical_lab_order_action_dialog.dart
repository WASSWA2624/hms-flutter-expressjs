import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_lab_request_catalog_dialog.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class ClinicalLabOrderActionDialog extends StatefulWidget {
  const ClinicalLabOrderActionDialog({
    required this.referenceData,
    required this.onRequest,
    required this.onUpdate,
    required this.onSearchLabTests,
    this.existingOrder,
    this.patientContext = const ClinicalRequestPatientContext(),
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final ClinicalActionLabOrderRecord? existingOrder;
  final ClinicalRequestPatientContext patientContext;
  final Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchLabTests;
  final Future<AppFailure?> Function({
    required List<String> labTestIds,
    required List<String> labPanelIds,
    ClinicalRequestBillingSubmit? billing,
  })
  onRequest;
  final Future<AppFailure?> Function({
    required String labOrderId,
    required List<String> labTestIds,
    required List<String> labPanelIds,
    ClinicalRequestBillingSubmit? billing,
  })
  onUpdate;

  @override
  State<ClinicalLabOrderActionDialog> createState() => _LabOrderDialogState();
}

enum _LabRequestSelectionKind { tests, panels }

final class _PendingLabRequest {
  const _PendingLabRequest({required this.kind, required this.option});

  final _LabRequestSelectionKind kind;
  final ClinicalActionCatalogOption option;

  String get id => option.apiId;
}

class _LabOrderDialogState extends State<ClinicalLabOrderActionDialog> {
  final List<_PendingLabRequest> _requests = <_PendingLabRequest>[];
  final Set<String> _selectedRequestKeys = <String>{};
  bool _isSaving = false;
  AppFailure? _failure;
  ClinicalRequestBillingSubmit? _billingSubmit;

  @override
  void initState() {
    super.initState();
    _requests.addAll(_initialRequests());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isEditingOrder = widget.existingOrder != null;

    return AppDialog(
      title: Text(
        isEditingOrder
            ? l10n.clinicalUpdateLabOrderAction
            : l10n.clinicalRequestLabAction,
      ),
      icon: const Icon(Icons.science_outlined),
      initialMaximized: true,
      maxWidth: 880,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          ClinicalRequestFlowToolbar(
            enabled: !_isSaving,
            leading: widget.patientContext.isEmpty
                ? null
                : ClinicalRequestPatientContextStrip(
                    patientContext: widget.patientContext,
                  ),
            removeSelectedDestructive: true,
            onAddItems: _openCatalogPicker,
            onReviewBilling: _requests.isEmpty ? null : _openBillingDialog,
            onRemoveSelected: _selectedRequestKeys.isEmpty
                ? null
                : () => unawaited(_confirmAndDeleteSelectedRequests()),
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          Expanded(child: _buildSelectedTable(context)),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: isEditingOrder
              ? l10n.clinicalUpdateLabOrderAction
              : l10n.clinicalRequestLabAction,
          leadingIcon: Icons.science_outlined,
          isLoading: _isSaving,
          enabled: !_isSaving && _requests.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildSelectedTable(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return ClinicalRequestSelectedCatalogTable<_PendingLabRequest>(
      items: _requests,
      itemKey: _requestKey,
      nameLabel: ( _PendingLabRequest request) =>
          request.option.name ?? request.option.displayTitle,
      typeLabel: ( _PendingLabRequest request) =>
          _labRequestTypeLabel(l10n, request.kind),
      optionFor: ( _PendingLabRequest request) => request.option,
      selectedKeys: _selectedRequestKeys,
      onSelectedKeysChanged: (Set<String> keys) {
        setState(() {
          _selectedRequestKeys
            ..clear()
            ..addAll(keys);
        });
      },
      onDeleteItem: (_PendingLabRequest request) {
        unawaited(_confirmAndDeleteRequest(request));
      },
      emptyLabel: l10n.clinicalLabRequestSelectedTableEmptyLabel,
      enabled: !_isSaving,
      billing: _billingSubmit,
    );
  }

  String _requestKey(_PendingLabRequest request) {
    return '${request.kind.name}:${request.id}';
  }

  int _requestIndex(_PendingLabRequest request) {
    return _requests.indexWhere(
      (_PendingLabRequest item) => _requestKey(item) == _requestKey(request),
    );
  }

  void _pruneSelection() {
    final Set<String> validKeys = _requests.map(_requestKey).toSet();
    _selectedRequestKeys.removeWhere((String key) => !validKeys.contains(key));
  }

  Future<void> _openCatalogPicker({
    ClinicalLabRequestCatalogKind initialKind =
        ClinicalLabRequestCatalogKind.tests,
  }) async {
    await showClinicalLabRequestCatalogDialog(
      context: context,
      referenceData: widget.referenceData,
      facilityOfferingsOnly: true,
      onSearchLabTests: widget.onSearchLabTests,
      initialKind: initialKind,
      selectedCount: _requests.length,
      isSelected:
          (
            ClinicalActionCatalogOption option,
            ClinicalLabRequestCatalogKind kind,
          ) {
            return _requests.any(
              (_PendingLabRequest request) =>
                  request.id == option.apiId &&
                  _matchesCatalogKind(request.kind, kind),
            );
          },
      onSelectionChanged:
          (
            ClinicalActionCatalogOption option,
            ClinicalLabRequestCatalogKind kind,
            bool selected,
          ) {
            setState(() {
              _failure = null;
              final _LabRequestSelectionKind selectionKind =
                  kind == ClinicalLabRequestCatalogKind.tests
                  ? _LabRequestSelectionKind.tests
                  : _LabRequestSelectionKind.panels;
              if (selected) {
                if (_isDuplicateSelection(option, selectionKind)) {
                  return;
                }
                _requests.add(
                  _PendingLabRequest(kind: selectionKind, option: option),
                );
                return;
              }
              _requests.removeWhere(
                (_PendingLabRequest request) =>
                    request.id == option.apiId &&
                    request.kind == selectionKind,
              );
              _pruneSelection();
            });
          },
    );
  }

  bool _matchesCatalogKind(
    _LabRequestSelectionKind selectionKind,
    ClinicalLabRequestCatalogKind catalogKind,
  ) {
    return switch ((selectionKind, catalogKind)) {
      (_LabRequestSelectionKind.tests, ClinicalLabRequestCatalogKind.tests) =>
        true,
      (
        _LabRequestSelectionKind.panels,
        ClinicalLabRequestCatalogKind.panels,
      ) =>
        true,
      _ => false,
    };
  }

  Future<void> _openBillingDialog() async {
    final ClinicalRequestBillingSubmit? billing =
        await showClinicalRequestBillingDialog(
          context: context,
          lineItems: clinicalRequestBillingLineItems(
            options: _requests
                .map((_PendingLabRequest request) => request.option)
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

  List<_PendingLabRequest> _initialRequests() {
    final ClinicalActionLabOrderRecord? order = widget.existingOrder;
    if (order == null) {
      return const <_PendingLabRequest>[];
    }

    final List<ClinicalActionCatalogOption> inferredPanels =
        _requestedPanelsForOrder(order, widget.referenceData);
    final Set<String> panelChildIds = inferredPanels
        .expand((ClinicalActionCatalogOption panel) => panel.childIds)
        .map(clinicalActionNormalizedCatalogToken)
        .where((String value) => value.isNotEmpty)
        .toSet();
    final Set<String> panelChildCodes = inferredPanels
        .expand((ClinicalActionCatalogOption panel) => panel.childCodes)
        .map(clinicalActionNormalizedCatalogToken)
        .where((String value) => value.isNotEmpty)
        .toSet();

    return <_PendingLabRequest>[
      for (final ClinicalActionCatalogOption panel in inferredPanels)
        _PendingLabRequest(
          kind: _LabRequestSelectionKind.panels,
          option: panel,
        ),
      ...order.labOrderItems
          .where(
            (ClinicalActionLabOrderItem item) =>
                clinicalActionHasText(item.labTestId) &&
                !panelChildIds.contains(
                  clinicalActionNormalizedCatalogToken(item.labTestId!),
                ) &&
                !panelChildCodes.contains(
                  clinicalActionNormalizedCatalogToken(item.testCode ?? ''),
                ),
          )
          .map((ClinicalActionLabOrderItem item) {
            return _PendingLabRequest(
              kind: _LabRequestSelectionKind.tests,
              option: _catalogOptionForLabOrderItem(item),
            );
          }),
    ];
  }

  ClinicalActionCatalogOption _catalogOptionForLabOrderItem(
    ClinicalActionLabOrderItem item,
  ) {
    for (final ClinicalActionCatalogOption option
        in widget.referenceData.labTests) {
      if (option.apiId == item.labTestId ||
          option.id == item.labTestId ||
          option.code == item.testCode) {
        return option;
      }
    }

    return ClinicalActionCatalogOption(
      id: item.labTestId ?? item.id,
      publicId: item.labTestId,
      name: item.testDisplayName,
      code: item.testCode,
      category: item.category,
      secondaryText: item.specimenType,
      status: item.status,
    );
  }

  Future<void> _confirmAndDeleteRequest(_PendingLabRequest request) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed =
        await showClinicalRequestRemoveItemsConfirmationDialog(
          context: context,
          items: <ClinicalRequestRemovePreviewItem>[
            ClinicalRequestRemovePreviewItem(
              name: request.option.name ?? request.option.displayTitle,
              typeLabel: _labRequestTypeLabel(l10n, request.kind),
            ),
          ],
        );
    if (!confirmed || !mounted) {
      return;
    }
    _deleteRequest(_requestIndex(request));
  }

  Future<void> _confirmAndDeleteSelectedRequests() async {
    if (_selectedRequestKeys.isEmpty) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final List<_PendingLabRequest> selectedRequests = _requests
        .where(
          (_PendingLabRequest request) =>
              _selectedRequestKeys.contains(_requestKey(request)),
        )
        .toList(growable: false);
    final bool confirmed =
        await showClinicalRequestRemoveItemsConfirmationDialog(
          context: context,
          items: selectedRequests
              .map(
                (_PendingLabRequest request) => ClinicalRequestRemovePreviewItem(
                  name: request.option.name ?? request.option.displayTitle,
                  typeLabel: _labRequestTypeLabel(l10n, request.kind),
                ),
              )
              .toList(growable: false),
        );
    if (!confirmed || !mounted) {
      return;
    }
    _deleteSelectedRequests();
  }

  void _deleteRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    final String removedKey = _requestKey(_requests[index]);
    setState(() {
      _requests.removeAt(index);
      _selectedRequestKeys.remove(removedKey);
      _failure = null;
    });
  }

  void _deleteSelectedRequests() {
    if (_selectedRequestKeys.isEmpty) {
      return;
    }
    setState(() {
      _requests.removeWhere(
        (_PendingLabRequest request) =>
            _selectedRequestKeys.contains(_requestKey(request)),
      );
      _selectedRequestKeys.clear();
      _failure = null;
    });
  }

  bool _isDuplicateSelection(
    ClinicalActionCatalogOption option,
    _LabRequestSelectionKind kind,
  ) {
    return _requests.any(
      (_PendingLabRequest request) =>
          request.kind == kind && request.id == option.apiId,
    );
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
    final List<String> labTestIds = <String>[
      for (final _PendingLabRequest request in _requests)
        if (request.kind == _LabRequestSelectionKind.tests) request.id,
    ];
    final List<String> labPanelIds = <String>[
      for (final _PendingLabRequest request in _requests)
        if (request.kind == _LabRequestSelectionKind.panels) request.id,
    ];
    final ClinicalActionLabOrderRecord? existingOrder = widget.existingOrder;
    final AppFailure? failure = existingOrder == null
        ? await widget.onRequest(
            labTestIds: labTestIds,
            labPanelIds: labPanelIds,
            billing: _billingSubmit,
          )
        : await widget.onUpdate(
            labOrderId: existingOrder.id,
            labTestIds: labTestIds,
            labPanelIds: labPanelIds,
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

String _labRequestTypeLabel(
  AppLocalizations l10n,
  _LabRequestSelectionKind kind,
) {
  return switch (kind) {
    _LabRequestSelectionKind.tests => l10n.clinicalLabRequestTestTypeLabel,
    _LabRequestSelectionKind.panels => l10n.clinicalLabRequestPanelTypeLabel,
  };
}

List<ClinicalActionCatalogOption> _requestedPanelsForOrder(
  ClinicalActionLabOrderRecord order,
  ClinicalActionReferenceData referenceData,
) {
  final Set<String> itemIds = order.labOrderItems
      .map((ClinicalActionLabOrderItem item) => item.labTestId)
      .whereType<String>()
      .map(clinicalActionNormalizedCatalogToken)
      .where((String value) => value.isNotEmpty)
      .toSet();
  final Set<String> itemCodes = order.labOrderItems
      .map((ClinicalActionLabOrderItem item) => item.testCode)
      .whereType<String>()
      .map(clinicalActionNormalizedCatalogToken)
      .where((String value) => value.isNotEmpty)
      .toSet();

  return referenceData.labPanels
      .where((ClinicalActionCatalogOption panel) {
        final Set<String> panelIds = panel.childIds
            .map(clinicalActionNormalizedCatalogToken)
            .where((String value) => value.isNotEmpty)
            .toSet();
        final Set<String> panelCodes = panel.childCodes
            .map(clinicalActionNormalizedCatalogToken)
            .where((String value) => value.isNotEmpty)
            .toSet();
        if (panelIds.length <= 1 && panelCodes.length <= 1) {
          return false;
        }
        final bool idsMatch =
            panelIds.isNotEmpty && panelIds.every(itemIds.contains);
        final bool codesMatch =
            panelCodes.isNotEmpty && panelCodes.every(itemCodes.contains);
        return idsMatch || codesMatch;
      })
      .toList(growable: false);
}
