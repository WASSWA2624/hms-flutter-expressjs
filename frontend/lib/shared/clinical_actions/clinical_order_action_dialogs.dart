import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_dialogs.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class ClinicalDiagnosisActionDialog extends StatefulWidget {
  const ClinicalDiagnosisActionDialog({
    required this.onSearchClinicalTerms,
    required this.onSubmit,
    super.key,
  });

  final Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
  })
  onSearchClinicalTerms;
  final Future<AppFailure?> Function({
    required String diagnosisType,
    required String description,
    String? code,
  })
  onSubmit;

  @override
  State<ClinicalDiagnosisActionDialog> createState() => _DiagnosisDialogState();
}

class _DiagnosisDialogState extends State<ClinicalDiagnosisActionDialog> {
  static const int _lookupMinLength = 2;
  static const Duration _lookupDebounceDuration = Duration(milliseconds: 350);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _termController;
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  Timer? _termLookupDebounce;
  Timer? _codeLookupDebounce;
  String _diagnosisType = 'PRIMARY';
  List<ClinicalActionCatalogOption> _termOptions =
      const <ClinicalActionCatalogOption>[];
  List<ClinicalActionCatalogOption> _codeOptions =
      const <ClinicalActionCatalogOption>[];
  _DiagnosisLookupTarget? _activeLookup;
  bool _isSaving = false;
  bool _isTermSearching = false;
  bool _isCodeSearching = false;
  bool _termHasText = false;
  bool _codeHasText = false;
  int _termLookupRequest = 0;
  int _codeLookupRequest = 0;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _termController = TextEditingController();
    _codeController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _termLookupDebounce?.cancel();
    _codeLookupDebounce?.cancel();
    _termController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.clinicalAddDiagnosisAction),
      icon: const Icon(Icons.rule_outlined),
      scrollable: true,
      maxWidth: 760,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          title: l10n.clinicalDiagnosisFormTitle,
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppSelectField<String>(
              value: _diagnosisType,
              labelText: l10n.opdDiagnosisTypeLabel,
              enabled: !_isSaving,
              isRequired: true,
              options: _statusOptions(_diagnosisTypes),
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _diagnosisType = value);
                }
              },
            ),
            _DiagnosisLookupField(
              controller: _termController,
              labelText: l10n.clinicalTermSearchLabel,
              clearLabel: MaterialLocalizations.of(context).clearButtonTooltip,
              options: _activeLookup == _DiagnosisLookupTarget.term
                  ? _termOptions
                  : const <ClinicalActionCatalogOption>[],
              isLoading:
                  _activeLookup == _DiagnosisLookupTarget.term &&
                  _isTermSearching,
              hasText: _termHasText,
              enabled: !_isSaving,
              onChanged: _handleTermLookupChanged,
              onClear: _clearTermLookup,
              onFocusChanged: (bool hasFocus) =>
                  _setActiveLookup(_DiagnosisLookupTarget.term, hasFocus),
              onSelected: _applyTerm,
              titleBuilder: _diagnosisTermLabel,
              subtitleBuilder: _diagnosisTermSubtitle,
            ),
            _DiagnosisLookupField(
              controller: _codeController,
              labelText: l10n.opdDiagnosisCodeLabel,
              clearLabel: MaterialLocalizations.of(context).clearButtonTooltip,
              options: _activeLookup == _DiagnosisLookupTarget.code
                  ? _codeOptions
                  : const <ClinicalActionCatalogOption>[],
              isLoading:
                  _activeLookup == _DiagnosisLookupTarget.code &&
                  _isCodeSearching,
              hasText: _codeHasText,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.characters,
              onChanged: _handleCodeLookupChanged,
              onClear: _clearCodeLookup,
              onFocusChanged: (bool hasFocus) =>
                  _setActiveLookup(_DiagnosisLookupTarget.code, hasFocus),
              onSelected: _applyCodeTerm,
              titleBuilder: _diagnosisCodeLabel,
              subtitleBuilder: _diagnosisCodeSubtitle,
            ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.opdDiagnosisLabel,
              prefixIcon: const Icon(Icons.medical_information_outlined),
              maxLines: 4,
              enabled: !_isSaving,
              isRequired: true,
              textCapitalization: TextCapitalization.sentences,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.clinicalAddDiagnosisAction,
        _isSaving,
        _submit,
      ),
    );
  }

  void _handleTermLookupChanged(String value) {
    final String query = value.trim();
    final bool hasText = query.isNotEmpty;
    if (_activeLookup != _DiagnosisLookupTarget.term ||
        _termHasText != hasText) {
      setState(() {
        _activeLookup = _DiagnosisLookupTarget.term;
        _termHasText = hasText;
      });
    }
    _scheduleTermLookup(query);
  }

  void _handleCodeLookupChanged(String value) {
    final String query = value.trim();
    final bool hasText = query.isNotEmpty;
    if (_activeLookup != _DiagnosisLookupTarget.code ||
        _codeHasText != hasText) {
      setState(() {
        _activeLookup = _DiagnosisLookupTarget.code;
        _codeHasText = hasText;
      });
    }
    _scheduleCodeLookup(query);
  }

  void _setActiveLookup(_DiagnosisLookupTarget target, bool hasFocus) {
    if (!hasFocus || _activeLookup == target) {
      return;
    }
    setState(() => _activeLookup = target);
  }

  void _scheduleTermLookup(String query) {
    _termLookupDebounce?.cancel();
    _termLookupRequest += 1;
    final int requestId = _termLookupRequest;
    if (query.length < _lookupMinLength) {
      if (_termOptions.isNotEmpty || _isTermSearching) {
        setState(() {
          _termOptions = const <ClinicalActionCatalogOption>[];
          _isTermSearching = false;
        });
      }
      return;
    }
    _termLookupDebounce = Timer(
      _lookupDebounceDuration,
      () => _loadTermLookup(query, requestId),
    );
  }

  void _scheduleCodeLookup(String query) {
    _codeLookupDebounce?.cancel();
    _codeLookupRequest += 1;
    final int requestId = _codeLookupRequest;
    if (query.length < _lookupMinLength) {
      if (_codeOptions.isNotEmpty || _isCodeSearching) {
        setState(() {
          _codeOptions = const <ClinicalActionCatalogOption>[];
          _isCodeSearching = false;
        });
      }
      return;
    }
    _codeLookupDebounce = Timer(
      _lookupDebounceDuration,
      () => _loadCodeLookup(query, requestId),
    );
  }

  Future<void> _loadTermLookup(String query, int requestId) async {
    if (!mounted || requestId != _termLookupRequest) {
      return;
    }
    setState(() {
      _termOptions = const <ClinicalActionCatalogOption>[];
      _isTermSearching = true;
    });
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchClinicalTerms(termType: 'DIAGNOSIS', query: query);
    if (!mounted || requestId != _termLookupRequest) {
      return;
    }
    setState(() {
      _termOptions = result.when(
        success: (List<ClinicalActionCatalogOption> value) => value,
        failure: (_) => const <ClinicalActionCatalogOption>[],
      );
      _isTermSearching = false;
    });
  }

  Future<void> _loadCodeLookup(String query, int requestId) async {
    if (!mounted || requestId != _codeLookupRequest) {
      return;
    }
    setState(() {
      _codeOptions = const <ClinicalActionCatalogOption>[];
      _isCodeSearching = true;
    });
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchClinicalTerms(termType: 'DIAGNOSIS', query: query);
    if (!mounted || requestId != _codeLookupRequest) {
      return;
    }
    setState(() {
      _codeOptions = result.when(
        success: (List<ClinicalActionCatalogOption> value) => value
            .where(
              (ClinicalActionCatalogOption option) =>
                  _trimmedOrNull(option.code) != null,
            )
            .toList(growable: false),
        failure: (_) => const <ClinicalActionCatalogOption>[],
      );
      _isCodeSearching = false;
    });
  }

  void _applyTerm(ClinicalActionCatalogOption term) {
    setState(() {
      _termController.text = _diagnosisTermLabel(term);
      _termHasText = true;
      _codeOptions = _mergeCatalogOption(_codeOptions, term);
      _codeController.text = term.code ?? '';
      _codeHasText = _trimmedOrNull(term.code) != null;
      _descriptionController.text = term.name ?? '';
      _termOptions = const <ClinicalActionCatalogOption>[];
      _isTermSearching = false;
      _activeLookup = null;
    });
  }

  void _applyCodeTerm(ClinicalActionCatalogOption term) {
    setState(() {
      _termOptions = _mergeCatalogOption(_termOptions, term);
      _termController.text = _diagnosisTermLabel(term);
      _termHasText = true;
      _codeController.text = term.code ?? '';
      _codeHasText = _trimmedOrNull(term.code) != null;
      _descriptionController.text = term.name ?? '';
      _codeOptions = const <ClinicalActionCatalogOption>[];
      _isCodeSearching = false;
      _activeLookup = null;
    });
  }

  void _clearTermLookup() {
    _termLookupDebounce?.cancel();
    _termLookupRequest += 1;
    setState(() {
      _termController.clear();
      _termHasText = false;
      _termOptions = const <ClinicalActionCatalogOption>[];
      _isTermSearching = false;
      if (_activeLookup == _DiagnosisLookupTarget.term) {
        _activeLookup = null;
      }
    });
  }

  void _clearCodeLookup() {
    _codeLookupDebounce?.cancel();
    _codeLookupRequest += 1;
    setState(() {
      _codeController.clear();
      _codeHasText = false;
      _codeOptions = const <ClinicalActionCatalogOption>[];
      _isCodeSearching = false;
      if (_activeLookup == _DiagnosisLookupTarget.code) {
        _activeLookup = null;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      diagnosisType: _diagnosisType,
      code: _codeController.text.trim(),
      description: _descriptionController.text.trim(),
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

enum _DiagnosisLookupTarget { term, code }

class _DiagnosisLookupField extends StatelessWidget {
  const _DiagnosisLookupField({
    required this.controller,
    required this.labelText,
    required this.clearLabel,
    required this.options,
    required this.hasText,
    required this.isLoading,
    required this.enabled,
    required this.onChanged,
    required this.onClear,
    required this.onFocusChanged,
    required this.onSelected,
    required this.titleBuilder,
    required this.subtitleBuilder,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String labelText;
  final String clearLabel;
  final List<ClinicalActionCatalogOption> options;
  final bool hasText;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<bool> onFocusChanged;
  final ValueChanged<ClinicalActionCatalogOption> onSelected;
  final String Function(ClinicalActionCatalogOption option) titleBuilder;
  final String Function(ClinicalActionCatalogOption option) subtitleBuilder;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    final bool showResults = isLoading || options.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          controller: controller,
          labelText: labelText,
          enabled: enabled,
          textCapitalization: textCapitalization,
          suffixIcon: _buildClearButton(context),
          onChanged: onChanged,
          onFocusChanged: onFocusChanged,
        ),
        if (showResults) ...<Widget>[
          SizedBox(height: spacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: options.isEmpty
                  ? SizedBox(
                      height: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: theme.appTokens.listIconSize,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final ClinicalActionCatalogOption option =
                            options[index];
                        return _DiagnosisLookupResult(
                          title: titleBuilder(option),
                          subtitle: subtitleBuilder(option),
                          enabled: enabled,
                          onSelected: () => onSelected(option),
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildClearButton(BuildContext context) {
    if (!enabled || !hasText) {
      return null;
    }
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: Center(
        child: TextButton(
          onPressed: onClear,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: theme.spacing.xs),
            minimumSize: const Size(72, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(clearLabel, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _DiagnosisLookupResult extends StatelessWidget {
  const _DiagnosisLookupResult({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onSelected,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSpacingTokens spacing = theme.spacing;
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: enabled ? onSelected : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty) ...<Widget>[
                SizedBox(height: spacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ClinicalProcedureActionDialog extends StatefulWidget {
  const ClinicalProcedureActionDialog({
    required this.onSearchClinicalTerms,
    required this.onSubmit,
    super.key,
  });

  final Future<Result<List<ClinicalActionCatalogOption>>> Function({
    required String termType,
    String? query,
    int? limit,
  })
  onSearchClinicalTerms;
  final Future<AppFailure?> Function({
    required List<ClinicalActionCatalogOption> procedures,
    DateTime? performedAt,
  })
  onSubmit;

  @override
  State<ClinicalProcedureActionDialog> createState() => _ProcedureDialogState();
}

class _ProcedureDialogState extends State<ClinicalProcedureActionDialog> {
  static const int _searchLimit = 80;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 160);
  static const double _menuHeight = 360;

  Timer? _searchDebounce;
  int _searchRequest = 0;
  List<ClinicalActionCatalogOption> _catalogOptions =
      const <ClinicalActionCatalogOption>[];
  final List<ClinicalActionCatalogOption> _selectedProcedures =
      <ClinicalActionCatalogOption>[];
  ClinicalActionCatalogOption? _activeProcedure;
  bool _isSearching = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _searchRequest += 1;
    unawaited(_loadProcedureCatalog('', _searchRequest));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalActionCatalogOption> options = _catalogWithActive();
    final ClinicalActionCatalogOption? activeProcedure = _activeProcedure;
    final String? activeProcedureKey = activeProcedure == null
        ? null
        : _procedureDedupKey(activeProcedure);
    final bool activeAlreadySelected =
        activeProcedureKey != null &&
        _selectedProcedures.any(
          (ClinicalActionCatalogOption item) =>
              _procedureDedupKey(item) == activeProcedureKey,
        );
    final bool canAddSelection =
        activeProcedure != null && !_isSaving && !activeAlreadySelected;
    return AppDialog(
      title: Text(l10n.clinicalRequestProcedureAction),
      icon: const Icon(Icons.healing_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 760,
      content: AppFormSection(
        title: l10n.clinicalProcedureSelectedTitle,
        density: AppFormSectionDensity.spacious,
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.manage_search_outlined,
                    color: colorScheme.primary,
                    size: theme.appTokens.listIconSize,
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Text(
                      l10n.clinicalProcedureDialogHelp,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppResponsiveFieldRow(
            gap: AppResponsiveFieldRowGap.form,
            children: <Widget>[
              AppSelectField<String>.searchable(
                value: _activeProcedure?.apiId,
                labelText: l10n.clinicalProcedureSearchLabel,
                hintText: l10n.clinicalProcedureSearchHint,
                enabled: !_isSaving,
                menuHeight: _menuHeight,
                options: _procedureNameOptions(options),
                onSearchTextChanged: _scheduleProcedureSearch,
                onChanged: _selectProcedureByApiId,
              ),
              AppSelectField<String>.searchable(
                value: _activeProcedure?.apiId,
                labelText: l10n.opdProcedureCodeLabel,
                hintText: l10n.clinicalProcedureCodeSearchHint,
                enabled: !_isSaving,
                menuHeight: _menuHeight,
                options: _procedureCodeOptions(options),
                onSearchTextChanged: _scheduleProcedureSearch,
                onChanged: _selectProcedureByApiId,
              ),
            ],
          ),
          if (_isSearching) const LinearProgressIndicator(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.secondary(
              label: l10n.clinicalLabRequestAddSelectionAction,
              leadingIcon: Icons.add,
              enabled: canAddSelection,
              onPressed: _addActiveProcedure,
            ),
          ),
          _ProcedureSelectedPanel(
            procedures: _selectedProcedures,
            isSaving: _isSaving,
            onDelete: _removeProcedure,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.clinicalRequestProcedureAction,
          isLoading: _isSaving,
          enabled: _selectedProcedures.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  List<AppSelectOption<String>> _procedureNameOptions(
    List<ClinicalActionCatalogOption> options,
  ) {
    return <AppSelectOption<String>>[
      for (final ClinicalActionCatalogOption option in options)
        AppSelectOption<String>(
          value: option.apiId,
          label: _procedureTitle(option),
          labelWidget: _ProcedureOptionLabel(
            title: _procedureTitle(option),
            subtitle: _procedureSubtitle(option),
          ),
          leadingIcon: const Icon(Icons.healing_outlined),
        ),
    ];
  }

  List<AppSelectOption<String>> _procedureCodeOptions(
    List<ClinicalActionCatalogOption> options,
  ) {
    return <AppSelectOption<String>>[
      for (final ClinicalActionCatalogOption option in options)
        AppSelectOption<String>(
          value: option.apiId,
          label: _procedureCodeLabel(option),
          labelWidget: _ProcedureOptionLabel(
            title: _procedureCodeLabel(option),
            subtitle: _joinDisplay(<String?>[
              _procedureTitle(option),
              option.displaySubtitle,
            ]),
          ),
          leadingIcon: const Icon(Icons.tag_outlined),
        ),
    ];
  }

  void _scheduleProcedureSearch(String value) {
    final String query = value.trim();
    _searchDebounce?.cancel();
    _searchRequest += 1;
    final int requestId = _searchRequest;
    _searchDebounce = Timer(
      _searchDebounceDuration,
      () => _loadProcedureCatalog(query, requestId),
    );
  }

  Future<void> _loadProcedureCatalog(String query, int requestId) async {
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() => _isSearching = true);
    final Result<List<ClinicalActionCatalogOption>> result = await widget
        .onSearchClinicalTerms(
          termType: 'PROCEDURE',
          query: query,
          limit: _searchLimit,
        );
    if (!mounted || requestId != _searchRequest) {
      return;
    }
    setState(() {
      _catalogOptions = result.when(
        success: _dedupeProcedureOptions,
        failure: (_) => const <ClinicalActionCatalogOption>[],
      );
      _failure = result.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      _isSearching = false;
    });
  }

  void _selectProcedureByApiId(String? value) {
    if (value == null) {
      setState(() {
        _activeProcedure = null;
        _failure = null;
      });
      return;
    }

    final ClinicalActionCatalogOption? procedure = _findProcedure(value);
    if (procedure == null) {
      return;
    }
    setState(() {
      _activeProcedure = procedure;
      _catalogOptions = _mergeCatalogOption(_catalogOptions, procedure);
      _failure = null;
    });
  }

  ClinicalActionCatalogOption? _findProcedure(String apiId) {
    for (final ClinicalActionCatalogOption option in _catalogWithActive()) {
      if (option.apiId == apiId) {
        return option;
      }
    }
    return null;
  }

  List<ClinicalActionCatalogOption> _catalogWithActive() {
    final ClinicalActionCatalogOption? active = _activeProcedure;
    if (active == null) {
      return _catalogOptions;
    }
    return _mergeCatalogOption(_catalogOptions, active);
  }

  void _addActiveProcedure() {
    final ClinicalActionCatalogOption? procedure = _activeProcedure;
    if (procedure == null) {
      return;
    }
    if (_selectedProcedures.any(
      (ClinicalActionCatalogOption item) =>
          _procedureDedupKey(item) == _procedureDedupKey(procedure),
    )) {
      setState(() {
        _activeProcedure = null;
        _failure = null;
      });
      return;
    }

    setState(() {
      _selectedProcedures.add(procedure);
      _activeProcedure = null;
      _failure = null;
    });
  }

  void _removeProcedure(int index) {
    if (index < 0 || index >= _selectedProcedures.length) {
      return;
    }
    setState(() {
      _selectedProcedures.removeAt(index);
      _failure = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedProcedures.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(
      procedures: List<ClinicalActionCatalogOption>.unmodifiable(
        _selectedProcedures,
      ),
      performedAt: DateTime.now(),
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

class _ProcedureOptionLabel extends StatelessWidget {
  const _ProcedureOptionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ProcedureSelectedPanel extends StatelessWidget {
  const _ProcedureSelectedPanel({
    required this.procedures,
    required this.isSaving,
    required this.onDelete,
  });

  final List<ClinicalActionCatalogOption> procedures;
  final bool isSaving;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.clinicalProcedureSelectedTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  l10n.clinicalProcedureSelectedCount(procedures.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: procedures.isEmpty
                ? SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(l10n.clinicalProcedureNoSelection),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: procedures.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _ProcedureSelectedRow(
                        procedure: procedures[index],
                        isSaving: isSaving,
                        onDelete: () => onDelete(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProcedureSelectedRow extends StatelessWidget {
  const _ProcedureSelectedRow({
    required this.procedure,
    required this.isSaving,
    required this.onDelete,
  });

  final ClinicalActionCatalogOption procedure;
  final bool isSaving;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String subtitle = _joinDisplay(<String?>[
      _trimmedOrNull(procedure.code),
      procedure.displaySubtitle,
    ]);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.healing_outlined,
            color: colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _procedureTitle(procedure),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.clinicalLabRequestDeleteSelectionAction,
            onPressed: isSaving ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class ClinicalLabOrderActionDialog extends StatefulWidget {
  const ClinicalLabOrderActionDialog({
    required this.referenceData,
    required this.onRequest,
    required this.onUpdate,
    this.existingOrder,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final ClinicalActionLabOrderRecord? existingOrder;
  final Future<AppFailure?> Function({
    required List<String> labTestIds,
    required List<String> labPanelIds,
  })
  onRequest;
  final Future<AppFailure?> Function({
    required String labOrderId,
    required List<String> labTestIds,
    required List<String> labPanelIds,
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

final class _LabCatalogSearchResults {
  const _LabCatalogSearchResults({
    required this.options,
    required this.totalMatches,
  });

  final List<ClinicalActionCatalogOption> options;
  final int totalMatches;
}

class _LabOrderDialogState extends State<ClinicalLabOrderActionDialog> {
  static const int _maxVisibleCatalogOptions = 80;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 120);

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  _LabRequestSelectionKind _selectionKind = _LabRequestSelectionKind.tests;
  String _searchQuery = '';
  final List<_PendingLabRequest> _requests = <_PendingLabRequest>[];
  int? _editingIndex;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _requests.addAll(_initialRequests());
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
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.64)
        .clamp(420.0, 620.0)
        .toDouble();
    final List<ClinicalActionCatalogOption> catalog = _catalogForSelection();
    final _LabCatalogSearchResults searchResults = _searchCatalog(catalog);
    final bool isEditingOrder = widget.existingOrder != null;
    return AppDialog(
      title: Text(
        isEditingOrder
            ? l10n.clinicalUpdateLabOrderAction
            : l10n.clinicalRequestLabAction,
      ),
      icon: const Icon(Icons.science_outlined),
      maxWidth: 920,
      closeEnabled: !_isSaving,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            SegmentedButton<_LabRequestSelectionKind>(
              segments: <ButtonSegment<_LabRequestSelectionKind>>[
                ButtonSegment<_LabRequestSelectionKind>(
                  value: _LabRequestSelectionKind.tests,
                  icon: const Icon(Icons.science_outlined),
                  label: Text(l10n.clinicalLabRequestTestsModeLabel),
                ),
                ButtonSegment<_LabRequestSelectionKind>(
                  value: _LabRequestSelectionKind.panels,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(l10n.clinicalLabRequestPanelsModeLabel),
                ),
              ],
              selected: <_LabRequestSelectionKind>{_selectionKind},
              onSelectionChanged: _isSaving
                  ? null
                  : (Set<_LabRequestSelectionKind> values) {
                      setState(() {
                        _selectionKind = values.first;
                        _failure = null;
                      });
                    },
            ),
            SizedBox(height: theme.spacing.md),
            AppTextField(
              controller: _searchController,
              labelText: l10n.clinicalLabRequestSearchLabel,
              hintText: l10n.clinicalLabRequestSearchHint,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : AppIconButton(
                      icon: Icons.close,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      onPressed: _isSaving ? null : _clearSearch,
                    ),
              onChanged: _scheduleSearch,
            ),
            if (_editingIndex != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.tertiary(
                  label: l10n.clinicalLabRequestCancelEditAction,
                  leadingIcon: Icons.close,
                  enabled: !_isSaving,
                  onPressed: _cancelEdit,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool twoColumns = constraints.maxWidth >= 760;
                  final Widget catalogPanel = _LabCatalogResultsPanel(
                    results: searchResults,
                    kind: _selectionKind,
                    isSaving: _isSaving,
                    isEditing: _editingIndex != null,
                    onSelected: _addOrUpdateRequest,
                    isDuplicate: _isDuplicateSelection,
                  );
                  final Widget selectedPanel = _LabSelectedRequestsPanel(
                    requests: _requests,
                    editingIndex: _editingIndex,
                    isSaving: _isSaving,
                    onEdit: _editRequest,
                    onDelete: _deleteRequest,
                  );

                  if (!twoColumns) {
                    return Column(
                      children: <Widget>[
                        Expanded(child: catalogPanel),
                        SizedBox(height: theme.spacing.md),
                        Expanded(child: selectedPanel),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: catalogPanel),
                      SizedBox(width: theme.spacing.md),
                      Expanded(child: selectedPanel),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: isEditingOrder
              ? l10n.clinicalUpdateLabOrderAction
              : l10n.clinicalRequestLabAction,
          isLoading: _isSaving,
          enabled: _requests.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
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
        .map(_normalizedCatalogToken)
        .where((String value) => value.isNotEmpty)
        .toSet();
    final Set<String> panelChildCodes = inferredPanels
        .expand((ClinicalActionCatalogOption panel) => panel.childCodes)
        .map(_normalizedCatalogToken)
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
                _hasText(item.labTestId) &&
                !panelChildIds.contains(
                  _normalizedCatalogToken(item.labTestId!),
                ) &&
                !panelChildCodes.contains(
                  _normalizedCatalogToken(item.testCode ?? ''),
                ),
          )
          .map((ClinicalActionLabOrderItem item) {
            final ClinicalActionCatalogOption option =
                _catalogOptionForLabOrderItem(item);
            return _PendingLabRequest(
              kind: _LabRequestSelectionKind.tests,
              option: option,
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

  List<ClinicalActionCatalogOption> _catalogForSelection() {
    return switch (_selectionKind) {
      _LabRequestSelectionKind.tests => widget.referenceData.labTests,
      _LabRequestSelectionKind.panels => widget.referenceData.labPanels,
    };
  }

  _LabCatalogSearchResults _searchCatalog(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return _LabCatalogSearchResults(
        options: catalog
            .take(_maxVisibleCatalogOptions)
            .toList(growable: false),
        totalMatches: catalog.length,
      );
    }

    final List<ClinicalActionCatalogOption> visible =
        <ClinicalActionCatalogOption>[];
    var totalMatches = 0;
    for (final ClinicalActionCatalogOption option in catalog) {
      final String searchText = _catalogSearchText(option);
      final bool isMatch = tokens.every(searchText.contains);
      if (!isMatch) {
        continue;
      }
      totalMatches += 1;
      if (visible.length < _maxVisibleCatalogOptions) {
        visible.add(option);
      }
    }

    return _LabCatalogSearchResults(
      options: visible,
      totalMatches: totalMatches,
    );
  }

  String _catalogSearchText(ClinicalActionCatalogOption option) {
    return _joinDisplay(<String?>[
      option.apiId,
      option.displayTitle,
      option.displaySubtitle,
      option.name,
      option.code,
      option.category,
      option.secondaryText,
      option.status,
    ]).toLowerCase();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    setState(_resetSearch);
  }

  void _resetSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
  }

  void _addOrUpdateRequest(ClinicalActionCatalogOption option) {
    final int? editingIndex = _editingIndex;
    final _PendingLabRequest request = _PendingLabRequest(
      kind: _selectionKind,
      option: option,
    );
    setState(() {
      _failure = null;
      if (editingIndex != null &&
          editingIndex >= 0 &&
          editingIndex < _requests.length) {
        _requests[editingIndex] = request;
        _editingIndex = null;
        _resetSearch();
        return;
      }
      _requests.add(request);
    });
  }

  void _editRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    final _PendingLabRequest request = _requests[index];
    setState(() {
      _selectionKind = request.kind;
      _editingIndex = index;
      _failure = null;
      _searchController.text = request.option.displayTitle;
      _searchQuery = request.option.displayTitle;
    });
  }

  void _deleteRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    setState(() {
      _requests.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _resetSearch();
      } else if (_editingIndex case final int editingIndex
          when editingIndex > index) {
        _editingIndex = editingIndex - 1;
      }
      _failure = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _failure = null;
      _resetSearch();
    });
  }

  bool _isDuplicateSelection(ClinicalActionCatalogOption option) {
    final int? editingIndex = _editingIndex;
    for (var index = 0; index < _requests.length; index += 1) {
      if (index == editingIndex) {
        continue;
      }
      final _PendingLabRequest request = _requests[index];
      if (request.kind == _selectionKind && request.id == option.apiId) {
        return true;
      }
    }
    return false;
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
          )
        : await widget.onUpdate(
            labOrderId: existingOrder.id,
            labTestIds: labTestIds,
            labPanelIds: labPanelIds,
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

class _LabCatalogResultsPanel extends StatelessWidget {
  const _LabCatalogResultsPanel({
    required this.results,
    required this.kind,
    required this.isSaving,
    required this.isEditing,
    required this.onSelected,
    required this.isDuplicate,
  });

  final _LabCatalogSearchResults results;
  final _LabRequestSelectionKind kind;
  final bool isSaving;
  final bool isEditing;
  final ValueChanged<ClinicalActionCatalogOption> onSelected;
  final bool Function(ClinicalActionCatalogOption option) isDuplicate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalActionCatalogOption> options = results.options;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Text(
              l10n.clinicalLabRequestMatchesLabel(
                options.length,
                results.totalMatches,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: options.isEmpty
                ? Center(child: Text(l10n.clinicalLabRequestNoCatalogOptions))
                : ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      final ClinicalActionCatalogOption option = options[index];
                      final bool duplicate = isDuplicate(option);
                      return _LabCatalogOptionRow(
                        option: option,
                        kind: kind,
                        isSaving: isSaving,
                        isEditing: isEditing,
                        isDuplicate: duplicate,
                        onSelected: duplicate ? null : () => onSelected(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LabCatalogOptionRow extends StatelessWidget {
  const _LabCatalogOptionRow({
    required this.option,
    required this.kind,
    required this.isSaving,
    required this.isEditing,
    required this.isDuplicate,
    required this.onSelected,
  });

  final ClinicalActionCatalogOption option;
  final _LabRequestSelectionKind kind;
  final bool isSaving;
  final bool isEditing;
  final bool isDuplicate;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String actionLabel = isEditing
        ? l10n.clinicalLabRequestUpdateSelectionAction
        : l10n.clinicalLabRequestAddSelectionAction;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            kind == _LabRequestSelectionKind.tests
                ? Icons.science_outlined
                : Icons.inventory_2_outlined,
            color: colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  option.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (option.displaySubtitle != null)
                  Text(
                    option.displaySubtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isSaving || isDuplicate ? null : onSelected,
            icon: Icon(
              isEditing ? Icons.done_outlined : Icons.add,
              size: theme.appTokens.listIconSize,
            ),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _LabSelectedRequestsPanel extends StatelessWidget {
  const _LabSelectedRequestsPanel({
    required this.requests,
    required this.editingIndex,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_PendingLabRequest> requests;
  final int? editingIndex;
  final bool isSaving;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.clinicalLabRequestSelectedTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  l10n.clinicalLabRequestSelectedCount(requests.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: requests.isEmpty
                ? Center(child: Text(l10n.clinicalLabRequestNoSelection))
                : ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _LabSelectedRequestRow(
                        request: requests[index],
                        isEditing: editingIndex == index,
                        isSaving: isSaving,
                        onEdit: () => onEdit(index),
                        onDelete: () => onDelete(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LabSelectedRequestRow extends StatelessWidget {
  const _LabSelectedRequestRow({
    required this.request,
    required this.isEditing,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final _PendingLabRequest request;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String typeLabel = _labRequestTypeLabel(l10n, request.kind);
    final String subtitle = _joinDisplay(<String?>[
      typeLabel,
      request.option.displaySubtitle,
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEditing
            ? colorScheme.primaryContainer.withValues(alpha: 0.38)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              request.kind == _LabRequestSelectionKind.tests
                  ? Icons.science_outlined
                  : Icons.inventory_2_outlined,
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    request.option.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.clinicalLabRequestEditSelectionAction,
              onPressed: isSaving ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: l10n.clinicalLabRequestDeleteSelectionAction,
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
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

class ClinicalRadiologyOrderActionDialog extends StatefulWidget {
  const ClinicalRadiologyOrderActionDialog({
    required this.referenceData,
    required this.onSubmit,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final Future<AppFailure?> Function({
    required List<ClinicalActionRadiologyRequest> requests,
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
  });

  final ClinicalActionCatalogOption option;
  final String? clinicalNote;
  final String? bodyRegion;
  final String? laterality;
  final String? priority;

  String get id => option.apiId;
}

final class _RadiologyCatalogSearchResults {
  const _RadiologyCatalogSearchResults({
    required this.options,
    required this.totalMatches,
  });

  final List<ClinicalActionCatalogOption> options;
  final int totalMatches;
}

class _RadiologyOrderDialogState
    extends State<ClinicalRadiologyOrderActionDialog> {
  static const int _maxVisibleCatalogOptions = 100;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 120);

  late final TextEditingController _searchController;
  late final TextEditingController _noteController;
  late final TextEditingController _bodyRegionController;
  Timer? _searchDebounce;
  String _searchQuery = '';
  String? _laterality;
  String? _priority;
  final List<_PendingRadiologyRequest> _requests = <_PendingRadiologyRequest>[];
  int? _editingIndex;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _noteController = TextEditingController();
    _bodyRegionController = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _noteController.dispose();
    _bodyRegionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final double bodyHeight = (MediaQuery.sizeOf(context).height * 0.68)
        .clamp(460.0, 680.0)
        .toDouble();
    final _RadiologyCatalogSearchResults searchResults = _searchCatalog(
      widget.referenceData.radiologyTests,
    );
    return AppDialog(
      title: Text(l10n.clinicalRequestRadiologyAction),
      icon: const Icon(Icons.biotech_outlined),
      maxWidth: 980,
      closeEnabled: !_isSaving,
      content: SizedBox(
        height: bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            AppTextField(
              controller: _searchController,
              labelText: l10n.clinicalRadiologyRequestSearchLabel,
              hintText: l10n.clinicalRadiologyRequestSearchHint,
              enabled: !_isSaving,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : AppIconButton(
                      icon: Icons.close,
                      semanticLabel: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).clearButtonTooltip,
                      onPressed: _isSaving ? null : _clearSearch,
                    ),
              onChanged: _scheduleSearch,
            ),
            SizedBox(height: theme.spacing.md),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 720;
                final List<Widget> fields = <Widget>[
                  AppSelectField<String>(
                    value: _priority,
                    labelText: l10n.clinicalRadiologyPriorityLabel,
                    enabled: !_isSaving,
                    options: _statusOptions(const <String>[
                      'ROUTINE',
                      'URGENT',
                      'STAT',
                    ]),
                    onChanged: (String? value) {
                      setState(() => _priority = value);
                    },
                  ),
                  AppSelectField<String>(
                    value: _laterality,
                    labelText: l10n.clinicalRadiologyLateralityLabel,
                    enabled: !_isSaving,
                    options: _statusOptions(const <String>[
                      'LEFT',
                      'RIGHT',
                      'BILATERAL',
                      'MIDLINE',
                      'NOT_APPLICABLE',
                    ]),
                    onChanged: (String? value) {
                      setState(() => _laterality = value);
                    },
                  ),
                  AppTextField(
                    controller: _bodyRegionController,
                    labelText: l10n.clinicalRadiologyBodyRegionLabel,
                    enabled: !_isSaving,
                  ),
                ];

                if (compact) {
                  return Column(
                    children: <Widget>[
                      for (final Widget field in fields) ...<Widget>[
                        field,
                        SizedBox(height: theme.spacing.sm),
                      ],
                    ],
                  );
                }

                return Row(
                  children: <Widget>[
                    for (
                      var index = 0;
                      index < fields.length;
                      index += 1
                    ) ...<Widget>[
                      Expanded(child: fields[index]),
                      if (index < fields.length - 1)
                        SizedBox(width: theme.spacing.sm),
                    ],
                  ],
                );
              },
            ),
            SizedBox(height: theme.spacing.sm),
            AppTextField(
              controller: _noteController,
              labelText: l10n.opdClinicalNoteLabel,
              enabled: !_isSaving,
              maxLines: 2,
            ),
            if (_editingIndex != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.tertiary(
                  label: l10n.clinicalRadiologyCancelEditAction,
                  leadingIcon: Icons.close,
                  enabled: !_isSaving,
                  onPressed: _cancelEdit,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool twoColumns = constraints.maxWidth >= 760;
                  final Widget catalogPanel = _RadiologyCatalogResultsPanel(
                    results: searchResults,
                    isSaving: _isSaving,
                    isEditing: _editingIndex != null,
                    onSelected: _addOrUpdateRequest,
                    isDuplicate: _isDuplicateSelection,
                  );
                  final Widget selectedPanel = _RadiologySelectedRequestsPanel(
                    requests: _requests,
                    editingIndex: _editingIndex,
                    isSaving: _isSaving,
                    onEdit: _editRequest,
                    onDelete: _deleteRequest,
                  );

                  if (!twoColumns) {
                    return Column(
                      children: <Widget>[
                        Expanded(child: catalogPanel),
                        SizedBox(height: theme.spacing.md),
                        Expanded(child: selectedPanel),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(child: catalogPanel),
                      SizedBox(width: theme.spacing.md),
                      Expanded(child: selectedPanel),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.clinicalRequestRadiologyAction,
          isLoading: _isSaving,
          enabled: _requests.isNotEmpty,
          onPressed: _submit,
        ),
      ],
    );
  }

  _RadiologyCatalogSearchResults _searchCatalog(
    List<ClinicalActionCatalogOption> catalog,
  ) {
    final List<String> tokens = _searchQuery
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return _RadiologyCatalogSearchResults(
        options: catalog
            .take(_maxVisibleCatalogOptions)
            .toList(growable: false),
        totalMatches: catalog.length,
      );
    }

    final List<ClinicalActionCatalogOption> visible =
        <ClinicalActionCatalogOption>[];
    var totalMatches = 0;
    for (final ClinicalActionCatalogOption option in catalog) {
      final String searchText = _catalogSearchText(option);
      final bool isMatch = tokens.every(searchText.contains);
      if (!isMatch) {
        continue;
      }
      totalMatches += 1;
      if (visible.length < _maxVisibleCatalogOptions) {
        visible.add(option);
      }
    }

    return _RadiologyCatalogSearchResults(
      options: visible,
      totalMatches: totalMatches,
    );
  }

  String _catalogSearchText(ClinicalActionCatalogOption option) {
    return _joinDisplay(<String?>[
      option.apiId,
      option.displayTitle,
      option.displaySubtitle,
      option.name,
      option.code,
      option.category,
      option.secondaryText,
      option.status,
      option.searchText,
    ]).toLowerCase();
  }

  void _scheduleSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    setState(_resetSearch);
  }

  void _resetSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchQuery = '';
  }

  void _addOrUpdateRequest(ClinicalActionCatalogOption option) {
    final int? editingIndex = _editingIndex;
    final _PendingRadiologyRequest request = _PendingRadiologyRequest(
      option: option,
      clinicalNote: _trimmedOrNull(_noteController.text),
      bodyRegion: _trimmedOrNull(_bodyRegionController.text),
      laterality: _laterality,
      priority: _priority,
    );

    setState(() {
      _failure = null;
      if (editingIndex != null &&
          editingIndex >= 0 &&
          editingIndex < _requests.length) {
        _requests[editingIndex] = request;
        _editingIndex = null;
        _resetSearch();
        _resetRequestDetails();
        return;
      }
      _requests.add(request);
      _resetRequestDetails();
    });
  }

  void _editRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    final _PendingRadiologyRequest request = _requests[index];
    setState(() {
      _editingIndex = index;
      _failure = null;
      _searchController.text = request.option.displayTitle;
      _searchQuery = request.option.displayTitle;
      _noteController.text = request.clinicalNote ?? '';
      _bodyRegionController.text = request.bodyRegion ?? '';
      _laterality = request.laterality;
      _priority = request.priority;
    });
  }

  void _deleteRequest(int index) {
    if (index < 0 || index >= _requests.length) {
      return;
    }
    setState(() {
      _requests.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _resetSearch();
        _resetRequestDetails();
      } else if (_editingIndex case final int editingIndex
          when editingIndex > index) {
        _editingIndex = editingIndex - 1;
      }
      _failure = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _failure = null;
      _resetSearch();
      _resetRequestDetails();
    });
  }

  void _resetRequestDetails() {
    _noteController.clear();
    _bodyRegionController.clear();
    _laterality = null;
    _priority = null;
  }

  bool _isDuplicateSelection(ClinicalActionCatalogOption option) {
    final int? editingIndex = _editingIndex;
    for (var index = 0; index < _requests.length; index += 1) {
      if (index == editingIndex) {
        continue;
      }
      if (_requests[index].id == option.apiId) {
        return true;
      }
    }
    return false;
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
          ),
      ],
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

class _RadiologyCatalogResultsPanel extends StatelessWidget {
  const _RadiologyCatalogResultsPanel({
    required this.results,
    required this.isSaving,
    required this.isEditing,
    required this.onSelected,
    required this.isDuplicate,
  });

  final _RadiologyCatalogSearchResults results;
  final bool isSaving;
  final bool isEditing;
  final ValueChanged<ClinicalActionCatalogOption> onSelected;
  final bool Function(ClinicalActionCatalogOption option) isDuplicate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<ClinicalActionCatalogOption> options = results.options;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Text(
              l10n.clinicalRadiologyRequestMatchesLabel(
                options.length,
                results.totalMatches,
              ),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: options.isEmpty
                ? Center(
                    child: Text(l10n.clinicalRadiologyRequestNoCatalogOptions),
                  )
                : ListView.separated(
                    itemCount: options.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      final ClinicalActionCatalogOption option = options[index];
                      final bool duplicate = isDuplicate(option);
                      return _RadiologyCatalogOptionRow(
                        option: option,
                        isSaving: isSaving,
                        isEditing: isEditing,
                        isDuplicate: duplicate,
                        onSelected: duplicate ? null : () => onSelected(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RadiologyCatalogOptionRow extends StatelessWidget {
  const _RadiologyCatalogOptionRow({
    required this.option,
    required this.isSaving,
    required this.isEditing,
    required this.isDuplicate,
    required this.onSelected,
  });

  final ClinicalActionCatalogOption option;
  final bool isSaving;
  final bool isEditing;
  final bool isDuplicate;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String actionLabel = isEditing
        ? l10n.clinicalRadiologyUpdateSelectionAction
        : l10n.clinicalRadiologyAddSelectionAction;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _radiologyCatalogIcon(option),
            color: colorScheme.primary,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  option.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (option.displaySubtitle != null)
                  Text(
                    option.displaySubtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: isSaving || isDuplicate ? null : onSelected,
            icon: Icon(
              isEditing ? Icons.done_outlined : Icons.add,
              size: theme.appTokens.listIconSize,
            ),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _RadiologySelectedRequestsPanel extends StatelessWidget {
  const _RadiologySelectedRequestsPanel({
    required this.requests,
    required this.editingIndex,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final List<_PendingRadiologyRequest> requests;
  final int? editingIndex;
  final bool isSaving;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.clinicalRadiologyRequestSelectedTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  l10n.clinicalRadiologyRequestSelectedCount(requests.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: requests.isEmpty
                ? Center(child: Text(l10n.clinicalRadiologyRequestNoSelection))
                : ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colorScheme.outlineVariant),
                    itemBuilder: (BuildContext context, int index) {
                      return _RadiologySelectedRequestRow(
                        request: requests[index],
                        isEditing: editingIndex == index,
                        isSaving: isSaving,
                        onEdit: () => onEdit(index),
                        onDelete: () => onDelete(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RadiologySelectedRequestRow extends StatelessWidget {
  const _RadiologySelectedRequestRow({
    required this.request,
    required this.isEditing,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final _PendingRadiologyRequest request;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String subtitle = _joinDisplay(<String?>[
      request.option.displaySubtitle,
      request.priority == null ? null : _apiLabel(request.priority!),
      request.laterality == null ? null : _apiLabel(request.laterality!),
      request.bodyRegion,
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isEditing
            ? colorScheme.primaryContainer.withValues(alpha: 0.38)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              _radiologyCatalogIcon(request.option),
              color: colorScheme.primary,
              size: theme.appTokens.listIconSize,
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    request.option.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_hasText(request.clinicalNote))
                    Text(
                      request.clinicalNote!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.clinicalRadiologyEditSelectionAction,
              onPressed: isSaving ? null : onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: l10n.clinicalRadiologyDeleteSelectionAction,
              onPressed: isSaving ? null : onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class ClinicalPrescriptionActionDialog extends StatefulWidget {
  const ClinicalPrescriptionActionDialog({
    required this.referenceData,
    required this.onSubmit,
    super.key,
  });

  final ClinicalActionReferenceData referenceData;
  final Future<AppFailure?> Function({
    required List<Map<String, Object?>> items,
  })
  onSubmit;

  @override
  State<ClinicalPrescriptionActionDialog> createState() =>
      _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<ClinicalPrescriptionActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<_PrescriptionLineFormState> _lines =
      <_PrescriptionLineFormState>[];
  int _nextLineId = 0;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _lines.add(_createLine());
  }

  @override
  void dispose() {
    for (final _PrescriptionLineFormState line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppSelectOption<String>> drugOptions = _drugCatalogOptions(
      widget.referenceData.drugs,
    );

    return AppDialog(
      title: Text(l10n.clinicalPrescribeAction),
      icon: const Icon(Icons.medication_outlined),
      maxWidth: 980,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            _PrescriptionIntroPanel(itemCount: _lines.length),
            for (var index = 0; index < _lines.length; index += 1)
              _buildLineCard(index, drugOptions),
            AppButton.secondary(
              label: l10n.clinicalPrescriptionAddMedicineAction,
              leadingIcon: Icons.add_circle_outline,
              enabled: !_isSaving,
              fullWidth: true,
              onPressed: _addLine,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: l10n.clinicalPrescribeAction,
          leadingIcon: Icons.send_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildLineCard(int index, List<AppSelectOption<String>> drugOptions) {
    final _PrescriptionLineFormState line = _lines[index];
    return _PrescriptionLineCard(
      key: ValueKey<int>(line.id),
      index: index,
      line: line,
      drugOptions: drugOptions,
      selectedDrugLabel: _catalogDisplayLabelById(
        widget.referenceData.drugs,
        line.drugId,
      ),
      enabled: !_isSaving,
      canRemove: !_isSaving && _lines.length > 1,
      onChanged: () => setState(() {}),
      onRemove: () => _removeLine(line),
    );
  }

  _PrescriptionLineFormState _createLine() {
    final _PrescriptionLineFormState line = _PrescriptionLineFormState(
      id: _nextLineId,
    );
    _nextLineId += 1;
    return line;
  }

  void _addLine() {
    setState(() {
      _lines.add(_createLine());
    });
  }

  void _removeLine(_PrescriptionLineFormState line) {
    if (_lines.length <= 1) {
      return;
    }
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final List<Map<String, Object?>> items = <Map<String, Object?>>[
      for (final _PrescriptionLineFormState line in _lines)
        _withoutEmptyValues(<String, Object?>{
          'drug_id': line.drugId,
          'quantity': int.tryParse(line.quantityController.text.trim()) ?? 1,
          'quantity_unit': line.quantityUnit,
          'dose_amount': num.tryParse(line.doseAmountController.text.trim()),
          'dose_unit': line.doseUnit,
          'route': line.route,
          'frequency': line.frequency,
          'duration_value': int.tryParse(line.durationController.text.trim()),
          'duration_unit': line.durationController.text.trim().isEmpty
              ? null
              : line.durationUnit,
          'instructions': line.instructionsController.text.trim(),
        }),
    ];

    final AppFailure? failure = await widget.onSubmit(items: items);
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

class _PrescriptionLineFormState {
  _PrescriptionLineFormState({required this.id})
    : quantityController = TextEditingController(text: '1'),
      doseAmountController = TextEditingController(),
      durationController = TextEditingController(),
      instructionsController = TextEditingController();

  final int id;
  final TextEditingController quantityController;
  final TextEditingController doseAmountController;
  final TextEditingController durationController;
  final TextEditingController instructionsController;
  String? drugId;
  String? quantityUnit;
  String? doseUnit;
  String? route = 'ORAL';
  String? frequency = 'BID';
  String? durationUnit = 'days';

  void dispose() {
    quantityController.dispose();
    doseAmountController.dispose();
    durationController.dispose();
    instructionsController.dispose();
  }
}

class _PrescriptionIntroPanel extends StatelessWidget {
  const _PrescriptionIntroPanel({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.36),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Icon(
                  Icons.medication_liquid_outlined,
                  color: colorScheme.onPrimary,
                  size: theme.appTokens.listIconSize,
                ),
              ),
            ),
            SizedBox(width: theme.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    l10n.clinicalPrescriptionHeaderTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    l10n.clinicalPrescriptionHeaderBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            _PrescriptionCountBadge(count: itemCount),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionCountBadge extends StatelessWidget {
  const _PrescriptionCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.format_list_numbered_outlined,
              size: theme.appTokens.listIconSize,
              color: colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.xs),
            Text(
              count.toString(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionLineCard extends StatelessWidget {
  const _PrescriptionLineCard({
    required this.index,
    required this.line,
    required this.drugOptions,
    required this.selectedDrugLabel,
    required this.enabled,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _PrescriptionLineFormState line;
  final List<AppSelectOption<String>> drugOptions;
  final String? selectedDrugLabel;
  final bool enabled;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            _PrescriptionLineHeader(
              index: index,
              selectedDrugLabel: selectedDrugLabel,
              canRemove: canRemove,
              onRemove: onRemove,
            ),
            AppSelectField<String>.searchable(
              value: line.drugId,
              labelText: l10n.clinicalPrescriptionDrugLabel,
              enabled: enabled,
              isRequired: true,
              options: drugOptions,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (String? value) {
                line.drugId = value;
                onChanged();
              },
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.quantityController,
                  labelText: l10n.opdDrugQuantityLabel,
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                  enabled: enabled,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  validator: (String? value) =>
                      _requiredPositiveIntegerValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.quantityUnit,
                  labelText: l10n.clinicalPrescriptionQuantityUnitLabel,
                  enabled: enabled,
                  options: _unitOptions(_quantityUnits),
                  onChanged: (String? value) {
                    line.quantityUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.doseAmountController,
                  labelText: l10n.clinicalDoseAmountLabel,
                  prefixIcon: const Icon(Icons.science_outlined),
                  enabled: enabled,
                  isRequired: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: _decimalFormatters,
                  validator: (String? value) =>
                      _requiredPositiveNumberValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.doseUnit,
                  labelText: l10n.clinicalDoseUnitLabel,
                  enabled: enabled,
                  options: _unitOptions(_doseUnits),
                  onChanged: (String? value) {
                    line.doseUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppSelectField<String>.searchable(
                  value: line.route,
                  labelText: l10n.opdMedicationRouteLabel,
                  enabled: enabled,
                  options: _medicationRouteOptions(),
                  onChanged: (String? value) {
                    line.route = value;
                    onChanged();
                  },
                ),
                AppSelectField<String>.searchable(
                  value: line.frequency,
                  labelText: l10n.opdFrequencyLabel,
                  enabled: enabled,
                  options: _medicationFrequencyOptions(),
                  onChanged: (String? value) {
                    line.frequency = value;
                    onChanged();
                  },
                ),
              ],
            ),
            _PrescriptionDurationField(
              line: line,
              enabled: enabled,
              onChanged: onChanged,
            ),
            AppTextField(
              controller: line.instructionsController,
              labelText: l10n.clinicalInstructionsLabel,
              prefixIcon: const Icon(Icons.notes_outlined),
              enabled: enabled,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionLineHeader extends StatelessWidget {
  const _PrescriptionLineHeader({
    required this.index,
    required this.selectedDrugLabel,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final String? selectedDrugLabel;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String fallback = l10n.clinicalPrescriptionItemDescription;

    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.sm),
            child: Icon(
              Icons.medication_outlined,
              color: colorScheme.onSecondaryContainer,
              size: theme.appTokens.listIconSize,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${l10n.clinicalPrescriptionMedicineLabel} ${index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                selectedDrugLabel ?? fallback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.clinicalPrescriptionRemoveMedicineAction,
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

class _PrescriptionDurationField extends StatelessWidget {
  const _PrescriptionDurationField({
    required this.line,
    required this.enabled,
    required this.onChanged,
  });

  final _PrescriptionLineFormState line;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.event_repeat_outlined,
                  color: colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.xs),
                Text(
                  l10n.clinicalDurationValueLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTextField(
                  controller: line.durationController,
                  labelText: l10n.clinicalDurationValueLabel,
                  prefixIcon: const Icon(Icons.timer_outlined),
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: _integerFormatters,
                  validator: (String? value) =>
                      _optionalPositiveIntegerValidator(l10n, value),
                ),
                AppSelectField<String>.searchable(
                  value: line.durationUnit,
                  labelText: l10n.clinicalDurationUnitLabel,
                  enabled: enabled,
                  options: _durationUnitOptions(),
                  validator: (String? value) {
                    final bool hasDuration = line.durationController.text
                        .trim()
                        .isNotEmpty;
                    return hasDuration && value == null
                        ? l10n.validationRequired
                        : null;
                  },
                  onChanged: (String? value) {
                    line.durationUnit = value;
                    onChanged();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<AppSelectOption<String>> _drugCatalogOptions(
  List<ClinicalActionCatalogOption> options,
) {
  return <AppSelectOption<String>>[
    for (final ClinicalActionCatalogOption option in options)
      AppSelectOption<String>(
        value: option.apiId,
        label: _joinDisplay(<String?>[
          option.displayTitle,
          option.displaySubtitle,
        ]),
        leadingIcon: const Icon(Icons.medication_outlined),
      ),
  ];
}

String? _catalogDisplayLabelById(
  List<ClinicalActionCatalogOption> options,
  String? apiId,
) {
  final ClinicalActionCatalogOption? option = _catalogOptionById(
    options,
    apiId,
  );
  if (option == null) {
    return null;
  }
  return _joinDisplay(<String?>[option.displayTitle, option.displaySubtitle]);
}

ClinicalActionCatalogOption? _catalogOptionById(
  List<ClinicalActionCatalogOption> options,
  String? id,
) {
  if (id == null || id.trim().isEmpty) {
    return null;
  }
  for (final ClinicalActionCatalogOption option in options) {
    if (_catalogIdMatches(option, id)) {
      return option;
    }
  }
  return null;
}

bool _catalogIdMatches(ClinicalActionCatalogOption option, String id) {
  final String normalized = id.trim();
  return option.id == normalized ||
      option.publicId == normalized ||
      option.apiId == normalized;
}

List<AppSelectOption<String>> _unitOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: value),
  ];
}

List<AppSelectOption<String>> _durationUnitOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _durationUnits)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: const Icon(Icons.event_repeat_outlined),
      ),
  ];
}

List<AppSelectOption<String>> _medicationRouteOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _medicationRoutes)
      AppSelectOption<String>(
        value: value,
        label: _apiLabel(value),
        leadingIcon: Icon(_medicationRouteIcon(value)),
      ),
  ];
}

List<AppSelectOption<String>> _medicationFrequencyOptions() {
  return <AppSelectOption<String>>[
    for (final String value in _medicationFrequencies)
      AppSelectOption<String>(
        value: value,
        label: _medicationFrequencyLabel(value),
        leadingIcon: Icon(_medicationFrequencyIcon(value)),
      ),
  ];
}

String _medicationFrequencyLabel(String value) {
  final String? description = switch (value) {
    'ONCE' => 'One time',
    'OD' => 'Once daily',
    'BID' => 'Twice daily',
    'TID' => 'Three times daily',
    'QID' => 'Four times daily',
    'Q4H' => 'Every 4 hours',
    'Q6H' => 'Every 6 hours',
    'Q8H' => 'Every 8 hours',
    'Q12H' => 'Every 12 hours',
    'QHS' => 'At bedtime',
    'WEEKLY' => 'Weekly',
    'PRN' => 'As needed',
    'STAT' => 'Immediately',
    'CUSTOM' => 'Custom',
    _ => null,
  };
  return description == null ? _apiLabel(value) : '$value - $description';
}

IconData _medicationFrequencyIcon(String value) {
  return switch (value) {
    'STAT' => Icons.priority_high_outlined,
    'PRN' => Icons.help_outline,
    'Q4H' || 'Q6H' || 'Q8H' || 'Q12H' || 'QHS' => Icons.schedule_outlined,
    'WEEKLY' => Icons.event_repeat_outlined,
    'CUSTOM' => Icons.tune_outlined,
    _ => Icons.repeat_outlined,
  };
}

IconData _medicationRouteIcon(String value) {
  return switch (value) {
    'IV' => Icons.water_drop_outlined,
    'IM' || 'SC' || 'INTRADERMAL' => Icons.vaccines_outlined,
    'TOPICAL' => Icons.spa_outlined,
    'INHALATION' || 'NASAL' => Icons.air_outlined,
    'OPHTHALMIC' => Icons.visibility_outlined,
    'OTIC' => Icons.hearing_outlined,
    'ORAL' || 'SUBLINGUAL' => Icons.medication_outlined,
    _ => Icons.medical_services_outlined,
  };
}

String? _requiredPositiveIntegerValidator(
  AppLocalizations l10n,
  String? value,
) {
  final String normalized = value?.trim() ?? '';
  final int? parsed = int.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

String? _optionalPositiveIntegerValidator(
  AppLocalizations l10n,
  String? value,
) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final int? parsed = int.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

String? _requiredPositiveNumberValidator(AppLocalizations l10n, String? value) {
  final String normalized = value?.trim() ?? '';
  final num? parsed = num.tryParse(normalized);
  return parsed == null || parsed <= 0 ? l10n.validationRequired : null;
}

Map<String, Object?> _withoutEmptyValues(Map<String, Object?> payload) {
  return <String, Object?>{
    for (final MapEntry<String, Object?> entry in payload.entries)
      if (!_isEmptyPrescriptionValue(entry.value)) entry.key: entry.value,
  };
}

bool _isEmptyPrescriptionValue(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is String) {
    return value.trim().isEmpty;
  }
  if (value is Iterable<Object?>) {
    return value.isEmpty;
  }
  if (value is Map<Object?, Object?>) {
    return value.isEmpty;
  }
  return false;
}

List<ClinicalActionCatalogOption> _mergeCatalogOption(
  List<ClinicalActionCatalogOption> options,
  ClinicalActionCatalogOption option,
) {
  if (options.any(
    (ClinicalActionCatalogOption item) => item.apiId == option.apiId,
  )) {
    return options;
  }
  return <ClinicalActionCatalogOption>[option, ...options];
}

String _diagnosisTermLabel(ClinicalActionCatalogOption option) {
  return _trimmedOrNull(option.name) ?? option.displayTitle;
}

String _diagnosisTermSubtitle(ClinicalActionCatalogOption option) {
  return _joinDisplay(<String?>[option.code, option.displaySubtitle]);
}

String _diagnosisCodeLabel(ClinicalActionCatalogOption option) {
  return _trimmedOrNull(option.code) ?? option.displayTitle;
}

String _diagnosisCodeSubtitle(ClinicalActionCatalogOption option) {
  return _joinDisplay(<String?>[option.name, option.displaySubtitle]);
}

List<ClinicalActionCatalogOption> _dedupeProcedureOptions(
  List<ClinicalActionCatalogOption> options,
) {
  final Set<String> seen = <String>{};
  final List<ClinicalActionCatalogOption> deduped =
      <ClinicalActionCatalogOption>[];
  for (final ClinicalActionCatalogOption option in options) {
    final String key = _procedureDedupKey(option);
    if (seen.add(key)) {
      deduped.add(option);
    }
  }
  return deduped;
}

String _procedureTitle(ClinicalActionCatalogOption option) {
  return _trimmedOrNull(option.name) ?? option.displayTitle;
}

String _procedureCodeLabel(ClinicalActionCatalogOption option) {
  return _trimmedOrNull(option.code) ?? option.displayTitle;
}

String _procedureSubtitle(ClinicalActionCatalogOption option) {
  return _joinDisplay(<String?>[option.code, option.displaySubtitle]);
}

String _procedureDedupKey(ClinicalActionCatalogOption option) {
  final String code = _trimmedOrNull(option.code)?.toUpperCase() ?? '';
  final String title = _procedureTitle(option).toUpperCase();
  if (code.isNotEmpty || title.isNotEmpty) {
    return '$code::$title';
  }
  return _trimmedOrNull(option.apiId)?.toUpperCase() ?? '';
}

String? _trimmedOrNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

IconData _radiologyCatalogIcon(ClinicalActionCatalogOption option) {
  return switch ((option.category ?? '').toUpperCase()) {
    'XRAY' => Icons.photo_camera_outlined,
    'CT' => Icons.donut_large_outlined,
    'MRI' => Icons.all_out_outlined,
    'ULTRASOUND' => Icons.graphic_eq_outlined,
    'FLUOROSCOPY' => Icons.video_camera_back_outlined,
    'MAMMOGRAPHY' => Icons.image_search_outlined,
    'PET' || 'NUCLEAR_MEDICINE' => Icons.blur_on_outlined,
    'INTERVENTIONAL_RADIOLOGY' => Icons.medical_services_outlined,
    'ECG' => Icons.monitor_heart_outlined,
    'ECHO' => Icons.favorite_border,
    'ENDO' || 'GASTRO' => Icons.biotech_outlined,
    _ => Icons.biotech_outlined,
  };
}

List<ClinicalActionCatalogOption> _requestedPanelsForOrder(
  ClinicalActionLabOrderRecord order,
  ClinicalActionReferenceData referenceData,
) {
  final Set<String> itemIds = order.labOrderItems
      .map((ClinicalActionLabOrderItem item) => item.labTestId)
      .whereType<String>()
      .map(_normalizedCatalogToken)
      .where((String value) => value.isNotEmpty)
      .toSet();
  final Set<String> itemCodes = order.labOrderItems
      .map((ClinicalActionLabOrderItem item) => item.testCode)
      .whereType<String>()
      .map(_normalizedCatalogToken)
      .where((String value) => value.isNotEmpty)
      .toSet();

  return referenceData.labPanels
      .where((ClinicalActionCatalogOption panel) {
        final Set<String> panelIds = panel.childIds
            .map(_normalizedCatalogToken)
            .where((String value) => value.isNotEmpty)
            .toSet();
        final Set<String> panelCodes = panel.childCodes
            .map(_normalizedCatalogToken)
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

String _normalizedCatalogToken(String value) {
  return value.trim().toUpperCase();
}

String _apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

String _joinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined;
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

const List<String> _diagnosisTypes = <String>[
  'PRIMARY',
  'SECONDARY',
  'DIFFERENTIAL',
];

const List<String> _medicationFrequencies = <String>[
  'ONCE',
  'OD',
  'BID',
  'TID',
  'QID',
  'Q4H',
  'Q6H',
  'Q8H',
  'Q12H',
  'QHS',
  'WEEKLY',
  'PRN',
  'STAT',
  'CUSTOM',
];

const List<String> _medicationRoutes = <String>[
  'ORAL',
  'IV',
  'IM',
  'SC',
  'SUBLINGUAL',
  'RECTAL',
  'VAGINAL',
  'TOPICAL',
  'INHALATION',
  'OPHTHALMIC',
  'OTIC',
  'NASAL',
  'INTRADERMAL',
  'OTHER',
];

const List<String> _quantityUnits = <String>[
  'tablet',
  'capsule',
  'vial',
  'ampoule',
  'bottle',
  'tube',
  'sachet',
  'patch',
  'drop',
  'mL',
  'dose',
  'pack',
];

const List<String> _doseUnits = <String>[
  'mg',
  'g',
  'mcg',
  'mL',
  'IU',
  'unit',
  'tablet',
  'capsule',
  'drop',
  'puff',
  'sachet',
  'patch',
];

const List<String> _durationUnits = <String>[
  'hours',
  'days',
  'weeks',
  'months',
];

final List<TextInputFormatter> _integerFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
];

final List<TextInputFormatter> _decimalFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];
