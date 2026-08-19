import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_document_sequence_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_document_sequence.dart';
import 'package:hosspi_hms/features/accounts/domain/repositories/accounts_document_sequence_repository.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_detail_fact_lines.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Bumped after every document numbering mutation so the tab badge, the
/// workspace summary, and any dependent panels refetch.
final accountsDocumentSequenceRevisionProvider = StateProvider<int>(
  (Ref ref) => 0,
);

/// Filtered document sequence count owned by the panel; null falls back to the
/// workspace summary so the badge never reflects only the painted page.
final accountsDocumentSequenceCountProvider = StateProvider<int?>(
  (Ref ref) => null,
);

enum AccountsDocumentSequenceDialogMode { create, edit, clone }

/// Affix and pattern characters the backend accepts; mirroring them here keeps
/// an invalid reference shape from round-tripping.
final RegExp _affixPattern = RegExp(r'^[A-Za-z0-9\-/]*$');
final RegExp _datePatternPattern = RegExp(r"^[yYmMdDqQwW'\-/.]*$");
final RegExp _sequenceCodePattern = RegExp(r'^[A-Za-z0-9\-_]+$');

/// A prefix plus the padded number plus a suffix must fit the reference column.
const int _maxReferenceLength = 32;
const int _maxMinimumLength = 20;

/// Create / edit / clone form for a document numbering policy.
///
/// Returns `true` when the record was written.
Future<bool> showAccountsDocumentSequenceDialog({
  required BuildContext context,
  required WidgetRef ref,
  AccountsDocumentSequenceDialogMode mode =
      AccountsDocumentSequenceDialogMode.create,
  AccountsDocumentSequence? source,
}) async {
  if (!canWriteAccountsDocumentSequences(ref.read(appAccessPolicyProvider))) {
    return false;
  }
  // The form owns the dialog so Close/Save live in the pinned footer rather
  // than scrolling away inside the body (`prompts/.cursor/dialogs.mdc`).
  final bool? saved = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _AccountsDocumentSequenceForm(mode: mode, source: source),
  );

  if (saved == true) {
    ref
        .read<StateController<int>>(
          accountsDocumentSequenceRevisionProvider.notifier,
        )
        .state++;
  }
  return saved ?? false;
}

class _AccountsDocumentSequenceForm extends ConsumerStatefulWidget {
  const _AccountsDocumentSequenceForm({required this.mode, this.source});

  final AccountsDocumentSequenceDialogMode mode;
  final AccountsDocumentSequence? source;

  @override
  ConsumerState<_AccountsDocumentSequenceForm> createState() =>
      _AccountsDocumentSequenceFormState();
}

