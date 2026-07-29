import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/communications_access.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showCommunicationsManageMembersDialogImpl(
  BuildContext context,
  WidgetRef ref, {
  required CommunicationsConversation conversation,
}) {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!CommunicationsMessagesAtomPermissions.manageMembers.isAllowed(policy)) {
    return Future<void>.value();
  }
  return showAppDialog<void>(
    context: context,
    builder: (_) => _ManageMembersDialog(conversation: conversation),
  );
}

class _ManageMembersDialog extends ConsumerStatefulWidget {
  const _ManageMembersDialog({required this.conversation});

  final CommunicationsConversation conversation;

  @override
  ConsumerState<_ManageMembersDialog> createState() =>
      _ManageMembersDialogState();
}

class _ManageMembersDialogState extends ConsumerState<_ManageMembersDialog> {
  String? _selectedUserId;
  List<CommunicationStaffOption> _staffOptions = <CommunicationStaffOption>[];
  bool _loadingStaff = false;

  @override
  void initState() {
    super.initState();
    _loadStaff('');
  }

  Future<void> _loadStaff(String query) async {
    setState(() => _loadingStaff = true);
    final List<CommunicationStaffOption> options = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .searchStaff(query);
    if (!mounted) {
      return;
    }
    final Set<String> memberIds = widget.conversation.participants
        .map((CommunicationsParticipant item) => item.userId)
        .toSet();
    setState(() {
      _loadingStaff = false;
      _staffOptions = options
          .where(
            (CommunicationStaffOption item) => !memberIds.contains(item.id),
          )
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final CommunicationsConversation conversation = widget.conversation;
    return AppDialog(
      title: Text(context.l10n.communicationsManageMembersTitle),
      icon: const Icon(Icons.group_outlined),
      scrollable: true,
      maxWidth: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final CommunicationsParticipant participant
              in conversation.participants)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                participant.user?.displayName ??
                    context.l10n.profileUnknownValue,
              ),
              subtitle: Text(
                communicationsParticipantMeta(context, participant),
              ),
              trailing: AppButton.tertiary(
                label: context.l10n.commonRemoveActionLabel,
                onPressed: () => _removeParticipant(participant.id),
              ),
            ),
          SizedBox(height: Theme.of(context).spacing.md),
          AppSelectField<String>.searchable(
            value: _selectedUserId,
            labelText: context.l10n.communicationsAddMemberLabel,
            options: _staffOptions
                .map(
                  (CommunicationStaffOption item) => AppSelectOption<String>(
                    value: item.id,
                    label: item.label,
                    searchText: item.searchableLabel,
                  ),
                )
                .toList(growable: false),
            isLoading: _loadingStaff,
            onSearchTextChanged: _loadStaff,
            onChanged: (String? value) =>
                setState(() => _selectedUserId = value),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton.secondary(
              label: context.l10n.communicationsAddMemberAction,
              leadingIcon: Icons.person_add_outlined,
              enabled: _selectedUserId != null,
              onPressed: _selectedUserId == null ? null : _addMember,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: context.l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  String communicationsParticipantMeta(
    BuildContext context,
    CommunicationsParticipant participant,
  ) {
    final List<String> parts = <String>[
      if (participant.roleSnapshot != null &&
          participant.roleSnapshot!.isNotEmpty)
        participant.roleSnapshot!,
      if (participant.lastReadAt != null)
        context.l10n.communicationsLastReadLabel(
          participant.lastReadAt!.toLocal().toString(),
        ),
    ];
    return parts.isEmpty ? context.l10n.profileUnknownValue : parts.join(' · ');
  }

  Future<void> _addMember() async {
    // Re-check before mutation — stale grants must not fire write paths.
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!CommunicationsMessagesAtomPermissions.manageMembers.isAllowed(
      policy,
    )) {
      return;
    }
    final String? userId = _selectedUserId;
    if (userId == null) {
      return;
    }
    final AppFailure? failure = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .addParticipantToSelected(userId);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      setState(() => _selectedUserId = null);
      Navigator.of(context).pop();
    }
  }

  Future<void> _removeParticipant(String participantId) async {
    // Re-check before mutation — stale grants must not fire write paths.
    final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
    if (!CommunicationsMessagesAtomPermissions.manageMembers.isAllowed(
      policy,
    )) {
      return;
    }
    final AppFailure? failure = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .removeParticipantFromSelected(participantId);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop();
    }
  }
}
