import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

typedef RadiologyCatalogUpdateSubmit =
    Future<AppFailure?> Function(String id, Map<String, Object?> payload);

typedef RadiologyOfferingCatalogSearch =
    Future<Result<List<RadiologyCatalogTest>>> Function({
      required RadiologyCatalogScope scope,
      String? query,
      int limit,
    });

class RadiologyEnableFacilityOfferingDialog extends StatefulWidget {
  const RadiologyEnableFacilityOfferingDialog({
    required this.scope,
    required this.onSearchCatalog,
    required this.onEnable,
    this.defaultCurrency = appDefaultCurrencyCode,
    super.key,
  });

  final RadiologyCatalogScope scope;
  final RadiologyOfferingCatalogSearch onSearchCatalog;
  final RadiologyCatalogUpdateSubmit onEnable;
  final String defaultCurrency;

  @override
  State<RadiologyEnableFacilityOfferingDialog> createState() =>
      _RadiologyEnableFacilityOfferingDialogState();
}

class _RadiologyEnableFacilityOfferingDialogState
    extends State<RadiologyEnableFacilityOfferingDialog> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 200);
  static const int _searchLimit = 100;
  static const String _modalityFilterKey = 'modality';

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  List<RadiologyCatalogTest> _catalogItems = const <RadiologyCatalogTest>[];
  AppFailure? _failure;
  bool _isSearching = true;
  int _searchRequest = 0;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;

  List<RadiologyCatalogTest> get _filteredCatalogItems {
    final String? modality = _filterValue.option(_modalityFilterKey);
    return _catalogItems
        .where((RadiologyCatalogTest item) {
          if (modality != null && item.modality != modality) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  List<RadiologyCatalogTest> get _availableItems {
    return _filteredCatalogItems
        .where((RadiologyCatalogTest item) => !item.isOfferedAtFacility)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchRequest += 1;
    unawaited(_loadCatalog(query: null, requestId: _searchRequest));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog({
    required String? query,
    required int requestId,
  }) async {
    setState(() {
      _isSearching = true;
      _failure = null;
    });
    final Result<List<RadiologyCatalogTest>> result = await widget
        .onSearchCatalog(
          scope: widget.scope,
          query: query?.trim().isEmpty ?? true ? null : query?.trim(),
          limit: _searchLimit,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    result.when(
      success: (List<RadiologyCatalogTest> items) {
        setState(() {
          _catalogItems = items;
          _isSearching = false;
        });
      },
      failure: (AppFailure value) {
        setState(() {
          _catalogItems = const <RadiologyCatalogTest>[];
          _isSearching = false;
          _failure = value;
        });
      },
    );
  }

  void _scheduleCatalogSearch(String query) {
    _searchDebounce?.cancel();
    _searchRequest += 1;
    final int requestId = _searchRequest;
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_loadCatalog(query: query, requestId: requestId));
    });
  }

  Future<void> _openPriceDialog(RadiologyCatalogTest item) async {
    if (item.isOfferedAtFacility) {
      return;
    }
    final bool? enabled = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEnableOfferingPriceDialog(
        item: item,
        defaultCurrency: widget.defaultCurrency,
        onEnable: widget.onEnable,
      ),
    );
    if (!mounted) {
      return;
    }
    if (enabled == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<RadiologyCatalogTest> available = _availableItems;

    return AppDialog(
      title: Text(l10n.radiologyEnableOfferingDialogTitle),
      icon: const Icon(Icons.add_circle_outline),
      scrollable: true,
      maxWidth: 980,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.md),
              child: AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            ),
          Text(
            l10n.radiologyEnableOfferingDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          if (_isSearching && _catalogItems.isEmpty)
            AppWorkspaceStatePanel.loading(
              title: l10n.radiologyConfigurationsLoadingTitle,
              body: l10n.radiologyConfigurationsLoadingBody,
              minHeight: 120,
            )
          else if (!_isSearching && _catalogItems.isEmpty)
            AppMutedText(l10n.radiologyEnableOfferingNoPlatformItemsLabel)
          else if (!_isSearching && _filteredCatalogItems.isEmpty)
            AppMutedText(l10n.radiologyEnableOfferingNoItemsLabel)
          else if (!_isSearching && available.isEmpty)
            AppMutedText(l10n.radiologyEnableOfferingNoItemsLabel)
          else
            AppListTable<RadiologyCatalogTest>(
              items: _filteredCatalogItems,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              tableHorizontalMargin: 0,
              isLoading: _isSearching,
              onRowSelected: (RadiologyCatalogTest item) {
                if (!item.isOfferedAtFacility) {
                  unawaited(_openPriceDialog(item));
                }
              },
              search: AppListTableSearch<RadiologyCatalogTest>(
                controller: _searchController,
                semanticLabel: l10n.radiologyConfigurationSearchLabel,
                hintText: l10n.radiologyConfigurationSearchHint,
                isLoading: _isSearching,
                matcher: (RadiologyCatalogTest item, String query) =>
                    item.matchesSearch(query),
                onChanged: _scheduleCatalogSearch,
                showAdvancedFilterButton: true,
                advancedFilterButtonLabel: l10n.radiologyFiltersLabel,
                advancedFilterTitle: l10n.radiologyFiltersLabel,
                advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
                advancedFilterResetLabel: l10n.radiologyClearFiltersAction,
                enableDateFilter: false,
                allFieldsLabel: l10n.labScopeAll,
                filterGroups: <AppSearchBarFilterGroup>[
                  AppSearchBarFilterGroup(
                    key: _modalityFilterKey,
                    label: l10n.radiologyModalityLabel,
                    allLabel: l10n.labScopeAll,
                    choices: _modalityFilterChoices(_catalogItems),
                  ),
                ],
                filterValue: _filterValue,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _filterValue = value);
                },
              ),
              columns: <AppListTableColumn<RadiologyCatalogTest>>[
                AppListTableColumn<RadiologyCatalogTest>(
                  id: 'name',
                  label: l10n.radiologyTestNameLabel,
                  cellBuilder: (_, RadiologyCatalogTest item) => Text(item.name),
                ),
                AppListTableColumn<RadiologyCatalogTest>(
                  id: 'code',
                  label: l10n.radiologyTestCodeLabel,
                  cellBuilder: (_, RadiologyCatalogTest item) =>
                      Text(item.code ?? l10n.profileUnknownValue),
                ),
                AppListTableColumn<RadiologyCatalogTest>(
                  id: 'modality',
                  label: l10n.radiologyModalityLabel,
                  cellBuilder: (_, RadiologyCatalogTest item) =>
                      Text(item.modality ?? l10n.profileUnknownValue),
                ),
                AppListTableColumn<RadiologyCatalogTest>(
                  id: 'status',
                  label: l10n.radiologyActionColumnLabel,
                  cellBuilder: (_, RadiologyCatalogTest item) => Text(
                    item.isOfferedAtFacility
                        ? l10n.radiologyEnableOfferingAlreadyOfferedLabel
                        : l10n.commonSelectActionLabel,
                  ),
                ),
              ],
              mobileItemBuilder: (BuildContext context, RadiologyCatalogTest item) {
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(item.code ?? l10n.profileUnknownValue),
                  trailing: Text(
                    item.isOfferedAtFacility
                        ? l10n.radiologyEnableOfferingAlreadyOfferedLabel
                        : l10n.commonSelectActionLabel,
                  ),
                  onTap: item.isOfferedAtFacility
                      ? null
                      : () => unawaited(_openPriceDialog(item)),
                );
              },
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  List<AppSearchBarFilterChoice> _modalityFilterChoices(
    List<RadiologyCatalogTest> items,
  ) {
    final Set<String> values = <String>{};
    for (final RadiologyCatalogTest item in items) {
      final String? modality = item.modality?.trim();
      if (modality != null && modality.isNotEmpty) {
        values.add(modality);
      }
    }
    return values
        .map(
          (String value) =>
              AppSearchBarFilterChoice(value: value, label: value),
        )
        .toList(growable: false);
  }
}

