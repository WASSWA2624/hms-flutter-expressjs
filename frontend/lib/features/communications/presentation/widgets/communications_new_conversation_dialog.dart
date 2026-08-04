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
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showCommunicationsNewDirectMessageDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!CommunicationsMessagesAtomPermissions.newMessage.isAllowed(policy)) {
    return;
  }
  final GlobalKey<_NewDirectMessageFieldsState> fieldsKey =
      GlobalKey<_NewDirectMessageFieldsState>();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(context.l10n.communicationsNewMessageAction),
    icon: const Icon(Icons.edit_outlined),
    cancelLabel: context.l10n.commonCancelActionLabel,
    submitLabel: context.l10n.communicationsStartConversationAction,
    submitIcon: Icons.edit_outlined,
    maxWidth: 520,
    buildFields: (context, formKey, isSubmitting, [failure]) =>
        _NewDirectMessageFields(key: fieldsKey, ref: ref),
    onSubmit: () => fieldsKey.currentState?.submit() ?? _missingRecipient(),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.communicationsConversationStartedMessage),
      ),
    );
  }
}

Future<void> showCommunicationsNewGroupDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!CommunicationsMessagesAtomPermissions.newGroup.isAllowed(policy)) {
    return;
  }
  final GlobalKey<_NewGroupFieldsState> fieldsKey =
      GlobalKey<_NewGroupFieldsState>();

  await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(context.l10n.communicationsNewGroupAction),
    icon: const Icon(Icons.group_add_outlined),
    cancelLabel: context.l10n.commonCancelActionLabel,
    submitLabel: context.l10n.communicationsCreateGroupAction,
    submitIcon: Icons.group_add_outlined,
    maxWidth: 560,
    buildFields: (context, formKey, isSubmitting, [failure]) =>
        _NewGroupFields(key: fieldsKey, ref: ref),
    onSubmit: () => fieldsKey.currentState?.submit() ?? _missingGroupFields(),
  );
}

Future<void> showCommunicationsNewScopedPostDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final AppAccessPolicy policy = ref.read(appAccessPolicyProvider);
  if (!CommunicationsMessagesAtomPermissions.newGroup.isAllowed(policy)) {
    return;
  }
  final GlobalKey<_NewScopedPostFieldsState> fieldsKey =
      GlobalKey<_NewScopedPostFieldsState>();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(context.l10n.communicationsNewScopedPostAction),
    icon: const Icon(Icons.campaign_outlined),
    cancelLabel: context.l10n.commonCancelActionLabel,
    submitLabel: context.l10n.communicationsCreateScopedPostAction,
    submitIcon: Icons.campaign_outlined,
    maxWidth: 560,
    buildFields: (context, formKey, isSubmitting, [failure]) =>
        _NewScopedPostFields(key: fieldsKey, ref: ref),
    onSubmit: () =>
        fieldsKey.currentState?.submit() ?? _missingScopedPostFields(),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.communicationsScopedPostCreatedMessage),
      ),
    );
  }
}

Future<AppFailure?> _missingRecipient() {
  return Future<AppFailure?>.value(
    AppFailure.validation(validationFields: <String>{'recipient'}),
  );
}

Future<AppFailure?> _missingGroupFields() {
  return Future<AppFailure?>.value(
    AppFailure.validation(validationFields: <String>{'name', 'members'}),
  );
}

Future<AppFailure?> _missingScopedPostFields() {
  return Future<AppFailure?>.value(
    AppFailure.validation(validationFields: <String>{'subject', 'roles'}),
  );
}

class _NewDirectMessageFields extends ConsumerStatefulWidget {
  const _NewDirectMessageFields({required this.ref, super.key});

  final WidgetRef ref;

  @override
  ConsumerState<_NewDirectMessageFields> createState() =>
      _NewDirectMessageFieldsState();
}

class _NewDirectMessageFieldsState
    extends ConsumerState<_NewDirectMessageFields> {
  final TextEditingController _subjectController = TextEditingController();
  String? _selectedUserId;
  List<CommunicationStaffOption> _staffOptions = <CommunicationStaffOption>[];
  bool _loadingStaff = false;

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
    final List<CommunicationStaffOption> options = await widget.ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .searchStaff(query);
    if (mounted) {
      setState(() {
        _loadingStaff = false;
        _staffOptions = options;
      });
    }
  }

  Future<AppFailure?> submit() async {
    // Re-check before mutation — stale grants must not fire write paths.
    final AppAccessPolicy policy = widget.ref.read(appAccessPolicyProvider);
    if (!CommunicationsMessagesAtomPermissions.newMessage.isAllowed(policy)) {
      return null;
    }
    final String? userId = _selectedUserId;
    if (userId == null) {
      return AppFailure.validation(validationFields: <String>{'recipient'});
    }
    return widget.ref
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
          onChanged: (String? value) => setState(() => _selectedUserId = value),
        ),
        AppTextField(
          controller: _subjectController,
          labelText: context.l10n.communicationsSubjectLabel,
        ),
      ],
    );
  }
}

class _NewGroupFields extends ConsumerStatefulWidget {
  const _NewGroupFields({required this.ref, super.key});

