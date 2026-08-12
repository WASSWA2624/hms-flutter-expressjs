import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';

/// Shared confirmation dialog for module actions that either return a boolean
/// confirmation or run an async action before closing.
///
/// Optional [leadingContent] inserts domain-neutral context above the body
/// (for example encounter summary panels) without forking the confirm shell.
///
/// Optional [noteFieldLabel] adds a free-text field below the body for
/// cancellation notes and similar confirm-with-reason flows. Prefer
/// [onConfirmWithNote] when the field is present; [onConfirm] ignores the note.
class AppConfirmActionDialog extends StatefulWidget {
  const AppConfirmActionDialog({
    required this.title,
    required this.body,
    required this.submitLabel,
    this.onConfirm,
    this.onConfirmWithNote,
    this.icon = const Icon(AppActionIcons.help),
    this.highlightedText,
    this.leadingContent = const <Widget>[],
    this.noteFieldLabel,
    this.noteIsRequired = false,
    this.noteMinLines,
    this.noteMaxLines = 3,
    this.notePrefixIcon,
    this.noteAutofocus = false,
    this.destructive = false,
    this.submitLeadingIcon,
    this.cancelLabel,
    this.cancelLeadingIcon = AppActionIcons.cancel,
    this.maxWidth = 600,
    this.sectionDensity = AppFormSectionDensity.regular,
    this.scrollable = false,
    this.pinActionsToBottom = false,
    this.initialMaximized = false,
    this.shouldPopOnFailure,
    this.failurePopValue,
    super.key,
  });

  final String title;
  final String body;
  final String submitLabel;
  final Widget icon;
  final String? highlightedText;
  final List<Widget> leadingContent;
  final String? noteFieldLabel;
  final bool noteIsRequired;
  final int? noteMinLines;
  final int noteMaxLines;
  final Widget? notePrefixIcon;
  final bool noteAutofocus;
  final bool destructive;
  final IconData? submitLeadingIcon;
  final String? cancelLabel;
  final IconData cancelLeadingIcon;
  final double maxWidth;
  final AppFormSectionDensity sectionDensity;
  final bool scrollable;
  final bool pinActionsToBottom;
  final bool initialMaximized;
  final Future<AppFailure?> Function()? onConfirm;
  final Future<AppFailure?> Function(String note)? onConfirmWithNote;
  /// When true for a failure from [onConfirm], close with [failurePopValue]
  /// instead of keeping the dialog open with an error banner.
  final bool Function(AppFailure failure)? shouldPopOnFailure;
  final Object? failurePopValue;

  bool get _hasNoteField =>
      noteFieldLabel != null && noteFieldLabel!.trim().isNotEmpty;

  @override
  State<AppConfirmActionDialog> createState() => _AppConfirmActionDialogState();
}

