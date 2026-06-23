import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_layer_selector.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class FacilityCatalogConfigPanel extends ConsumerStatefulWidget {
  const FacilityCatalogConfigPanel({
    required this.facilityId,
    this.enabled = true,
    super.key,
  });

  final String facilityId;
  final bool enabled;

  @override
  ConsumerState<FacilityCatalogConfigPanel> createState() =>
      _FacilityCatalogConfigPanelState();
}

class _FacilityCatalogConfigPanelState
    extends ConsumerState<FacilityCatalogConfigPanel> {
  static const int _searchLimit = 40;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  ClinicalCatalogTermType _termType = ClinicalCatalogTermType.diagnosis;
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.global;
  List<ClinicalCatalogOption> _searchResults = const <ClinicalCatalogOption>[];
  List<Map<String, Object?>> _offerings = const <Map<String, Object?>>[];
  bool _isSearching = false;
  bool _isLoadingOfferings = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadOfferings());
        unawaited(_searchCatalog(''));
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          l10n.clinicalCatalogConfigurationBody,
          style: theme.textTheme.bodyMedium,
        ),
        SizedBox(height: theme.spacing.md),
        if (_failure != null) AppFailureStateView(failure: _failure!),
        AppSelectField<ClinicalCatalogTermType>(
          value: _termType,
          labelText: l10n.clinicalCatalogConfigurationTitle,
          enabled: widget.enabled,
          options: <AppSelectOption<ClinicalCatalogTermType>>[
            AppSelectOption<ClinicalCatalogTermType>(
              value: ClinicalCatalogTermType.diagnosis,
              label: l10n.clinicalAddDiagnosisAction,
            ),
            AppSelectOption<ClinicalCatalogTermType>(
              value: ClinicalCatalogTermType.procedure,
              label: l10n.clinicalRequestProcedureAction,
            ),
            AppSelectOption<ClinicalCatalogTermType>(
              value: ClinicalCatalogTermType.labTest,
              label: l10n.clinicalRequestLabAction,
            ),
            AppSelectOption<ClinicalCatalogTermType>(
              value: ClinicalCatalogTermType.radiologyTest,
              label: l10n.clinicalRequestRadiologyAction,
            ),
            AppSelectOption<ClinicalCatalogTermType>(
              value: ClinicalCatalogTermType.prescription,
              label: l10n.clinicalPrescriptionHeaderTitle,
            ),
          ],
          onChanged: (ClinicalCatalogTermType? value) {
            if (value == null) {
              return;
            }
            setState(() => _termType = value);
            unawaited(_loadOfferings());
            unawaited(_searchCatalog(_searchController.text));
          },
        ),
        SizedBox(height: theme.spacing.sm),
        ClinicalCatalogLayerSelector(
          value: _catalogSource,
          enabled: widget.enabled,
          onChanged: (ClinicalCatalogSource source) {
            setState(() => _catalogSource = source);
            unawaited(_searchCatalog(_searchController.text));
          },
        ),
        SizedBox(height: theme.spacing.sm),
        AppTextField(
          controller: _searchController,
          labelText: l10n.settingsWorkspaceSearchLabel,
          enabled: widget.enabled,
          prefixIcon: const Icon(Icons.manage_search_outlined),
          onChanged: _scheduleSearch,
        ),
        if (_isSearching || _isLoadingOfferings) ...<Widget>[
          SizedBox(height: theme.spacing.xs),
          const LinearProgressIndicator(),
        ],
        SizedBox(height: theme.spacing.md),
        AppSectionPanel(
          title: l10n.clinicalCatalogSourceGlobal,
          children: <Widget>[
            if (_searchResults.isEmpty)
              Text(l10n.settingsWorkspaceEmptyStatus)
            else
              for (final ClinicalCatalogOption option in _searchResults)
                ListTile(
                  dense: true,
                  title: Text(option.displayTitle),
                  subtitle: option.displaySubtitle == null
                      ? null
                      : Text(option.displaySubtitle!),
                  trailing: AppButton.secondary(
                    label: l10n.clinicalLabRequestAddSelectionAction,
                    enabled: widget.enabled,
                    onPressed: () => _addOffering(option),
                  ),
                ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppSectionPanel(
          title: l10n.clinicalCatalogSourceFacility,
          children: <Widget>[
            if (_offerings.isEmpty)
              Text(l10n.settingsWorkspaceEmptyStatus)
            else
              for (final Map<String, Object?> offering in _offerings)
                ListTile(
                  dense: true,
                  title: Text(
                    offering['item_id']?.toString() ??
                        offering['id']?.toString() ??
                        '',
                  ),
                  subtitle: Text(
                    offering['term_type']?.toString() ?? _termType.apiValue,
                  ),
                ),
          ],
        ),
      ],
    );
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }
      unawaited(_searchCatalog(value));
    });
  }

  Future<void> _searchCatalog(String query) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSearching = true;
      _failure = null;
    });
    final Result<List<ClinicalCatalogOption>> result = await ref
        .read(clinicalRepositoryProvider)
        .searchClinicalCatalog(
          termType: _termType.apiValue,
          query: query.trim().isEmpty ? null : query.trim(),
          limit: _searchLimit,
          source: _catalogSource.apiValue,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _searchResults = result.when(
        success: (List<ClinicalCatalogOption> value) => value,
        failure: (_) => const <ClinicalCatalogOption>[],
      );
      _failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      _isSearching = false;
    });
  }

  Future<void> _loadOfferings() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoadingOfferings = true);
    final Result<List<Map<String, Object?>>> result = await ref
        .read(clinicalRepositoryProvider)
        .listFacilityCatalogOfferings(
          facilityId: widget.facilityId,
          termType: _termType.apiValue,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _offerings = result.when(
        success: (List<Map<String, Object?>> value) => value,
        failure: (_) => const <Map<String, Object?>>[],
      );
      _isLoadingOfferings = false;
    });
  }

  Future<void> _addOffering(ClinicalCatalogOption option) async {
    if (!widget.enabled) {
      return;
    }
    final Result<void> result = await ref
        .read(clinicalRepositoryProvider)
        .upsertFacilityCatalogOffering(<String, Object?>{
          'facility_id': widget.facilityId,
          'term_type': _termType.apiValue,
          'item_id': option.id,
        });
    if (!mounted) {
      return;
    }
    result.when(
      success: (_) {
        unawaited(_loadOfferings());
      },
      failure: (AppFailure failure) {
        setState(() => _failure = failure);
      },
    );
  }
}
