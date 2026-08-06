import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/scan/app_live_camera.dart';

typedef ClinicalPrescriptionCatalogLoader =
    Future<List<ClinicalActionCatalogOption>> Function(String query);

Future<List<ClinicalActionCatalogOption>?>
showClinicalPrescriptionCatalogDialog({
  required BuildContext context,
  required List<ClinicalActionCatalogOption> drugs,
  Set<String> alreadySelectedDrugIds = const <String>{},
  ClinicalPrescriptionCatalogLoader? loadDrugs,
  String billingEntity = 'FACILITY',
}) {
  return showAppDialog<List<ClinicalActionCatalogOption>>(
    context: context,
    builder: (BuildContext context) => ClinicalPrescriptionCatalogDialog(
      drugs: drugs,
      alreadySelectedDrugIds: alreadySelectedDrugIds,
      loadDrugs: loadDrugs,
      billingEntity: billingEntity,
    ),
  );
}

class ClinicalPrescriptionCatalogDialog extends StatefulWidget {
  const ClinicalPrescriptionCatalogDialog({
    required this.drugs,
    this.alreadySelectedDrugIds = const <String>{},
    this.loadDrugs,
    this.billingEntity = 'FACILITY',
    super.key,
  });

  final List<ClinicalActionCatalogOption> drugs;
  final Set<String> alreadySelectedDrugIds;
  final ClinicalPrescriptionCatalogLoader? loadDrugs;

  /// Billing entity used for unit-price lane (FACILITY vs PHARMACY).
  final String billingEntity;

  @override
  State<ClinicalPrescriptionCatalogDialog> createState() =>
      _ClinicalPrescriptionCatalogDialogState();
}

