import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/hr/data/repositories/hr_repository_impl.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_presentation_helpers.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_roster_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum _HrAssignRosterMethod { existingTemplate, createNew, copyFromStaff }

/// Opens Add/Change roster for [staff], offering template / create / copy paths.
Future<bool> showHrAssignRosterDialog(
  BuildContext context,
  WidgetRef ref, {
  required HrStaffProfile staff,
  String? currentRosterId,
}) async {
  if (!HrHumanResourcesAtomPermissions.nestedRosterWrite.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return false;
  }
  if (!context.mounted) {
    return false;
  }

  final bool isChange = (currentRosterId ?? '').trim().isNotEmpty;
  final _HrAssignRosterMethod? method =
      await showAppDialog<_HrAssignRosterMethod>(
        context: context,
        builder: (BuildContext dialogContext) =>
            _HrAssignRosterMethodDialog(isChange: isChange),
      );
  if (method == null || !context.mounted) {
    return false;
  }

  switch (method) {
    case _HrAssignRosterMethod.existingTemplate:
      return _showSelectExistingRosterDialog(
        context,
        ref,
        staff: staff,
        currentRosterId: currentRosterId,
      );
    case _HrAssignRosterMethod.createNew:
      return _createNewRosterForStaff(
        context,
        ref,
        staff: staff,
        currentRosterId: currentRosterId,
      );
    case _HrAssignRosterMethod.copyFromStaff:
      return _showCopyRosterFromStaffDialog(
        context,
        ref,
        staff: staff,
        currentRosterId: currentRosterId,
      );
  }
}

Future<bool> _createNewRosterForStaff(
  BuildContext context,
  WidgetRef ref, {
  required HrStaffProfile staff,
  String? currentRosterId,
}) async {
  if (!context.mounted) {
    return false;
  }
  final bool created = await showHrCreateRosterDialog(
    context,
    ref,
    attachStaffProfileIds: <String>[staff.effectiveId],
  );
  if (!created) {
    return false;
  }

  final String previousRosterId = (currentRosterId ?? '').trim();
  if (previousRosterId.isEmpty) {
    return true;
  }

  final Result<Map<String, Object?>> detach = await ref
      .read(hrWorkspaceControllerProvider.notifier)
      .detachRosterStaff(
        rosterId: previousRosterId,
        staffProfileId: staff.effectiveId,
      );
  final AppFailure? detachFailure = detach.when(
    success: (_) => null,
    failure: (AppFailure failure) => failure,
  );
  if (detachFailure != null && context.mounted) {
    showHrMutationSnackBar(context, detachFailure);
  }
  return true;
}

Future<bool> _showSelectExistingRosterDialog(
  BuildContext context,
  WidgetRef ref, {
  required HrStaffProfile staff,
  String? currentRosterId,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _HrSelectRosterTemplateDialog(
      staff: staff,
      currentRosterId: currentRosterId,
    ),
  );
  return saved == true;
}

Future<bool> _showCopyRosterFromStaffDialog(
  BuildContext context,
  WidgetRef ref, {
  required HrStaffProfile staff,
  String? currentRosterId,
}) async {
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => _HrCopyRosterFromStaffDialog(
      staff: staff,
      currentRosterId: currentRosterId,
    ),
  );
  return saved == true;
}

String _rosterSelectionKey(HrWorkItem item) {
  return (item.rosterId ?? item.backendIdentifier ?? item.effectiveId).trim();
}

String _rosterTitle(HrWorkItem item, AppLocalizations l10n) {
  final String name = (item.rosterName ?? item.periodLabel ?? '').trim();
  if (name.isNotEmpty) {
    return name;
  }
  final String id = _rosterSelectionKey(item);
  return id.isEmpty ? l10n.hrRosterDraftTitle : id;
}

String _rosterStatusLabel(AppLocalizations l10n, String? status) {
  final String normalized = (status ?? '').trim().toUpperCase();
  return switch (normalized) {
    'DRAFT' => l10n.hrRosterStatusDraft,
    'PUBLISHED' => l10n.hrRosterStatusCompleted,
    'DELETED' => l10n.hrRosterStatusDeleted,
    _ => (status ?? '').trim().isEmpty ? '—' : status!,
  };
}

