import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_select_helpers.dart';
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
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final ClinicalActionLabOrderRecord? existingOrder;
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
  String? _focusedSelectionId;
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool isEditingOrder = widget.existingOrder != null;
    final List<ClinicalRequestBillingLineItem> lineItems =
        clinicalRequestBillingLineItems(
          options: _requests
              .map((_PendingLabRequest request) => request.option)
              .toList(growable: false),
        );

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
          Text(
            l10n.clinicalRequestMainPanelHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          ClinicalRequestFlowToolbar(
            enabled: !_isSaving,
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

  Widget _buildSelectedPanel(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final _PendingLabRequest? focusedRequest = _focusedRequest();
    final List<AppSelectOption<String>> options = clinicalCatalogSelectOptions(
      _requests.map((_PendingLabRequest request) => request.option).toList(),
      icon: Icons.science_outlined,
      labelBuilder: (ClinicalActionCatalogOption option) {
        final _PendingLabRequest request = _requests.firstWhere(
          (_PendingLabRequest item) => item.option.apiId == option.apiId,
        );
        return ClinicalCatalogOptionLabel(
          option: option,
          subtitle: clinicalActionJoinDisplay(<String?>[
            _labRequestTypeLabel(l10n, request.kind),
            option.displaySubtitle,
          ]),
        );
      },
    );

    return ClinicalRequestSelectionManager(
      title: l10n.clinicalLabRequestSelectedTitle,
      emptyLabel: l10n.clinicalLabRequestNoSelection,
      options: options,
      value: _focusedSelectionId,
      enabled: !_isSaving,
      onChanged: (String? value) {
        setState(() => _focusedSelectionId = value);
      },
      onEdit: focusedRequest == null
          ? null
          : () => _editRequest(_requestIndex(focusedRequest)),
      onDelete: focusedRequest == null
          ? null
          : () => _deleteRequest(_requestIndex(focusedRequest)),
    );
  }

  _PendingLabRequest? _focusedRequest() {
    if (_focusedSelectionId == null) {
      return null;
    }
    for (final _PendingLabRequest request in _requests) {
      if (request.id == _focusedSelectionId) {
        return request;
      }
    }
    return null;
  }

  int _requestIndex(_PendingLabRequest request) {
    return _requests.indexWhere(
      (_PendingLabRequest item) => item.id == request.id,
    );
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
              if (_focusedSelectionId == option.apiId) {
                _focusedSelectionId = null;
              }
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

  void _editRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    final _PendingLabRequest request = _requests[index];
    unawaited(
      _openCatalogPicker(
        initialKind: request.kind == _LabRequestSelectionKind.tests
            ? ClinicalLabRequestCatalogKind.tests
            : ClinicalLabRequestCatalogKind.panels,
      ),
    );
  }

  void _deleteRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    final String removedId = _requests[index].id;
    setState(() {
      _requests.removeAt(index);
      if (_focusedSelectionId == removedId) {
        _focusedSelectionId = null;
      }
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
