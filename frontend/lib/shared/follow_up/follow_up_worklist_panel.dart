import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_follow_up_controller.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_follow_up_detail_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Scoped Follow-ups worklist for clinical workspaces.
///
/// Pass [scope] with an encounter type (`OPD`, `IPD`, `ICU`, `THEATRE`) or an
/// empty scope for hospital-wide lists. Unauthorized callers see nothing.
///
/// Defaults use Reception front-desk gates. Clinical hosts should pass
/// clinical follow-up read/write requirements instead.
///
/// When [onNarrowedCountChanged] is set, the host receives `null` for the
/// unfiltered scope total and the visible membership length when search or
/// advanced filters narrow the list (tabs.mdc active-badge rule).
class FollowUpWorklistPanel extends ConsumerStatefulWidget {
  const FollowUpWorklistPanel({
    required this.scope,
    this.storageKeyPrefix = 'follow_up_worklist',
    this.readRequirement = receptionFollowUpsRequirement,
    this.writeRequirement = receptionFrontDeskWriteRequirement,
    this.createAction,
    this.showAdvancedFilterButton = false,
    this.advancedFilterButtonLabel,
    this.advancedFilterTitle,
    this.advancedFilterApplyLabel,
    this.advancedFilterResetLabel,
    this.advancedFilterCloseLabel,
    this.enableDateFilter = false,
    this.dateFilterLabel,
    this.dateFromLabel,
    this.dateToLabel,
    this.textFilters = const <AppSearchBarTextFilter>[],
    this.filterGroups = const <AppSearchBarFilterGroup>[],
    this.onSettingsPressed,
    this.canExport = true,
    this.enableExport = true,
    this.enablePrint = false,
    this.canPrint = true,
    this.printLabel,
    this.onPrint,
    this.onNarrowedCountChanged,
    super.key,
  });

  final FollowUpWorklistScope scope;
  final String storageKeyPrefix;
  final AccessRequirement readRequirement;
  final AccessRequirement writeRequirement;
  final AppSearchBarAction? createAction;
  final bool showAdvancedFilterButton;
  final String? advancedFilterButtonLabel;
  final String? advancedFilterTitle;
  final String? advancedFilterApplyLabel;
  final String? advancedFilterResetLabel;
  final String? advancedFilterCloseLabel;
  final bool enableDateFilter;
  final String? dateFilterLabel;
  final String? dateFromLabel;
  final String? dateToLabel;
  final List<AppSearchBarTextFilter> textFilters;
  final List<AppSearchBarFilterGroup> filterGroups;
  final Future<void> Function()? onSettingsPressed;
  final bool canExport;
  final bool enableExport;
  final bool enablePrint;
  final bool canPrint;
  final String? printLabel;
  final Future<void> Function(List<ReceptionFollowUpEntry> entries)? onPrint;
  final ValueChanged<int?>? onNarrowedCountChanged;

  @override
  ConsumerState<FollowUpWorklistPanel> createState() =>
      _FollowUpWorklistPanelState();
}

class _FollowUpWorklistPanelState extends ConsumerState<FollowUpWorklistPanel> {
  final TextEditingController _searchController = TextEditingController();
  AppSearchBarFilterValue _filterValue = AppSearchBarFilterValue.empty;
  int? _lastReportedCount;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _reportNarrowedCount({
    required int visibleCount,
    required bool narrowed,
  }) {
    final ValueChanged<int?>? callback = widget.onNarrowedCountChanged;
    if (callback == null) {
      return;
    }
    final int? next = narrowed ? visibleCount : null;
    if (next == _lastReportedCount) {
      return;
    }
    _lastReportedCount = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      callback(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppAccessActionGate(
      requirement: widget.readRequirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }
        return _FollowUpWorklistBody(
          scope: widget.scope,
          storageKeyPrefix: widget.storageKeyPrefix,
          searchController: _searchController,
          writeRequirement: widget.writeRequirement,
          createAction: widget.createAction,
          showAdvancedFilterButton: widget.showAdvancedFilterButton,
          advancedFilterButtonLabel: widget.advancedFilterButtonLabel,
          advancedFilterTitle: widget.advancedFilterTitle,
          advancedFilterApplyLabel: widget.advancedFilterApplyLabel,
          advancedFilterResetLabel: widget.advancedFilterResetLabel,
          advancedFilterCloseLabel: widget.advancedFilterCloseLabel,
          enableDateFilter: widget.enableDateFilter,
          dateFilterLabel: widget.dateFilterLabel,
          dateFromLabel: widget.dateFromLabel,
          dateToLabel: widget.dateToLabel,
          textFilters: widget.textFilters,
          filterGroups: widget.filterGroups,
          onSettingsPressed: widget.onSettingsPressed,
          canExport: widget.canExport,
          enableExport: widget.enableExport,
          enablePrint: widget.enablePrint,
          canPrint: widget.canPrint,
          printLabel: widget.printLabel,
          onPrint: widget.onPrint,
          filterValue: _filterValue,
          onFilterChanged: (AppSearchBarFilterValue value) {
            setState(() => _filterValue = value);
          },
          onVisibleCountResolved: _reportNarrowedCount,
        );
      },
    );
  }
}

