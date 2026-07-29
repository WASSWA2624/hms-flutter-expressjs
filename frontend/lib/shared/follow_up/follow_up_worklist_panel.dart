import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/controllers/reception_follow_up_controller.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_follow_up_detail_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';

/// Scoped Follow-ups worklist for clinical workspaces.
///
/// Pass [scope] with an encounter type (`OPD`, `IPD`, `ICU`, `THEATRE`) or an
/// empty scope for hospital-wide lists. Unauthorized callers see nothing.
///
/// Defaults use Reception front-desk gates. Clinical hosts should pass
/// clinical follow-up read/write requirements instead.
class FollowUpWorklistPanel extends ConsumerStatefulWidget {
  const FollowUpWorklistPanel({
    required this.scope,
    this.storageKeyPrefix = 'follow_up_worklist',
    this.readRequirement = receptionFollowUpsRequirement,
    this.writeRequirement = receptionFrontDeskWriteRequirement,
    super.key,
  });

  final FollowUpWorklistScope scope;
  final String storageKeyPrefix;
  final AccessRequirement readRequirement;
  final AccessRequirement writeRequirement;

  @override
  ConsumerState<FollowUpWorklistPanel> createState() =>
      _FollowUpWorklistPanelState();
}

class _FollowUpWorklistPanelState extends ConsumerState<FollowUpWorklistPanel> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
  });

  final FollowUpWorklistScope scope;
  final String storageKeyPrefix;
  final TextEditingController searchController;
  final AccessRequirement writeRequirement;

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
            final List<ReceptionFollowUpEntry> entries = state.entries;
            if (entries.isEmpty) {
              return AppStateView(
                title: l10n.receptionFollowUpsEmptyTitle,
                body: l10n.receptionFollowUpsEmptyBody,
                variant: AppStateViewVariant.empty,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: theme.spacing.sm),
                AppListTable<ReceptionFollowUpEntry>(
                  items: entries,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  columnVisibilityStorageKey: '${storageKeyPrefix}_cols',
                  columnWidthStorageKey: '${storageKeyPrefix}_cw',
                  columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
                  columnVisibilityTitle: l10n.commonTableSettingsTitle,
                  columnVisibilityApplyLabel: l10n.receptionApplyColumnsAction,
                  columnVisibilityResetLabel: l10n.receptionResetColumnsAction,
                  columnVisibilityCloseLabel: l10n.commonCloseActionLabel,
                  itemKeyBuilder: (ReceptionFollowUpEntry entry) =>
                      ValueKey<String>(entry.id),
                  onRowSelected: (ReceptionFollowUpEntry entry) {
                    unawaited(
                      _openDetail(context, ref, entry, writeRequirement),
                    );
                  },
                  mobileItemBuilder:
                      (BuildContext context, ReceptionFollowUpEntry entry) {
                        return _FollowUpMobileRow(entry: entry, locale: locale);
                      },
                  search: AppListTableSearch<ReceptionFollowUpEntry>(
                    controller: searchController,
                    semanticLabel: l10n.receptionFollowUpsSearchHint,
                    hintText: l10n.receptionFollowUpsSearchHint,
                    clearLabel: l10n.receptionClearFiltersAction,
                    matcher: (ReceptionFollowUpEntry entry, String query) {
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
                      ].any(
                        (String? value) =>
                            value?.toLowerCase().contains(q) ?? false,
                      );
                    },
                  ),
                  columns: <AppListTableColumn<ReceptionFollowUpEntry>>[
                    AppListTableColumn<ReceptionFollowUpEntry>(
                      id: 'patient',
                      label: l10n.opdPatientNameLabel,
                      alwaysVisible: true,
                      cellBuilder:
                          (
                            BuildContext context,
                            ReceptionFollowUpEntry entry,
                          ) {
                            return AppListItemText(
                              title:
                                  entry.patientDisplayName?.trim().isNotEmpty ==
                                      true
                                  ? entry.patientDisplayName!.trim()
                                  : l10n.profileUnknownValue,
                              subtitle: entry.patientIdentifier,
                            );
                          },
                    ),
                    AppListTableColumn<ReceptionFollowUpEntry>(
                      id: 'phone',
                      label: l10n.patientsPhoneLabel,
                      cellBuilder:
                          (
                            BuildContext context,
                            ReceptionFollowUpEntry entry,
                          ) {
                            return Text(
                              entry.patientPhone?.trim().isNotEmpty == true
                                  ? entry.patientPhone!.trim()
                                  : l10n.profileUnknownValue,
                            );
                          },
                    ),
                    AppListTableColumn<ReceptionFollowUpEntry>(
                      id: 'email',
                      label: l10n.patientsEmailLabel,
                      cellBuilder:
                          (
                            BuildContext context,
                            ReceptionFollowUpEntry entry,
                          ) {
                            return Text(
                              entry.patientEmail?.trim().isNotEmpty == true
                                  ? entry.patientEmail!.trim()
                                  : l10n.profileUnknownValue,
                            );
                          },
                    ),
                    AppListTableColumn<ReceptionFollowUpEntry>(
                      id: 'date',
                      label: l10n.opdFollowUpDateLabel,
                      cellBuilder:
                          (
                            BuildContext context,
                            ReceptionFollowUpEntry entry,
                          ) {
                            return Text(
                              AppFormatters.shortDate(
                                entry.scheduledAt.toLocal(),
                                locale,
                              ),
                            );
                          },
                    ),
                    AppListTableColumn<ReceptionFollowUpEntry>(
                      id: 'time',
                      label: l10n.opdFollowUpTimeLabel,
                      cellBuilder:
                          (
                            BuildContext context,
                            ReceptionFollowUpEntry entry,
                          ) {
                            return Text(
                              AppFormatters.time(
                                entry.scheduledAt.toLocal(),
                                locale,
                              ),
                            );
                          },
                    ),
                  ],
                ),
              ],
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