class _AppConfirmActionDialogState extends State<AppConfirmActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppLocalizations l10n = context.l10n;
    final List<Widget> children = <Widget>[
      ...widget.leadingContent,
      if (widget.destructive)
        _DestructiveConfirmationBody(
          body: widget.body,
          highlightedText: widget.highlightedText,
        )
      else
        Text(
          widget.body,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      if (widget._hasNoteField)
        AppTextField(
          controller: _noteController,
          labelText: widget.noteFieldLabel!,
          prefixIcon: widget.notePrefixIcon,
          minLines: widget.noteMinLines,
          maxLines: widget.noteMaxLines,
          enabled: !_isSaving,
          isRequired: widget.noteIsRequired,
          autofocus: widget.noteAutofocus,
          textCapitalization: TextCapitalization.sentences,
          validator: widget.noteIsRequired
              ? AppValidators.requiredText(l10n.validationRequired)
              : null,
        ),
    ];

    return AppDialog(
      title: Text(widget.title),
      icon: _resolveHeaderIcon(colorScheme),
      maxWidth: widget.maxWidth,
      initialMaximized: widget.initialMaximized,
      scrollable: widget.scrollable,
      pinActionsToBottom: widget.pinActionsToBottom,
      showMaximizeButton: false,
      closeEnabled: !_isSaving,
      content: widget._hasNoteField
          ? AppFormShell(
              formKey: _formKey,
              enabled: !_isSaving,
              density: widget.sectionDensity,
              children: children,
            )
          : AppFormSection(
              density: widget.sectionDensity,
              children: children,
            ),
      actions: _actionDialogButtons(
        context,
        submitLabel: widget.submitLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
        destructive: widget.destructive,
        submitLeadingIcon: widget.submitLeadingIcon,
        cancelLabel: widget.cancelLabel,
        cancelLeadingIcon: widget.cancelLeadingIcon,
      ),
    );
  }

  Widget _resolveHeaderIcon(ColorScheme colorScheme) {
    if (!widget.destructive) {
      return widget.icon;
    }

    if (widget.icon case final Icon icon) {
      return Icon(
        icon.icon,
        size: icon.size,
        semanticLabel: icon.semanticLabel,
        color: colorScheme.error,
      );
    }

    return IconTheme(
      data: IconThemeData(color: colorScheme.error),
      child: widget.icon,
    );
  }

  Future<void> _submit() async {
    if (widget._hasNoteField &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final Future<AppFailure?> Function(String note)? onConfirmWithNote =
        widget.onConfirmWithNote;
    final Future<AppFailure?> Function()? onConfirm = widget.onConfirm;
    if (onConfirmWithNote == null && onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = true;
    });
    final AppFailure? failure = onConfirmWithNote != null
        ? await onConfirmWithNote(_noteController.text.trim())
        : await onConfirm!();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    if (widget.shouldPopOnFailure?.call(failure) == true) {
      Navigator.of(context).pop(widget.failurePopValue);
      return;
    }
    // Prefer snackbars over inline failure panels — confirm shells stay compact.
    showAppFailureSnackBar(context, failure);
    setState(() {
      _isSaving = false;
    });
  }
}

/// Shared free-text action dialog for notes, summaries, handovers, and similar
/// module workflows.
///
/// Optional [leadingContent] inserts domain-neutral context above the field
/// (for example encounter identity banners) without forking the text shell.
class AppTextActionDialog extends StatefulWidget {
  const AppTextActionDialog({
    required this.title,
    required this.fieldLabel,
    required this.submitLabel,
    required this.onSubmit,
    this.icon = const Icon(Icons.edit_note_outlined),
    this.semanticLabel,
    this.description,
    this.sectionTitle,
    this.leadingContent = const <Widget>[],
    this.initialValue,
    this.prefixIcon,
    this.minLines = 3,
    this.maxLines = 8,
    this.maxWidth = 720,
    this.autofocus = true,
    this.isRequired = true,
    this.pinActionsToBottom = true,
    this.submitLeadingIcon,
    super.key,
  });

  final String title;
  final String? semanticLabel;
  final String? sectionTitle;
  final String? description;
  final List<Widget> leadingContent;
  final String fieldLabel;
  final String submitLabel;
  final Widget icon;
  final Widget? prefixIcon;
  final String? initialValue;
  final int minLines;
  final int maxLines;
  final double maxWidth;
  final bool autofocus;
  final bool isRequired;
  final bool pinActionsToBottom;
  final IconData? submitLeadingIcon;
  final Future<AppFailure?> Function(String value) onSubmit;

  @override
  State<AppTextActionDialog> createState() => _AppTextActionDialogState();
}

/// Shared select-only dialog for simple action modals.
///
/// Without [onSubmit], pops the selected value. With [onSubmit], runs the
/// mutation in-dialog (loading, failure banner, blocked dismiss) and pops
/// `true` on success.
class AppSelectActionDialog<T> extends StatefulWidget {
  const AppSelectActionDialog({
    required this.title,
    required this.fieldLabel,
    required this.submitLabel,
    required this.cancelLabel,
    required this.options,
    required this.requiredMessage,
    this.initialValue,
    this.icon = const Icon(Icons.tune_outlined),
    this.semanticLabel,
    this.searchable = false,
    this.isRequired = true,
    this.scrollable = false,
    this.maxWidth = 600,
    this.onSubmit,
    this.submitLeadingIcon,
    super.key,
  });

