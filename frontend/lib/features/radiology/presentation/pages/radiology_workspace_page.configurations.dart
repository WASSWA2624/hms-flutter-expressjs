part of 'radiology_workspace_page.dart';

class _RadiologyConfigurationsDialog extends ConsumerStatefulWidget {
  const _RadiologyConfigurationsDialog({this.tenantId});

  final String? tenantId;

  @override
  ConsumerState<_RadiologyConfigurationsDialog> createState() =>
      _RadiologyConfigurationsDialogState();
}

class _RadiologyConfigurationsDialogState
    extends ConsumerState<_RadiologyConfigurationsDialog> {
  static const int _maxVisibleItems = 140;

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<RadiologyCatalogTest>
  _testColumnController =
      AppListTableColumnVisibilityController<RadiologyCatalogTest>();
  RadiologyWorkspaceState? _dialogState;

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
    final AsyncValue<Result<RadiologyWorkspaceState>> asyncState = ref.watch(
      radiologyWorkspaceControllerProvider,
    );
    final RadiologyWorkspaceState? latest = _stateFromAsync(asyncState);
    if (latest != null && _configurationStateChanged(_dialogState, latest)) {
      _dialogState = latest;
    }
    final RadiologyWorkspaceState? state = _dialogState ?? latest;
    final String query = _searchController.text;
    final List<RadiologyCatalogTest> tests = state == null
        ? const <RadiologyCatalogTest>[]
        : state.catalogTests
              .where((RadiologyCatalogTest test) => test.matchesSearch(query))
              .toList(growable: false);
    final bool isBusy = state?.isMutating == true || asyncState.isLoading;

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
          if (state == null && asyncState.isLoading)
            AppWorkspaceStatePanel.loading(
              title: l10n.radiologyConfigurationsLoadingTitle,
              body: l10n.radiologyConfigurationsLoadingBody,
              minHeight: 220,
            )
          else
            _buildTestsTable(context, tests, isBusy),
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
      columnVisibilityCancelLabel: l10n.commonCancelActionLabel,
      search: AppListTableSearch<RadiologyCatalogTest>(
        controller: _searchController,
        semanticLabel: l10n.radiologyConfigurationSearchLabel,
        hintText: l10n.radiologyConfigurationSearchHint,
        matcher: (RadiologyCatalogTest item, String query) =>
            item.matchesSearch(query),
        onChanged: (_) => setState(() {}),
        trailingActions: <AppSearchBarAction>[
          AppSearchBarAction(
            icon: Icons.add_circle_outline,
            label: l10n.radiologyCreateImagingTestAction,
            tooltip: l10n.radiologyCreateImagingTestAction,
            enabled: !isBusy,
            onPressed: isBusy
                ? null
                : () => _openRadiologyTestConfigurationDialog(
                    context,
                    tenantId: widget.tenantId,
                  ),
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
        body: l10n.radiologyNoImagingTestsBody,
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
            subtitle: _joinDisplay(<String?>[
              item.effectiveId,
              item.isStandard
                  ? l10n.radiologyStandardCatalogBadge
                  : l10n.radiologyCustomCatalogBadge,
            ]),
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
        _testActionsColumn(context, isBusy),
      ],
      columnChoices: <AppListTableColumn<RadiologyCatalogTest>>[
        AppListTableColumn<RadiologyCatalogTest>(
          id: 'source',
          label: l10n.radiologySourceColumnLabel,
          cellBuilder: (_, RadiologyCatalogTest item) => Text(
            item.isStandard
                ? l10n.radiologyStandardCatalogBadge
                : l10n.radiologyCustomCatalogBadge,
          ),
        ),
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
                  item.isStandard
                      ? l10n.radiologyStandardCatalogBadge
                      : l10n.radiologyCustomCatalogBadge,
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
        if (item.isStandard)
          AppButton(iconOnly: true, 
            leadingIcon: Icons.copy_outlined,
            label: l10n.radiologyCopyStandardTestAction,

            semanticLabel: l10n.radiologyCopyStandardTestAction,
            tooltip: l10n.radiologyCopyStandardTestAction,
            onPressed: isBusy
                ? null
                : () => _openRadiologyTestConfigurationDialog(
                    context,
                    initial: item,
                    copyStandard: true,
                    tenantId: widget.tenantId,
                  ),
          )
        else ...<Widget>[
          AppButton(iconOnly: true, 
            leadingIcon: Icons.edit_outlined,
            label: l10n.radiologyEditImagingTestAction,

            semanticLabel: l10n.radiologyEditImagingTestAction,
            tooltip: l10n.radiologyEditImagingTestAction,
            onPressed: isBusy
                ? null
                : () => _openRadiologyTestConfigurationDialog(
                    context,
                    initial: item,
                    tenantId: widget.tenantId,
                  ),
          ),
          AppButton(iconOnly: true, 
            leadingIcon: Icons.delete_outline,
            label: l10n.radiologyDeleteImagingTestAction,

            semanticLabel: l10n.radiologyDeleteImagingTestAction,
            tooltip: l10n.radiologyDeleteImagingTestAction,
            onPressed: isBusy
                ? null
                : () => _openDeleteRadiologyTestDialog(context, item),
          ),
        ],
      ],
    );
  }

  Future<void> _refreshConfigurations(BuildContext context) async {
    final AppFailure? failure = await ref
        .read(radiologyWorkspaceControllerProvider.notifier)
        .refreshConfigurations(search: _searchController.text.trim());
    if (context.mounted) {
      _showFailureIfNeeded(context, failure);
    }
  }

  Future<void> _openRadiologyTestConfigurationDialog(
    BuildContext context, {
    RadiologyCatalogTest? initial,
    bool copyStandard = false,
    String? tenantId,
  }) async {
    await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RadiologyTestConfigurationDialog(
        initial: initial,
        copyStandard: copyStandard,
        tenantId: tenantId,
      ),
    );
  }

  Future<void> _openDeleteRadiologyTestDialog(
    BuildContext context,
    RadiologyCatalogTest test,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (_) => AppDialog(
        title: Text(l10n.radiologyDeleteImagingTestDialogTitle),
        icon: const Icon(Icons.delete_outline),
        content: Text(l10n.radiologyDeleteImagingTestDialogBody(test.name)),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          AppButton.primary(
            label: l10n.radiologyDeleteImagingTestAction,
            leadingIcon: Icons.delete_outline,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final AppFailure? failure = await ref
        .read(radiologyWorkspaceControllerProvider.notifier)
        .deleteRadiologyTest(test.id);
    if (context.mounted) {
      _showMutationResult(context, failure);
    }
  }

  RadiologyWorkspaceState? _stateFromAsync(
    AsyncValue<Result<RadiologyWorkspaceState>> value,
  ) {
    return value.asData?.value.when(
      success: (RadiologyWorkspaceState state) => state,
      failure: (_) => null,
    );
  }

  bool _configurationStateChanged(
    RadiologyWorkspaceState? current,
    RadiologyWorkspaceState next,
  ) {
    return current == null ||
        current.catalogTests != next.catalogTests ||
        current.isMutating != next.isMutating ||
        current.isRefreshing != next.isRefreshing;
  }
}

class _RadiologyTestConfigurationDialog extends ConsumerStatefulWidget {
  const _RadiologyTestConfigurationDialog({
    this.initial,
    this.copyStandard = false,
    this.tenantId,
  });

  final RadiologyCatalogTest? initial;
  final bool copyStandard;
  final String? tenantId;

  @override
  ConsumerState<_RadiologyTestConfigurationDialog> createState() =>
      _RadiologyTestConfigurationDialogState();
}

class _RadiologyTestConfigurationDialogState
    extends ConsumerState<_RadiologyTestConfigurationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late String _modality;
  AppFailure? _failure;
  bool _isSaving = false;

  bool get _isCreate => widget.initial == null || widget.copyStandard;

  @override
  void initState() {
    super.initState();
    final RadiologyCatalogTest? initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _codeController = TextEditingController(
      text: widget.copyStandard ? '' : initial?.code ?? '',
    );
    final String normalized = (initial?.modality ?? 'XRAY')
        .trim()
        .toUpperCase();
    _modality = radiologyModalities.contains(normalized) ? normalized : 'OTHER';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canSubmit =
        !_isSaving && (!_isCreate || widget.tenantId != null);
    return AppDialog(
      title: Text(
        _isCreate
            ? l10n.radiologyCreateImagingTestAction
            : l10n.radiologyEditImagingTestAction,
      ),
      icon: const Icon(Icons.image_search_outlined),
      scrollable: true,
      maxWidth: 560,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.initial?.isStandard == true && widget.copyStandard)
              AppWorkspaceStatePanel.empty(
                title: l10n.radiologyReadOnlyStandardTestTitle,
                body: l10n.radiologyReadOnlyStandardTestMessage,
                icon: Icons.lock_outline,
                minHeight: 96,
              ),
            if (_isCreate && widget.tenantId == null)
              Text(
                l10n.radiologyTenantRequiredForConfigMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (_failure != null) AppFailureStateView(failure: _failure!),
          ],
        ),
        children: <Widget>[
          AppTextField(
            controller: _nameController,
            labelText: l10n.radiologyTestNameLabel,
            isRequired: true,
            validator: AppValidators.requiredText(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyTestNameLabel),
            ),
          ),
          AppTextField(
            controller: _codeController,
            labelText: l10n.radiologyTestCodeOptionalLabel,
          ),
          AppSelectField<String>(
            value: _modality,
            labelText: l10n.radiologyModalityLabel,
            isRequired: true,
            options: <AppSelectOption<String>>[
              for (final String modality in radiologyModalities)
                AppSelectOption<String>(
                  value: modality,
                  label: _modalityLabel(l10n, modality),
                  leadingIcon: Icon(_radiologyModalityIcon(modality)),
                ),
            ],
            validator: AppValidators.requiredValue(
              l10n.radiologyFieldRequiredLabel(l10n.radiologyModalityLabel),
            ),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _modality = value);
              }
            },
          ),
        ],
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
          enabled: canSubmit,
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(validateAndSaveAppForm(_formKey))) {
      return;
    }
    if (_isCreate && widget.tenantId == null) {
      setState(() {
        _failure = AppFailure.validation();
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final Map<String, Object?> payload = <String, Object?>{
      if (_isCreate) 'tenant_id': widget.tenantId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim(),
      'modality': _modality,
    };
    final AppFailure? failure = _isCreate
        ? await ref
              .read(radiologyWorkspaceControllerProvider.notifier)
              .createRadiologyTest(payload)
        : await ref
              .read(radiologyWorkspaceControllerProvider.notifier)
              .updateRadiologyTest(widget.initial!.id, payload);
    if (failure == null) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }
    if (mounted) {
      setState(() {
        _failure = failure;
        _isSaving = false;
      });
    }
  }
}

Future<void> _showAssignDialog(BuildContext context, WidgetRef ref) async {
  final AppLocalizations l10n = context.l10n;
  final Map<String, Object?>? payload = await showAppWorkspaceActionDialog(
    context: context,
    title: Text(l10n.radiologyAssignDialogTitle),
    content: const _AssignForm(),
    icon: const Icon(Icons.person_add_alt_outlined),
    maxWidth: 520,
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
