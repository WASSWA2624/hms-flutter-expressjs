import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/controllers/icu_workspace_controller.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_action_dialogs.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_bed_board_panel.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_board_panel.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_detail_panel.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class IcuWorkspacePage extends ConsumerStatefulWidget {
  const IcuWorkspacePage({super.key, this.initialQuery});

  final IcuBoardQuery? initialQuery;

  @override
  ConsumerState<IcuWorkspacePage> createState() => _IcuWorkspacePageState();
}

class _IcuWorkspacePageState extends ConsumerState<IcuWorkspacePage> {
  bool _deepLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _scheduleDeepLink();
  }

  void _scheduleDeepLink() {
    final IcuBoardQuery? query = widget.initialQuery;
    if (query == null || !query.hasRouteTargeting || _deepLinkHandled) {
      return;
    }
    _deepLinkHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_handleDeepLink(query));
    });
  }

  Future<void> _handleDeepLink(IcuBoardQuery query) async {
    final String? focusId = query.focusAdmissionId?.trim();
    if (focusId == null || focusId.isEmpty) {
      return;
    }

    final Result<IcuWorkspaceState> loadResult = await ref.read(
      icuWorkspaceControllerProvider.future,
    );
    if (!mounted || loadResult.isFailure) {
      return;
    }

    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final AppFailure? failure = await controller.selectPatientByDisplayId(
      focusId,
    );
    if (!mounted || failure != null) {
      return;
    }
    final IcuWorkspaceState? state = readIcuWorkspaceState(ref);
    if (state?.selectedDetail == null) {
      return;
    }
    final IcuPatientSummary summary = state!.selectedDetail!.summary;
    final IcuWorkspaceSection section =
        IcuWorkspaceSectionX.fromQueryParam(query.section);
    final AccessRequirement writeRequirement =
        IcuWorkspaceWriteRequirement.writeRequirement;

    // Panel-focused deep links open the mutation dialog directly (no empty
    // detail shell). Bare admission links open detail with the stage
    // next-action omitted so it is not duplicated inside Quick Actions.
    if (query.focusPanel != null) {
      await openIcuFocusedAction(
        context,
        ref,
        state,
        summary,
        query.focusPanel!,
      );
      return;
    }

    await openIcuDetailDialog(
      context,
      ref,
      state,
      summary,
      writeRequirement,
      omitNextActionKind: icuBoardNextActionKind(summary, section),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Result<IcuWorkspaceState>> state = ref.watch(
      icuWorkspaceControllerProvider,
    );
    final AppLocalizations l10n = context.l10n;

    return AsyncStateScaffold<IcuWorkspaceState>(
      value: state,
      loadingTitle: l10n.icuLoadingBoardTitle,
      loadingBody: l10n.icuLoadingBoardBody,
      maxWidth: PageMaxWidth.dataHeavy,
      centerVertically: false,
      onRetry: () {
        ref.read(icuWorkspaceControllerProvider.notifier).refresh();
      },
      dataBuilder: (BuildContext context, IcuWorkspaceState data) {
        return _IcuWorkspaceContent(
          state: data,
          initialQuery: widget.initialQuery,
        );
      },
    );
  }
}

class _IcuWorkspaceContent extends ConsumerStatefulWidget {
  const _IcuWorkspaceContent({required this.state, this.initialQuery});

  final IcuWorkspaceState state;
  final IcuBoardQuery? initialQuery;

  @override
  ConsumerState<_IcuWorkspaceContent> createState() =>
      _IcuWorkspaceContentState();
}