class _FollowUpWorklistBody extends ConsumerWidget {
  const _FollowUpWorklistBody({
    required this.scope,
    required this.storageKeyPrefix,
    required this.searchController,
    required this.writeRequirement,
    required this.filterValue,
    required this.onFilterChanged,
    required this.onVisibleCountResolved,
    this.createAction,
    this.showAdvancedFilterButton = false,
    this.advancedFilterButtonLabel,
    this.advancedFilterTitle,
    this.advancedFilterApplyLabel,
    this.advancedFilterResetLabel,
    this.advancedFilterCloseLabel,
    this.enableDateFilter = false,
    this.dateFilterLabel,
    this.dateFromLabel,
    this.dateToLabel,
    this.textFilters = const <AppSearchBarTextFilter>[],
    this.filterGroups = const <AppSearchBarFilterGroup>[],
    this.onSettingsPressed,
    this.canExport = true,
    this.enableExport = true,
    this.enablePrint = false,
    this.canPrint = true,
    this.printLabel,
    this.onPrint,
  });

  final FollowUpWorklistScope scope;
  final String storageKeyPrefix;
  final TextEditingController searchController;
  final AccessRequirement writeRequirement;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue> onFilterChanged;
  final void Function({required int visibleCount, required bool narrowed})
  onVisibleCountResolved;
  final AppSearchBarAction? createAction;
  final bool showAdvancedFilterButton;
  final String? advancedFilterButtonLabel;
  final String? advancedFilterTitle;
  final String? advancedFilterApplyLabel;
  final String? advancedFilterResetLabel;
  final String? advancedFilterCloseLabel;
  final bool enableDateFilter;
  final String? dateFilterLabel;
  final String? dateFromLabel;
  final String? dateToLabel;
  final List<AppSearchBarTextFilter> textFilters;
  final List<AppSearchBarFilterGroup> filterGroups;
  final Future<void> Function()? onSettingsPressed;
  final bool canExport;
  final bool enableExport;
  final bool enablePrint;
  final bool canPrint;
  final String? printLabel;
  final Future<void> Function(List<ReceptionFollowUpEntry> entries)? onPrint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Locale locale = Localizations.localeOf(context);
    final AsyncValue<Result<ReceptionFollowUpState>> asyncState = ref.watch(
      scopedFollowUpControllerProvider(scope),
    );

    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => AppStateView(
        title: l10n.errorUnexpectedTitle,
        body: l10n.errorUnexpectedMessage,
        variant: AppStateViewVariant.error,
        action: AppButton.secondary(
          label: l10n.commonRetryActionLabel,
          onPressed: () => unawaited(refreshScopedFollowUps(ref, scope)),
        ),
      ),
      data: (Result<ReceptionFollowUpState> result) {
        return result.when(
          failure: (AppFailure failure) => AppStateView(
            title: l10n.errorUnexpectedTitle,
            body: l10n.errorUnexpectedMessage,
            variant: AppStateViewVariant.error,
            action: AppButton.secondary(
              label: l10n.commonRetryActionLabel,
              onPressed: () => unawaited(refreshScopedFollowUps(ref, scope)),
            ),
          ),
          success: (ReceptionFollowUpState state) {
            final List<ReceptionFollowUpEntry> advancedFiltered =
                _filterFollowUpEntries(state.entries, filterValue);
            final String query = searchController.text.trim();
            final List<ReceptionFollowUpEntry> visibleEntries = query.isEmpty
                ? advancedFiltered
                : advancedFiltered
                      .where(
                        (ReceptionFollowUpEntry entry) =>
                            _matchesFollowUpSearch(entry, query),
                      )
                      .toList(growable: false);
            final bool narrowed =
                filterValue.isActive || query.isNotEmpty;
            onVisibleCountResolved(
              visibleCount: visibleEntries.length,
              narrowed: narrowed,
            );

            final List<AppListTableColumn<ReceptionFollowUpEntry>> columns =
                _followUpDefaultColumns(l10n, locale);
            final List<AppListTableColumn<ReceptionFollowUpEntry>> choices =
                _followUpColumnChoices(l10n);

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool boundedHeight = constraints.hasBoundedHeight;
                final Widget table = AppListTable<ReceptionFollowUpEntry>(
                  items: advancedFiltered,
                  shrinkWrap: !boundedHeight,
                  physics: boundedHeight
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  columnVisibilityStorageKey: '${storageKeyPrefix}_cols',
                  columnWidthStorageKey: '${storageKeyPrefix}_cw',
                  columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
                  columnVisibilityTitle: l10n.commonTableSettingsTitle,
                  columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
                  columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
                  columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
                  onSettingsPressed: onSettingsPressed,
                  enableExport: enableExport,
                  canExport: canExport,
                  enablePrint: enablePrint && onPrint != null,
                  canPrint: canPrint,
                  exportLabel: l10n.commonTableExportActionLabel,
                  exportDialogTitle: l10n.commonTableExportDialogTitle,
                  exportCancelLabel: l10n.commonCancelActionLabel,
                  exportColumnsSectionLabel:
                      l10n.commonTableExportColumnsSectionLabel,
                  exportFiltersSectionLabel:
                      l10n.commonTableExportFiltersSectionLabel,
                  exportEmptyColumnsMessage:
                      l10n.commonTableExportEmptyColumnsMessage,
                  exportEmptyRowsMessage:
                      l10n.commonTableExportEmptyRowsMessage,
                  exportSuccessMessage: l10n.commonTableExportSuccessMessage,
                  exportFailureMessage: l10n.commonTableExportFailureMessage,
                  printLabel: printLabel ?? l10n.commonPrintActionLabel,
                  onPrint: onPrint == null
                      ? null
                      : (List<ReceptionFollowUpEntry> items) => onPrint!(items),
                  goToTopLabel: l10n.commonGoToTopActionLabel,
                  loadingMoreLabel: l10n.commonLoadingMoreLabel,
                  allRowsLoadedLabel: l10n.commonAllRowsLoadedLabel,
                  exportConfig: AppListTableExportConfig<ReceptionFollowUpEntry>(
                    fileNameStem: storageKeyPrefix,
                    items: visibleEntries,
                    dateOf: (ReceptionFollowUpEntry entry) => entry.scheduledAt,
                    dateFromLabel: l10n.commonTableExportDateFromLabel,
                    dateToLabel: l10n.commonTableExportDateToLabel,
                    rowFilter:
                        (
                          ReceptionFollowUpEntry entry,
                          AppSearchBarFilterValue filters,
                        ) {
                      return _filterFollowUpEntries(
                        <ReceptionFollowUpEntry>[entry],
                        filters,
                      ).isNotEmpty;
                    },
                  ),
                  itemKeyBuilder: (ReceptionFollowUpEntry entry) =>
                      ValueKey<String>(entry.id),
                  onRowSelected: (ReceptionFollowUpEntry entry) {
                    unawaited(
                      _openDetail(context, ref, entry, writeRequirement),
                    );
                  },
                  emptyBuilder: (_) => AppStateView(
                    title: l10n.receptionFollowUpsEmptyTitle,
                    body: l10n.receptionFollowUpsEmptyBody,
                    variant: AppStateViewVariant.empty,
                  ),
                  mobileItemBuilder:
                      (BuildContext context, ReceptionFollowUpEntry entry) {
                        return _FollowUpMobileRow(
                          entry: entry,
                          locale: locale,
                        );
                      },
                  search: AppListTableSearch<ReceptionFollowUpEntry>(
                    controller: searchController,
                    semanticLabel: l10n.receptionFollowUpsSearchHint,
                    hintText: l10n.receptionFollowUpsSearchHint,
                    clearLabel: l10n.receptionClearFiltersAction,
                    showAdvancedFilterButton: showAdvancedFilterButton,
                    advancedFilterButtonLabel: advancedFilterButtonLabel,
                    advancedFilterTitle: advancedFilterTitle,
                    advancedFilterApplyLabel: advancedFilterApplyLabel,
                    advancedFilterResetLabel: advancedFilterResetLabel,
                    advancedFilterCloseLabel: advancedFilterCloseLabel,
                    enableDateFilter: enableDateFilter,
                    dateFilterLabel: dateFilterLabel,
                    dateFromLabel: dateFromLabel,
                    dateToLabel: dateToLabel,
                    textFilters: textFilters,
                    filterGroups: filterGroups,
                    filterValue: filterValue,
                    onFilterChanged: onFilterChanged,
                    hasActiveFilters:
                        filterValue.isActive &&
                        (filterValue.dateFrom != null ||
                            filterValue.dateTo != null ||
                            filterValue.texts.values.any(
                              (String? value) =>
                                  value?.trim().isNotEmpty == true,
                            ) ||
                            filterValue.options.values.any(
                              (String? value) =>
                                  value?.trim().isNotEmpty == true,
                            )),
                    trailingActions: <AppSearchBarAction>[?createAction],
                    matcher: _matchesFollowUpSearch,
                  ),
                  columns: columns,
                  columnChoices: choices,
                );

                if (boundedHeight) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(height: theme.spacing.sm),
                      Expanded(child: table),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(height: theme.spacing.sm),
                    table,
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    WidgetRef ref,
    ReceptionFollowUpEntry entry,
    AccessRequirement writeRequirement,
  ) async {
    final bool? changed = await showReceptionFollowUpDetailDialog(
      context: context,
      entry: entry,
      writeRequirement: writeRequirement,
    );
    if (changed == true) {
      await refreshScopedFollowUps(ref, scope);
    }
  }
}

bool _matchesFollowUpSearch(ReceptionFollowUpEntry entry, String query) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return true;
  }
  return <String?>[
    entry.patientDisplayName,
    entry.patientIdentifier,
    entry.patientPhone,
    entry.patientEmail,
    entry.notes,
    entry.status,
  ].any((String? value) => value?.toLowerCase().contains(q) ?? false);
}

