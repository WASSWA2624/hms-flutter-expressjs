import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/reports/data/repositories/reports_repository_impl.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// In-place Overview shortcut dialogs (catalog / delivery / dataset) that do not
/// change the workspace panel away from Overview.
enum ReportsOverviewShortcutKind { catalog, delivery, dataset }

Future<void> openReportsOverviewShortcutDialog({
  required BuildContext context,
  required WidgetRef ref,
  required ReportsOverviewShortcutKind kind,
  String? datasetKey,
  String? title,
  required Future<void> Function(ReportsWorkspaceItem item) onOpenItem,
}) {
  final AppLocalizations l10n = context.l10n;
  final String? trimmedDataset = datasetKey?.trim();
  final String resolvedTitle =
      title ??
      switch (kind) {
        ReportsOverviewShortcutKind.catalog => l10n.reportsPanelCatalog,
        ReportsOverviewShortcutKind.delivery =>
          l10n.reportsOverviewViewDeliveryAction,
        ReportsOverviewShortcutKind.dataset =>
          (trimmedDataset != null && trimmedDataset.isNotEmpty)
              ? trimmedDataset
              : l10n.reportsPanelCatalog,
      };

  return showAppDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: Text(resolvedTitle),
      icon: Icon(switch (kind) {
        ReportsOverviewShortcutKind.catalog => Icons.library_books_outlined,
        ReportsOverviewShortcutKind.delivery => Icons.local_shipping_outlined,
        ReportsOverviewShortcutKind.dataset => Icons.insights_outlined,
      }),
      scrollable: true,
      maxWidth: 720,
      content: _ReportsOverviewShortcutDialogBody(
        kind: kind,
        datasetKey: datasetKey,
        onOpenItem: onOpenItem,
      ),
    ),
  );
}

class _ReportsOverviewShortcutDialogBody extends ConsumerStatefulWidget {
  const _ReportsOverviewShortcutDialogBody({
    required this.kind,
    required this.onOpenItem,
    this.datasetKey,
  });

  final ReportsOverviewShortcutKind kind;
  final String? datasetKey;
  final Future<void> Function(ReportsWorkspaceItem item) onOpenItem;

  @override
  ConsumerState<_ReportsOverviewShortcutDialogBody> createState() =>
      _ReportsOverviewShortcutDialogBodyState();
}

class _ReportsOverviewShortcutDialogBodyState
    extends ConsumerState<_ReportsOverviewShortcutDialogBody> {
  bool _loading = true;
  AppFailure? _failure;
  List<ReportsWorkspaceItem> _items = const <ReportsWorkspaceItem>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_load());
    });
  }

  ReportsWorkspaceQuery get _query {
    final String? dataset = widget.datasetKey?.trim();
    return switch (widget.kind) {
      ReportsOverviewShortcutKind.catalog => const ReportsWorkspaceQuery(
        panel: ReportsWorkspacePanel.catalog,
        resource: ReportsWorkspaceResource.reportDefinitions,
        pageRequest: AppPageRequest(pageSize: 25),
      ),
      ReportsOverviewShortcutKind.delivery => const ReportsWorkspaceQuery(
        panel: ReportsWorkspacePanel.delivery,
        resource: ReportsWorkspaceResource.reportRuns,
        pageRequest: AppPageRequest(pageSize: 25),
      ),
      ReportsOverviewShortcutKind.dataset => ReportsWorkspaceQuery(
        panel: ReportsWorkspacePanel.catalog,
        resource: ReportsWorkspaceResource.reportDefinitions,
        dataset: (dataset == null || dataset.isEmpty) ? null : dataset,
        pageRequest: const AppPageRequest(pageSize: 25),
      ),
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    final ReportsRepository repository = ref.read(reportsRepositoryProvider);
    final Result<ReportsWorkspaceOverview> result = await repository
        .getWorkspace(_query);
    if (!mounted) {
      return;
    }
    result.when(
      success: (ReportsWorkspaceOverview overview) {
        setState(() {
          _items = overview.items.items;
          _loading = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _loading = false;
          _items = const <ReportsWorkspaceItem>[];
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    if (_loading) {
      return AppLoadingIndicator(
        title: l10n.reportsLoadingTitle,
        body: l10n.reportsLoadingBody,
      );
    }

    if (_failure != null) {
      return AppWorkspaceStatePanel.error(
        title: l10n.reportsOverviewEmptyTitle,
        body: l10n.failureMessage(_failure!),
        icon: Icons.error_outline,
        action: AppButton.secondary(
          label: l10n.commonRetryActionLabel,
          leadingIcon: Icons.refresh,
          onPressed: () => unawaited(_load()),
        ),
      );
    }

    if (_items.isEmpty) {
      return AppWorkspaceStatePanel.empty(
        title: l10n.reportsOverviewEmptyTitle,
        body: l10n.reportsOverviewEmptyBody,
        icon: Icons.analytics_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ReportsWorkspaceItem item in _items) ...<Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.kind == ReportItemKind.run
                  ? Icons.play_circle_outline
                  : Icons.description_outlined,
            ),
            title: Text(item.title),
            subtitle: Text(
              <String?>[item.subtitle, item.status, item.datasetKey]
                  .whereType<String>()
                  .where((String value) => value.isNotEmpty)
                  .join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => unawaited(widget.onOpenItem(item)),
          ),
          Divider(height: theme.spacing.md, color: theme.borders.faint),
        ],
      ],
    );
  }
}
