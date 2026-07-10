import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

/// Shared confirmation dialog for module actions that either return a boolean
/// confirmation or run an async action before closing.
class AppConfirmActionDialog extends StatefulWidget {
  const AppConfirmActionDialog({
    required this.title,
    required this.body,
    required this.submitLabel,
    this.onConfirm,
    this.icon = const Icon(Icons.help_outline),
    this.highlightedText,
    this.destructive = false,
    this.submitLeadingIcon,
    this.cancelLeadingIcon = Icons.close,
    this.maxWidth = 600,
    super.key,
  });

  final String title;
  final String body;
  final String submitLabel;
  final Widget icon;
  final String? highlightedText;
  final bool destructive;
  final IconData? submitLeadingIcon;
  final IconData cancelLeadingIcon;
  final double maxWidth;
  final Future<AppFailure?> Function()? onConfirm;

  @override
  State<AppConfirmActionDialog> createState() => _AppConfirmActionDialogState();
}

class _AppConfirmActionDialogState extends State<AppConfirmActionDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return AppDialog(
      title: Text(widget.title),
      icon: _resolveHeaderIcon(colorScheme),
      maxWidth: widget.maxWidth,
      initialMaximized: false,
      closeEnabled: !_isSaving,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
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
        ],
      ),
      actions: _actionDialogButtons(
        context,
        submitLabel: widget.submitLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
        destructive: widget.destructive,
        submitLeadingIcon: widget.submitLeadingIcon,
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
    final Future<AppFailure?> Function()? onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await onConfirm();
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

/// Shared free-text action dialog for notes, summaries, handovers, and similar
/// module workflows.
class AppTextActionDialog extends StatefulWidget {
  const AppTextActionDialog({
    required this.title,
    required this.fieldLabel,
    required this.submitLabel,
    required this.onSubmit,
    this.icon = const Icon(Icons.edit_note_outlined),
    this.description,
    this.sectionTitle,
    this.initialValue,
    this.prefixIcon,
    this.minLines = 3,
    this.maxLines = 8,
    this.maxWidth = 720,
    this.autofocus = true,
    this.isRequired = true,
    super.key,
  });

  final String title;
  final String? sectionTitle;
  final String? description;
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
  final Future<AppFailure?> Function(String value) onSubmit;

  @override
  State<AppTextActionDialog> createState() => _AppTextActionDialogState();
}

/// Shared select-only dialog for simple action modals that return a value.
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
    this.searchable = false,
    this.isRequired = true,
    this.scrollable = false,
    this.maxWidth = 600,
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
  final bool searchable;
  final bool isRequired;
  final bool scrollable;
  final double maxWidth;

  @override
  State<AppSelectActionDialog<T>> createState() =>
      _AppSelectActionDialogState<T>();
}

class _AppSelectActionDialogState<T> extends State<AppSelectActionDialog<T>> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  T? _value;

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
      scrollable: widget.scrollable,
      maxWidth: widget.maxWidth,
      initialMaximized: false,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[_selectField()],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.submitLabel,
          leadingIcon: Icons.save_outlined,
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
        options: widget.options,
        validator: widget.isRequired ? _requiredSelect : null,
        onChanged: _handleChanged,
      );
    }

    return AppSelectField<T>(
      value: _value,
      labelText: widget.fieldLabel,
      isRequired: widget.isRequired,
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

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_value);
    }
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
    this.icon = const Icon(Icons.edit_note_outlined),
    this.initialValue,
    this.prefixIcon,
    this.minLines = 3,
    this.maxLines = 6,
    this.maxWidth = 600,
    this.isRequired = true,
    this.scrollable = false,
    super.key,
  });

  final String title;
  final String fieldLabel;
  final String submitLabel;
  final String cancelLabel;
  final String requiredMessage;
  final Widget icon;
  final Widget? prefixIcon;
  final String? initialValue;
  final int minLines;
  final int maxLines;
  final double maxWidth;
  final bool isRequired;
  final bool scrollable;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      scrollable: widget.scrollable,
      maxWidth: widget.maxWidth,
      initialMaximized: false,
      content: AppFormShell(
        formKey: _formKey,
        children: <Widget>[
          AppTextField(
            controller: _controller,
            labelText: widget.fieldLabel,
            prefixIcon: widget.prefixIcon,
            isRequired: widget.isRequired,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            textCapitalization: TextCapitalization.sentences,
            validator: widget.isRequired ? _requiredText : null,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: widget.cancelLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.submitLabel,
          leadingIcon: Icons.check_circle_outline,
          onPressed: _submit,
        ),
      ],
    );
  }

  String? _requiredText(String? value) {
    return (value ?? '').trim().isEmpty ? widget.requiredMessage : null;
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
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      maxWidth: widget.maxWidth,
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          title: widget.sectionTitle,
          description: widget.description,
          density: AppFormSectionDensity.spacious,
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
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
        ),
      ),
      actions: _actionDialogButtons(
        context,
        submitLabel: widget.submitLabel,
        isSaving: _isSaving,
        onSubmit: _submit,
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
  IconData cancelLeadingIcon = Icons.close,
}) {
  final AppLocalizations l10n = context.l10n;
  final ColorScheme colorScheme = Theme.of(context).colorScheme;

  return <Widget>[
    AppButton.secondary(
      label: l10n.commonCancelActionLabel,
      leadingIcon: cancelLeadingIcon,
      enabled: !isSaving,
      onPressed: () => Navigator.of(context).pop(false),
    ),
    AppButton.primary(
      label: submitLabel,
      leadingIcon: submitLeadingIcon ?? (destructive ? Icons.delete_outline : null),
      color: destructive ? colorScheme.error : null,
      isLoading: isSaving,
      onPressed: onSubmit,
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
        TextStyle(color: colorScheme.onSurface, height: 1.5);
    final TextStyle emphasisStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(theme.spacing.md),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.28)),
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
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }
      spans.add(TextSpan(text: highlight, style: emphasisStyle));
      start = index + highlight.length;
    }

    return Text.rich(TextSpan(children: spans));
  }
}
