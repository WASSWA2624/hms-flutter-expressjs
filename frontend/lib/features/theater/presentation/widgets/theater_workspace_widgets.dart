part of '../pages/theater_workspace_page.dart';

List<AppListTableColumn<TheaterCase>> defaultTheaterColumnsForSection(
  BuildContext context,
  TheaterSection section,
  bool canWrite,
) {
  final Set<String> ids = switch (section) {
    TheaterSection.scheduled => const <String>{
      'patient',
      'procedure',
      'time',
      'status',
      'next_action',
    },
    TheaterSection.inTheater => const <String>{
      'patient',
      'procedure',
      'room',
      'status',
      'next_action',
    },
    TheaterSection.recovery => const <String>{
      'patient',
      'procedure',
      'room',
      'status',
      'next_action',
    },
    TheaterSection.all => const <String>{
      'patient',
      'procedure',
      'time',
      'status',
      'next_action',
    },
  };
  return _allTheaterColumns(context, canWrite: canWrite)
      .where(
        (AppListTableColumn<TheaterCase> column) => ids.contains(column.id),
      )
      .toList(growable: false);
}

List<AppListTableColumn<TheaterCase>> theaterColumnChoicesForSection(
  BuildContext context,
  TheaterSection section,
  bool canWrite,
) {
  final Set<String> defaultIds = switch (section) {
    TheaterSection.scheduled => const <String>{
      'patient',
      'procedure',
      'time',
      'status',
      'next_action',
    },
    TheaterSection.inTheater => const <String>{
      'patient',
      'procedure',
      'room',
      'status',
      'next_action',
    },
    TheaterSection.recovery => const <String>{
      'patient',
      'procedure',
      'room',
      'status',
      'next_action',
    },
    TheaterSection.all => const <String>{
      'patient',
      'procedure',
      'time',
      'status',
      'next_action',
    },
  };
  return _allTheaterColumns(context, canWrite: canWrite)
      .where(
        (AppListTableColumn<TheaterCase> column) =>
            !defaultIds.contains(column.id),
      )
      .toList(growable: false);
}

List<AppListTableColumn<TheaterCase>> _allTheaterColumns(
  BuildContext context, {
  required bool canWrite,
}) {
  return <AppListTableColumn<TheaterCase>>[
    _theaterCaseIdColumn(context),
    _theaterProcedureColumn(context),
    _theaterPatientColumn(context),
    _theaterTimeColumn(context),
    _theaterRoomColumn(context),
    _theaterStatusColumn(context),
    _theaterReadinessColumn(context),
    _theaterOwnerColumn(context),
    _theaterNextActionColumn(context, canWrite: canWrite),
  ];
}

AppListTableColumn<TheaterCase> _theaterCaseIdColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'case_id',
    label: l10n.theaterCaseIdColumnLabel,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareText(
          left.effectiveDisplayId,
          right.effectiveDisplayId,
        ),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return Text(item.effectiveDisplayId);
    },
  );
}

AppListTableColumn<TheaterCase> _theaterProcedureColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'procedure',
    label: l10n.theaterProcedureColumnLabel,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareText(left.procedureName, right.procedureName),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return Text(item.procedureName ?? l10n.profileUnknownValue);
    },
  );
}

AppListTableColumn<TheaterCase> _theaterPatientColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'patient',
    label: l10n.theaterPatientColumnLabel,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareText(
          left.patientDisplayName ?? left.patientDisplayId,
          right.patientDisplayName ?? right.patientDisplayId,
        ),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return _TwoLineCell(
        title: item.patientDisplayName ?? l10n.profileUnknownValue,
        subtitle: _joinDisplay(<String?>[
          item.patientDisplayId,
          item.encounterDisplayId,
        ]),
      );
    },
  );
}

AppListTableColumn<TheaterCase> _theaterTimeColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'time',
    label: l10n.theaterTimeColumnLabel,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareDateTime(left.scheduledAt, right.scheduledAt),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return Text(_formatDateTime(context, item.scheduledAt));
    },
  );
}

AppListTableColumn<TheaterCase> _theaterRoomColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'room',
    label: l10n.theaterRoomColumnLabel,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareText(
          _roomLabel(context, left),
          _roomLabel(context, right),
        ),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return _TwoLineCell(
        title: item.roomDisplayLabel?.trim().isNotEmpty == true
            ? item.roomDisplayLabel!.trim()
            : l10n.profileUnknownValue,
        subtitle: item.roomDisplayId?.trim() ?? '',
      );
    },
  );
}

AppListTableColumn<TheaterCase> _theaterStatusColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'status',
    label: l10n.theaterStatusColumnLabel,
    alwaysVisible: true,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareText(left.status, right.status),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: _caseStatusLabel(l10n, item.status),
          tone: _statusTone(item.status),
        ),
      );
    },
  );
}

AppListTableColumn<TheaterCase> _theaterReadinessColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'readiness',
    label: l10n.theaterReadinessColumnLabel,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareNumber(
          left.checklistCompleted,
          right.checklistCompleted,
        ),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return Text(_readinessLabel(context, item));
    },
  );
}

