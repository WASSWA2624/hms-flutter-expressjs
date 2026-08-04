part of 'radiology_workspace_page.dart';

class _RadiologyConfigurationsDialog extends ConsumerStatefulWidget {
  const _RadiologyConfigurationsDialog({required this.state});

  final RadiologyWorkspaceState state;

  @override
  ConsumerState<_RadiologyConfigurationsDialog> createState() =>
      _RadiologyConfigurationsDialogState();
}

class _RadiologyConfigurationsDialogState
    extends ConsumerState<_RadiologyConfigurationsDialog> {
  static const String _modalityFilterKey = 'modality';
  static const int _maxVisibleItems = 140;

  late final TextEditingController _searchController;
  late final AppListTableColumnVisibilityController<RadiologyCatalogProcedure>
  _testColumnController;
  late RadiologyWorkspaceState _dialogState;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  String? _tenantId;
  String? _facilityId;
  bool _initializedScope = false;
  final Set<String> _selectedOfferingIds = <String>{};

  RadiologyCatalogScope get _catalogScope =>
      RadiologyCatalogScope(tenantId: _tenantId, facilityId: _facilityId);

  bool get _showTenantSelector {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.isElevated;
  }

  bool get _showFacilitySelector {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (policy.isElevated) {
      return true;
    }
    return policy.canManageTenant() && !policy.hasFacilityContext;
  }

  bool get _showScopeContextLabel {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return !_showTenantSelector &&
        !_showFacilitySelector &&
        policy.hasFacilityContext;
  }

  bool get _canEnableOfferings {
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    return policy.isElevated || policy.hasRole(AppRole.tenantAdmin);
  }

  @override
  void initState() {
    super.initState();
    _dialogState = widget.state;
    _searchController = TextEditingController();
    _testColumnController =
        AppListTableColumnVisibilityController<RadiologyCatalogProcedure>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_initializeScope());
    });
  }

  Future<void> _initializeScope() async {
    if (!mounted) {
      return;
    }
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    final RadiologyCatalogScope? existingScope = widget.state.catalogScope;
    final String? tenantId = _showTenantSelector
        ? existingScope?.tenantId
        : policy.tenantId ?? existingScope?.tenantId;
    final bool hasResolvedTenant = tenantId?.trim().isNotEmpty ?? false;
    final String? facilityId = _resolveInitialFacilityId(
      policy: policy,
      existingScope: existingScope,
      hasResolvedTenant: hasResolvedTenant,
    );

    setState(() {
      _tenantId = tenantId;
      _facilityId = facilityId;
      _initializedScope = true;
    });
    await _reloadCatalogIfReady();
  }

  String? _resolveInitialFacilityId({
    required AppAccessPolicy policy,
    required RadiologyCatalogScope? existingScope,
    required bool hasResolvedTenant,
  }) {
    if (!_showFacilitySelector) {
      return policy.facilityId ?? existingScope?.facilityId;
    }
    if (_showTenantSelector) {
      return hasResolvedTenant ? existingScope?.facilityId : null;
    }
    return policy.facilityId ?? existingScope?.facilityId;
  }

  Future<void> _reloadCatalogIfReady() async {
    await ref
        .read(radiologyWorkspaceControllerProvider.notifier)
        .loadFacilityCatalogConfig(_catalogScope);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _testColumnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    ref.listen<AsyncValue<Result<RadiologyWorkspaceState>>>(
      radiologyWorkspaceControllerProvider,
      (_, AsyncValue<Result<RadiologyWorkspaceState>> next) {
        final RadiologyWorkspaceState? nextState = _stateFromAsync(next);
        if (nextState == null ||
            !_shouldSyncCatalogState(_dialogState, nextState)) {
          return;
        }
        setState(() {
          _dialogState = nextState;
          _pruneOfferingSelection(nextState.catalogTests);
        });
      },
    );
    final RadiologyWorkspaceState state = _dialogState;
    final String query = _searchController.text;
    final List<RadiologyCatalogProcedure> tests = state.catalogTests
        .where((RadiologyCatalogProcedure test) => test.matchesSearch(query))
        .where((RadiologyCatalogProcedure test) {
          final String? modality = _filterValue.option(_modalityFilterKey);
          if (modality != null && test.modality != modality) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    final bool scopeReady = _catalogScope.isReady;
    final bool isLoadingCatalog =
        scopeReady && (!_initializedScope || state.isLoadingCatalog);
    final bool showCatalogLoadingPanel =
        isLoadingCatalog && state.catalogTests.isEmpty;
    final AppFailure? loadFailure = state.catalogLoadFailure is AppFailure
        ? state.catalogLoadFailure as AppFailure
        : null;
    final AsyncValue<Result<HomeDashboardLookups>>? lookupsAsync =
        _initializedScope
        ? ref.watch(
            homeLookupsControllerProvider(
              HomeDashboardRequest(
                tenantId: _tenantId,
                facilityId: _facilityId,
              ),
            ),
          )
        : null;
    final List<HomeLookupOption> tenantOptions =
        lookupsAsync?.value?.when(
          success: (HomeDashboardLookups value) => value.tenants,
          failure: (_) => const <HomeLookupOption>[],
        ) ??
        const <HomeLookupOption>[];
    final bool hasTenant = _tenantId?.trim().isNotEmpty ?? false;
    final List<HomeLookupOption> facilityOptions = _facilityOptionsForScope(
      lookupsAsync: lookupsAsync,
      hasTenant: hasTenant,
    );
    final String? facilityLabel = _facilityLabel(facilityOptions);
    final String? tenantLabel = _tenantLabel(tenantOptions);
    final bool facilitySelectorEnabled = _showTenantSelector
        ? hasTenant
        : facilityOptions.isNotEmpty;

    return AppDialog(
      title: Text(l10n.radiologyConfigurationsDialogTitle),
      icon: const Icon(Icons.tune_outlined),
      scrollable: true,
      maxWidth: 980,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FacilityCatalogScopeSection(
            labels: FacilityCatalogScopeLabels(
              facilityContextLabel:
                  l10n.radiologyConfigurationsFacilityContextLabel,
              selectTenantFirstTooltip:
                  l10n.radiologyConfigurationsSelectTenantFirstTooltip,
              tenantLabel: l10n.settingsWorkspaceTenantLabel,
              facilityLabel: l10n.settingsWorkspaceFacilitySelectorLabel,
            ),
            scopeReady: scopeReady,
            showTenantSelector: _showTenantSelector,
            showFacilitySelector: _showFacilitySelector,
            showScopeContextLabel: _showScopeContextLabel,
            showScopeGuidanceWhenReady: false,
            tenantOptions: tenantOptions,
            facilityOptions: facilityOptions,
            tenantId: _tenantId,
            facilityId: _facilityId,
            facilitySelectorEnabled: facilitySelectorEnabled,
            facilityLabel: facilityLabel,
            scopePromptMessage: _scopePromptMessage(
              l10n,
              tenantLabel: tenantLabel,
            ),
            onTenantChanged: (String? value) async {
              setState(() {
                _tenantId = value;
                _facilityId = null;
              });
              await _reloadCatalogIfReady();
            },
            onFacilityChanged: (String? value) async {
              setState(() => _facilityId = value);
              await _reloadCatalogIfReady();
            },
          ),
          if (scopeReady) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            if (showCatalogLoadingPanel)
              AppWorkspaceStatePanel.loading(
                title: l10n.radiologyConfigurationsLoadingTitle,
                body: l10n.radiologyConfigurationsLoadingBody,
                minHeight: 220,
              )
            else if (loadFailure != null && state.catalogTests.isEmpty)
              AppFormInformationBanner.failure(
                context: context,
                failure: loadFailure,
              )
            else
              _buildTestsTable(
                context,
                tests,
                isLoadingCatalog: isLoadingCatalog,
                isMutating: state.isMutating,
              ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: showCatalogLoadingPanel
              ? null
              : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTestsTable(
    BuildContext context,
    List<RadiologyCatalogProcedure> tests, {
    required bool isLoadingCatalog,
    required bool isMutating,
  }) {
    final bool tableBusy = isLoadingCatalog || isMutating;
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(bottom: theme.spacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: theme.spacing.xs,
                  runSpacing: theme.spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (_selectedOfferingIds.isNotEmpty)
                      AppTabToolbarAction(
                        label: l10n.radiologyDeleteSelectedOfferingsAction,
                        icon: Icons.delete_outline,
                        tooltip: l10n.radiologyDeleteSelectedOfferingsAction,
                        enabled: !tableBusy,
                        onPressed: tableBusy
                            ? null
                            : () => _openDeleteSelectedOfferingsDialog(
                                context,
                                tests,
                              ),
                      ),
                    AppTabToolbarAction(
                      label: l10n.commonRefreshActionLabel,
                      icon: Icons.refresh_outlined,
                      tooltip: l10n.commonRefreshActionLabel,
                      enabled: !tableBusy,
                      onPressed: tableBusy
                          ? null
                          : () => _refreshConfigurations(context),
                    ),
                  ],
                ),
              ),
              if (_canEnableOfferings)
                AppTabToolbarPrimary(
                  label: l10n.radiologyEnableProcedureAction,
                  icon: Icons.add_circle_outline,
                  tooltip: l10n.radiologyEnableProcedureAction,
                  enabled: !tableBusy,
                  onPressed: tableBusy
                      ? null
                      : () => _openEnableProcedureDialog(context),
                ),
            ],
          ),
        ),
        AppListTable<RadiologyCatalogProcedure>(
          items: tests,
          isLoading: tableBusy,
          maxVisibleItems: _maxVisibleItems,
          maxTrailingActions: 3,
          trailingActionsOverflowLabel: l10n.workspaceToolbarOverflowLabel,
          shrinkWrap: true,
          columnVisibilityController: _testColumnController,
          columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
          columnVisibilityTitle: l10n.commonTableSettingsTitle,
          columnVisibilityStorageKey: 'radiology_catalog_tests',
          columnWidthStorageKey: 'radiology_catalog_cw_tests',
          columnVisibilityApplyLabel: l10n.radiologyApplyColumnsAction,
          columnVisibilityResetLabel: l10n.radiologyResetColumnsAction,
          onRowSelected: (RadiologyCatalogProcedure item) {
            unawaited(_openEditOfferingDialog(context, item));
          },
          search: AppListTableSearch<RadiologyCatalogProcedure>(
            controller: _searchController,
            semanticLabel: l10n.radiologyConfigurationSearchLabel,
            hintText: l10n.radiologyConfigurationSearchHint,
            matcher: (RadiologyCatalogProcedure item, String query) =>
                item.matchesSearch(query),
            onChanged: (_) => setState(() {}),
            showAdvancedFilterButton: true,
            advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
            advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
            advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
            advancedFilterResetLabel: l10n.radiologyClearFiltersAction,
            enableDateFilter: false,
            allFieldsLabel: l10n.labScopeAll,
            filterGroups: <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: _modalityFilterKey,
                label: l10n.radiologyModalityLabel,
                allLabel: l10n.labScopeAll,
                choices: _modalityFilterChoices(tests),
              ),
            ],
            filterValue: _filterValue,
            onFilterChanged: (AppSearchBarFilterValue value) {
              setState(() => _filterValue = value);
            },
          ),
          emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
            title: l10n.radiologyNoProceduresTitle,
            body: l10n.radiologyEnableOfferingNoItemsLabel,
            icon: Icons.image_search_outlined,
            minHeight: 180,
          ),
          columns: <AppListTableColumn<RadiologyCatalogProcedure>>[
            AppListTableColumn<RadiologyCatalogProcedure>(
              id: 'name',
              label: l10n.radiologyProcedureNameLabel,
              sortComparator:
                  (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
                      appListTableCompareText(left.name, right.name),
              cellBuilder: (BuildContext context, RadiologyCatalogProcedure item) {
                final ThemeData theme = Theme.of(context);
                return AppListItemRow(
                  title: item.name,
                  subtitle: item.code,
                  leadingIcon: _radiologyModalityIcon(item.modality),
                  padding: EdgeInsets.zero,
                  titleStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                  ),
                );
              },
            ),
            AppListTableColumn<RadiologyCatalogProcedure>(
              id: 'code',
              label: l10n.radiologyProcedureCodeLabel,
              sortComparator:
                  (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
                      appListTableCompareText(left.code, right.code),
              cellBuilder: (_, RadiologyCatalogProcedure item) =>
                  Text(item.code ?? l10n.profileUnknownValue),
            ),
            AppListTableColumn<RadiologyCatalogProcedure>(
              id: 'modality',
              label: l10n.radiologyModalityLabel,
              sortComparator:
                  (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
                      appListTableCompareText(left.modality, right.modality),
              cellBuilder: (_, RadiologyCatalogProcedure item) =>
                  _ModalityLabel(modality: item.modality),
            ),
            AppListTableColumn<RadiologyCatalogProcedure>(
              id: 'price',
              label: l10n.clinicalRequestUnitPriceLabel,
              sortComparator:
                  (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
                      (left.unitPrice ?? 0).compareTo(right.unitPrice ?? 0),
              cellBuilder: (BuildContext context, RadiologyCatalogProcedure item) =>
                  Text(_formatRadiologyCatalogUnitPrice(context, item, l10n)),
            ),
            AppListTableColumn<RadiologyCatalogProcedure>(
              id: 'body_region',
              label: l10n.radiologyBodyRegionLabel,
              sortComparator:
                  (RadiologyCatalogProcedure left, RadiologyCatalogProcedure right) =>
                      appListTableCompareText(
                        left.bodyRegion,
                        right.bodyRegion,
                      ),
              cellBuilder: (_, RadiologyCatalogProcedure item) =>
                  Text(item.bodyRegion ?? l10n.profileUnknownValue),
            ),
          ],
          columnChoices: <AppListTableColumn<RadiologyCatalogProcedure>>[
            AppListTableColumn<RadiologyCatalogProcedure>(
              id: 'laterality',
              label: l10n.radiologyLateralityLabel,
              cellBuilder: (_, RadiologyCatalogProcedure item) =>
                  Text(item.laterality ?? l10n.profileUnknownValue),
            ),
          ],
          mobileItemBuilder: (BuildContext context, RadiologyCatalogProcedure item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppListTableMobileItem(
                  leading: Checkbox(
                    value: _selectedOfferingIds.contains(
                      _offeringSelectionKey(item),
                    ),
                    onChanged: tableBusy
                        ? null
                        : (bool? value) => _toggleOfferingSelection(
                            item,
                            selected: value ?? false,
                          ),
                    visualDensity: VisualDensity.compact,
                  ),
                  title: item.name,
                  caption: item.code,
                  meta: <AppListTableMobileMeta>[
                    AppListTableMobileMeta(
                      label: _joinDisplay(<String?>[
                        _modalityLabelOrNull(l10n, item.modality),
                        _formatRadiologyCatalogUnitPrice(context, item, l10n),
                      ]),
                      icon: Icons.biotech_outlined,
                    ),
                  ],
                  showAvatar: false,
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: theme.spacing.sm,
                    right: theme.spacing.sm,
                    bottom: theme.spacing.sm,
                  ),
                  child: _testActionButtons(context, item, tableBusy),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _testActionButtons(
    BuildContext context,
    RadiologyCatalogProcedure item,
    bool isBusy,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        AppButton(
          iconOnly: true,
          leadingIcon: Icons.edit_outlined,
          label: l10n.radiologyEditProcedureAction,
          semanticLabel: l10n.radiologyEditProcedureAction,
          tooltip: l10n.radiologyEditProcedureAction,
          onPressed: isBusy
              ? null
              : () => _openEditOfferingDialog(context, item),
        ),
        AppButton(
          iconOnly: true,
          leadingIcon: Icons.delete_outline,
          label: l10n.radiologyDeleteProcedureAction,
          semanticLabel: l10n.radiologyDeleteProcedureAction,
          tooltip: l10n.radiologyDeleteProcedureAction,
          color: colorScheme.error,
          onPressed: isBusy
              ? null
              : () => _openDeleteOfferingDialog(context, item),
        ),
      ],
    );
  }

  Future<void> _refreshConfigurations(BuildContext context) async {
    final AppFailure? failure = await ref
        .read(radiologyWorkspaceControllerProvider.notifier)
        .loadFacilityCatalogConfig(
          _catalogScope,
          search: _searchController.text.trim(),
        );
    if (context.mounted) {
      _showFailureIfNeeded(context, failure);
    }
  }

  Future<void> _openEnableProcedureDialog(BuildContext context) async {
    final RadiologyWorkspaceController controller = ref.read(
      radiologyWorkspaceControllerProvider.notifier,
    );
    final RadiologyCatalogScope scope = _catalogScope;
    final AppLocalizations l10n = context.l10n;
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEnableFacilityOfferingDialog(
        scope: scope,
        onSearchCatalog:
            ({
              required RadiologyCatalogScope scope,
              String? query,
              int limit = 100,
            }) {
              return controller.searchPlatformRadiologyCatalogForOffering(
                scope: scope,
                query: query,
                limit: limit,
              );
            },
        onEnable: (String id, Map<String, Object?> payload) =>
            controller.upsertRadiologyTestOffering(id, payload, scope: scope),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (saved == true) {
      await _reloadCatalogIfReady();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.radiologySaveConfigurationAction)),
      );
    }
  }

  Future<void> _openEditOfferingDialog(
    BuildContext context,
    RadiologyCatalogProcedure item,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkspaceController controller = ref.read(
      radiologyWorkspaceControllerProvider.notifier,
    );
    final bool? saved = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEditFacilityOfferingDialog(
        item: item,
        onUpdate: (String id, Map<String, Object?> payload) => controller
            .upsertRadiologyTestOffering(id, payload, scope: _catalogScope),
      ),
    );
    if (!context.mounted || saved != true) {
      return;
    }
    await _reloadCatalogIfReady();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.radiologySaveConfigurationAction)),
    );
  }

  Future<void> _openDeleteOfferingDialog(
    BuildContext context,
    RadiologyCatalogProcedure test,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkspaceController controller = ref.read(
      radiologyWorkspaceControllerProvider.notifier,
    );
    final bool? deleted = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabDeleteReasonDialog(
        title: l10n.radiologyDisableOfferingDialogTitle,
        body: l10n.radiologyDisableOfferingDialogBody(test.name),
        submitLabel: l10n.radiologyDeleteProcedureAction,
        destructiveSubmit: true,
        onDelete: (String reason) => controller.disableRadiologyTestOffering(
          test.apiId,
          reason,
          scope: _catalogScope,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (deleted == true) {
      setState(() {
        _selectedOfferingIds.remove(_offeringSelectionKey(test));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.radiologyOfferingDisabledMessage)),
      );
    }
  }

  Future<void> _openDeleteSelectedOfferingsDialog(
    BuildContext context,
    List<RadiologyCatalogProcedure> visibleTests,
  ) async {
    if (_selectedOfferingIds.isEmpty) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkspaceController controller = ref.read(
      radiologyWorkspaceControllerProvider.notifier,
    );
    final List<String> selectedIds = visibleTests
        .where(
          (RadiologyCatalogProcedure item) =>
              _selectedOfferingIds.contains(_offeringSelectionKey(item)),
        )
        .map((RadiologyCatalogProcedure item) => item.apiId)
        .toList(growable: false);
    if (selectedIds.isEmpty) {
      return;
    }
    final bool? deleted = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LabDeleteReasonDialog(
        title: l10n.radiologyDeleteSelectedOfferingsDialogTitle,
        body: l10n.radiologyDeleteSelectedOfferingsDialogBody(
          selectedIds.length,
        ),
        submitLabel: l10n.radiologyDeleteSelectedOfferingsAction,
        destructiveSubmit: true,
        onDelete: (String reason) => controller.disableRadiologyTestOfferings(
          selectedIds,
          reason,
          scope: _catalogScope,
        ),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (deleted == true) {
      setState(() => _selectedOfferingIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.radiologyOfferingDisabledMessage)),
      );
    }
  }

  String _offeringSelectionKey(RadiologyCatalogProcedure item) => item.apiId;

  void _toggleOfferingSelection(
    RadiologyCatalogProcedure item, {
    required bool selected,
  }) {
    final String key = _offeringSelectionKey(item);
    setState(() {
      if (selected) {
        _selectedOfferingIds.add(key);
      } else {
        _selectedOfferingIds.remove(key);
      }
    });
  }

  void _pruneOfferingSelection(List<RadiologyCatalogProcedure> catalogTests) {
    final Set<String> validKeys = catalogTests
        .map(_offeringSelectionKey)
        .toSet();
    _selectedOfferingIds.removeWhere((String key) => !validKeys.contains(key));
  }

  RadiologyWorkspaceState? _stateFromAsync(
    AsyncValue<Result<RadiologyWorkspaceState>> value,
  ) {
    return value.asData?.value.when(
      success: (RadiologyWorkspaceState state) => state,
      failure: (_) => null,
    );
  }

  bool _shouldSyncCatalogState(
    RadiologyWorkspaceState current,
    RadiologyWorkspaceState next,
  ) {
    return current.catalogTests != next.catalogTests ||
        current.catalogScope != next.catalogScope ||
        current.isMutating != next.isMutating ||
        current.isLoadingCatalog != next.isLoadingCatalog ||
        current.catalogLoadFailure != next.catalogLoadFailure;
  }

  String? _facilityLabel(List<HomeLookupOption> facilityOptions) {
    if (_facilityId == null || _facilityId!.trim().isEmpty) {
      return null;
    }
    for (final HomeLookupOption option in facilityOptions) {
      if (option.id == _facilityId) {
        return option.label;
      }
    }
    return null;
  }

  String? _tenantLabel(List<HomeLookupOption> tenantOptions) {
    if (_tenantId == null || _tenantId!.trim().isEmpty) {
      return null;
    }
    for (final HomeLookupOption option in tenantOptions) {
      if (option.id == _tenantId) {
        return option.label;
      }
    }
    return null;
  }

  List<HomeLookupOption> _facilityOptionsForScope({
    required AsyncValue<Result<HomeDashboardLookups>>? lookupsAsync,
    required bool hasTenant,
  }) {
    if (_showTenantSelector && !hasTenant) {
      return const <HomeLookupOption>[];
    }
    return lookupsAsync?.value?.when(
          success: (HomeDashboardLookups value) =>
              value.facilitiesForTenant(_tenantId),
          failure: (_) => const <HomeLookupOption>[],
        ) ??
        const <HomeLookupOption>[];
  }

  String _scopePromptMessage(
    AppLocalizations l10n, {
    required String? tenantLabel,
  }) {
    final bool hasTenant = _tenantId?.trim().isNotEmpty ?? false;
    final bool hasFacility = _facilityId?.trim().isNotEmpty ?? false;
    if (hasTenant && !hasFacility) {
      return l10n.radiologyConfigurationsSelectFacilityOnlyBody(
        tenantLabel ?? l10n.profileUnknownValue,
      );
    }
    return l10n.radiologyConfigurationsSelectScopeBody;
  }

  List<AppSearchBarFilterChoice> _modalityFilterChoices(
    List<RadiologyCatalogProcedure> items,
  ) {
    final Set<String> values = <String>{};
    for (final RadiologyCatalogProcedure item in items) {
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

String _formatRadiologyCatalogUnitPrice(
  BuildContext context,
  RadiologyCatalogProcedure item,
  AppLocalizations l10n,
) {
  final num? price = item.unitPrice;
  if (price == null) {
    return l10n.clinicalRequestPriceNotSetLabel;
  }
  return AppFormatters.currency(
    price.toDouble(),
    Localizations.localeOf(context),
    currencyCode: item.currency,
  );
}

Future<void> _showAssignDialog(BuildContext context, WidgetRef ref) async {
  final Map<String, Object?>? payload =
      await showAppDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => const _AssignForm(),
      );
  if (payload == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(radiologyWorkspaceControllerProvider.notifier)
      .assignOrder(payload);
  if (context.mounted) {
    _showMutationResult(context, failure);
  }
}