List<AppListTableColumn<ReceptionFollowUpEntry>> _followUpDefaultColumns(
  AppLocalizations l10n,
  Locale locale,
) {
  return <AppListTableColumn<ReceptionFollowUpEntry>>[
    AppListTableColumn<ReceptionFollowUpEntry>(
      id: 'patient',
      label: l10n.opdPatientNameLabel,
      alwaysVisible: true,
      exportValue: (ReceptionFollowUpEntry entry) =>
          entry.patientDisplayName?.trim().isNotEmpty == true
          ? entry.patientDisplayName!.trim()
          : l10n.profileUnknownValue,
      cellBuilder: (BuildContext context, ReceptionFollowUpEntry entry) {
        return AppListItemText(
          title: entry.patientDisplayName?.trim().isNotEmpty == true
              ? entry.patientDisplayName!.trim()
              : l10n.profileUnknownValue,
        );
      },
    ),
    AppListTableColumn<ReceptionFollowUpEntry>(
      id: 'phone',
      label: l10n.patientsPhoneIdentifierColumnLabel,
      exportValue: (ReceptionFollowUpEntry entry) =>
          entry.patientPhone?.trim() ?? '',
      cellBuilder: (BuildContext context, ReceptionFollowUpEntry entry) {
        return Text(
          entry.patientPhone?.trim().isNotEmpty == true
              ? entry.patientPhone!.trim()
              : l10n.profileUnknownValue,
        );
      },
    ),
    AppListTableColumn<ReceptionFollowUpEntry>(
      id: 'status',
      label: l10n.receptionStatusLabel,
      exportValue: (ReceptionFollowUpEntry entry) =>
          opdStageDisplayLabel(l10n, entry.status),
      cellBuilder: (BuildContext context, ReceptionFollowUpEntry entry) {
        return Text(opdStageDisplayLabel(l10n, entry.status));
      },
    ),
    AppListTableColumn<ReceptionFollowUpEntry>(
      id: 'date',
      label: l10n.opdFollowUpDateLabel,
      exportValue: (ReceptionFollowUpEntry entry) =>
          AppFormatters.shortDate(entry.scheduledAt.toLocal(), locale),
      cellBuilder: (BuildContext context, ReceptionFollowUpEntry entry) {
        return Text(
          AppFormatters.shortDate(entry.scheduledAt.toLocal(), locale),
        );
      },
    ),
    AppListTableColumn<ReceptionFollowUpEntry>(
      id: 'time',
      label: l10n.opdFollowUpTimeLabel,
      exportValue: (ReceptionFollowUpEntry entry) =>
          AppFormatters.time(entry.scheduledAt.toLocal(), locale),
      cellBuilder: (BuildContext context, ReceptionFollowUpEntry entry) {
        return Text(AppFormatters.time(entry.scheduledAt.toLocal(), locale));
      },
    ),
  ];
}

