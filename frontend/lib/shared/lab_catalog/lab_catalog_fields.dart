import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

@immutable
final class EditableLabValue {
  const EditableLabValue({required this.value, this.id, this.label});

  factory EditableLabValue.fromUnitOption(LabUnitOption option) {
    return EditableLabValue(
      id: option.id,
      value: option.unit ?? option.label ?? '',
      label: option.label,
    );
  }

  factory EditableLabValue.fromResultOption(LabResultOption option) {
    return EditableLabValue(
      id: option.id,
      value: option.value ?? option.label ?? '',
      label: option.label,
    );
  }

  final String value;
  final String? id;
  final String? label;
}

class LabEditableValueListField extends StatefulWidget {
  const LabEditableValueListField({
    required this.labelText,
    required this.values,
    required this.suggestions,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final String labelText;
  final List<EditableLabValue> values;
  final List<String> suggestions;
  final bool enabled;
  final ValueChanged<String> onAdd;
  final ValueChanged<EditableLabValue> onRemove;

  @override
  State<LabEditableValueListField> createState() =>
      _LabEditableValueListFieldState();
}

class _LabEditableValueListFieldState extends State<LabEditableValueListField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LabSearchableTextField(
          controller: _controller,
          labelText: widget.labelText,
          hintText: l10n.labAddValueFieldHint,
          enabled: widget.enabled,
          prefixIcon: const Icon(Icons.search),
          options: widget.suggestions,
          suffixIcon: Padding(
            padding: EdgeInsets.only(right: theme.spacing.xs),
            child: AppButton(
              iconOnly: true,
              leadingIcon: Icons.add,
              label: l10n.labAddValueAction,
              semanticLabel: l10n.labAddValueAction,
              tooltip: l10n.labAddValueAction,
              enabled: widget.enabled,
              onPressed: widget.enabled ? _addCurrentValue : null,
            ),
          ),
          onFieldSubmitted: (_) => _addCurrentValue(),
        ),
        if (widget.values.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(
                context.responsiveRadius(theme.radius.md),
              ),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  for (final EditableLabValue value in widget.values)
                    InputChip(
                      label: Text(value.value),
                      onDeleted: widget.enabled
                          ? () => widget.onRemove(value)
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _addCurrentValue() {
    final String value = _controller.text.trim();
    if (value.isEmpty) {
      return;
    }
    if (widget.values.any(
      (EditableLabValue existing) =>
          labNormalizeCatalogToken(existing.value) ==
          labNormalizeCatalogToken(value),
    )) {
      _controller.clear();
      return;
    }
    widget.onAdd(value);
    _controller.clear();
  }
}

class LabSearchableTextField extends StatefulWidget {
  const LabSearchableTextField({
    required this.controller,
    required this.labelText,
    required this.options,
    this.enabled = true,
    this.isRequired = false,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String labelText;
  final List<String> options;
  final bool enabled;
  final bool isRequired;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  State<LabSearchableTextField> createState() => _LabSearchableTextFieldState();
}

class _LabSearchableTextFieldState extends State<LabSearchableTextField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final String query = value.text.trim().toLowerCase();
        final List<String> matches = widget.options
            .where(
              (String option) =>
                  query.isEmpty || option.toLowerCase().contains(query),
            )
            .take(10)
            .toList(growable: false);
        if (query.isEmpty ||
            matches.any((String option) => option.toLowerCase() == query)) {
          return matches;
        }
        return <String>[value.text.trim(), ...matches];
      },
      onSelected: (String value) {
        widget.controller.text = value;
        widget.onChanged?.call(value);
      },
      fieldViewBuilder:
          (
            BuildContext context,
            TextEditingController controller,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted,
          ) {
            return AppTextField(
              controller: controller,
              focusNode: focusNode,
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              enabled: widget.enabled,
              isRequired: widget.isRequired,
              validator: widget.validator,
              onChanged: widget.onChanged,
              onFieldSubmitted: (String value) {
                onFieldSubmitted();
                widget.onFieldSubmitted?.call(value);
              },
            );
          },
      optionsViewBuilder:
          (
            BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options,
          ) {
            final ThemeData theme = Theme.of(context);
            final List<String> visibleOptions = options.toList(growable: false);
            if (visibleOptions.isEmpty) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                elevation: 4,
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  context.responsiveRadius(theme.radius.md),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 240,
                    maxWidth: 420,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: visibleOptions.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = visibleOptions[index];
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
    );
  }
}

String labNormalizeCatalogToken(String? value) {
  return (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

List<String> labUniqueNonEmpty(Iterable<String?> values) {
  final Set<String> seen = <String>{};
  final List<String> result = <String>[];
  for (final String? value in values) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      continue;
    }
    final String key = trimmed.toLowerCase();
    if (seen.add(key)) {
      result.add(trimmed);
    }
  }
  result.sort(
    (String left, String right) =>
        left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return result;
}