class _IcuWorkspaceContentState extends ConsumerState<_IcuWorkspaceContent> {
  late final TextEditingController _searchController;
  late IcuWorkspaceSection _section;
  late final AppListTableColumnVisibilityController<IcuPatientSummary>
  _columnVisibilityController;
  AppSearchBarFilterValue _boardFilterValue = AppSearchBarFilterValue.empty;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.state.query.search);
    _section = IcuWorkspaceSectionX.fromQueryParam(widget.initialQuery?.section);
    _columnVisibilityController =
        AppListTableColumnVisibilityController<IcuPatientSummary>();

    final IcuBoardScope? scope = _section.toBoardScope();
    if (scope != null && scope != widget.state.query.scope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(icuWorkspaceControllerProvider.notifier).applyScope(scope);
      });
    }
    if (_section.isBedBoard && widget.state.bedBoard.beds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(icuWorkspaceControllerProvider.notifier).loadBedBoard();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _IcuWorkspaceContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query.search != widget.state.query.search &&
        _searchController.text != widget.state.query.search) {
      _searchController.text = widget.state.query.search;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _columnVisibilityController.dispose();
    super.dispose();
  }

  void _updateUrlForSection(IcuWorkspaceSection section) {
    if (!mounted) return;
    final String tab = section.queryValue;
    final String location = AppRoutes.icu.location(
      queryParameters: <String, String>{if (tab != 'active') 'section': tab},
    );
    GoRouter.of(context).replace<void>(location);
  }

  String _sectionLabel(AppLocalizations l10n, IcuWorkspaceSection section) {
    return switch (section) {
      IcuWorkspaceSection.active => l10n.icuActiveIcuLabel,
      IcuWorkspaceSection.critical => l10n.icuCriticalAlertsLabel,
      IcuWorkspaceSection.transfers => l10n.icuTransfersLabel,
      IcuWorkspaceSection.discharge => l10n.icuDischargeReadyLabel,
      IcuWorkspaceSection.ended => l10n.icuEndedStaysLabel,
      IcuWorkspaceSection.all => l10n.icuAllIcuLabel,
      IcuWorkspaceSection.beds => l10n.icuViewBedBoard,
      IcuWorkspaceSection.followUps => l10n.opdFollowUpsTitle,
    };
  }

  static IconData _sectionIcon(IcuWorkspaceSection section) {
    return switch (section) {
      IcuWorkspaceSection.active => Icons.bed_outlined,
      IcuWorkspaceSection.critical => Icons.priority_high_outlined,
      IcuWorkspaceSection.transfers => Icons.compare_arrows_outlined,
      IcuWorkspaceSection.discharge => Icons.fact_check_outlined,
      IcuWorkspaceSection.ended => Icons.output_outlined,
      IcuWorkspaceSection.all => Icons.inventory_2_outlined,
      IcuWorkspaceSection.beds => Icons.bed_outlined,
      IcuWorkspaceSection.followUps => Icons.phone_callback_outlined,
    };
  }

  int? _sectionCount(IcuWorkspaceState state, IcuWorkspaceSection section) {
    if (section.isFollowUps) {
      return null;
    }
    return switch (section) {
      IcuWorkspaceSection.active => state.activeCount,
      IcuWorkspaceSection.critical => state.criticalCount,
      IcuWorkspaceSection.transfers => state.transferCount,
      IcuWorkspaceSection.discharge => state.dischargeReadyCount,
      IcuWorkspaceSection.ended =>
        state.board.items
            .where((IcuPatientSummary item) => item.isEndedIcu)
            .length,
      IcuWorkspaceSection.all => _pageTotal(state.board),
      IcuWorkspaceSection.beds => state.bedBoard.beds.length,
      IcuWorkspaceSection.followUps => null,
    };
  }

  static AppTabCountTone _sectionCountTone(IcuWorkspaceSection section) {
    return switch (section) {
      IcuWorkspaceSection.critical => AppTabCountTone.danger,
      IcuWorkspaceSection.active ||
      IcuWorkspaceSection.transfers ||
      IcuWorkspaceSection.discharge => AppTabCountTone.warning,
      IcuWorkspaceSection.ended ||
      IcuWorkspaceSection.all ||
      IcuWorkspaceSection.beds ||
      IcuWorkspaceSection.followUps => AppTabCountTone.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final IcuWorkspaceState state = widget.state;
    final IcuWorkspaceController controller = ref.read(
      icuWorkspaceControllerProvider.notifier,
    );
    final bool isBedView = _section.isBedBoard;
    final bool isFollowUpsView = _section.isFollowUps;

    return ResponsivePage(
      maxWidth: PageMaxWidth.dataHeavy,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTabStrip(
              tabs: <AppTabItem>[
                for (final IcuWorkspaceSection section
                    in IcuWorkspaceSection.values)
                  AppTabItem(
                    id: section.name,
                    icon: _sectionIcon(section),
                    label: _sectionLabel(l10n, section),
                    count: section.isFollowUps
                        ? ref.watch(
                            followUpTabCountProvider(
                              const FollowUpWorklistScope(
                                encounterType: 'ICU',
                              ),
                            ),
                          )
                        : _sectionCount(state, section),
                    countTone: _sectionCountTone(section),
                  ),
              ],
              selectedId: _section.name,
              onTabTapped: (String tabId) {
                for (final IcuWorkspaceSection section
                    in IcuWorkspaceSection.values) {
                  if (section.name == tabId) {
                    setState(() => _section = section);
                    _updateUrlForSection(section);
                    if (section.isFollowUps) {
                      break;
                    }
                    final IcuBoardScope? scope = section.toBoardScope();
                    if (scope != null) {
                      controller.applyScope(scope);
                    }
                    if (section.isBedBoard && state.bedBoard.beds.isEmpty) {
                      controller.loadBedBoard();
                    }
                    break;
                  }
                }
              },
            ),
            SizedBox(height: theme.spacing.sm),
            if (isFollowUpsView)
              const FollowUpWorklistPanel(
                scope: FollowUpWorklistScope(encounterType: 'ICU'),
                storageKeyPrefix: 'icu_follow_ups',
              )
            else if (isBedView)
              IcuBedBoardPanel(state: state)
            else
              IcuBoardPanel(
                state: state,
                section: _section,
                writeRequirement: IcuWorkspaceWriteRequirement.writeRequirement,
                searchController: _searchController,
                columnVisibilityController: _columnVisibilityController,
                filterValue: _boardFilterValue,
                onFilterChanged: (AppSearchBarFilterValue value) {
                  setState(() => _boardFilterValue = value);
                },
              ),
          ],
        ),
      ),
    );
  }
}

int _pageTotal<T>(AppPage<T> page) => page.totalItemCount ?? page.items.length;