List<AppListTableColumn<ReceptionFollowUpEntry>> _followUpColumnChoices(
  AppLocalizations l10n,
) {
  return <AppListTableColumn<ReceptionFollowUpEntry>>[
    AppListTableColumn<ReceptionFollowUpEntry>(
      id: 'patient_id',
      label: l10n.opdPatientIdLabel,
      exportValue: (ReceptionFollowUpEntry entry) => entry.patientIdentifier,
      cellBuilder: (BuildContext context, ReceptionFollowUpEntry entry) {
        return Text(
          entry.patientIdentifier.trim().isNotEmpty
              ? entry.patientIdentifier.trim()
              : l10n.profileUnknownValue,
        );
      },
    ),
    AppListTableColumn<ReceptionFollowUpEntry>(
      id: 'email',
      label: l10n.patientsEmailLabel,
      exportValue: (ReceptionFollowUpEntry entry) =>
          entry.patientEmail?.trim() ?? '',
      cellBuilder: (BuildContext context, ReceptionFollowUpEntry entry) {
        return Text(
          entry.patientEmail?.trim().isNotEmpty == true
              ? entry.patientEmail!.trim()
              : l10n.profileUnknownValue,
        );
      },
    ),
    AppListTableColumn<ReceptionFollowUpEntry>(
      id: 'notes',
      label: l10n.opdNotesLabel,
      exportValue: (ReceptionFollowUpEntry entry) => entry.notes?.trim() ?? '',
      cellBuilder: (BuildContext context, ReceptionFollowUpEntry entry) {
        final bool hasNotes = entry.notes?.trim().isNotEmpty == true;
        return Text(
          hasNotes ? l10n.commonYesLabel : l10n.profileUnknownValue,
        );
      },
    ),
  ];
}

