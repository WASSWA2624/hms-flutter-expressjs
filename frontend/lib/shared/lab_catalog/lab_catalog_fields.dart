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
    this.optionIcon,
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
  final IconData Function(String value)? optionIcon;

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
            final RenderBox? fieldBox =
                _focusNode.context?.findRenderObject() as RenderBox?;
            final double fieldWidth = fieldBox != null && fieldBox.hasSize
                ? fieldBox.size.width
                : 320;
            return Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                elevation: 4,
                color: theme.colorScheme.surface,
                shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.14),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(
                    context.responsiveRadius(theme.radius.md),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: fieldWidth,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: visibleOptions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        final String option = visibleOptions[index];
                        return ListTile(
                          dense: true,
                          leading: widget.optionIcon == null
                              ? null
                              : Icon(
                                  widget.optionIcon!(option),
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                          title: Text(
                            option,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
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

/// Icon for a lab catalog category name (known presets + sensible default).
/// Builds searchable select options for free-text catalog values (category,
/// specimen, unit, etc.), optionally including a current custom value.
List<AppSelectOption<String>> labCatalogStringSelectOptions(
  Iterable<String> values, {
  IconData? icon,
  IconData Function(String value)? iconForValue,
  String? includeValue,
}) {
  final List<String> unique = labUniqueNonEmpty(<String?>[
    ...values,
    includeValue,
  ]);
  return <AppSelectOption<String>>[
    for (final String value in unique)
      AppSelectOption<String>(
        value: value,
        label: value,
        leadingIcon: iconForValue != null
            ? Icon(iconForValue(value))
            : (icon == null ? null : Icon(icon)),
        searchText: value,
      ),
  ];
}

IconData labCatalogCategoryIcon(String? category) {
  switch (labNormalizeCatalogToken(category)) {
    case 'blood gas':
      return Icons.air_outlined;
    case 'cardiac':
      return Icons.favorite_outline;
    case 'chemistry':
      return Icons.science_outlined;
    case 'coagulation':
      return Icons.water_drop_outlined;
    case 'critical care':
      return Icons.monitor_heart_outlined;
    case 'endocrine':
      return Icons.medication_liquid_outlined;
    case 'hematology':
      return Icons.bloodtype_outlined;
    case 'immunology':
      return Icons.shield_outlined;
    case 'inflammation':
      return Icons.local_fire_department_outlined;
    case 'lipids':
      return Icons.opacity_outlined;
    case 'liver':
      return Icons.spa_outlined;
    case 'microbiology':
      return Icons.biotech_outlined;
    case 'nutrition':
      return Icons.restaurant_outlined;
    case 'parasitology':
      return Icons.bug_report_outlined;
    case 'renal':
      return Icons.medical_services_outlined;
    case 'reproductive health':
      return Icons.pregnant_woman_outlined;
    case 'serology':
      return Icons.coronavirus_outlined;
    case 'transfusion':
      return Icons.volunteer_activism_outlined;
    case 'tuberculosis':
      return Icons.masks_outlined;
    case 'urinalysis':
      return Icons.science_outlined;
    case 'virology':
      return Icons.coronavirus_outlined;
    default:
      return Icons.category_outlined;
  }
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
