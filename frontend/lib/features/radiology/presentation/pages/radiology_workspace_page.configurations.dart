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
  late final AppListTableColumnVisibilityController<RadiologyCatalogTest>
  _testColumnController;
  late RadiologyWorkspaceState _dialogState;
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  String? _tenantId;
  String? _facilityId;
  bool _initializedScope = false;

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
        AppListTableColumnVisibilityController<RadiologyCatalogTest>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        setState(() => _dialogState = nextState);
      },
    );
    final RadiologyWorkspaceState state = _dialogState;
    final String query = _searchController.text;
    final List<RadiologyCatalogTest> tests = state.catalogTests
        .where((RadiologyCatalogTest test) => test.matchesSearch(query))
        .where((RadiologyCatalogTest test) {
          final String? modality = _filterValue.option(_modalityFilterKey);
          if (modality != null && test.modality != modality) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    final bool scopeReady = _catalogScope.isReady;
    final bool isBusy =
        state.isMutating ||
        (scopeReady && (!_initializedScope || state.isLoadingCatalog));
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
          Text(
            l10n.radiologyConfigurationsDialogBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
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
            if (isBusy)
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
              _buildTestsTable(context, tests, isBusy),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCloseActionLabel,
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTestsTable(
    BuildContext context,
    List<RadiologyCatalogTest> tests,
    bool isBusy,
  ) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return AppListTable<RadiologyCatalogTest>(
      items: tests,
      isLoading: isBusy,
      maxVisibleItems: _maxVisibleItems,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      columnVisibilityController: _testColumnController,
      columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
      columnVisibilityTitle: l10n.radiologyTableColumnsTitle,
      columnVisibilityApplyLabel: l10n.radiologyApplyColumnsAction,
      columnVisibilityResetLabel: l10n.radiologyResetColumnsAction,
      search: AppListTableSearch<RadiologyCatalogTest>(
        controller: _searchController,
        semanticLabel: l10n.radiologyConfigurationSearchLabel,
        hintText: l10n.radiologyConfigurationSearchHint,
        matcher: (RadiologyCatalogTest item, String query) =>
            item.matchesSearch(query),
        onChanged: (_) => setState(() {}),
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
            choices: _modalityFilterChoices(tests),
          ),
        ],
        filterValue: _filterValue,
        onFilterChanged: (AppSearchBarFilterValue value) {
          setState(() => _filterValue = value);
        },
        trailingActions: <AppSearchBarAction>[
          if (_canEnableOfferings)
            AppSearchBarAction(
              icon: Icons.add_circle_outline,
              label: l10n.radiologyEnableProcedureAction,
              tooltip: l10n.radiologyEnableProcedureAction,
              enabled: !isBusy,
              onPressed: isBusy ? null : () => _openEnableProcedureDialog(context),
            ),
          AppSearchBarAction(
            icon: Icons.refresh_outlined,
            label: l10n.commonRefreshActionLabel,
            tooltip: l10n.commonRefreshActionLabel,
            enabled: !isBusy,
            onPressed: isBusy ? null : () => _refreshConfigurations(context),
          ),
        ],
      ),
      emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
        title: l10n.radiologyNoImagingTestsTitle,
        body: l10n.radiologyEnableOfferingNoItemsLabel,
        icon: Icons.image_search_outlined,
        minHeight: 180,
      ),
      columns: <AppListTableColumn<RadiologyCatalogTest>>[
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'name',
          label: l10n.radiologyTestNameLabel,
          sortComparator:
              (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                  appListTableCompareText(left.name, right.name),
          cellBuilder: (_, RadiologyCatalogTest item) => _IconTwoLineCell(
            icon: _radiologyModalityIcon(item.modality),
            title: item.name,
            subtitle: _joinDisplay(<String?>[item.effectiveId, item.code]),
          ),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'code',
          label: l10n.radiologyTestCodeLabel,
          sortComparator:
              (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                  appListTableCompareText(left.code, right.code),
          cellBuilder: (_, RadiologyCatalogTest item) =>
              Text(item.code ?? l10n.profileUnknownValue),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'modality',
          label: l10n.radiologyModalityLabel,
          sortComparator:
              (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                  appListTableCompareText(left.modality, right.modality),
          cellBuilder: (_, RadiologyCatalogTest item) =>
              _ModalityLabel(modality: item.modality),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'price',
          label: l10n.clinicalRequestUnitPriceLabel,
          sortComparator:
              (RadiologyCatalogTest left, RadiologyCatalogTest right) =>
                  (left.unitPrice ?? 0).compareTo(right.unitPrice ?? 0),
          cellBuilder: (BuildContext context, RadiologyCatalogTest item) =>
              Text(_formatRadiologyCatalogUnitPrice(context, item, l10n)),
        ),
        _testActionsColumn(context, isBusy),
      ],
      columnChoices: <AppListTableColumn<RadiologyCatalogTest>>[
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'body_region',
          label: l10n.radiologyBodyRegionLabel,
          cellBuilder: (_, RadiologyCatalogTest item) =>
              Text(item.bodyRegion ?? l10n.profileUnknownValue),
        ),
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'laterality',
          label: l10n.radiologyLateralityLabel,
          cellBuilder: (_, RadiologyCatalogTest item) =>
              Text(item.laterality ?? l10n.profileUnknownValue),
        ),
      ],
      mobileItemBuilder: (BuildContext context, RadiologyCatalogTest item) {
        return Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _IconTwoLineCell(
                icon: _radiologyModalityIcon(item.modality),
                title: item.name,
                subtitle: _joinDisplay(<String?>[
                  item.code,
                  _modalityLabelOrNull(l10n, item.modality),
                  _formatRadiologyCatalogUnitPrice(context, item, l10n),
                ]),
              ),
              SizedBox(height: theme.spacing.xs),
              _testActionButtons(context, item, isBusy),
            ],
          ),
        );
      },
    );
  }

  AppListTableColumn<RadiologyCatalogTest> _testActionsColumn(
    BuildContext context,
    bool isBusy,
  ) {
    final AppLocalizations l10n = context.l10n;
    return AppListTableColumn<RadiologyCatalogTest>(
      id: 'actions',
      label: l10n.radiologyActionColumnLabel,
      alwaysVisible: true,
      cellBuilder: (BuildContext context, RadiologyCatalogTest item) {
        return _testActionButtons(context, item, isBusy);
      },
    );
  }

  Widget _testActionButtons(
    BuildContext context,
    RadiologyCatalogTest item,
    bool isBusy,
  ) {
    final AppLocalizations l10n = context.l10n;
    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        AppButton(
          iconOnly: true,
          leadingIcon: Icons.edit_outlined,
          label: l10n.radiologyEditImagingTestAction,
          semanticLabel: l10n.radiologyEditImagingTestAction,
          tooltip: l10n.radiologyEditImagingTestAction,
          onPressed: isBusy
              ? null
              : () => _openEditOfferingDialog(context, item),
        ),
        AppButton(
          iconOnly: true,
          leadingIcon: Icons.delete_outline,
          label: l10n.radiologyDeleteImagingTestAction,
          semanticLabel: l10n.radiologyDeleteImagingTestAction,
          tooltip: l10n.radiologyDeleteImagingTestAction,
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
        .loadFacilityCatalogConfig(_catalogScope, search: _searchController.text.trim());
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.radiologySaveConfigurationAction)),
      );
      await _reloadCatalogIfReady();
    }
  }

  Future<void> _openEditOfferingDialog(
    BuildContext context,
    RadiologyCatalogTest item,
  ) async {
    final RadiologyWorkspaceController controller = ref.read(
      radiologyWorkspaceControllerProvider.notifier,
    );
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RadiologyEditFacilityOfferingDialog(
        item: item,
        onUpdate: (String id, Map<String, Object?> payload) =>
            controller.upsertRadiologyTestOffering(
              id,
              payload,
              scope: _catalogScope,
            ),
      ),
    );
  }

  Future<void> _openDeleteOfferingDialog(
    BuildContext context,
    RadiologyCatalogTest test,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final RadiologyWorkspaceController controller = ref.read(
      radiologyWorkspaceControllerProvider.notifier,
    );
    await showAppDialog<bool>(
      context: context,
      builder: (_) => LabDeleteReasonDialog(
        title: l10n.radiologyDeleteImagingTestDialogTitle,
        body: l10n.radiologyDeleteImagingTestDialogBody(test.name),
        submitLabel: l10n.radiologyDeleteImagingTestAction,
        onDelete: (String reason) =>
            controller.disableRadiologyTestOffering(test.apiId, reason),
      ),
    );
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

String _formatRadiologyCatalogUnitPrice(
  BuildContext context,
  RadiologyCatalogTest item,
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
