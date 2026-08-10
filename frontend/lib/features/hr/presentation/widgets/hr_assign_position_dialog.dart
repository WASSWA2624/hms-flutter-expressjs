import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position_similarity.dart';
import 'package:hosspi_hms/features/hr/domain/repositories/hr_repository.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_staff_detail_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

export 'package:hosspi_hms/features/hr/presentation/widgets/hr_position_details_dialog.dart'
    show showHrStaffPositionDetailDialog;

/// Assign a catalog position to [staff] via the positions table.
Future<void> showHrAssignPositionDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffProfile staff,
) async {
  if (!HrHumanResourcesAtomPermissions.assignPosition.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }
  if (!context.mounted) {
    return;
  }

  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _HrAssignPositionDialog(staff: staff),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
  }
}

Future<HrStaffPosition?> showHrCreateStaffPositionDialog(
  BuildContext context,
  WidgetRef ref, {
  required String tenantId,
  required String facilityId,
  List<HrStaffPosition> existing = const <HrStaffPosition>[],
  HrStaffPosition? editing,
}) {
  return showAppDialog<HrStaffPosition>(
    context: context,
    builder: (BuildContext dialogContext) => _HrStaffPositionMutationDialog(
      tenantId: tenantId,
      facilityId: facilityId,
      existing: existing,
      editing: editing,
    ),
  );
}

class _HrAssignPositionDialog extends ConsumerStatefulWidget {
  const _HrAssignPositionDialog({required this.staff});

  final HrStaffProfile staff;

  @override
  ConsumerState<_HrAssignPositionDialog> createState() =>
      _HrAssignPositionDialogState();
}