class _ClinicalPrescriptionCatalogDialogState
    extends State<ClinicalPrescriptionCatalogDialog> {
  static const String _selectColumnKey = 'select';
  static const String _nameColumnKey = 'name';
  static const String _codeColumnKey = 'code';
  static const String _availableColumnKey = 'available';
  static const String _priceColumnKey = 'price';
  static const String _columnVisibilityStorageKey =
      'clinical_prescription_catalog_columns';
  static const Duration _remoteSearchDebounceDuration =
      Duration(milliseconds: 280);

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<ClinicalActionCatalogOption>
  _columnVisibilityController;
  final Set<String> _stagedIds = <String>{};
  final List<ClinicalActionCatalogOption> _stagedOptions =
      <ClinicalActionCatalogOption>[];

  List<ClinicalActionCatalogOption> _catalog = const <ClinicalActionCatalogOption>[];
  bool _isLoadingCatalog = false;
  String? _catalogError;
  Timer? _remoteSearchDebounce;
  int _remoteSearchGeneration = 0;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _columnVisibilityController =
        AppListTableColumnVisibilityController<ClinicalActionCatalogOption>();
    _catalog = List<ClinicalActionCatalogOption>.of(widget.drugs);
    if (widget.loadDrugs != null) {
      unawaited(_reloadCatalog(_searchController.text));
    }
  }

  @override
  void dispose() {
    _remoteSearchDebounce?.cancel();
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalActionCatalogOption> catalog = _availableDrugs();
    final List<AppListTableColumn<ClinicalActionCatalogOption>> columns =
        _catalogColumns(context);
    final List<AppListTableColumn<ClinicalActionCatalogOption>> columnChoices =
        columns
            .where(
              (AppListTableColumn<ClinicalActionCatalogOption> column) =>
                  column.key != _selectColumnKey,
            )
            .toList(growable: false);

    return AppDialog(
      title: Text(l10n.clinicalPrescriptionCatalogPickerTitle),
      icon: const Icon(Icons.manage_search_outlined),
      maxWidth: 980,
      pinActionsToBottom: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              l10n.clinicalPrescriptionCatalogSelectedCount(_stagedIds.length),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: AppFontWeight.emphasis,
                color: colorScheme.primary,
              ),
            ),
          ),
          if (_catalogError != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            AppFormInformationBanner.message(
              message: _catalogError!,
              variant: AppFormInformationVariant.error,
            ),
          ],
          SizedBox(height: theme.spacing.sm),
          Expanded(
            child: AppListTable<ClinicalActionCatalogOption>(
              items: catalog,
              columns: columns,
              columnChoices: columnChoices,
              columnVisibilityController: _columnVisibilityController,
              columnVisibilityStorageKey: _columnVisibilityStorageKey,
              columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
              columnVisibilityTitle:
                  l10n.clinicalPrescriptionCatalogColumnsTitle,
              columnVisibilityApplyLabel: l10n.labApplyColumnsAction,
              columnVisibilityResetLabel: l10n.labResetColumnsAction,
              displayMode: AppListTableDisplayMode.table,
              tableHorizontalMargin: 0,
              showRowNumbers: false,
              enableExport: false,
              isLoading: _isLoadingCatalog,
              onRowSelected: (ClinicalActionCatalogOption item) {
                _toggleSelection(
                  item,
                  selected: !_stagedIds.contains(item.apiId),
                );
              },
              rowColorBuilder:
                  (BuildContext context, ClinicalActionCatalogOption item) {
                    if (!_stagedIds.contains(item.apiId)) {
                      return null;
                    }
                    return colorScheme.primaryContainer.withValues(alpha: 0.35);
                  },
              itemKeyBuilder: (ClinicalActionCatalogOption item) =>
                  ValueKey<String>(item.apiId),
              search: AppListTableSearch<ClinicalActionCatalogOption>(
                controller: _searchController,
                semanticLabel: l10n.clinicalPrescriptionCatalogSearchLabel,
                hintText: l10n.clinicalPrescriptionCatalogSearchHint,
                matcher: widget.loadDrugs == null
                    ? _matchesCatalogSearch
                    : (_, _) => true,
                isLoading: _isLoadingCatalog || _isScanning,
                onChanged: widget.loadDrugs == null
                    ? null
                    : _scheduleRemoteSearch,
                onSubmitted: widget.loadDrugs == null
                    ? null
                    : (String value) => unawaited(_reloadCatalog(value)),
                trailingActions: <AppSearchBarAction>[
                  AppSearchBarAction(
                    icon: Icons.qr_code_scanner_outlined,
                    label: l10n.pharmacyDrugScanBarcodeAction,
                    tooltip: l10n.pharmacyDrugScanBarcodeAction,
                    enabled: !_isScanning,
                    onPressed: _isScanning
                        ? null
                        : () => unawaited(_scanBarcode()),
                  ),
                ],
              ),
              emptyBuilder: (_) =>
                  AppMutedText(l10n.clinicalPrescriptionCatalogNoOptions),
              mobileItemBuilder:
                  (BuildContext context, ClinicalActionCatalogOption item) {
                    final bool selected = _stagedIds.contains(item.apiId);
                    return InkWell(
                      onTap: () =>
                          _toggleSelection(item, selected: !selected),
                      child: AppListTableMobileItem(
                        leading: IgnorePointer(
                          child: Checkbox(
                            value: selected,
                            onChanged: (_) {},
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        title: clinicalPrescriptionDrugIdentityLabel(item),
                        caption: item.code,
                        meta: <AppListTableMobileMeta>[
                          if ((item.displaySubtitle ?? '').isNotEmpty)
                            AppListTableMobileMeta(label: item.displaySubtitle!),
                          if (_availabilityLabel(context, item).isNotEmpty)
                            AppListTableMobileMeta(
                              label: _availabilityLabel(context, item),
                            ),
                          AppListTableMobileMeta(
                            label:
                                '${_unitPriceColumnLabel(l10n)}: ${clinicalRequestPriceLabel(
                              context,
                              clinicalCatalogOptionUnitPrice(
                                item,
                                billingEntity: widget.billingEntity,
                              ),
                              clinicalCatalogOptionCurrency(item),
                            )}',
                          ),
                        ],
                        showAvatar: false,
                      ),
                    );
                  },
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          leadingIcon: AppActionIcons.cancel,
          label: l10n.commonCancelActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: l10n.clinicalPrescriptionCatalogConfirmAction,
          leadingIcon: Icons.playlist_add_check,
          enabled: _stagedOptions.isNotEmpty,
          onPressed: _stagedOptions.isEmpty
              ? null
              : () => Navigator.of(context).pop(
                  List<ClinicalActionCatalogOption>.from(_stagedOptions),
                ),
        ),
      ],
    );
  }

  String _availabilityLabel(
    BuildContext context,
    ClinicalActionCatalogOption item,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final num? available = clinicalCatalogOptionAvailableQuantity(item);
    final String status = clinicalCatalogOptionStockStatusLabel(
      clinicalCatalogOptionStockStatus(item),
    );
    if (available != null) {
      final String quantityLabel = l10n.pharmacyAvailableQuantityLabel(
        '$available',
      );
      return status.isEmpty ? quantityLabel : '$quantityLabel · $status';
    }
    return status;
  }

  void _scheduleRemoteSearch(String query) {
    _remoteSearchDebounce?.cancel();
    _remoteSearchDebounce = Timer(_remoteSearchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_reloadCatalog(query));
    });
  }

  Future<void> _reloadCatalog(String query) async {
    final ClinicalPrescriptionCatalogLoader? loader = widget.loadDrugs;
    if (loader == null) {
      return;
    }
    final int generation = ++_remoteSearchGeneration;
    setState(() {
      _isLoadingCatalog = true;
      _catalogError = null;
    });
    try {
      final List<ClinicalActionCatalogOption> next = await loader(query);
      if (!mounted || generation != _remoteSearchGeneration) {
        return;
      }
      setState(() {
        _catalog = next;
        _isLoadingCatalog = false;
      });
    } catch (_) {
      if (!mounted || generation != _remoteSearchGeneration) {
        return;
      }
      setState(() {
        _isLoadingCatalog = false;
        _catalogError = context.l10n.clinicalPrescriptionCatalogNoOptions;
      });
    }
  }

  Future<void> _scanBarcode() async {
    if (_isScanning) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    setState(() => _isScanning = true);
    try {
      final String? code = await scanLiveBarcode(
        context: context,
        title: l10n.pharmacyDrugScanBarcodeTitle,
        body: l10n.pharmacyDrugScanBarcodeBody,
        closeLabel: l10n.commonCloseActionLabel,
        unavailableBody: l10n.pharmacyDrugScanBarcodeUnavailableBody,
      );
      if (!mounted || code == null || code.trim().isEmpty) {
        return;
      }
      final String normalized = code.trim();
      _searchController.text = normalized;
      if (widget.loadDrugs != null) {
        await _reloadCatalog(normalized);
      }
      if (!mounted) {
        return;
      }
      _selectMatchesForScan(normalized);
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _selectMatchesForScan(String code) {
    final String normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) {
      return;
    }
    final List<ClinicalActionCatalogOption> matches = _availableDrugs()
        .where((ClinicalActionCatalogOption item) {
          final String itemCode = (item.code ?? '').trim().toLowerCase();
          final String apiId = item.apiId.trim().toLowerCase();
          final String haystack = clinicalActionJoinDisplay(<String?>[
            item.name,
            item.code,
            item.searchText,
            item.displayTitle,
          ], separator: ' ').toLowerCase();
          return itemCode == normalized ||
              apiId == normalized ||
              haystack.contains(normalized);
        })
        .toList(growable: false);
    if (matches.isEmpty) {
      return;
    }
    setState(() {
      for (final ClinicalActionCatalogOption item in matches) {
        final String apiId = item.apiId;
        if (_stagedIds.contains(apiId)) {
          continue;
        }
        _stagedIds.add(apiId);
        _stagedOptions.add(item);
      }
    });
  }

  List<ClinicalActionCatalogOption> _availableDrugs() {
    final Set<String> excluded = widget.alreadySelectedDrugIds
        .map((String id) => id.trim().toLowerCase())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final List<ClinicalActionCatalogOption> source =
        widget.loadDrugs == null ? widget.drugs : _catalog;
    final List<ClinicalActionCatalogOption> available =
        <ClinicalActionCatalogOption>[];
    for (final ClinicalActionCatalogOption option in source) {
      final String apiId = option.apiId.trim();
      if (apiId.isEmpty) {
        continue;
      }
      if (excluded.contains(apiId.toLowerCase())) {
        continue;
      }
      available.add(option);
    }
    available.sort(
      (ClinicalActionCatalogOption left, ClinicalActionCatalogOption right) {
        final int bySelected =
            (_stagedIds.contains(right.apiId) ? 1 : 0) -
            (_stagedIds.contains(left.apiId) ? 1 : 0);
        if (bySelected != 0) {
          return bySelected;
        }
        return appListTableCompareText(
          clinicalPrescriptionDrugIdentityLabel(left),
          clinicalPrescriptionDrugIdentityLabel(right),
        );
      },
    );
    return available;
  }

  List<AppListTableColumn<ClinicalActionCatalogOption>> _catalogColumns(
    BuildContext context,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return <AppListTableColumn<ClinicalActionCatalogOption>>[
      _selectionColumn(context),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _nameColumnKey,
        label: l10n.clinicalPrescriptionMedicineLabel,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) => appListTableCompareText(
              clinicalPrescriptionDrugIdentityLabel(left),
              clinicalPrescriptionDrugIdentityLabel(right),
            ),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(clinicalPrescriptionDrugIdentityLabel(item));
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _codeColumnKey,
        label: l10n.clinicalPrescriptionCatalogCodeLabel,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) => appListTableCompareText(left.code, right.code),
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Text(item.code ?? l10n.profileUnknownValue);
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _availableColumnKey,
        label: l10n.pharmacyAvailableColumnLabel,
        numeric: true,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) {
              final num leftQty =
                  clinicalCatalogOptionAvailableQuantity(left) ?? -1;
              final num rightQty =
                  clinicalCatalogOptionAvailableQuantity(right) ?? -1;
              return leftQty.compareTo(rightQty);
            },
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          final String label = _availabilityLabel(context, item);
          return Text(
            label.isEmpty ? l10n.profileUnknownValue : label,
          );
        },
      ),
      AppListTableColumn<ClinicalActionCatalogOption>(
        id: _priceColumnKey,
        label: _unitPriceColumnLabel(l10n),
        numeric: true,
        sortComparator:
            (
              ClinicalActionCatalogOption left,
              ClinicalActionCatalogOption right,
            ) {
              final num leftPrice =
                  clinicalCatalogOptionUnitPrice(
                    left,
                    billingEntity: widget.billingEntity,
                  ) ??
                  0;
              final num rightPrice =
                  clinicalCatalogOptionUnitPrice(
                    right,
                    billingEntity: widget.billingEntity,
                  ) ??
                  0;
              return leftPrice.compareTo(rightPrice);
            },
        cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
          return Padding(
            padding: EdgeInsetsDirectional.only(end: theme.spacing.md),
            child: Text(
              clinicalRequestPriceLabel(
                context,
                clinicalCatalogOptionUnitPrice(
                  item,
                  billingEntity: widget.billingEntity,
                ),
                clinicalCatalogOptionCurrency(item),
              ),
              textAlign: TextAlign.end,
            ),
          );
        },
      ),
    ];
  }

  String _unitPriceColumnLabel(AppLocalizations l10n) {
    final String entity = widget.billingEntity.trim().toUpperCase();
    if (entity == 'PHARMACY') {
      return l10n.clinicalPrescriptionCatalogPharmacyUnitPriceLabel;
    }
    if (entity == 'FACILITY') {
      return l10n.clinicalPrescriptionCatalogFacilityUnitPriceLabel;
    }
    return l10n.clinicalRequestUnitPriceLabel;
  }

  AppListTableColumn<ClinicalActionCatalogOption> _selectionColumn(
    BuildContext context,
  ) {
    return AppListTableColumn<ClinicalActionCatalogOption>(
      id: _selectColumnKey,
      label: '',
      alwaysVisible: true,
      fixedWidth: 40,
      headerBuilder: (BuildContext context) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (BuildContext context, TextEditingValue value, Widget? _) {
            final List<ClinicalActionCatalogOption> visibleItems =
                widget.loadDrugs == null
                ? _availableDrugs()
                      .where(
                        (ClinicalActionCatalogOption item) =>
                            _matchesCatalogSearch(item, value.text),
                      )
                      .toList(growable: false)
                : _availableDrugs();
            final bool allSelected =
                visibleItems.isNotEmpty &&
                visibleItems.every(
                  (ClinicalActionCatalogOption item) =>
                      _stagedIds.contains(item.apiId),
                );
            final bool someSelected = visibleItems.any(
              (ClinicalActionCatalogOption item) =>
                  _stagedIds.contains(item.apiId),
            );
            return Center(
              child: Checkbox(
                tristate: true,
                value: allSelected
                    ? true
                    : someSelected
                    ? null
                    : false,
                onChanged: visibleItems.isEmpty
                    ? null
                    : (bool? checked) {
                        _toggleFilteredItems(
                          visibleItems,
                          selected: checked ?? false,
                        );
                      },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            );
          },
        );
      },
      cellBuilder: (BuildContext context, ClinicalActionCatalogOption item) {
        return Center(
          child: IgnorePointer(
            child: Checkbox(
              value: _stagedIds.contains(item.apiId),
              onChanged: (_) {},
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        );
      },
    );
  }

  bool _matchesCatalogSearch(ClinicalActionCatalogOption item, String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    final String haystack = clinicalActionJoinDisplay(<String?>[
      item.name,
      item.code,
      item.category,
      item.secondaryText,
      item.status,
      item.searchText,
      item.displayTitle,
      item.displaySubtitle,
    ], separator: ' ').toLowerCase();
    return haystack.contains(normalized);
  }

  void _toggleSelection(
    ClinicalActionCatalogOption option, {
    required bool selected,
  }) {
    final String apiId = option.apiId;
    final bool currentlySelected = _stagedIds.contains(apiId);
    if (currentlySelected == selected) {
      return;
    }
    setState(() {
      if (selected) {
        _stagedIds.add(apiId);
        if (!_stagedOptions.any(
          (ClinicalActionCatalogOption item) => item.apiId == apiId,
        )) {
          _stagedOptions.add(option);
        }
        return;
      }
      _stagedIds.remove(apiId);
      _stagedOptions.removeWhere(
        (ClinicalActionCatalogOption item) => item.apiId == apiId,
      );
    });
  }

  void _toggleFilteredItems(
    List<ClinicalActionCatalogOption> items, {
    required bool selected,
  }) {
    setState(() {
      for (final ClinicalActionCatalogOption item in items) {
        final String apiId = item.apiId;
        final bool currentlySelected = _stagedIds.contains(apiId);
        if (currentlySelected == selected) {
          continue;
        }
        if (selected) {
          _stagedIds.add(apiId);
          if (!_stagedOptions.any(
            (ClinicalActionCatalogOption option) => option.apiId == apiId,
          )) {
            _stagedOptions.add(item);
          }
          continue;
        }
        _stagedIds.remove(apiId);
        _stagedOptions.removeWhere(
          (ClinicalActionCatalogOption option) => option.apiId == apiId,
        );
      }
    });
  }
}