AppListTableColumn<TheaterCase> _theaterOwnerColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'owner',
    label: l10n.theaterResponsibleRoleColumnLabel,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareText(
          _responsibleRoleLabel(l10n, left),
          _responsibleRoleLabel(l10n, right),
        ),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return Text(_responsibleRoleLabel(l10n, item));
    },
  );
}

AppListTableColumn<TheaterCase> _theaterNextActionColumn(
  BuildContext context, {
  required bool canWrite,
}) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'next_action',
    label: l10n.theaterNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareText(
          _nextActionLabel(context, left),
          _nextActionLabel(context, right),
        ),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return _TheaterNextActionButton(theaterCase: item, canWrite: canWrite);
    },
  );
}

bool theaterTableSearchMatcher(
  BuildContext context,
  TheaterCase item,
  String query,
) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  final AppLocalizations l10n = context.l10n;
  return <String?>[
    item.effectiveDisplayId,
    item.procedureName,
    item.patientDisplayName,
    item.patientDisplayId,
    item.encounterDisplayId,
    _formatDateTime(context, item.scheduledAt),
    item.roomDisplayLabel,
    item.roomDisplayId,
    _roomLabel(context, item),
    item.status,
    _caseStatusLabel(l10n, item.status),
    item.workflowStage,
    _stageLabel(l10n, item.workflowStage),
    _readinessLabel(context, item),
    _responsibleRoleLabel(l10n, item),
    _nextActionLabel(context, item),
    item.surgeonUserDisplayId,
    item.surgeonDisplayName,
    item.anesthetistUserDisplayId,
    item.anesthetistDisplayName,
  ].whereType<String>().any(
    (String value) => value.toLowerCase().contains(needle),
  );
}

class _TheaterNextActionButton extends ConsumerWidget {
  const _TheaterNextActionButton({
    required this.theaterCase,
    required this.canWrite,
  });

  final TheaterCase theaterCase;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String label = _nextActionLabel(context, theaterCase);
    final bool isTerminal =
        theaterCase.normalizedStatus == 'CANCELLED' ||
        theaterCase.normalizedStatus == 'COMPLETED';
    if (isTerminal || !canWrite) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final bool isMutating =
        ref
            .watch(theaterWorkspaceControllerProvider)
            .asData
            ?.value
            .when(
              success: (TheaterWorkspaceState state) => state.isMutating,
              failure: (_) => false,
            ) ??
        false;

    return AppButton.tertiary(
      label: label,
      enabled: !isMutating,
      onPressed: isMutating
          ? null
          : () => unawaited(_runTheaterNextAction(context, ref, theaterCase)),
    );
  }
}

Future<void> _runTheaterNextAction(
  BuildContext context,
  WidgetRef ref,
  TheaterCase theaterCase,
) async {
  final TheaterWorkspaceController controller = ref.read(
    theaterWorkspaceControllerProvider.notifier,
  );
  final TheaterWorkspaceState? currentState = _readTheaterState(ref);
  if (currentState?.isMutating == true) {
    return;
  }

  final AppFailure? selectFailure = await controller.selectCase(theaterCase);
  if (!context.mounted) {
    return;
  }
  if (selectFailure != null) {
    _showMutationResult(context, selectFailure);
    return;
  }

  final TheaterCase active =
      _readTheaterState(ref)?.selectedCase ?? theaterCase;

  if (!active.isReady) {
    await _showChecklistDialog(context, ref);
    return;
  }
  if (active.normalizedStatus == 'SCHEDULED') {
    await _showStageDialog(context, ref, active);
    return;
  }
  if (!active.hasFinalAnesthesia) {
    await _showAnesthesiaDialog(context, ref, active);
    return;
  }
  if (!active.hasFinalPostOp) {
    await _showPostOpDialog(context, ref, active);
    return;
  }
  await _showHandoverDialog(context, ref);
}

class _TheaterCaseListTile extends StatelessWidget {
  const _TheaterCaseListTile({
    required this.theaterCase,
    required this.canWrite,
  });

  final TheaterCase theaterCase;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(theme.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _TwoLineCell(
                  title:
                      theaterCase.patientDisplayName ??
                      l10n.profileUnknownValue,
                  subtitle: _joinDisplay(<String?>[
                    theaterCase.patientDisplayId,
                    theaterCase.encounterDisplayId,
                  ]),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              AppWorkspaceStatusBadge(
                status: AppWorkspaceStatus(
                  label: _caseStatusLabel(l10n, theaterCase.status),
                  tone: _statusTone(theaterCase.status),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            theaterCase.procedureName ?? l10n.profileUnknownValue,
            style: theme.textTheme.bodySmall,
          ),
          SizedBox(height: theme.spacing.xs),
          Text(
            _formatDateTime(context, theaterCase.scheduledAt),
            style: theme.textTheme.bodySmall,
          ),
          SizedBox(height: theme.spacing.sm),
          _TheaterNextActionButton(
            theaterCase: theaterCase,
            canWrite: canWrite,
          ),
        ],
      ),
    );
  }
}