class _HrAssignPositionDialogState
    extends ConsumerState<_HrAssignPositionDialog> {
  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<HrStaffPosition>
  _columnController = AppListTableColumnVisibilityController<HrStaffPosition>(
    storageKey: 'hr.assign_position.table',
  );

  static const String _statusFilterKey = 'is_active';

  List<HrStaffPosition> _items = const <HrStaffPosition>[];
  bool _loading = true;
  AppFailure? _failure;
  String? _selectedId;
  bool _assigning = false;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue(
    options: <String, String>{_statusFilterKey: 'true'},
  );

  String? get _tenantId =>
      ref.read(sessionStateProvider).session?.user?.tenantId;
  String? get _facilityId =>
      ref.read(sessionStateProvider).session?.user?.facilityId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reload());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final String? tenantId = _tenantId;
    final String? facilityId = _facilityId;
    if (tenantId == null || tenantId.isEmpty) {
      setState(() {
        _loading = false;
        _failure = AppFailure.validation();
      });
      return;
    }

    setState(() {
      _loading = true;
      _failure = null;
    });

    final String? activeFilter = _filterValue.option(_statusFilterKey);
    final bool? isActive = activeFilter == null || activeFilter.isEmpty
        ? null
        : activeFilter == 'true';

    final Result<AppPage<HrStaffPosition>> result = await ref
        .read(hrRepositoryProvider)
        .listStaffPositions(
          HrStaffPositionQuery(
            tenantId: tenantId,
            facilityId: facilityId,
            search: _searchController.text.trim(),
            isActive: isActive,
            pageRequest: const AppPageRequest(
              pageSize: AppPageRequest.maxPageSize,
            ),
          ),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<HrStaffPosition> page) {
        final String currentName = (widget.staff.position ?? '').trim();
        String? selected = _selectedId;
        if (selected == null && currentName.isNotEmpty) {
          for (final HrStaffPosition item in page.items) {
            if (item.name.trim().toLowerCase() == currentName.toLowerCase()) {
              selected = item.effectiveId;
              break;
            }
          }
        }
        setState(() {
          _items = page.items;
          _selectedId = selected;
          _loading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
        });
      },
    );
  }

  Future<void> _createPosition() async {
    final String? tenantId = _tenantId;
    final String? facilityId = _facilityId;
    if (tenantId == null ||
        tenantId.isEmpty ||
        facilityId == null ||
        facilityId.isEmpty) {
      showHrMutationSnackBar(context, AppFailure.validation());
      return;
    }

    final HrStaffPosition? created = await showHrCreateStaffPositionDialog(
      context,
      ref,
      tenantId: tenantId,
      facilityId: facilityId,
      existing: _items,
    );
    if (created == null || !mounted) {
      return;
    }
    setState(() => _selectedId = created.effectiveId);
    await _reload();
  }

  Future<void> _assign() async {
    final String? selectedId = _selectedId;
    if (selectedId == null || selectedId.isEmpty) {
      showHrMutationSnackBar(context, AppFailure.validation());
      return;
    }
    HrStaffPosition? selected;
    for (final HrStaffPosition item in _items) {
      if (item.effectiveId == selectedId || item.id == selectedId) {
        selected = item;
        break;
      }
    }
    if (selected == null) {
      showHrMutationSnackBar(context, AppFailure.validation());
      return;
    }

    setState(() => _assigning = true);
    final AppFailure? failure = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .updateSelectedStaffProfile(<String, Object?>{
          'position': selected.name,
        });
    if (!mounted) {
      return;
    }
    setState(() => _assigning = false);
    if (failure != null) {
      showHrMutationSnackBar(context, failure);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool canWrite = HrHumanResourcesAtomPermissions.write.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );
    final bool isChange = staffHasAssignedPosition(widget.staff);

    return AppDialog(
      title: Text(
        isChange
            ? l10n.hrChangePositionDialogTitle
            : l10n.hrAssignPositionDialogTitle,
      ),
      icon: const Icon(Icons.work_outline),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 920,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            Padding(
              padding: EdgeInsets.only(bottom: Theme.of(context).spacing.md),
              child: AppFormInformationBanner(
                title: l10n.hrPositionsLoadErrorTitle,
                message: l10n.failureMessage(_failure!),
                variant: AppFormInformationVariant.error,
              ),
            ),
          AppListTable<HrStaffPosition>(
            items: _items,
            isLoading: _loading,
            columnVisibilityController: _columnController,
            onRowSelected: _assigning
                ? null
                : (HrStaffPosition item) {
                    setState(() => _selectedId = item.effectiveId);
                  },
            search: AppListTableSearch<HrStaffPosition>(
              controller: _searchController,
              semanticLabel: l10n.hrPositionsSearchHint,
              hintText: l10n.hrPositionsSearchHint,
              matcher: (HrStaffPosition item, String query) {
                final String needle = query.trim().toLowerCase();
                if (needle.isEmpty) {
                  return true;
                }
                return item.name.toLowerCase().contains(needle) ||
                    item.effectiveId.toLowerCase().contains(needle) ||
                    (item.description ?? '').toLowerCase().contains(needle);
              },
              onSubmitted: (_) => unawaited(_reload()),
              onClear: () {
                _searchController.clear();
                unawaited(_reload());
              },
              showAdvancedFilterButton: true,
              advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
              advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
              advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
              advancedFilterResetLabel: l10n.hrClearFiltersAction,
              allFieldsLabel: l10n.opdAllFieldsFilterLabel,
              filterGroups: <AppSearchBarFilterGroup>[
                AppSearchBarFilterGroup(
                  key: _statusFilterKey,
                  label: l10n.hrStatusLabel,
                  allLabel: l10n.opdAllFieldsFilterLabel,
                  choices: <AppSearchBarFilterChoice>[
                    AppSearchBarFilterChoice(
                      value: 'true',
                      label: l10n.hrPositionActiveStatus,
                    ),
                    AppSearchBarFilterChoice(
                      value: 'false',
                      label: l10n.hrPositionInactiveStatus,
                    ),
                  ],
                ),
              ],
              filterValue: _filterValue,
              hasActiveFilters:
                  (_filterValue.option(_statusFilterKey) ?? 'true') != 'true',
              onFilterChanged: (AppSearchBarFilterValue value) {
                setState(() => _filterValue = value);
                unawaited(_reload());
              },
              trailingActions: <AppSearchBarAction>[
                if (canWrite)
                  AppSearchBarAction(
                    label: l10n.hrCreatePositionAction,
                    icon: Icons.add_outlined,
                    enabled: !_assigning,
                    onPressed: () => unawaited(_createPosition()),
                  ),
              ],
            ),
            columns: <AppListTableColumn<HrStaffPosition>>[
              AppListTableColumn<HrStaffPosition>(
                id: 'select',
                label: l10n.hrSelectPositionColumnLabel,
                alwaysVisible: true,
                cellBuilder: (BuildContext context, HrStaffPosition item) {
                  return Radio<String>(
                    value: item.effectiveId,
                    groupValue: _selectedId,
                    onChanged: _assigning
                        ? null
                        : (String? value) {
                            setState(() => _selectedId = value);
                          },
                  );
                },
              ),
              AppListTableColumn<HrStaffPosition>(
                id: 'name',
                label: l10n.hrPositionLabel,
                alwaysVisible: true,
                cellBuilder: (_, HrStaffPosition item) => Text(item.name),
                sortComparator: (HrStaffPosition a, HrStaffPosition b) =>
                    a.name.compareTo(b.name),
              ),
              AppListTableColumn<HrStaffPosition>(
                id: 'id',
                label: l10n.hrPositionIdLabel,
                cellBuilder: (_, HrStaffPosition item) =>
                    Text(item.effectiveId),
              ),
              AppListTableColumn<HrStaffPosition>(
                id: 'description',
                label: l10n.hrPositionDescriptionLabel,
                cellBuilder: (_, HrStaffPosition item) => Text(
                  (item.description ?? '').trim().isEmpty
                      ? '—'
                      : item.description!,
                ),
              ),
            ],
            mobileItemBuilder: (BuildContext context, HrStaffPosition item) {
              return AppListTableMobileItem(
                title: item.name,
                caption: item.effectiveId,
                leading: Radio<String>(
                  value: item.effectiveId,
                  groupValue: _selectedId,
                  onChanged: _assigning
                      ? null
                      : (String? value) {
                          setState(() => _selectedId = value);
                        },
                ),
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: isChange
              ? l10n.hrChangePositionAction
              : l10n.hrAssignPositionAction,
          leadingIcon: Icons.check_outlined,
          isLoading: _assigning,
          onPressed: _assigning || _selectedId == null
              ? null
              : () => unawaited(_assign()),
        ),
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          leadingIcon: Icons.close,
          onPressed: _assigning ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _HrStaffPositionMutationDialog extends ConsumerStatefulWidget {
  const _HrStaffPositionMutationDialog({
    required this.tenantId,
    required this.facilityId,
    required this.existing,
    this.editing,
  });

  final String tenantId;
  final String facilityId;
  final List<HrStaffPosition> existing;
  final HrStaffPosition? editing;

  @override
  ConsumerState<_HrStaffPositionMutationDialog> createState() =>
      _HrStaffPositionMutationDialogState();
}

class _HrStaffPositionMutationDialogState
    extends ConsumerState<_HrStaffPositionMutationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late bool _isActive;
  bool _saving = false;
  String? _nameError;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.editing?.description ?? '',
    );
    _isActive = widget.editing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<bool> _reviewSimilarity(String name) async {
    final HrStaffPositionDuplicateCheckResult check =
        checkHrStaffPositionDuplicates(
          name: name,
          existing: widget.existing,
          excludePositionId: widget.editing?.id,
        );
    if (!check.exactNameConflict && check.overridableMatches.isEmpty) {
      return true;
    }

    final AppLocalizations l10n = context.l10n;
    final AppSimilarityReviewResult<HrStaffPosition> result =
        await showAppSimilarityReviewDialog<HrStaffPosition>(
          context,
          title: l10n.hrSimilarPositionDialogTitle,
          bannerTitle: check.exactNameConflict
              ? l10n.hrPositionNameAlreadyInUse
              : l10n.hrSimilarPositionWarningTitle,
          bannerMessage: l10n.hrSimilarPositionWarningBody,
          bannerVariant: check.exactNameConflict
              ? AppFormInformationVariant.error
              : AppFormInformationVariant.warning,
          proposedFields: <AppSimilarityProposedField>[
            AppSimilarityProposedField(
              key: 'name',
              label: l10n.hrPositionLabel,
              initialValue: name,
              isRequired: true,
            ),
          ],
          matches: <AppSimilarityMatch<HrStaffPosition>>[
            for (final HrStaffPositionSimilarityMatch match
                in check.similarMatches.take(5))
              AppSimilarityMatch<HrStaffPosition>(
                item: match.position,
                overallScore: match.score,
                isExact: match.exactNameConflict,
                title: match.position.name,
                subtitle: match.position.effectiveId,
                fields: <AppSimilarityFieldRow>[
                  AppSimilarityFieldRow(
                    key: 'name',
                    label: l10n.hrPositionLabel,
                    proposedValue: name,
                    existingValue: match.position.name,
                    score: match.score,
                  ),
                ],
              ),
          ],
          overallScore: check.similarMatches.isEmpty
              ? 0
              : check.similarMatches.first.score,
          blockProceed: check.exactNameConflict,
        );

    switch (result.action) {
      case AppSimilarityReviewAction.cancel:
        return false;
      case AppSimilarityReviewAction.useExisting:
        if (result.selected != null && mounted) {
          Navigator.of(context).pop(result.selected);
        }
        return false;
      case AppSimilarityReviewAction.proceed:
      case AppSimilarityReviewAction.replaceExisting:
      case AppSimilarityReviewAction.retry:
        final String? nextName = result.proposedValues['name']?.trim();
        if (nextName != null && nextName.isNotEmpty) {
          _nameController.text = nextName;
        }
        return result.action == AppSimilarityReviewAction.proceed ||
            result.action == AppSimilarityReviewAction.replaceExisting;
    }
  }

  Future<void> _submit({required bool confirmSimilar}) async {
    setState(() => _nameError = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String name = _nameController.text.trim();
    if (!confirmSimilar) {
      final bool ok = await _reviewSimilarity(name);
      if (!ok || !mounted) {
        return;
      }
    }

    setState(() => _saving = true);
    final HrRepository repository = ref.read(hrRepositoryProvider);
    final Map<String, Object?> payload = <String, Object?>{
      if (!_isEdit) 'tenant_id': widget.tenantId,
      if (!_isEdit) 'facility_id': widget.facilityId,
      'name': name,
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'is_active': _isActive,
      if (confirmSimilar) 'confirm_similar': true,
    };

    final Result<HrStaffPosition> result = _isEdit
        ? await repository.updateStaffPosition(
            widget.editing!.effectiveId,
            payload,
          )
        : await repository.createStaffPosition(payload);

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    await result.when(
      success: (HrStaffPosition position) async {
        Navigator.of(context).pop(position);
      },
      failure: (AppFailure failure) async {
        if (failure.messageKey == 'errors.staff_position.duplicate_name') {
          setState(() => _nameError = context.l10n.hrPositionNameAlreadyInUse);
          return;
        }
        if (failure.messageKey == 'errors.staff_position.similar_exists') {
          final bool ok = await _reviewSimilarity(name);
          if (ok && mounted) {
            await _submit(confirmSimilar: true);
          }
          return;
        }
        showHrMutationSnackBar(context, failure);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(
        _isEdit
            ? l10n.hrEditPositionDialogTitle
            : l10n.hrCreatePositionDialogTitle,
      ),
      icon: const Icon(Icons.work_outline),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 560,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            AppTextField(
              controller: _nameController,
              labelText: l10n.hrPositionLabel,
              isRequired: true,
              errorText: _nameError,
              validator: AppValidators.requiredText(
                l10n.hrFieldRequiredLabel(l10n.hrPositionLabel),
              ),
            ),
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.hrPositionDescriptionLabel,
              maxLines: 3,
            ),
            AppCheckboxField(
              title: l10n.hrPositionActiveStatus,
              value: _isActive,
              onChanged: (bool value) => setState(() => _isActive = value),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: _isEdit
              ? l10n.commonSaveActionLabel
              : l10n.hrCreatePositionAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _saving,
          onPressed: _saving
              ? null
              : () => unawaited(_submit(confirmSimilar: false)),
        ),
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
