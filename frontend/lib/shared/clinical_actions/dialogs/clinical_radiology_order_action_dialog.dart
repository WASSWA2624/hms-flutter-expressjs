import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_radiology_catalog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_resolve.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_radiology_request_catalog_dialog.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class ClinicalRadiologyOrderActionDialog extends StatefulWidget {
  const ClinicalRadiologyOrderActionDialog({
    required this.referenceData,
    required this.onSearchRadiologyTests,
    required this.onSubmit,
    this.initialRequests = const <ClinicalActionRadiologyRequest>[],
    this.patientContext = const ClinicalRequestPatientContext(),
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
    String source,
  })
  onSearchRadiologyTests;
  final List<ClinicalActionRadiologyRequest> initialRequests;
  final ClinicalRequestPatientContext patientContext;
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
  final Set<String> _selectedRequestKeys = <String>{};
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
    return ClinicalActionCatalogOption(
      id: id,
      publicId: id,
      name: id,
      metadata: <String, Object?>{
        'modality': request.modality,
        'body_region': request.bodyRegion,
        'laterality': request.laterality,
        'priority': request.priority,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppDialog(
      title: Text(l10n.clinicalRequestRadiologyAction),
      icon: const Icon(Icons.biotech_outlined),
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
            addItemsLabel: l10n.clinicalRadiologyAddStudyAction,
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
          label: l10n.clinicalRequestRadiologyAction,
          leadingIcon: Icons.biotech_outlined,
          isLoading: _isSaving,
          enabled: !_isSaving && _requests.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildSelectedTable(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return ClinicalRequestSelectedCatalogTable<_PendingRadiologyRequest>(
      items: _requests,
      itemKey: (_PendingRadiologyRequest request) => request.id,
      nameLabel: (_PendingRadiologyRequest request) =>
          request.option.name ?? request.option.displayTitle,
      typeLabel: (_PendingRadiologyRequest request) =>
          clinicalRadiologyModalityDisplayLabel(
            l10n,
            request.modality ?? clinicalRadiologyOptionModality(request.option),
          ),
      optionFor: (_PendingRadiologyRequest request) => request.option,
      selectedKeys: _selectedRequestKeys,
      onSelectedKeysChanged: (Set<String> keys) {
        setState(() {
          _selectedRequestKeys
            ..clear()
            ..addAll(keys);
        });
      },
      onDeleteItem: (_PendingRadiologyRequest request) {
        unawaited(_confirmAndDeleteRequest(request));
      },
      emptyLabel: l10n.clinicalRadiologyRequestSelectedTableEmptyLabel,
      enabled: !_isSaving,
      billing: _billingSubmit,
    );
  }

  int _requestIndex(_PendingRadiologyRequest request) {
    return _requests.indexWhere(
      (_PendingRadiologyRequest item) => item.id == request.id,
    );
  }

  void _pruneSelection() {
    final Set<String> validKeys = _requests.map((r) => r.id).toSet();
    _selectedRequestKeys.removeWhere((String key) => !validKeys.contains(key));
  }

  Future<void> _openCatalogPicker() async {
    final List<ClinicalRadiologyCatalogSelection>? confirmed =
        await showClinicalRadiologyRequestCatalogDialog(
          context: context,
          onSearchRadiologyTests: widget.onSearchRadiologyTests,
          initialSelections: _requests
              .map((_PendingRadiologyRequest request) => request.selection)
              .toList(growable: false),
        );
    if (!mounted || confirmed == null) {
      return;
    }
    setState(() {
      _failure = null;
      _requests
        ..clear()
        ..addAll(
          confirmed.map(
            (ClinicalRadiologyCatalogSelection selection) =>
                _PendingRadiologyRequest(
                  option: selection.option,
                  clinicalNote: selection.clinicalNote,
                  bodyRegion: selection.bodyRegion,
                  laterality: selection.laterality,
                  priority: selection.priority,
                  modality: selection.modality,
                ),
          ),
        );
      _pruneSelection();
    });
  }

  Future<void> _openBillingDialog() async {
    final ClinicalRequestBillingSubmit? billing =
        await showResolvedClinicalRequestBillingDialog(
          context: context,
          options: _requests
              .map((_PendingRadiologyRequest request) => request.option)
              .toList(growable: false),
          initialBilling: _billingSubmit,
          catalogType: 'RADIOLOGY_TEST',
          billingEntity: 'FACILITY',
          enabled: !_isSaving,
        );
    if (!mounted || billing == null) {
      return;
    }
    setState(() => _billingSubmit = billing);
  }

  Future<void> _confirmAndDeleteRequest(
    _PendingRadiologyRequest request,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed =
        await showClinicalRequestRemoveItemsConfirmationDialog(
          context: context,
          items: <ClinicalRequestRemovePreviewItem>[
            ClinicalRequestRemovePreviewItem(
              name: request.option.name ?? request.option.displayTitle,
              typeLabel: clinicalRadiologyModalityDisplayLabel(
                l10n,
                request.modality ??
                    clinicalRadiologyOptionModality(request.option),
              ),
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
    final List<_PendingRadiologyRequest> selectedRequests = _requests
        .where(
          (_PendingRadiologyRequest request) =>
              _selectedRequestKeys.contains(request.id),
        )
        .toList(growable: false);
    final bool confirmed =
        await showClinicalRequestRemoveItemsConfirmationDialog(
          context: context,
          items: selectedRequests
              .map(
                (_PendingRadiologyRequest request) =>
                    ClinicalRequestRemovePreviewItem(
                      name: request.option.name ?? request.option.displayTitle,
                      typeLabel: clinicalRadiologyModalityDisplayLabel(
                        l10n,
                        request.modality ??
                            clinicalRadiologyOptionModality(request.option),
                      ),
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
    final String removedId = _requests[index].id;
    setState(() {
      _requests.removeAt(index);
      _selectedRequestKeys.remove(removedId);
      _failure = null;
    });
  }

  void _deleteSelectedRequests() {
    if (_selectedRequestKeys.isEmpty) {
      return;
    }
    setState(() {
      _requests.removeWhere(
        (_PendingRadiologyRequest request) =>
            _selectedRequestKeys.contains(request.id),
      );
      _selectedRequestKeys.clear();
      _failure = null;
    });
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
