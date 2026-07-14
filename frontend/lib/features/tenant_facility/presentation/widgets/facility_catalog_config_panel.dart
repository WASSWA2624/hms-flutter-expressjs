import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/radiology/data/repositories/radiology_repository_impl.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/domain/repositories/radiology_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_layer_selector.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_models.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/facility_catalog_scope.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_catalog_dialogs.dart';
import 'package:hosspi_hms/shared/radiology_catalog/radiology_catalog_dialogs.dart';

enum _FacilityCatalogMode { clinical, lab, radiology }

class FacilityCatalogConfigPanel extends ConsumerStatefulWidget {
  const FacilityCatalogConfigPanel({
    required this.facilityId,
    required this.tenantId,
    this.defaultCurrency = appDefaultCurrencyCode,
    this.enabled = true,
    super.key,
  });

  final String facilityId;
  final String tenantId;
  final String defaultCurrency;
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
  _FacilityCatalogMode _mode = _FacilityCatalogMode.clinical;
  ClinicalCatalogTermType _termType = ClinicalCatalogTermType.diagnosis;
  ClinicalCatalogSource _catalogSource = ClinicalCatalogSource.global;
  List<ClinicalCatalogOption> _searchResults = const <ClinicalCatalogOption>[];
  List<Map<String, Object?>> _offerings = const <Map<String, Object?>>[];
  bool _isSearching = false;
  bool _isLoadingOfferings = false;
  AppFailure? _failure;

  FacilityCatalogScope get _scope => FacilityCatalogScope(
    tenantId: widget.tenantId,
    facilityId: widget.facilityId,
  );