List<ReceptionFollowUpEntry> _filterFollowUpEntries(
  List<ReceptionFollowUpEntry> entries,
  AppSearchBarFilterValue filterValue,
) {
  if (!filterValue.isActive) {
    return entries;
  }
  final String? status = filterValue.option('follow_up_status')?.toLowerCase();
  final String patient =
      (filterValue.text('patient') ?? '').trim().toLowerCase();
  final String patientId =
      (filterValue.text('patient_id') ?? '').trim().toLowerCase();
  final String phone = (filterValue.text('phone') ?? '').trim().toLowerCase();
  final DateTime? from = filterValue.dateFrom;
  final DateTime? to = filterValue.dateTo;

  return entries.where((ReceptionFollowUpEntry entry) {
    if (status != null && status.isNotEmpty) {
      final String actual = entry.status.trim().toLowerCase();
      final bool completed =
          actual == 'completed' || actual == 'done' || actual == 'closed';
      if (status == 'completed' && !completed) {
        return false;
      }
      if (status == 'pending' && completed) {
        return false;
      }
    }
    if (patient.isNotEmpty) {
      final String name = (entry.patientDisplayName ?? '').toLowerCase();
      if (!name.contains(patient)) {
        return false;
      }
    }
    if (patientId.isNotEmpty) {
      if (!entry.patientIdentifier.toLowerCase().contains(patientId)) {
        return false;
      }
    }
    if (phone.isNotEmpty) {
      final String value = (entry.patientPhone ?? '').toLowerCase();
      if (!value.contains(phone)) {
        return false;
      }
    }
    if (from != null || to != null) {
      final DateTime scheduled = entry.scheduledAt.toLocal();
      if (from != null && scheduled.isBefore(from)) {
        return false;
      }
      if (to != null) {
        final DateTime end = DateTime(to.year, to.month, to.day, 23, 59, 59);
        if (scheduled.isAfter(end)) {
          return false;
        }
      }
    }
    return true;
  }).toList(growable: false);
}

class _FollowUpMobileRow extends StatelessWidget {
  const _FollowUpMobileRow({required this.entry, required this.locale});

  final ReceptionFollowUpEntry entry;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DateTime local = entry.scheduledAt.toLocal();
    final String? phone = entry.patientPhone?.trim();
    return AppListTableMobileItem(
      title: entry.patientDisplayName?.trim().isNotEmpty == true
          ? entry.patientDisplayName!.trim()
          : l10n.profileUnknownValue,
      caption: entry.patientIdentifier.trim().isNotEmpty
          ? entry.patientIdentifier.trim()
          : null,
      meta: <AppListTableMobileMeta>[
        if (phone != null && phone.isNotEmpty)
          AppListTableMobileMeta(label: phone, icon: Icons.phone_outlined),
        AppListTableMobileMeta(
          label: AppDisplay.apiLabel(entry.status),
          icon: Icons.flag_outlined,
        ),
        AppListTableMobileMeta(
          label: AppFormatters.shortDate(local, locale),
          icon: AppActionIcons.calendar,
        ),
        AppListTableMobileMeta(
          label: AppFormatters.time(local, locale),
          icon: AppActionIcons.time,
        ),
      ],
    );
  }
}
