import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class NursingHandoverDialog extends ConsumerStatefulWidget {
  const NursingHandoverDialog({this.escalation = false, super.key});

  final bool escalation;

  @override
  ConsumerState<NursingHandoverDialog> createState() =>
      _NursingHandoverDialogState();
}

class _NursingHandoverDialogState extends ConsumerState<NursingHandoverDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  String? _toUserId;
  List<NursingUserOption> _userOptions = const <NursingUserOption>[];
  List<XFile> _attachments = const <XFile>[];
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    ref.read(nursingWorkspaceControllerProvider.notifier).searchUsers('').then((
      List<NursingUserOption> users,
    ) {
      if (mounted) {
        setState(() => _userOptions = users);
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String title = widget.escalation
        ? l10n.nursingActionEscalate
        : l10n.nursingActionCreateHandover;
    return AppDialog(
      title: Text(title),
      icon: Icon(
        widget.escalation
            ? Icons.report_problem_outlined
            : Icons.swap_horiz_outlined,
      ),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_failure != null) ...<Widget>[
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
              SizedBox(height: Theme.of(context).spacing.md),
            ],
            AppHandoverActionForm(
              toUserLabel: l10n.nursingHandoverToUserLabel,
              notesLabel: widget.escalation
                  ? l10n.nursingEscalationMessageLabel
                  : l10n.nursingHandoverNotesLabel,
              requiredMessage: l10n.validationRequired,
              toUserValue: _toUserId,
              userOptions: _userSelectOptions(),
              notesController: _notesController,
              enabled: !_isSaving,
              onToUserChanged: (String? value) {
                setState(() => _toUserId = value);
              },
              onUserSearchTextChanged: _loadUsers,
              confirmLabel: widget.escalation
                  ? l10n.nursingConfirmEscalationLabel
                  : null,
              confirmed: _confirm,
              onConfirmedChanged: widget.escalation
                  ? (bool value) => setState(() => _confirm = value)
                  : null,
              attachmentTitle: widget.escalation
                  ? null
                  : l10n.patientsDocumentUploadTitle,
              attachmentEmptyDescription: widget.escalation
                  ? null
                  : l10n.patientsDocumentUploadEmpty,
              attachmentChooseLabel: widget.escalation
                  ? null
                  : l10n.patientsChooseDocumentAction,
              attachmentClearLabel: widget.escalation
                  ? null
                  : l10n.patientsClearFiltersAction,
              attachmentFileNames: _attachments
                  .map((XFile file) => file.name)
                  .toList(growable: false),
              onChooseAttachments: widget.escalation
                  ? null
                  : _chooseAttachments,
              onClearAttachments: widget.escalation
                  ? null
                  : () => setState(() => _attachments = const <XFile>[]),
            ),
          ],
        ),
      ),
      actions: nursingDialogActions(
        context,
        submitLabel: title,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  List<AppSelectOption<String>> _userSelectOptions() {
    return <AppSelectOption<String>>[
      for (final NursingUserOption user in _userOptions)
        AppSelectOption<String>(value: user.id, label: user.searchableLabel),
    ];
  }

  Future<void> _loadUsers(String query) async {
    final List<NursingUserOption> users = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .searchUsers(query);
    if (!mounted) {
      return;
    }
    setState(() => _userOptions = users);
  }

  Future<void> _chooseAttachments() async {
    final List<XFile> files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: nursingDocumentsTypeGroupLabel,
          extensions: <String>['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        ),
      ],
    );
    if (mounted && files.isNotEmpty) {
      setState(() => _attachments = files);
    }
  }

  Future<List<PatientDocumentUploadFile>> _documentUploadFiles() async {
    final List<PatientDocumentUploadFile> files = <PatientDocumentUploadFile>[];
    for (final XFile file in _attachments) {
      files.add(
        PatientDocumentUploadFile(
          name: file.name,
          bytes: await file.readAsBytes(),
          contentType: file.mimeType,
        ),
      );
    }
    return files;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? toUserId = _toUserId?.trim();
    if (toUserId == null || toUserId.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );
    final List<PatientDocumentUploadFile> documentFiles;
    try {
      documentFiles = widget.escalation
          ? const <PatientDocumentUploadFile>[]
          : await _documentUploadFiles();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _failure = AppFailure.validation();
        _isSaving = false;
      });
      return;
    }
    final AppFailure? failure = widget.escalation
        ? await controller.escalate(
            toUserId: toUserId,
            message: _notesController.text.trim(),
          )
        : await controller.createHandover(
            toUserId: toUserId,
            notes: _notesController.text.trim(),
            documentFiles: documentFiles,
          );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}