class _AccountsDocumentSequenceFormState
    extends ConsumerState<_AccountsDocumentSequenceForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _sequenceCodeController;
  late final TextEditingController _facilityController;
  late final TextEditingController _prefixController;
  late final TextEditingController _suffixController;
  late final TextEditingController _datePatternController;
  late final TextEditingController _minimumLengthController;
  late final TextEditingController _notesController;

  AccountsDocumentType? _documentType;
  String? _module;
  AccountsDocumentSequenceResetFrequency _resetFrequency =
      AccountsDocumentSequenceResetFrequency.never;
  AccountsDocumentSequenceGapPolicy _gapPolicy =
      AccountsDocumentSequenceGapPolicy.allowGaps;
  bool _isSubmitting = false;
  AppFailure? _failure;

  bool get _isEdit => widget.mode == AccountsDocumentSequenceDialogMode.edit;

  /// The reference shape freezes once the counter has issued a number: editing
  /// it would make old and new references indistinguishable.
  bool get _shapeLocked => _isEdit && (widget.source?.hasIssued ?? false);

  @override
  void initState() {
    super.initState();
    final AccountsDocumentSequence? source = widget.source;
    // A clone must not reuse the source code; it is unique per tenant.
    _sequenceCodeController = TextEditingController(
      text: _isEdit ? source?.sequenceCode ?? '' : '',
    );
    _facilityController = TextEditingController(
      text: source?.facilityHumanFriendlyId ?? '',
    );
    _prefixController = TextEditingController(text: source?.prefix ?? '');
    _suffixController = TextEditingController(text: source?.suffix ?? '');
    _datePatternController = TextEditingController(
      text: source?.datePattern ?? '',
    );
    _minimumLengthController = TextEditingController(
      text: '${source?.minimumLength ?? 7}',
    );
    _notesController = TextEditingController(text: source?.notes ?? '');
    _documentType = source?.documentType;
    _module = source?.module.trim().isNotEmpty == true ? source!.module : null;
    _resetFrequency =
        source?.resetFrequency ?? AccountsDocumentSequenceResetFrequency.never;
    _gapPolicy =
        source?.gapPolicy ?? AccountsDocumentSequenceGapPolicy.allowGaps;
  }

  @override
  void dispose() {
    _sequenceCodeController.dispose();
    _facilityController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    _datePatternController.dispose();
    _minimumLengthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Module options: the shared finance module vocabulary, plus any stored
  /// value this build does not recognise so an existing row never loses it.
  List<String> get _moduleOptions {
    final List<String> options = <String>[...accountsFiscalModuleWireValues];
    final String stored = (_module ?? '').trim();
    if (stored.isNotEmpty && !options.contains(stored)) {
      options.insert(0, stored);
    }
    return options;
  }

  /// Live preview of the reference this policy will issue next.
  ///
  /// Derived the same way the server derives it, so the operator sees the
  /// effect of the shape without saving. The running number itself still comes
  /// from the server.
  String get _referencePreview {
    final int minimumLength =
        int.tryParse(_minimumLengthController.text.trim()) ?? 1;
    final int next = widget.source?.nextNumber ?? 1;
    final String body = next.toString().padLeft(
      minimumLength.clamp(1, _maxMinimumLength),
      '0',
    );
    return <String>[
      _prefixController.text.trim().toUpperCase(),
      _datePatternController.text.trim(),
      body,
      _suffixController.text.trim().toUpperCase(),
    ].where((String part) => part.isNotEmpty).join();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String required = l10n.accountsDocumentSequenceRequiredField;

    return AppDialog(
      title: Text(switch (widget.mode) {
        AccountsDocumentSequenceDialogMode.create =>
          l10n.accountsDocumentSequenceCreateTitle,
        AccountsDocumentSequenceDialogMode.edit =>
          l10n.accountsDocumentSequenceEditTitle,
        AccountsDocumentSequenceDialogMode.clone =>
          l10n.accountsDocumentSequenceCloneTitle,
      }),
      icon: const Icon(Icons.pin_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      content: AppFormShell(
        formKey: _formKey,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          // The running number lives with the documents themselves; say so once
          // rather than letting an operator expect to set it here.
          AppFormInformationBanner.message(
            message: l10n.accountsDocumentSequenceCounterNotice,
          ),
          if (_shapeLocked)
            AppFormInformationBanner.message(
              message: l10n.accountsDocumentSequenceShapeLockedNotice,
            ),
          AppFormSection(
            title: l10n.accountsDocumentSequenceIdentitySection,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                left: AppTextField(
                  controller: _sequenceCodeController,
                  labelText: l10n.accountsDocumentSequenceCodeColumn,
                  isRequired: true,
                  validator: AppValidators.compose<String>(
                    <FormFieldValidator<String>>[
                      AppValidators.requiredText(required),
                      AppValidators.pattern(
                        _sequenceCodePattern,
                        l10n.accountsDocumentSequenceInvalidCode,
                      ),
                      AppValidators.maxLength(
                        32,
                        l10n.accountsDocumentSequenceInvalidCode,
                      ),
                    ],
                  ),
                ),
                right: AppSelectField<AccountsDocumentType>(
                  value: _documentType,
                  labelText: l10n.accountsDocumentSequenceTypeColumn,
                  isRequired: true,
                  allowClear: false,
                  enabled: !_shapeLocked,
                  options: <AppSelectOption<AccountsDocumentType>>[
                    for (final AccountsDocumentType type
                        in AccountsDocumentType.values)
                      AppSelectOption<AccountsDocumentType>(
                        value: type,
                        label: accountsDocumentTypeLabel(l10n, type),
                      ),
                  ],
                  validator: AppValidators.requiredValue<AccountsDocumentType>(
                    required,
                  ),
                  onChanged: (AccountsDocumentType? value) =>
                      setState(() => _documentType = value),
                ),
              ),
              AppResponsiveFieldRow.two(
                left: AppSelectField<String>(
                  value: _module,
                  labelText: l10n.accountsDocumentSequenceModuleColumn,
                  isRequired: true,
                  allowClear: false,
                  options: <AppSelectOption<String>>[
                    for (final String value in _moduleOptions)
                      AppSelectOption<String>(
                        value: value,
                        label: accountsFiscalModuleLabel(l10n, value),
                      ),
                  ],
                  validator: AppValidators.requiredValue<String>(required),
                  onChanged: (String? value) => setState(() => _module = value),
                ),
                right: AppTextField(
                  controller: _facilityController,
                  labelText: l10n.accountsDocumentSequenceFacilityColumn,
                  helperText: l10n.accountsDocumentSequenceFacilityHelper,
                ),
              ),
            ],
          ),
          AppFormSection(
            title: l10n.accountsDocumentSequenceShapeSection,
            children: <Widget>[
              AppResponsiveFieldRow.two(
                left: AppTextField(
                  controller: _prefixController,
                  labelText: l10n.accountsDocumentSequencePrefixColumn,
                  isRequired: true,
                  enabled: !_shapeLocked,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  validator: AppValidators.compose<String>(
                    <FormFieldValidator<String>>[
                      AppValidators.requiredText(required),
                      AppValidators.pattern(
                        _affixPattern,
                        l10n.accountsDocumentSequenceInvalidAffix,
                      ),
                      AppValidators.maxLength(
                        16,
                        l10n.accountsDocumentSequenceInvalidAffix,
                      ),
                    ],
                  ),
                ),
                right: AppTextField(
                  controller: _suffixController,
                  labelText: l10n.accountsDocumentSequenceSuffixColumn,
                  enabled: !_shapeLocked,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  validator: AppValidators.compose<String>(
                    <FormFieldValidator<String>>[
                      AppValidators.pattern(
                        _affixPattern,
                        l10n.accountsDocumentSequenceInvalidAffix,
                      ),
                      AppValidators.maxLength(
                        16,
                        l10n.accountsDocumentSequenceInvalidAffix,
                      ),
                    ],
                  ),
                ),
              ),
              AppResponsiveFieldRow.two(
                left: AppTextField(
                  controller: _datePatternController,
                  labelText: l10n.accountsDocumentSequenceDatePatternColumn,
                  helperText: l10n.accountsDocumentSequenceDatePatternHelper,
                  enabled: !_shapeLocked,
                  onChanged: (_) => setState(() {}),
                  validator: AppValidators.compose<String>(
                    <FormFieldValidator<String>>[
                      AppValidators.pattern(
                        _datePatternPattern,
                        l10n.accountsDocumentSequenceInvalidDatePattern,
                      ),
                      AppValidators.maxLength(
                        32,
                        l10n.accountsDocumentSequenceInvalidDatePattern,
                      ),
                    ],
                  ),
                ),
                right: AppTextField(
                  controller: _minimumLengthController,
                  labelText: l10n.accountsDocumentSequenceMinimumLengthColumn,
                  isRequired: true,
                  enabled: !_shapeLocked,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(() {}),
                  validator: (String? value) =>
                      _validateMinimumLength(l10n, value),
                ),
              ),
              AppResponsiveFieldRow.two(
                left: AppSelectField<AccountsDocumentSequenceResetFrequency>(
                  value: _resetFrequency,
                  labelText: l10n.accountsDocumentSequenceResetColumn,
                  isRequired: true,
                  allowClear: false,
                  options:
                      <AppSelectOption<AccountsDocumentSequenceResetFrequency>>[
                        for (final AccountsDocumentSequenceResetFrequency
                            frequency
                            in AccountsDocumentSequenceResetFrequency.values)
                          AppSelectOption<
                            AccountsDocumentSequenceResetFrequency
                          >(
                            value: frequency,
                            label: accountsDocumentResetFrequencyLabel(
                              l10n,
                              frequency,
                            ),
                          ),
                      ],
                  onChanged:
                      (AccountsDocumentSequenceResetFrequency? value) =>
                          setState(
                            () => _resetFrequency =
                                value ??
                                AccountsDocumentSequenceResetFrequency.never,
                          ),
                ),
                right: AppSelectField<AccountsDocumentSequenceGapPolicy>(
                  value: _gapPolicy,
                  labelText: l10n.accountsDocumentSequenceGapPolicyColumn,
                  isRequired: true,
                  allowClear: false,
                  options: <AppSelectOption<AccountsDocumentSequenceGapPolicy>>[
                    for (final AccountsDocumentSequenceGapPolicy policy
                        in AccountsDocumentSequenceGapPolicy.values)
                      AppSelectOption<AccountsDocumentSequenceGapPolicy>(
                        value: policy,
                        label: accountsDocumentGapPolicyLabel(l10n, policy),
                      ),
                  ],
                  onChanged: (AccountsDocumentSequenceGapPolicy? value) =>
                      setState(
                        () => _gapPolicy =
                            value ??
                            AccountsDocumentSequenceGapPolicy.allowGaps,
                      ),
                ),
              ),
              // Next Number is server-owned: it is read back from the counter
              // the documents themselves increment, never set from this form.
              AppResponsiveFieldRow.two(
                left: AppTextField(
                  key: const Key('document-sequence-next-number'),
                  labelText: l10n.accountsDocumentSequenceNextNumberColumn,
                  readOnly: true,
                  enabled: false,
                  helperText: l10n.accountsDocumentSequenceNextNumberHelper,
                  controller: TextEditingController(
                    text: accountsDocumentSequenceNumber(
                      widget.source?.nextNumber ?? 1,
                      int.tryParse(_minimumLengthController.text.trim()) ?? 1,
                    ),
                  ),
                ),
                right: AppTextField(
                  key: const Key('document-sequence-preview'),
                  labelText: l10n.accountsDocumentSequencePreviewLabel,
                  readOnly: true,
                  enabled: false,
                  controller: TextEditingController(text: _referencePreview),
                ),
              ),
              AppTextField(
                controller: _notesController,
                labelText: l10n.accountsDocumentSequenceNotesLabel,
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
      actions: buildAppDialogFormActions(
        cancelLabel: l10n.commonCancelActionLabel,
        submitLabel: switch (widget.mode) {
          AccountsDocumentSequenceDialogMode.create =>
            l10n.commonAddActionLabel,
          AccountsDocumentSequenceDialogMode.edit => l10n.commonSaveActionLabel,
          AccountsDocumentSequenceDialogMode.clone =>
            l10n.accountsDocumentSequenceCloneAction,
        },
        submitIcon: Icons.save_outlined,
        isSubmitting: _isSubmitting,
        onCancel: () => Navigator.of(context).pop(false),
        onSubmit: _submit,
      ),
    );
  }

  String? _validateMinimumLength(AppLocalizations l10n, String? value) {
    final int? parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 1 || parsed > _maxMinimumLength) {
      return l10n.accountsDocumentSequenceInvalidMinimumLength;
    }
    return null;
  }

  /// Mirrors the server's reference budget so an unissuable shape never
  /// round-trips.
  String? _referenceBudgetError() {
    final int minimumLength =
        int.tryParse(_minimumLengthController.text.trim()) ?? 0;
    if (minimumLength <= 0) {
      return null;
    }
    final int width =
        _prefixController.text.trim().length +
        _suffixController.text.trim().length +
        _datePatternController.text.trim().length +
        minimumLength;
    if (width > _maxReferenceLength) {
      return context.l10n.accountsDocumentSequenceReferenceTooLong(
        _maxReferenceLength,
      );
    }
    return null;
  }

  String? _optional(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final String? budgetError = _referenceBudgetError();
    if (budgetError != null) {
      setState(
        () => _failure = AppFailure.validation(detailMessage: budgetError),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final Map<String, Object?> payload = <String, Object?>{
      'sequence_code': _sequenceCodeController.text.trim(),
      'document_type': _documentType?.wireValue,
      'module': _module,
      'facility_id': _optional(_facilityController),
      'prefix': _prefixController.text.trim(),
      'suffix': _optional(_suffixController),
      'date_pattern': _optional(_datePatternController),
      'minimum_length': int.tryParse(_minimumLengthController.text.trim()),
      'reset_frequency': _resetFrequency.wireValue,
      'gap_policy': _gapPolicy.wireValue,
      'notes': _optional(_notesController),
      if (_isEdit) 'version': widget.source?.version,
    };

    final AccountsDocumentSequenceRepository repository = ref.read(
      accountsDocumentSequenceRepositoryProvider,
    );
    final Result<AccountsDocumentSequence> result = _isEdit
        ? await repository.updateDocumentSequence(
            widget.source!.humanFriendlyId,
            payload,
          )
        : await repository.createDocumentSequence(payload);

    if (!mounted) {
      return;
    }
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isSubmitting = false;
        });
      },
    );
  }
}

