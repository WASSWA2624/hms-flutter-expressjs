import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class NursingShiftContextDialog extends ConsumerWidget {
  const NursingShiftContextDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<NursingWorkspaceState>> value = ref.watch(
      nursingWorkspaceControllerProvider,
    );
    final NursingWorkspaceState? state = value.asData?.value.when(
      success: (NursingWorkspaceState data) => data,
      failure: (_) => null,
    );

    return AppDialog(
      title: Text(l10n.nursingShiftContextTitle),
      icon: const Icon(Icons.assignment_ind_outlined),
      semanticLabel: l10n.nursingShiftContextTitle,
      scrollable: true,
      maxWidth: 760,
      content: state == null
          ? AppWorkspaceStatePanel.loading(
              title: l10n.nursingLoadingTitle,
              body: l10n.nursingLoadingBody,
            )
          : NursingShiftContextPanel(state: state),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
      ],
    );
  }
}

class NursingShiftContextPanel extends StatelessWidget {
  const NursingShiftContextPanel({required this.state, super.key});

  final NursingWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppWorkspaceDetailPanel(
      title: l10n.nursingShiftContextTitle,
      description: l10n.nursingShiftContextDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.nursingRosterTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
          AppRosterAssignmentList(
            items: nursingRosterViews(context, state.rosters),
            emptyLabel: l10n.nursingNoRosterLabel,
          ),
          SizedBox(height: Theme.of(context).spacing.md),
          Text(
            l10n.nursingPendingHandoverTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: Theme.of(context).spacing.sm),
          AppWardActivityList(
            items: nursingHandoverActivityEntries(
              context,
              state.pendingHandovers,
            ),
            emptyLabel: l10n.nursingNoRecordsLabel,
          ),
        ],
      ),
    );
  }
}