Future<AppFailure?> _assignStaffToRoster(
  WidgetRef ref, {
  required String rosterId,
  required String staffProfileId,
  String? currentRosterId,
}) async {
  final String previous = (currentRosterId ?? '').trim();
  final String next = rosterId.trim();
  if (next.isEmpty) {
    return AppFailure.validation();
  }
  if (previous.isNotEmpty && previous == next) {
    return null;
  }

  final notifier = ref.read(hrWorkspaceControllerProvider.notifier);
  if (previous.isNotEmpty) {
    final Result<Map<String, Object?>> detach = await notifier.detachRosterStaff(
      rosterId: previous,
      staffProfileId: staffProfileId,
    );
    final AppFailure? detachFailure = detach.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
    if (detachFailure != null) {
      return detachFailure;
    }
  }

  final Result<Map<String, Object?>> attach = await notifier.attachRosterStaff(
    rosterId: next,
    staffProfileId: staffProfileId,
  );
  return attach.when(
    success: (_) => null,
    failure: (AppFailure failure) => failure,
  );
}

class _HrAssignRosterMethodDialog extends StatelessWidget {
  const _HrAssignRosterMethodDialog({required this.isChange});

  final bool isChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      title: Text(
        isChange
            ? l10n.hrChangeRosterDialogTitle
            : l10n.hrAddRosterDialogTitle,
      ),
      icon: Icon(
        isChange ? Icons.edit_calendar_outlined : Icons.add_outlined,
      ),
      scrollable: true,
      maxWidth: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            isChange
                ? l10n.hrChangeRosterMethodHint
                : l10n.hrAddRosterMethodHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.md),
          _MethodOption(
            icon: Icons.view_list_outlined,
            title: l10n.hrAssignRosterUseTemplateAction,
            subtitle: l10n.hrAssignRosterUseTemplateHint,
            onTap: () => Navigator.of(
              context,
            ).pop(_HrAssignRosterMethod.existingTemplate),
          ),
          SizedBox(height: theme.spacing.sm),
          _MethodOption(
            icon: Icons.playlist_add_outlined,
            title: l10n.hrAssignRosterCreateNewAction,
            subtitle: l10n.hrAssignRosterCreateNewHint,
            onTap: () =>
                Navigator.of(context).pop(_HrAssignRosterMethod.createNew),
          ),
          SizedBox(height: theme.spacing.sm),
          _MethodOption(
            icon: Icons.person_search_outlined,
            title: l10n.hrAssignRosterCopyFromStaffAction,
            subtitle: l10n.hrAssignRosterCopyFromStaffHint,
            onTap: () =>
                Navigator.of(context).pop(_HrAssignRosterMethod.copyFromStaff),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radius.md),
        side: BorderSide(color: theme.borders.faint),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radius.md),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: theme.colorScheme.primary),
              SizedBox(width: theme.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrSelectRosterTemplateDialog extends ConsumerStatefulWidget {
  const _HrSelectRosterTemplateDialog({
    required this.staff,
    this.currentRosterId,
  });

  final HrStaffProfile staff;
  final String? currentRosterId;

  @override
  ConsumerState<_HrSelectRosterTemplateDialog> createState() =>
      _HrSelectRosterTemplateDialogState();
}

class _HrSelectRosterTemplateDialogState
    extends ConsumerState<_HrSelectRosterTemplateDialog> {
  static const String _statusFilterKey = 'status';

  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<HrWorkItem> _columnController =
      AppListTableColumnVisibilityController<HrWorkItem>(
        storageKey: 'hr.assign_roster.templates.v1',
      );

  List<HrWorkItem> _items = const <HrWorkItem>[];
  bool _loading = true;
  bool _assigning = false;
  AppFailure? _failure;
  String? _selectedId;
  AppSearchBarFilterValue _filterValue = const AppSearchBarFilterValue();

  bool get _isChange => (widget.currentRosterId ?? '').trim().isNotEmpty;

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
    setState(() {
      _loading = true;
      _failure = null;
    });

    final String? status = _filterValue.option(_statusFilterKey);
    final Result<AppPage<HrWorkItem>> result = await ref
        .read(hrRepositoryProvider)
        .listWorkItems(
          HrWorkItemsQuery(
            queue: HrQueue.rosterDrafts,
            search: _searchController.text.trim(),
            status: (status ?? '').trim().isEmpty ? null : status,
            pageRequest: const AppPageRequest(
              pageSize: AppPageRequest.maxPageSize,
            ),
          ),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<HrWorkItem> page) {
        final String current = (widget.currentRosterId ?? '').trim();
        final List<HrWorkItem> items = page.items
            .where((HrWorkItem item) {
              final String status = (item.status ?? '').trim().toUpperCase();
              return status != 'DELETED';
            })
            .toList(growable: false);
        String? selected = _selectedId;
        if (selected != null) {
          final bool stillPresent = items.any(
            (HrWorkItem item) => _rosterSelectionKey(item) == selected,
          );
          if (!stillPresent) {
            selected = null;
          }
        }
        if (selected == null && current.isNotEmpty) {
          for (final HrWorkItem item in items) {
            if (_rosterSelectionKey(item) == current) {
              selected = current;
              break;
            }
          }
        }
        setState(() {
          _items = items;
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

  Future<void> _confirm() async {
    final String? selectedId = _selectedId;
    if (selectedId == null || selectedId.isEmpty) {
      showHrMutationSnackBar(context, AppFailure.validation());
      return;
    }

    setState(() => _assigning = true);
    final AppFailure? failure = await _assignStaffToRoster(
      ref,
      rosterId: selectedId,
      staffProfileId: widget.staff.effectiveId,
      currentRosterId: widget.currentRosterId,
    );
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

    return AppDialog(
      title: Text(
        _isChange
            ? l10n.hrChangeRosterSelectTemplateTitle
            : l10n.hrAddRosterSelectTemplateTitle,
      ),
      icon: const Icon(Icons.view_list_outlined),
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
                title: l10n.hrAssignRosterTemplatesLoadErrorTitle,
                message: l10n.failureMessage(_failure!),
                variant: AppFormInformationVariant.error,
              ),
            ),
          AppListTable<HrWorkItem>(
            items: _items,
            isLoading: _loading,
            columnVisibilityController: _columnController,
            columnVisibilityStorageKey: 'hr.assign_roster.templates.v1',
            columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
            onRowSelected: _assigning
                ? null
                : (HrWorkItem item) {
                    setState(() => _selectedId = _rosterSelectionKey(item));
                  },
            emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
              title: l10n.hrAssignRosterTemplatesEmptyTitle,
              body: l10n.hrAssignRosterTemplatesEmptyBody,
            ),
            search: AppListTableSearch<HrWorkItem>(
              controller: _searchController,
              semanticLabel: l10n.hrAssignRosterTemplatesSearchHint,
              hintText: l10n.hrAssignRosterTemplatesSearchHint,
              clearLabel: l10n.hrClearFiltersAction,
              matcher: (HrWorkItem item, String query) {
                final String needle = query.trim().toLowerCase();
                if (needle.isEmpty) {
                  return true;
                }
                return _rosterTitle(item, l10n).toLowerCase().contains(needle) ||
                    _rosterSelectionKey(item).toLowerCase().contains(needle) ||
                    (item.periodLabel ?? '').toLowerCase().contains(needle) ||
                    (item.status ?? '').toLowerCase().contains(needle);
              },
              onSubmitted: (_) => unawaited(_reload()),
              onClear: () {
                _searchController.clear();
                setState(() => _filterValue = const AppSearchBarFilterValue());
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
                  label: l10n.hrRosterStatusFieldLabel,
                  allLabel: l10n.opdAllFieldsFilterLabel,
                  choices: <AppSearchBarFilterChoice>[
                    AppSearchBarFilterChoice(
                      value: 'DRAFT',
                      label: l10n.hrRosterStatusDraft,
                    ),
                    AppSearchBarFilterChoice(
                      value: 'PUBLISHED',
                      label: l10n.hrRosterStatusCompleted,
                    ),
                  ],
                ),
              ],
              filterValue: _filterValue,
              onFilterChanged: (AppSearchBarFilterValue value) {
                setState(() => _filterValue = value);
                unawaited(_reload());
              },
            ),
            columns: <AppListTableColumn<HrWorkItem>>[
              AppListTableColumn<HrWorkItem>(
                id: 'select',
                label: l10n.hrSelectPositionColumnLabel,
                alwaysVisible: true,
                fixedWidth: 48,
                exportable: false,
                cellBuilder: (BuildContext context, HrWorkItem item) {
                  final String id = _rosterSelectionKey(item);
                  return Radio<String>(
                    value: id,
                    groupValue: _selectedId,
                    onChanged: _assigning
                        ? null
                        : (String? value) {
                            setState(() => _selectedId = value);
                          },
                  );
                },
              ),
              AppListTableColumn<HrWorkItem>(
                id: 'name',
                label: l10n.hrRosterDraftTitle,
                alwaysVisible: true,
                preferredWidth: 220,
                cellBuilder: (BuildContext context, HrWorkItem item) => Text(
                  _rosterTitle(item, l10n),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                sortComparator: (HrWorkItem a, HrWorkItem b) => _rosterTitle(
                  a,
                  l10n,
                ).compareTo(_rosterTitle(b, l10n)),
              ),
              AppListTableColumn<HrWorkItem>(
                id: 'id',
                label: l10n.hrRosterOverviewIdLabel,
                preferredWidth: 140,
                cellBuilder: (BuildContext context, HrWorkItem item) =>
                    Text(_rosterSelectionKey(item)),
                sortComparator: (HrWorkItem a, HrWorkItem b) =>
                    _rosterSelectionKey(a).compareTo(_rosterSelectionKey(b)),
              ),
              AppListTableColumn<HrWorkItem>(
                id: 'period',
                label: l10n.hrPeriodColumnLabel,
                preferredWidth: 180,
                cellBuilder: (BuildContext context, HrWorkItem item) =>
                    Text(item.periodLabel ?? '—'),
                sortComparator: (HrWorkItem a, HrWorkItem b) =>
                    (a.periodLabel ?? '').compareTo(b.periodLabel ?? ''),
              ),
              AppListTableColumn<HrWorkItem>(
                id: 'staff_count',
                label: l10n.hrRosterAttachedStaffTitle,
                preferredWidth: 120,
                cellBuilder: (BuildContext context, HrWorkItem item) =>
                    Text('${item.assignmentCount}'),
                sortComparator: (HrWorkItem a, HrWorkItem b) =>
                    a.assignmentCount.compareTo(b.assignmentCount),
              ),
              AppListTableColumn<HrWorkItem>(
                id: 'status',
                label: l10n.hrStatusLabel,
                preferredWidth: 120,
                cellBuilder: (BuildContext context, HrWorkItem item) {
                  final String status = (item.status ?? '').trim().toUpperCase();
                  return AppStatusBadge(
                    label: _rosterStatusLabel(l10n, item.status),
                    tone: status == 'PUBLISHED'
                        ? AppWorkspaceStatusTone.success
                        : AppWorkspaceStatusTone.neutral,
                  );
                },
                sortComparator: (HrWorkItem a, HrWorkItem b) =>
                    (a.status ?? '').compareTo(b.status ?? ''),
              ),
            ],
            mobileItemBuilder: (BuildContext context, HrWorkItem item) {
              final String id = _rosterSelectionKey(item);
              return AppListTableMobileItem(
                title: _rosterTitle(item, l10n),
                caption: item.periodLabel ?? id,
                leading: Radio<String>(
                  value: id,
                  groupValue: _selectedId,
                  onChanged: _assigning
                      ? null
                      : (String? value) {
                          setState(() => _selectedId = value);
                        },
                ),
                meta: <AppListTableMobileMeta>[
                  AppListTableMobileMeta(
                    label: _rosterStatusLabel(l10n, item.status),
                  ),
                  AppListTableMobileMeta(
                    label: l10n.hrRosterAssignedStaffCountChip(
                      item.assignmentCount,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: _assigning ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: _isChange
              ? l10n.hrChangeRosterConfirmAction
              : l10n.hrAddRosterConfirmAction,
          leadingIcon: _isChange
              ? Icons.edit_calendar_outlined
              : Icons.person_add_alt_1_outlined,
          onPressed: _assigning || (_selectedId ?? '').isEmpty
              ? null
              : () => unawaited(_confirm()),
        ),
      ],
    );
  }
}

class _HrCopyRosterFromStaffDialog extends ConsumerStatefulWidget {
  const _HrCopyRosterFromStaffDialog({
    required this.staff,
    this.currentRosterId,
  });

  final HrStaffProfile staff;
  final String? currentRosterId;

  @override
  ConsumerState<_HrCopyRosterFromStaffDialog> createState() =>
      _HrCopyRosterFromStaffDialogState();
}

class _HrCopyRosterFromStaffDialogState
    extends ConsumerState<_HrCopyRosterFromStaffDialog> {
  final TextEditingController _searchController = TextEditingController();
  final AppListTableColumnVisibilityController<HrStaffProfile>
  _columnController = AppListTableColumnVisibilityController<HrStaffProfile>(
    storageKey: 'hr.assign_roster.copy_staff.v1',
  );

  List<HrStaffProfile> _candidates = const <HrStaffProfile>[];
  bool _loading = true;
  bool _loadingRoster = false;
  bool _assigning = false;
  AppFailure? _failure;
  String? _selectedStaffId;
  String? _selectedRosterId;
  String? _selectedRosterName;
  String? _selectedRosterPeriod;

  bool get _isChange => (widget.currentRosterId ?? '').trim().isNotEmpty;

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
    setState(() {
      _loading = true;
      _failure = null;
    });

    final Result<AppPage<HrStaffProfile>> result = await ref
        .read(hrRepositoryProvider)
        .listStaffProfiles(
          const HrStaffQuery(
            pageRequest: AppPageRequest(pageSize: AppPageRequest.maxPageSize),
          ),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<HrStaffProfile> page) {
        final String selfId = widget.staff.effectiveId;
        final String selfUuid = widget.staff.id;
        final List<HrStaffProfile> candidates = page.items.where((
          HrStaffProfile row,
        ) {
          if (row.isSeparated) {
            return false;
          }
          if (row.effectiveId == selfId || row.id == selfUuid) {
            return false;
          }
          return true;
        }).toList(growable: false);
        setState(() {
          _candidates = candidates;
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

  Future<void> _selectStaff(HrStaffProfile row) async {
    setState(() {
      _selectedStaffId = row.effectiveId;
      _selectedRosterId = null;
      _selectedRosterName = null;
      _selectedRosterPeriod = null;
      _loadingRoster = true;
      _failure = null;
    });

    final Result<HrStaffDetail> result = await ref
        .read(hrRepositoryProvider)
        .loadStaffDetail(row);

    if (!mounted) {
      return;
    }

    result.when(
      success: (HrStaffDetail detail) {
        final String? rosterId = _primaryRosterId(detail.shiftAssignments);
        if (rosterId == null || rosterId.isEmpty) {
          setState(() {
            _loadingRoster = false;
            _selectedRosterId = null;
          });
          return;
        }

        unawaited(_loadRosterSummary(rosterId));
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loadingRoster = false;
        });
      },
    );
  }

  Future<void> _loadRosterSummary(String rosterId) async {
    final Result<Map<String, Object?>> result = await ref
        .read(hrWorkspaceControllerProvider.notifier)
        .getRoster(rosterId);
    if (!mounted) {
      return;
    }
    result.when(
      success: (Map<String, Object?> roster) {
        final String name = (roster['name'] ?? '').toString().trim();
        final String period = _periodLabelFromRoster(roster);
        setState(() {
          _selectedRosterId = (roster['human_friendly_id'] ??
                  roster['display_id'] ??
                  roster['id'] ??
                  rosterId)
              .toString()
              .trim();
          _selectedRosterName = name.isEmpty ? null : name;
          _selectedRosterPeriod = period.isEmpty ? null : period;
          _loadingRoster = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loadingRoster = false;
          _selectedRosterId = rosterId;
        });
      },
    );
  }

  String _periodLabelFromRoster(Map<String, Object?> roster) {
    final Object? startRaw = roster['period_start'];
    final Object? endRaw = roster['period_end'];
    DateTime? start;
    DateTime? end;
    if (startRaw is String && startRaw.trim().isNotEmpty) {
      start = DateTime.tryParse(startRaw);
    } else if (startRaw is DateTime) {
      start = startRaw;
    }
    if (endRaw is String && endRaw.trim().isNotEmpty) {
      end = DateTime.tryParse(endRaw);
    } else if (endRaw is DateTime) {
      end = endRaw;
    }
    if (start == null && end == null) {
      return '';
    }
    final Locale locale = Localizations.localeOf(context);
    final String startLabel = start == null
        ? '—'
        : AppFormatters.shortDate(start, locale);
    final String endLabel = end == null
        ? '—'
        : AppFormatters.shortDate(end, locale);
    return '$startLabel – $endLabel';
  }

  String? _primaryRosterId(List<HrShiftAssignment> assignments) {
    final Map<String, int> counts = <String, int>{};
    for (final HrShiftAssignment assignment in assignments) {
      final String id = (assignment.rosterId ?? '').trim();
      if (id.isEmpty) {
        continue;
      }
      counts[id] = (counts[id] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return null;
    }
    String? best;
    int bestCount = 0;
    for (final MapEntry<String, int> entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  Future<void> _confirm() async {
    final String? rosterId = _selectedRosterId;
    if (rosterId == null || rosterId.isEmpty) {
      showHrMutationSnackBar(context, AppFailure.validation());
      return;
    }

    setState(() => _assigning = true);
    final AppFailure? failure = await _assignStaffToRoster(
      ref,
      rosterId: rosterId,
      staffProfileId: widget.staff.effectiveId,
      currentRosterId: widget.currentRosterId,
    );
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
    final ThemeData theme = Theme.of(context);
    final bool hasRoster =
        (_selectedRosterId ?? '').trim().isNotEmpty && !_loadingRoster;

    return AppDialog(
      title: Text(
        _isChange
            ? l10n.hrChangeRosterCopyFromStaffTitle
            : l10n.hrAddRosterCopyFromStaffTitle,
      ),
      icon: const Icon(Icons.person_search_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 920,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_failure != null)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.md),
              child: AppFormInformationBanner(
                title: l10n.hrAssignRosterCopyLoadErrorTitle,
                message: l10n.failureMessage(_failure!),
                variant: AppFormInformationVariant.error,
              ),
            ),
          AppListTable<HrStaffProfile>(
            items: _candidates,
            isLoading: _loading,
            columnVisibilityController: _columnController,
            columnVisibilityStorageKey: 'hr.assign_roster.copy_staff.v1',
            columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
            onRowSelected: _assigning || _loadingRoster
                ? null
                : (HrStaffProfile row) => unawaited(_selectStaff(row)),
            emptyBuilder: (_) => AppWorkspaceStatePanel.empty(
              title: l10n.hrNoStaffTitle,
              body: l10n.hrNoStaffBody,
            ),
            search: AppListTableSearch<HrStaffProfile>(
              controller: _searchController,
              semanticLabel: l10n.hrSearchLabel,
              hintText: l10n.hrSearchHint,
              clearLabel: l10n.hrClearFiltersAction,
              matcher: (HrStaffProfile row, String query) {
                final String needle = query.trim().toLowerCase();
                if (needle.isEmpty) {
                  return true;
                }
                return row.displayName.toLowerCase().contains(needle) ||
                    (row.staffNumber ?? '').toLowerCase().contains(needle) ||
                    (row.userEmail ?? '').toLowerCase().contains(needle) ||
                    (row.position ?? '').toLowerCase().contains(needle) ||
                    row.effectiveId.toLowerCase().contains(needle);
              },
              showAdvancedFilterButton: true,
              advancedFilterButtonLabel: l10n.commonFiltersActionLabel,
              advancedFilterTitle: l10n.commonAdvancedFiltersTitle,
              advancedFilterApplyLabel: l10n.opdApplyFiltersAction,
              advancedFilterResetLabel: l10n.hrClearFiltersAction,
              allFieldsLabel: l10n.opdAllFieldsFilterLabel,
            ),
            columns: <AppListTableColumn<HrStaffProfile>>[
              AppListTableColumn<HrStaffProfile>(
                id: 'select',
                label: l10n.hrSelectPositionColumnLabel,
                alwaysVisible: true,
                fixedWidth: 48,
                exportable: false,
                cellBuilder: (BuildContext context, HrStaffProfile row) {
                  return Radio<String>(
                    value: row.effectiveId,
                    groupValue: _selectedStaffId,
                    onChanged: _assigning || _loadingRoster
                        ? null
                        : (_) => unawaited(_selectStaff(row)),
                  );
                },
              ),
              AppListTableColumn<HrStaffProfile>(
                id: 'name',
                label: l10n.hrStaffNameLabel,
                alwaysVisible: true,
                preferredWidth: 200,
                cellBuilder: (BuildContext context, HrStaffProfile row) =>
                    Text(row.displayName),
                sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
                    a.displayName.compareTo(b.displayName),
              ),
              AppListTableColumn<HrStaffProfile>(
                id: 'staff_number',
                label: l10n.hrStaffNumberLabel,
                preferredWidth: 140,
                cellBuilder: (BuildContext context, HrStaffProfile row) =>
                    Text(row.staffNumber ?? row.effectiveId),
                sortComparator: (HrStaffProfile a, HrStaffProfile b) =>
                    (a.staffNumber ?? a.effectiveId).compareTo(
                      b.staffNumber ?? b.effectiveId,
                    ),
              ),
              AppListTableColumn<HrStaffProfile>(
                id: 'department',
                label: l10n.hrDepartmentLabel,
                preferredWidth: 160,
                cellBuilder: (BuildContext context, HrStaffProfile row) => Text(
                  row.departmentName ?? row.departmentDisplayId ?? '—',
                ),
              ),
              AppListTableColumn<HrStaffProfile>(
                id: 'position',
                label: l10n.hrPositionLabel,
                preferredWidth: 160,
                cellBuilder: (BuildContext context, HrStaffProfile row) => Text(
                  (row.position ?? '').trim().isEmpty ? '—' : row.position!,
                ),
              ),
            ],
            mobileItemBuilder: (BuildContext context, HrStaffProfile row) {
              return AppListTableMobileItem(
                title: row.displayName,
                caption: row.staffNumber ?? row.effectiveId,
                leading: Radio<String>(
                  value: row.effectiveId,
                  groupValue: _selectedStaffId,
                  onChanged: _assigning || _loadingRoster
                      ? null
                      : (_) => unawaited(_selectStaff(row)),
                ),
                meta: <AppListTableMobileMeta>[
                  if ((row.departmentName ?? '').trim().isNotEmpty)
                    AppListTableMobileMeta(label: row.departmentName!),
                  if ((row.position ?? '').trim().isNotEmpty)
                    AppListTableMobileMeta(label: row.position!),
                ],
              );
            },
          ),
          if (_selectedStaffId != null) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            if (_loadingRoster)
              const Center(child: CircularProgressIndicator())
            else if (hasRoster)
              AppFormInformationBanner(
                title: l10n.hrAssignRosterSelectedRosterTitle,
                message: <String>[
                  _selectedRosterName ?? _selectedRosterId!,
                  if ((_selectedRosterPeriod ?? '').trim().isNotEmpty)
                    _selectedRosterPeriod!,
                  _selectedRosterId!,
                ].join(' · '),
                variant: AppFormInformationVariant.info,
              )
            else
              AppFormInformationBanner(
                title: l10n.hrAssignRosterSourceStaffNoRosterTitle,
                message: l10n.hrAssignRosterSourceStaffNoRosterBody,
                variant: AppFormInformationVariant.warning,
              ),
          ],
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: Icons.close,
          onPressed: _assigning ? null : () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: _isChange
              ? l10n.hrChangeRosterConfirmAction
              : l10n.hrAddRosterConfirmAction,
          leadingIcon: _isChange
              ? Icons.edit_calendar_outlined
              : Icons.person_add_alt_1_outlined,
          onPressed: _assigning || !hasRoster
              ? null
              : () => unawaited(_confirm()),
        ),
      ],
    );
  }
}