class RadiologyEnableOfferingPriceDialog extends StatefulWidget {
  const RadiologyEnableOfferingPriceDialog({
    required this.item,
    required this.onEnable,
    required this.defaultCurrency,
    super.key,
  });

  final RadiologyCatalogTest item;
  final RadiologyCatalogUpdateSubmit onEnable;
  final String defaultCurrency;

  @override
  State<RadiologyEnableOfferingPriceDialog> createState() =>
      _RadiologyEnableOfferingPriceDialogState();
}

class _RadiologyEnableOfferingPriceDialogState
    extends State<RadiologyEnableOfferingPriceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late String _currency;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.unitPrice?.toString() ?? '',
    );
    _currency = widget.item.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyCatalogTest item = widget.item;

    return AppDialog(
      title: Text(l10n.radiologyEnableProcedureAction),
      icon: const Icon(Icons.image_search_outlined),
      scrollable: true,
      maxWidth: 520,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              item.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.code != null && item.code!.isNotEmpty)
              AppMutedText(
                <String?>[item.code, item.modality].whereType<String>().join(' · '),
              ),
            AppCurrencyAmountField(
              amountController: _priceController,
              currency: _currency,
              amountLabelText: l10n.clinicalRequestUnitPriceLabel,
              currencyLabelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving,
              isRequired: true,
              allowZero: false,
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
              validator: (String? value) => _positiveUnitPriceValidator(l10n, value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.radiologyEnableProcedureAction,
          leadingIcon: Icons.check_circle_outline,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onEnable(
      widget.item.apiId,
      <String, Object?>{
        'is_active': true,
        'unit_price':
            num.tryParse(normalizeCurrencyAmount(_priceController.text)) ?? 0,
        'currency': _currency,
      },
    );
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

class RadiologyEditFacilityOfferingDialog extends StatefulWidget {
  const RadiologyEditFacilityOfferingDialog({
    required this.item,
    required this.onUpdate,
    this.defaultCurrency = appDefaultCurrencyCode,
    super.key,
  });

  final RadiologyCatalogTest item;
  final RadiologyCatalogUpdateSubmit onUpdate;
  final String defaultCurrency;

  @override
  State<RadiologyEditFacilityOfferingDialog> createState() =>
      _RadiologyEditFacilityOfferingDialogState();
}

class _RadiologyEditFacilityOfferingDialogState
    extends State<RadiologyEditFacilityOfferingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _priceController;
  late String _currency;
  AppFailure? _failure;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.item.unitPrice?.toString() ?? '',
    );
    _currency = widget.item.currency ?? widget.defaultCurrency;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(l10n.radiologyEditOfferingDialogTitle),
      icon: const Icon(Icons.edit_outlined),
      scrollable: true,
      maxWidth: 520,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            Text(
              widget.item.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            AppCurrencyAmountField(
              amountController: _priceController,
              currency: _currency,
              amountLabelText: l10n.clinicalRequestUnitPriceLabel,
              currencyLabelText: l10n.opdCurrencyLabel,
              enabled: !_isSaving,
              isRequired: true,
              allowZero: false,
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
              validator: (String? value) => _positiveUnitPriceValidator(l10n, value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.radiologySaveConfigurationAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onUpdate(
      widget.item.apiId,
      <String, Object?>{
        'is_active': true,
        'unit_price':
            num.tryParse(normalizeCurrencyAmount(_priceController.text)) ?? 0,
        'currency': _currency,
      },
    );
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

String? _positiveUnitPriceValidator(AppLocalizations l10n, String? value) {
  final String normalized = normalizeCurrencyAmount(value ?? '');
  if (normalized.isEmpty) {
    return l10n.validationRequired;
  }
  final num? parsed = num.tryParse(normalized);
  if (parsed == null || parsed <= 0) {
    return l10n.validationRequired;
  }
  return null;
}