/// Read-only detail view: summary, related records, attachments, and audit.
Future<void> showAccountsDocumentSequenceDetail({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsDocumentSequence sequence,
  Future<void> Function()? onChanged,
}) async {
  await showAppWorkspaceDetailDrawer<void>(
    context: context,
    title: Text(context.l10n.accountsDocumentSequenceDetailTitle),
    child: _AccountsDocumentSequenceDetail(
      sequence: sequence,
      onChanged: onChanged,
    ),
  );
}

class _AccountsDocumentSequenceDetail extends ConsumerWidget {
  const _AccountsDocumentSequenceDetail({
    required this.sequence,
    this.onChanged,
  });

  final AccountsDocumentSequence sequence;
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    sequence.sequenceCode,
                    style: theme.textTheme.titleLarge,
                  ),
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: accountsDocumentSequenceStatusLabel(
                        l10n,
                        sequence.status,
                      ),
                      tone: accountsDocumentSequenceStatusTone(sequence.status),
                      icon: accountsDocumentSequenceStatusIcon(sequence.status),
                    ),
                  ),
                ],
              ),
            ),
            AppCopyableIdentifier(
              value:
                  accountsPublicLabel(sequence.humanFriendlyId) ??
                  accountsUnknownValue(),
              tooltip: l10n.accountsDocumentSequenceReferenceColumn,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: l10n.accountsDocumentSequenceSummarySection,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceTypeColumn,
                value: accountsDocumentTypeLabel(l10n, sequence.documentType),
                icon: Icons.description_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceModuleColumn,
                value: accountsFiscalModuleLabel(l10n, sequence.module),
                icon: Icons.widgets_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceFacilityColumn,
                value: sequence.facility ?? accountsUnknownValue(),
                icon: Icons.apartment_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequencePrefixColumn,
                value: sequence.prefix,
                icon: Icons.text_fields_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceSuffixColumn,
                value: sequence.suffix ?? accountsUnknownValue(),
                icon: Icons.text_format_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceDatePatternColumn,
                value: sequence.datePattern ?? accountsUnknownValue(),
                icon: Icons.event_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceMinimumLengthColumn,
                value: '${sequence.minimumLength}',
                icon: Icons.straighten_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceResetColumn,
                value: accountsDocumentResetFrequencyLabel(
                  l10n,
                  sequence.resetFrequency,
                ),
                icon: Icons.restart_alt_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceGapPolicyColumn,
                value: accountsDocumentGapPolicyLabel(l10n, sequence.gapPolicy),
                icon: Icons.rule_outlined,
              ),
              if ((sequence.notes ?? '').trim().isNotEmpty)
                AppWorkspacePatientContextField(
                  label: l10n.accountsDocumentSequenceNotesLabel,
                  value: sequence.notes!,
                  icon: Icons.sticky_note_2_outlined,
                ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        // The issued numbers belong to the documents this policy numbers, not
        // to the policy row; the section names where they come from.
        AppCollapsibleSection(
          title: l10n.accountsDocumentSequenceRelatedSection,
          initiallyExpanded: false,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceNextNumberColumn,
                value: accountsDocumentSequenceNumber(
                  sequence.nextNumber,
                  sequence.minimumLength,
                ),
                icon: Icons.tag_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequencePreviewLabel,
                value: sequence.nextReferencePreview ?? accountsUnknownValue(),
                icon: Icons.visibility_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceLastIssuedNumberColumn,
                value: accountsDocumentSequenceNumber(
                  sequence.lastIssuedNumber,
                  sequence.minimumLength,
                ),
                icon: Icons.confirmation_number_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceLastIssuedAtColumn,
                value: accountsDateTime(context, sequence.lastIssuedAt),
                icon: Icons.schedule_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceRelatedSection,
                value: l10n.accountsDocumentSequenceRelatedEmpty,
                icon: Icons.link_outlined,
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsDocumentSequenceAttachmentsSection,
          initiallyExpanded: false,
          child: Text(l10n.accountsDocumentSequenceAttachmentsEmpty),
        ),
        SizedBox(height: theme.spacing.sm),
        AppCollapsibleSection(
          title: l10n.accountsDocumentSequenceActivitySection,
          initiallyExpanded: false,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceActivityCreated,
                value: accountsDateTime(context, sequence.createdAt),
                icon: Icons.add_circle_outline,
              ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceActivityUpdated,
                value: accountsDateTime(context, sequence.updatedAt),
                icon: Icons.update_outlined,
              ),
              if (sequence.archivedAt != null)
                AppWorkspacePatientContextField(
                  label: l10n.accountsDocumentSequenceActivityArchived,
                  value: accountsDateTime(context, sequence.archivedAt),
                  icon: Icons.inventory_2_outlined,
                ),
              AppWorkspacePatientContextField(
                label: l10n.accountsDocumentSequenceVersionLabel,
                value: '${sequence.version}',
                icon: Icons.history_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirms and posts a workflow transition; returns true when applied.
Future<bool> confirmAccountsDocumentSequenceAction({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsDocumentSequence sequence,
  required AccountsDocumentSequenceAction action,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String reference =
      accountsPublicLabel(sequence.humanFriendlyId) ?? sequence.sequenceCode;
  final (
    String title,
    String body,
    bool destructive,
    IconData icon,
  ) = switch (action) {
    AccountsDocumentSequenceAction.activate => (
      l10n.accountsDocumentSequenceActivateConfirmTitle,
      l10n.accountsDocumentSequenceActivateConfirmBody(reference),
      false,
      Icons.check_circle_outline,
    ),
    AccountsDocumentSequenceAction.deactivate => (
      l10n.accountsDocumentSequenceDeactivateConfirmTitle,
      l10n.accountsDocumentSequenceDeactivateConfirmBody(reference),
      true,
      Icons.pause_circle_outline,
    ),
    AccountsDocumentSequenceAction.archive => (
      l10n.accountsDocumentSequenceArchiveConfirmTitle,
      l10n.accountsDocumentSequenceArchiveConfirmBody,
      true,
      Icons.inventory_2_outlined,
    ),
    AccountsDocumentSequenceAction.restore => (
      l10n.accountsDocumentSequenceRestoreConfirmTitle,
      l10n.accountsDocumentSequenceRestoreConfirmBody(reference),
      false,
      Icons.restore_outlined,
    ),
  };

  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AppConfirmActionDialog(
      title: title,
      body: body,
      highlightedText: reference,
      submitLabel: accountsDocumentSequenceActionLabel(l10n, action),
      destructive: destructive,
      icon: Icon(icon),
      onConfirm: () async {
        final Result<AccountsDocumentSequence> result = await ref
            .read(accountsDocumentSequenceRepositoryProvider)
            .applyAction(
              sequence.humanFriendlyId,
              action,
              version: sequence.version,
            );
        return result.when(
          success: (_) {
            ref
                .read<StateController<int>>(
                  accountsDocumentSequenceRevisionProvider.notifier,
                )
                .state++;
            return null;
          },
          failure: (AppFailure failure) => failure,
        );
      },
    ),
  );
  return confirmed == true;
}

String accountsDocumentSequenceActionLabel(
  AppLocalizations l10n,
  AccountsDocumentSequenceAction action,
) {
  return switch (action) {
    AccountsDocumentSequenceAction.activate =>
      l10n.accountsDocumentSequenceActivateAction,
    AccountsDocumentSequenceAction.deactivate =>
      l10n.accountsDocumentSequenceDeactivateAction,
    AccountsDocumentSequenceAction.archive =>
      l10n.accountsDocumentSequenceArchiveAction,
    AccountsDocumentSequenceAction.restore =>
      l10n.accountsDocumentSequenceRestoreAction,
  };
}
