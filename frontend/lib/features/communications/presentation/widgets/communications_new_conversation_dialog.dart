import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/controllers/communications_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showCommunicationsNewDirectMessageDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => const _NewDirectMessageDialog(),
  );
}

Future<void> showCommunicationsNewGroupDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => const _NewGroupDialog(),
  );
}

class _NewDirectMessageDialog extends ConsumerStatefulWidget {
  const _NewDirectMessageDialog();

  @override
  ConsumerState<_NewDirectMessageDialog> createState() =>
      _NewDirectMessageDialogState();
}

class _NewDirectMessageDialogState
    extends ConsumerState<_NewDirectMessageDialog> {
  final TextEditingController _subjectController = TextEditingController();
  String? _selectedUserId;
  List<CommunicationStaffOption> _staffOptions = <CommunicationStaffOption>[];
  bool _loadingStaff = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadStaff('');
  }

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff(String query) async {
    setState(() => _loadingStaff = true);
    final List<CommunicationStaffOption> options = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .searchStaff(query);
    if (mounted) {
      setState(() {
        _loadingStaff = false;
        _staffOptions = options;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(context.l10n.communicationsNewMessageAction),
      icon: const Icon(Icons.edit_outlined),
      scrollable: true,
      maxWidth: 520,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _selectedUserId,
            labelText: context.l10n.communicationsRecipientLabel,
            isRequired: true,
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
          AppTextField(
            controller: _subjectController,
            labelText: context.l10n.communicationsSubjectLabel,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: context.l10n.commonCancelActionLabel,
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: context.l10n.communicationsStartConversationAction,
          isLoading: _submitting,
          enabled: _selectedUserId != null,
          onPressed: _selectedUserId == null || _submitting ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final String? userId = _selectedUserId;
    if (userId == null) {
      return;
    }
    setState(() => _submitting = true);
    final AppFailure? failure = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .createConversation(
          CommunicationConversationDraft(
            participantIds: <String>[userId],
            subject: _subjectController.text.trim().isEmpty
                ? null
                : _subjectController.text.trim(),
            conversationType: 'DIRECT',
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (failure == null) {
      Navigator.of(context).pop();
    }
  }
}

class _NewGroupDialog extends ConsumerStatefulWidget {
  const _NewGroupDialog();

  @override
  ConsumerState<_NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends ConsumerState<_NewGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedMemberIds = <String>{};
  List<CommunicationStaffOption> _staffOptions = <CommunicationStaffOption>[];
  bool _loadingStaff = false;
  bool _isSensitive = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadStaff('');
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff(String query) async {
    setState(() => _loadingStaff = true);
    final List<CommunicationStaffOption> options = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .searchStaff(query);
    if (mounted) {
      setState(() {
        _loadingStaff = false;
        _staffOptions = options;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(context.l10n.communicationsNewGroupAction),
      icon: const Icon(Icons.group_add_outlined),
      scrollable: true,
      maxWidth: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppTextField(
            controller: _nameController,
            labelText: context.l10n.communicationsGroupNameLabel,
            isRequired: true,
          ),
          AppSelectField<String>.searchable(
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
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _selectedMemberIds.add(value));
              }
            },
          ),
          if (_selectedMemberIds.isNotEmpty)
            Wrap(
              spacing: Theme.of(context).spacing.xs,
              runSpacing: Theme.of(context).spacing.xs,
              children: <Widget>[
                for (final String memberId in _selectedMemberIds)
                  InputChip(
                    label: Text(_memberLabel(memberId)),
                    onDeleted: () =>
                        setState(() => _selectedMemberIds.remove(memberId)),
                  ),
              ],
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.communicationsSensitiveConversationLabel),
            value: _isSensitive,
            onChanged: (bool value) => setState(() => _isSensitive = value),
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: context.l10n.commonCancelActionLabel,
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: context.l10n.communicationsCreateGroupAction,
          isLoading: _submitting,
          enabled:
              _nameController.text.trim().isNotEmpty &&
              _selectedMemberIds.isNotEmpty,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }

  String _memberLabel(String memberId) {
    return _staffOptions
            .where((CommunicationStaffOption item) => item.id == memberId)
            .map((CommunicationStaffOption item) => item.label)
            .firstOrNull ??
        memberId;
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty || _selectedMemberIds.isEmpty) {
      return;
    }
    setState(() => _submitting = true);
    final AppFailure? failure = await ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .createConversation(
          CommunicationConversationDraft(
            participantIds: _selectedMemberIds.toList(growable: false),
            subject: _nameController.text.trim(),
            isSensitive: _isSensitive,
            conversationType: 'GROUP',
          ),
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (failure == null) {
      Navigator.of(context).pop();
    }
  }
}