  final String title;
  final String fieldLabel;
  final String submitLabel;
  final String cancelLabel;
  final List<AppSelectOption<T>> options;
  final String requiredMessage;
  final T? initialValue;
  final Widget icon;
  final String? semanticLabel;
  final bool searchable;
  final bool isRequired;
  final bool scrollable;
  final double maxWidth;
  final Future<AppFailure?> Function(T value)? onSubmit;
  final IconData? submitLeadingIcon;

  @override
  State<AppSelectActionDialog<T>> createState() =>
      _AppSelectActionDialogState<T>();
}

class _AppSelectActionDialogState<T> extends State<AppSelectActionDialog<T>> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  T? _value;
  bool _isSaving = false;
  AppFailure? _failure;

  bool get _mutatesInDialog => widget.onSubmit != null;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      semanticLabel: widget.semanticLabel,
      scrollable: widget.scrollable,
      maxWidth: widget.maxWidth,
      initialMaximized: false,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          _selectField(),
        ],
      ),
      actions: _mutatesInDialog
          ? _actionDialogButtons(
              context,
              submitLabel: widget.submitLabel,
              isSaving: _isSaving,
              onSubmit: _submit,
              submitLeadingIcon:
                  widget.submitLeadingIcon ?? AppActionIcons.edit,
            )
          : <Widget>[
              AppButton.close(
                label: widget.cancelLabel,
                leadingIcon: AppActionIcons.cancel,
                enabled: !_isSaving,
                onPressed: () => Navigator.of(context).pop(),
              ),
              AppButton.primary(
                label: widget.submitLabel,
                leadingIcon: widget.submitLeadingIcon ?? AppActionIcons.save,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
    );
  }

  Widget _selectField() {
    if (widget.searchable) {
      return AppSelectField<T>.searchable(
        value: _value,
        labelText: widget.fieldLabel,
        isRequired: widget.isRequired,
        enabled: !_isSaving,
        options: widget.options,
        validator: widget.isRequired ? _requiredSelect : null,
        onChanged: _handleChanged,
      );
    }

    return AppSelectField<T>(
      value: _value,
      labelText: widget.fieldLabel,
      isRequired: widget.isRequired,
      enabled: !_isSaving,
      options: widget.options,
      validator: widget.isRequired ? _requiredSelect : null,
      onChanged: _handleChanged,
    );
  }

  void _handleChanged(T? value) {
    setState(() => _value = value);
  }

  String? _requiredSelect(T? value) {
    return value == null || value.toString().trim().isEmpty
        ? widget.requiredMessage
        : null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final T? value = _value;
    if (value == null) {
      return;
    }

    final Future<AppFailure?> Function(T value)? onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      Navigator.of(context).pop(value);
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await onSubmit(value);
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

/// Shared free-text dialog for simple action modals that return entered text.
class AppTextInputActionDialog extends StatefulWidget {
  const AppTextInputActionDialog({
    required this.title,
    required this.fieldLabel,
    required this.submitLabel,
    required this.cancelLabel,
    required this.requiredMessage,
    this.description,
    this.icon = const Icon(Icons.edit_note_outlined),
    this.initialValue,
    this.prefixIcon,
    this.minLines = 3,
    this.maxLines = 6,
    this.maxWidth = 600,
    this.isRequired = true,
    this.scrollable = false,
    this.destructive = false,
    this.confirmExactValue,
    this.confirmMatches,
    this.confirmMismatchMessage,
    super.key,
  }) : assert(
         confirmExactValue == null || confirmMatches == null,
         'Provide confirmExactValue or confirmMatches, not both.',
       );

  final String title;
  final String fieldLabel;
  final String submitLabel;
  final String cancelLabel;
  final String requiredMessage;
  final String? description;
  final Widget icon;
  final Widget? prefixIcon;
  final String? initialValue;
  final int minLines;
  final int maxLines;
  final double maxWidth;
  final bool isRequired;
  final bool scrollable;
  final bool destructive;

  /// When set, typed text must equal this value (trim, case-insensitive).
  final String? confirmExactValue;

  /// Custom matcher for type-to-confirm flows with multiple accepted values.
  final bool Function(String value)? confirmMatches;

  /// Validation message when [confirmExactValue] / [confirmMatches] fails.
  final String? confirmMismatchMessage;

  bool get _requiresConfirmMatch =>
      confirmExactValue != null || confirmMatches != null;

  @override
  State<AppTextInputActionDialog> createState() =>
      _AppTextInputActionDialogState();
}

class _AppTextInputActionDialogState extends State<AppTextInputActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    if (widget._requiresConfirmMatch) {
      _controller.addListener(_onConfirmTextChanged);
    }
  }

  @override
  void dispose() {
    if (widget._requiresConfirmMatch) {
      _controller.removeListener(_onConfirmTextChanged);
    }
    _controller.dispose();
    super.dispose();
  }

  void _onConfirmTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _matchesConfirmValue(String value) {
    final String typed = value.trim();
    if (typed.isEmpty) {
      return false;
    }
    final bool Function(String value)? matches = widget.confirmMatches;
    if (matches != null) {
      return matches(typed);
    }
    final String? expected = widget.confirmExactValue?.trim();
    if (expected == null || expected.isEmpty) {
      return true;
    }
    return typed.toLowerCase() == expected.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool canSubmit = !widget._requiresConfirmMatch ||
        _matchesConfirmValue(_controller.text);

    return AppDialog(
      title: Text(widget.title),
      icon: widget.destructive
          ? Icon(
              (widget.icon is Icon)
                  ? (widget.icon as Icon).icon ?? Icons.delete_forever_outlined
                  : Icons.delete_forever_outlined,
              color: colorScheme.error,
            )
          : widget.icon,
      scrollable: widget.scrollable,
      maxWidth: widget.maxWidth,
      initialMaximized: false,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          if (widget.description != null &&
              widget.description!.trim().isNotEmpty)
            Text(
              widget.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: widget.destructive
                    ? colorScheme.error
                    : colorScheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: widget.destructive
                    ? AppFontWeight.emphasis
                    : AppFontWeight.regular,
              ),
            ),
          AppTextField(
            controller: _controller,
            labelText: widget.fieldLabel,
            prefixIcon: widget.prefixIcon,
            isRequired: widget.isRequired,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            textCapitalization: TextCapitalization.sentences,
            validator: _validate,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.close(
          label: widget.cancelLabel,
          leadingIcon: AppActionIcons.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.submitLabel,
          leadingIcon: widget.destructive
              ? Icons.delete_forever_outlined
              : Icons.check_circle_outline,
          color: widget.destructive ? colorScheme.error : null,
          enabled: canSubmit,
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }

  String? _validate(String? value) {
    final String typed = (value ?? '').trim();
    if (widget.isRequired && typed.isEmpty) {
      return widget.requiredMessage;
    }
    if (widget._requiresConfirmMatch && !_matchesConfirmValue(typed)) {
      return widget.confirmMismatchMessage ?? widget.fieldLabel;
    }
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }
}

class _AppTextActionDialogState extends State<AppTextActionDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      semanticLabel: widget.semanticLabel,
      maxWidth: widget.maxWidth,
      scrollable: true,
      pinActionsToBottom: widget.pinActionsToBottom,
      initialMaximized: false,
      closeEnabled: !_isSaving,
      content: AppFormShell(
        formKey: _formKey,
        density: AppFormSectionDensity.spacious,
        enabled: !_isSaving,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          ...widget.leadingContent,
          if (widget.sectionTitle != null &&
              widget.sectionTitle!.trim().isNotEmpty)
            AppFormSection(
              title: widget.sectionTitle,
              description: widget.description,
              children: <Widget>[
                AppTextField(
                  controller: _controller,
                  labelText: widget.fieldLabel,
                  prefixIcon: widget.prefixIcon,
                  minLines: widget.minLines,
                  maxLines: widget.maxLines,
                  enabled: !_isSaving,
                  isRequired: widget.isRequired,
                  autofocus: widget.autofocus,
                  textCapitalization: TextCapitalization.sentences,
                  validator: widget.isRequired
                      ? AppValidators.requiredText(l10n.validationRequired)
                      : null,
                ),
              ],
            )
          else ...<Widget>[
            if (widget.description != null &&
                widget.description!.trim().isNotEmpty)
              Text(
                widget.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            AppTextField(
              controller: _controller,
              labelText: widget.fieldLabel,
              prefixIcon: widget.prefixIcon,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              enabled: !_isSaving,
              isRequired: widget.isRequired,
              autofocus: widget.autofocus,
              textCapitalization: TextCapitalization.sentences,
              validator: widget.isRequired
                  ? AppValidators.requiredText(l10n.validationRequired)
                  : null,
            ),
          ],
        ],
      ),
      actions: _actionDialogButtons(
        context,
        submitLabel: widget.submitLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
        submitLeadingIcon: widget.submitLeadingIcon ?? AppActionIcons.save,
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await widget.onSubmit(_controller.text.trim());
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

List<Widget> _actionDialogButtons(
  BuildContext context, {
  required String submitLabel,
  required bool isSaving,
  required VoidCallback onSubmit,
  bool destructive = false,
  IconData? submitLeadingIcon,
  String? cancelLabel,
  IconData cancelLeadingIcon = AppActionIcons.cancel,
}) {
  final AppLocalizations l10n = context.l10n;
  final ColorScheme colorScheme = Theme.of(context).colorScheme;

  return <Widget>[
    AppButton.close(
      label: cancelLabel ?? l10n.commonCancelActionLabel,
      leadingIcon: cancelLeadingIcon,
      enabled: !isSaving,
      onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
    ),
    if (destructive)
      AppButton.tertiary(
        label: submitLabel,
        leadingIcon: submitLeadingIcon ?? AppActionIcons.delete,
        color: colorScheme.error,
        isLoading: isSaving,
        onPressed: isSaving ? null : onSubmit,
      )
    else
      AppButton.primary(
        label: submitLabel,
        leadingIcon: submitLeadingIcon ?? AppActionIcons.save,
        isLoading: isSaving,
        onPressed: isSaving ? null : onSubmit,
      ),
  ];
}

class _DestructiveConfirmationBody extends StatelessWidget {
  const _DestructiveConfirmationBody({
    required this.body,
    this.highlightedText,
  });

  final String body;
  final String? highlightedText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle baseStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          height: 1.5,
        ) ??
        theme.fonts.style(color: colorScheme.onSurface, height: 1.5);
    final TextStyle emphasisStyle = baseStyle.copyWith(
      fontWeight: AppFontWeight.emphasis,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: theme.borders.all(color: colorScheme.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.error,
              size: 22,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: _HighlightedConfirmationText(
              text: body,
              highlightedText: highlightedText,
              baseStyle: baseStyle,
              emphasisStyle: emphasisStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedConfirmationText extends StatelessWidget {
  const _HighlightedConfirmationText({
    required this.text,
    required this.baseStyle,
    required this.emphasisStyle,
    this.highlightedText,
  });

  final String text;
  final String? highlightedText;
  final TextStyle baseStyle;
  final TextStyle emphasisStyle;

  @override
  Widget build(BuildContext context) {
    final String? highlight = highlightedText?.trim();
    if (highlight == null || highlight.isEmpty || !text.contains(highlight)) {
      return Text(text, style: baseStyle);
    }

    final List<InlineSpan> spans = <InlineSpan>[];
    int start = 0;
    while (true) {
      final int index = text.indexOf(highlight, start);
      if (index < 0) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        }
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }
      spans.add(TextSpan(text: highlight, style: emphasisStyle));
      start = index + highlight.length;
    }

    return Text.rich(TextSpan(children: spans));
  }
}
