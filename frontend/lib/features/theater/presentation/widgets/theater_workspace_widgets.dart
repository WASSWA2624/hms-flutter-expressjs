part of '../pages/theater_workspace_page.dart';

/// Prefer **5 data columns**; `next_action` is an allowed always-visible write
/// chrome column when [showNextAction] (tests exclude it from the prefer-5 set).
List<AppListTableColumn<TheaterCase>> defaultTheaterColumnsForSection(
  BuildContext context,
  TheaterSection section, {
  required bool showNextAction,
}) {
  final List<String> dataIds = switch (section) {
    TheaterSection.scheduled ||
    TheaterSection.all ||
    TheaterSection.followUps => <String>[
      'patient',
      'procedure',
      'time',
      'room',
      'status',
    ],
    TheaterSection.inTheater || TheaterSection.recovery => <String>[
      'patient',
      'procedure',
      'room',
      'time',
      'status',
    ],
  };
  final List<AppListTableColumn<TheaterCase>> defaults =
      <AppListTableColumn<TheaterCase>>[
        for (final String id in dataIds)
          _theaterColumnById(context, id)!,
        if (showNextAction) _theaterNextActionColumn(context),
      ];
  if (defaults.where((AppListTableColumn<TheaterCase> c) => c.id != 'next_action').length >=
      5) {
    return defaults;
  }
  // Promote from optional pool when RBAC or section yields fewer than 5 data cols.
  final List<AppListTableColumn<TheaterCase>> resolved =
      List<AppListTableColumn<TheaterCase>>.of(defaults);
  final Set<String> resolvedIds = resolved
      .map((AppListTableColumn<TheaterCase> column) => column.key)
      .toSet();
  for (final AppListTableColumn<TheaterCase> choice
      in _theaterOptionalColumnPool(context, showNextAction: showNextAction)) {
    final int dataCount = resolved
        .where((AppListTableColumn<TheaterCase> c) => c.id != 'next_action')
        .length;
    if (dataCount >= 5) {
      break;
    }
    if (resolvedIds.contains(choice.key)) {
      continue;
    }
    resolved.add(choice);
    resolvedIds.add(choice.key);
  }
  return resolved;
}

List<AppListTableColumn<TheaterCase>> theaterColumnChoicesForSection(
  BuildContext context,
  TheaterSection section, {
  required bool showNextAction,
}) {
  final Set<String> defaultIds = defaultTheaterColumnsForSection(
    context,
    section,
    showNextAction: showNextAction,
  ).map((AppListTableColumn<TheaterCase> column) => column.key).toSet();

  return <AppListTableColumn<TheaterCase>>[
    for (final AppListTableColumn<TheaterCase> column
        in _theaterOptionalColumnPool(context, showNextAction: showNextAction))
      if (!defaultIds.contains(column.key)) column,
  ];
}

List<AppListTableColumn<TheaterCase>> _theaterOptionalColumnPool(
  BuildContext context, {
  required bool showNextAction,
}) {
  return <AppListTableColumn<TheaterCase>>[
    _theaterCaseIdColumn(context),
    _theaterReadinessColumn(context),
    _theaterOwnerColumn(context),
    if (showNextAction) _theaterNextActionColumn(context),
  ];
}

AppListTableColumn<TheaterCase>? _theaterColumnById(
  BuildContext context,
  String id,
) {
  return switch (id) {
    'case_id' => _theaterCaseIdColumn(context),
    'procedure' => _theaterProcedureColumn(context),
    'patient' => _theaterPatientColumn(context),
    'time' => _theaterTimeColumn(context),
    'room' => _theaterRoomColumn(context),
    'status' => _theaterStatusColumn(context),
    'readiness' => _theaterReadinessColumn(context),
    'owner' => _theaterOwnerColumn(context),
    'next_action' => _theaterNextActionColumn(context),
    _ => null,
  };
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
    exportValue: (TheaterCase item) => item.effectiveDisplayId,
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
    exportValue: (TheaterCase item) =>
        item.procedureName ?? l10n.profileUnknownValue,
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
    exportValue: (TheaterCase item) =>
        item.patientDisplayName ?? l10n.profileUnknownValue,
    cellBuilder: (BuildContext context, TheaterCase item) {
      return AppListItemText(
        title: item.patientDisplayName ?? l10n.profileUnknownValue,
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
    exportValue: (TheaterCase item) => _formatDateTime(context, item.scheduledAt),
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
    exportValue: (TheaterCase item) {
      final String? label = item.roomDisplayLabel?.trim();
      if (label != null && label.isNotEmpty) {
        return label;
      }
      return item.roomDisplayId?.trim() ?? l10n.profileUnknownValue;
    },
    cellBuilder: (BuildContext context, TheaterCase item) {
      final String? label = item.roomDisplayLabel?.trim();
      return Text(
        (label != null && label.isNotEmpty)
            ? label
            : (item.roomDisplayId?.trim() ?? l10n.profileUnknownValue),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    exportValue: (TheaterCase item) => _caseStatusLabel(l10n, item.status),
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
    exportValue: (TheaterCase item) => _readinessLabel(context, item),
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
    exportValue: (TheaterCase item) => _responsibleRoleLabel(l10n, item),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return Text(_responsibleRoleLabel(l10n, item));
    },
  );
}

AppListTableColumn<TheaterCase> _theaterNextActionColumn(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<TheaterCase>(
    id: 'next_action',
    label: l10n.theaterNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (TheaterCase left, TheaterCase right) =>
        appListTableCompareText(
          theaterNextActionLabel(l10n, left),
          theaterNextActionLabel(l10n, right),
        ),
    exportValue: (TheaterCase item) => theaterNextActionLabel(l10n, item),
    cellBuilder: (BuildContext context, TheaterCase item) {
      return _TheaterNextActionButton(theaterCase: item);
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
    theaterNextActionLabel(l10n, item),
    item.surgeonUserDisplayId,
    item.surgeonDisplayName,
    item.anesthetistUserDisplayId,
    item.anesthetistDisplayName,
  ].whereType<String>().any(
    (String value) => value.toLowerCase().contains(needle),
  );
}

class _TheaterNextActionButton extends ConsumerWidget {
  const _TheaterNextActionButton({required this.theaterCase});

  final TheaterCase theaterCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String label = theaterNextActionLabel(l10n, theaterCase);
    final TheaterNextActionKind? kind = theaterResolveNextActionKind(
      theaterCase,
    );
    if (kind == null) {
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
  final TheaterNextActionKind? kind = theaterResolveNextActionKind(active);
  if (kind == null) {
    return;
  }

  switch (kind) {
    case TheaterNextActionKind.updateReadiness:
      await _showChecklistDialog(context, ref);
    case TheaterNextActionKind.startCase:
      // Confirm-only: do not open Update stage (would restate status/stage).
      await _showStartCaseDialog(context, ref);
    case TheaterNextActionKind.anesthesia:
      await _showAnesthesiaDialog(context, ref, active);
    case TheaterNextActionKind.postOp:
      await _showPostOpDialog(context, ref, active);
    case TheaterNextActionKind.handover:
      await _showHandoverDialog(context, ref);
  }
}