  final WidgetRef ref;

  @override
  ConsumerState<_NewGroupFields> createState() => _NewGroupFieldsState();
}

class _NewGroupFieldsState extends ConsumerState<_NewGroupFields> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selectedMemberIds = <String>{};
  List<CommunicationStaffOption> _staffOptions = <CommunicationStaffOption>[];
  bool _loadingStaff = false;
  bool _isSensitive = false;

  @override
  void initState() {
    super.initState();
    _loadStaff('');
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _hasName => _nameController.text.trim().isNotEmpty;

  bool get _canSubmit => _hasName && _selectedMemberIds.isNotEmpty;

  Future<void> _loadStaff(String query) async {
    setState(() => _loadingStaff = true);
    final List<CommunicationStaffOption> options = await widget.ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .searchStaff(query);
    if (mounted) {
      setState(() {
        _loadingStaff = false;
        _staffOptions = options;
      });
    }
  }

  Future<AppFailure?> submit() async {
    // Re-check before mutation — stale grants must not fire write paths.
    final AppAccessPolicy policy = widget.ref.read(appAccessPolicyProvider);
    if (!CommunicationsMessagesAtomPermissions.newGroup.isAllowed(policy)) {
      return null;
    }
    if (!_canSubmit) {
      return AppFailure.validation(
        validationFields: <String>{
          if (!_hasName) 'name',
          if (_selectedMemberIds.isEmpty) 'members',
        },
      );
    }
    return widget.ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .createConversation(
          CommunicationConversationDraft(
            participantIds: _selectedMemberIds.toList(growable: false),
            subject: _nameController.text.trim(),
            isSensitive: _isSensitive,
            conversationType: 'GROUP',
          ),
        );
  }

  String _memberLabel(String memberId) {
    return _staffOptions
            .where((CommunicationStaffOption item) => item.id == memberId)
            .map((CommunicationStaffOption item) => item.label)
            .firstOrNull ??
        memberId;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          controller: _nameController,
          labelText: context.l10n.communicationsGroupNameLabel,
          isRequired: true,
          helperText: _hasName && _selectedMemberIds.isEmpty
              ? context.l10n.communicationsGroupMembersRequiredHelper
              : null,
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
    );
  }
}

class _NewScopedPostFields extends ConsumerStatefulWidget {
  const _NewScopedPostFields({required this.ref, super.key});

  final WidgetRef ref;

  @override
  ConsumerState<_NewScopedPostFields> createState() =>
      _NewScopedPostFieldsState();
}

class _NewScopedPostFieldsState extends ConsumerState<_NewScopedPostFields> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final Set<String> _selectedRoleCodes = <String>{};
  List<CommunicationRoleOption> _roleOptions = <CommunicationRoleOption>[];
  bool _loadingRoles = false;
  bool _isSensitive = false;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() => _loadingRoles = true);
    final List<CommunicationRoleOption> options = await widget.ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .listRoles();
    if (mounted) {
      setState(() {
        _loadingRoles = false;
        _roleOptions = options;
      });
    }
  }

  Future<AppFailure?> submit() async {
    final AppAccessPolicy policy = widget.ref.read(appAccessPolicyProvider);
    if (!CommunicationsMessagesAtomPermissions.newGroup.isAllowed(policy)) {
      return null;
    }
    final String subject = _subjectController.text.trim();
    if (subject.isEmpty || _selectedRoleCodes.isEmpty) {
      return AppFailure.validation(
        validationFields: <String>{
          if (subject.isEmpty) 'subject',
          if (_selectedRoleCodes.isEmpty) 'roles',
        },
      );
    }
    return widget.ref
        .read(communicationsWorkspaceControllerProvider.notifier)
        .createConversation(
          CommunicationConversationDraft(
            subject: subject,
            isSensitive: _isSensitive,
            conversationType: 'GROUP',
            visibilityRoles: _selectedRoleCodes.toList(growable: false),
            initialMessage: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          context.l10n.communicationsScopedPostHelper,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SizedBox(height: Theme.of(context).spacing.sm),
        AppTextField(
          controller: _subjectController,
          labelText: context.l10n.communicationsScopedPostSubjectLabel,
          isRequired: true,
        ),
        SizedBox(height: Theme.of(context).spacing.sm),
        AppTextField(
          controller: _messageController,
          labelText: context.l10n.communicationsScopedPostMessageLabel,
          minLines: 3,
          maxLines: 6,
        ),
        SizedBox(height: Theme.of(context).spacing.sm),
        Text(
          context.l10n.communicationsScopedPostRolesLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (_loadingRoles)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Wrap(
            spacing: Theme.of(context).spacing.xs,
            runSpacing: Theme.of(context).spacing.xs,
            children: <Widget>[
              for (final CommunicationRoleOption role in _roleOptions)
                FilterChip(
                  label: Text(role.label),
                  selected: _selectedRoleCodes.contains(role.code),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedRoleCodes.add(role.code);
                      } else {
                        _selectedRoleCodes.remove(role.code);
                      }
                    });
                  },
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
    );
  }
}