  String get _resolvedCurrency =>
      resolveFacilityDefaultCurrency(widget.defaultCurrency);

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
        if (_failure != null)
          AppFormInformationBanner.failure(
            context: context,
            failure: _failure!,
          ),
        AppSelectField<_FacilityCatalogMode>(
          value: _mode,
          labelText: l10n.clinicalCatalogConfigurationTitle,
          enabled: widget.enabled,
          options: <AppSelectOption<_FacilityCatalogMode>>[
            AppSelectOption<_FacilityCatalogMode>(
              value: _FacilityCatalogMode.clinical,
              label: l10n.clinicalAddDiagnosisAction,
            ),
            AppSelectOption<_FacilityCatalogMode>(
              value: _FacilityCatalogMode.lab,
              label: l10n.clinicalRequestLabAction,
            ),
            AppSelectOption<_FacilityCatalogMode>(
              value: _FacilityCatalogMode.radiology,
              label: l10n.clinicalRequestRadiologyAction,
            ),
          ],
          onChanged: (_FacilityCatalogMode? value) {
            if (value == null) {
              return;
            }
            setState(() {
              _mode = value;
              _failure = null;
              if (value == _FacilityCatalogMode.clinical) {
                _termType = ClinicalCatalogTermType.diagnosis;
              }
            });
            if (value == _FacilityCatalogMode.clinical) {
              unawaited(_loadOfferings());
              unawaited(_searchCatalog(_searchController.text));
            }
          },
        ),
        SizedBox(height: theme.spacing.md),
        if (_mode == _FacilityCatalogMode.clinical)
          ..._buildClinicalSection(l10n, theme),
        if (_mode == _FacilityCatalogMode.lab) ..._buildLabSection(l10n, theme),
        if (_mode == _FacilityCatalogMode.radiology)
          ..._buildRadiologySection(l10n, theme),
      ],
    );
  }

  List<Widget> _buildClinicalSection(AppLocalizations l10n, ThemeData theme) {
    return <Widget>[
      AppSelectField<ClinicalCatalogTermType>(
        value: _termType,
        labelText: l10n.clinicalCatalogSourceFacility,
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
    ];
  }

  List<Widget> _buildLabSection(AppLocalizations l10n, ThemeData theme) {
    return <Widget>[
      Text(
        l10n.labEnableOfferingDialogBody,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      SizedBox(height: theme.spacing.md),
      Wrap(
        spacing: theme.spacing.sm,
        runSpacing: theme.spacing.sm,
        children: <Widget>[
          AppButton.primary(
            label: l10n.labEnableTestAction,
            leadingIcon: Icons.add_circle_outline,
            enabled: widget.enabled,
            onPressed: () =>
                unawaited(_openLabEnableDialog(LabEnableOfferingKind.test)),
          ),
          AppButton.secondary(
            label: l10n.labEnablePanelAction,
            leadingIcon: Icons.add_box_outlined,
            enabled: widget.enabled,
            onPressed: () =>
                unawaited(_openLabEnableDialog(LabEnableOfferingKind.panel)),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildRadiologySection(AppLocalizations l10n, ThemeData theme) {
    return <Widget>[
      Text(
        l10n.clinicalRadiologyCatalogSelectBody,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      SizedBox(height: theme.spacing.md),
      AppButton.primary(
        label: l10n.clinicalRadiologyCatalogSelectTitle,
        leadingIcon: Icons.image_search_outlined,
        enabled: widget.enabled,
        onPressed: () => unawaited(_openRadiologyEnableDialog()),
      ),
    ];
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
    if (!mounted || _mode != _FacilityCatalogMode.clinical) {
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
    if (!mounted || _mode != _FacilityCatalogMode.clinical) {
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

  Future<void> _openLabEnableDialog(LabEnableOfferingKind kind) async {
    final LabRepository repository = ref.read(labRepositoryProvider);
    final FacilityCatalogScope scope = _scope;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabEnableFacilityOfferingDialog(
        kind: kind,
        scope: scope,
        defaultCurrency: _resolvedCurrency,
        onSearchCatalog:
            ({
              required LabEnableOfferingKind kind,
              required LabCatalogScope scope,
              String? query,
              int limit = 100,
            }) {
              return _searchLabCatalog(
                repository: repository,
                kind: kind,
                scope: scope,
                query: query,
                limit: limit,
              );
            },
        onEnable: (String id, Map<String, Object?> payload) async {
          final Result<LabCatalogItem> result =
              kind == LabEnableOfferingKind.test
              ? await repository.upsertFacilityLabTestOffering(
                  id,
                  payload,
                  tenantId: scope.tenantId,
                  facilityId: scope.facilityId,
                )
              : await repository.upsertFacilityLabPanelOffering(
                  id,
                  payload,
                  tenantId: scope.tenantId,
                  facilityId: scope.facilityId,
                );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.labSavedMessage)));
  }

  Future<void> _openRadiologyEnableDialog() async {
    final RadiologyRepository repository = ref.read(
      radiologyRepositoryProvider,
    );
    final FacilityCatalogScope scope = _scope;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEnableFacilityOfferingDialog(
        scope: scope,
        defaultCurrency: _resolvedCurrency,
        onSearchCatalog:
            ({
              required RadiologyCatalogScope scope,
              String? query,
              int limit = 100,
            }) {
              return _searchRadiologyCatalog(
                repository: repository,
                scope: scope,
                query: query,
                limit: limit,
              );
            },
        onEnable: (String id, Map<String, Object?> payload) async {
          final Result<RadiologyCatalogTest> result = await repository
              .upsertFacilityRadiologyTestOffering(
                id,
                payload,
                tenantId: scope.tenantId,
                facilityId: scope.facilityId,
              );
          return result.when(
            success: (_) => null,
            failure: (AppFailure failure) => failure,
          );
        },
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.radiologySaveConfigurationAction)),
    );
  }

  Future<Result<List<LabCatalogItem>>> _searchLabCatalog({
    required LabRepository repository,
    required LabEnableOfferingKind kind,
    required LabCatalogScope scope,
    String? query,
    int limit = 100,
  }) async {
    if (!scope.isReady) {
      return const Result<List<LabCatalogItem>>.success(<LabCatalogItem>[]);
    }
    final Future<Result<List<LabCatalogItem>>> platformFuture =
        kind == LabEnableOfferingKind.test
        ? repository.listTests(
            search: query,
            tenantId: scope.tenantId,
            includeStandardCatalog: true,
            limit: limit,
          )
        : repository.listPanels(
            search: query,
            tenantId: scope.tenantId,
            includeStandardCatalog: true,
            limit: limit,
          );
    final Future<Result<List<LabCatalogItem>>> offeredFuture =
        kind == LabEnableOfferingKind.test
        ? repository.listFacilityLabTests(
            tenantId: scope.tenantId,
            facilityId: scope.facilityId,
            offeredOnly: true,
            limit: limit,
          )
        : repository.listFacilityLabPanels(
            tenantId: scope.tenantId,
            facilityId: scope.facilityId,
            offeredOnly: true,
            limit: limit,
          );
    final List<Result<List<LabCatalogItem>>> results = await Future.wait(
      <Future<Result<List<LabCatalogItem>>>>[platformFuture, offeredFuture],
    );
    return results[0].when(
      success: (List<LabCatalogItem> platformItems) {
        final Set<String> offeredIds = <String>{};
        final Set<String> offeredCodes = <String>{};
        results[1].when(
          success: (List<LabCatalogItem> offeredItems) {
            for (final LabCatalogItem item in offeredItems) {
              offeredIds.add(item.apiId);
              final String? code = item.code?.trim();
              if (code != null && code.isNotEmpty) {
                offeredCodes.add(code.toUpperCase());
              }
            }
          },
          failure: (_) {},
        );
        return Result<List<LabCatalogItem>>.success(
          platformItems
              .map((LabCatalogItem item) {
                final String? code = item.code?.trim();
                final bool isOffered =
                    offeredIds.contains(item.apiId) ||
                    (code != null &&
                        code.isNotEmpty &&
                        offeredCodes.contains(code.toUpperCase()));
                return isOffered
                    ? item.copyWith(isOfferedAtFacility: true)
                    : item;
              })
              .toList(growable: false),
        );
      },
      failure: (AppFailure failure) =>
          Result<List<LabCatalogItem>>.failure(failure),
    );
  }

  Future<Result<List<RadiologyCatalogTest>>> _searchRadiologyCatalog({
    required RadiologyRepository repository,
    required RadiologyCatalogScope scope,
    String? query,
    int limit = 100,
  }) async {
    if (!scope.isReady) {
      return const Result<List<RadiologyCatalogTest>>.success(
        <RadiologyCatalogTest>[],
      );
    }
    final Future<Result<List<RadiologyCatalogTest>>> platformFuture = repository
        .listRadiologyCatalogTests(search: query, limit: limit);
    final Future<Result<List<RadiologyCatalogTest>>> offeredFuture = repository
        .listFacilityRadiologyTests(
          tenantId: scope.tenantId,
          facilityId: scope.facilityId,
          offeredOnly: true,
          limit: limit,
        );
    final List<Result<List<RadiologyCatalogTest>>> results = await Future.wait(
      <Future<Result<List<RadiologyCatalogTest>>>>[
        platformFuture,
        offeredFuture,
      ],
    );
    return results[0].when(
      success: (List<RadiologyCatalogTest> platformItems) {
        final Set<String> offeredIds = <String>{};
        final Set<String> offeredCodes = <String>{};
        results[1].when(
          success: (List<RadiologyCatalogTest> offeredItems) {
            for (final RadiologyCatalogTest item in offeredItems) {
              offeredIds.add(item.apiId);
              final String? code = item.code?.trim();
              if (code != null && code.isNotEmpty) {
                offeredCodes.add(code.toUpperCase());
              }
            }
          },
          failure: (_) {},
        );
        return Result<List<RadiologyCatalogTest>>.success(
          platformItems
              .map((RadiologyCatalogTest item) {
                final String? code = item.code?.trim();
                final bool isOffered =
                    offeredIds.contains(item.apiId) ||
                    (code != null &&
                        code.isNotEmpty &&
                        offeredCodes.contains(code.toUpperCase()));
                if (!isOffered) {
                  return item;
                }
                return item.copyWith(isOfferedAtFacility: true);
              })
              .toList(growable: false),
        );
      },
      failure: (AppFailure failure) =>
          Result<List<RadiologyCatalogTest>>.failure(failure),
    );
  }
}
