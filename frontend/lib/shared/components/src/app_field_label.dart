import 'package:flutter/material.dart';

class AppFieldRequirementScope extends InheritedWidget {
  const AppFieldRequirementScope({
    required this.showOptionalIndicators,
    required super.child,
    super.key,
  });

  final bool showOptionalIndicators;

  static bool shouldShowOptionalIndicator(BuildContext context) {
    final AppFieldRequirementScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppFieldRequirementScope>();
    if (scope?.showOptionalIndicators != true) {
      return false;
    }

    return context.findAncestorWidgetOfExactType<Form>() != null;
  }

  @override
  bool updateShouldNotify(AppFieldRequirementScope oldWidget) {
    return showOptionalIndicators != oldWidget.showOptionalIndicators;
  }
}

String? appFieldLabel(String? label, {required bool isRequired}) {
  final _AppFieldLabelParts? parts = _parseFieldLabel(label);
  if (parts == null) {
    return label;
  }

  if (isRequired || parts.isRequired) {
    return '${parts.label} *';
  }

  if (parts.isOptional) {
    return '${parts.label} (optional)';
  }

  return parts.label;
}

Widget? appFieldLabelWidget(
  BuildContext context,
  String? label, {
  required bool isRequired,
  TextStyle? style,
}) {
  final _AppFieldLabelParts? parts = _parseFieldLabel(label);
  if (parts == null) {
    return null;
  }

  final ThemeData theme = Theme.of(context);
  final bool markRequired = isRequired || parts.isRequired;
  final bool markOptional =
      !markRequired &&
      (parts.isOptional ||
          AppFieldRequirementScope.shouldShowOptionalIndicator(context));

  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(text: parts.label),
        if (markRequired)
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          )
        else if (markOptional)
          TextSpan(
            text: ' (optional)',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
}

_AppFieldLabelParts? _parseFieldLabel(String? label) {
  final String value = label?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }

  final bool isRequired = _requiredSuffix.hasMatch(value);
  final bool isOptional = !isRequired && _optionalSuffix.hasMatch(value);
  final String normalized = value
      .replaceFirst(isRequired ? _requiredSuffix : _optionalSuffix, '')
      .trim();

  return _AppFieldLabelParts(
    label: normalized.isEmpty ? value : normalized,
    isRequired: isRequired,
    isOptional: isOptional,
  );
}

final RegExp _requiredSuffix = RegExp(
  r'\s*\(required\)\s*$',
  caseSensitive: false,
);
final RegExp _optionalSuffix = RegExp(
  r'\s*\(optional\)\s*$',
  caseSensitive: false,
);

class _AppFieldLabelParts {
  const _AppFieldLabelParts({
    required this.label,
    required this.isRequired,
    required this.isOptional,
  });

  final String label;
  final bool isRequired;
  final bool isOptional;
}
