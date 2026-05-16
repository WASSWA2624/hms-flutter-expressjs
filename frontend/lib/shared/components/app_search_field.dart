import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    required this.semanticLabel,
    this.hintText,
    this.clearLabel,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.enabled = true,
    this.isLoading = false,
    this.autofocus = false,
    this.showClearButton = true,
    super.key,
  });

  final TextEditingController controller;
  final String semanticLabel;
  final String? hintText;
  final String? clearLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool enabled;
  final bool isLoading;
  final bool autofocus;
  final bool showClearButton;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        final String effectiveClearLabel =
            clearLabel ?? MaterialLocalizations.of(context).clearButtonTooltip;
        final bool canClear =
            showClearButton && value.text.isNotEmpty && enabled && !isLoading;

        return AppTextField(
          controller: controller,
          semanticLabel: semanticLabel,
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: canClear
              ? AppIconButton(
                  icon: Icons.close,
                  semanticLabel: effectiveClearLabel,
                  tooltip: effectiveClearLabel,
                  onPressed: _clear,
                )
              : null,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          isLoading: isLoading,
          autofocus: autofocus,
        );
      },
    );
  }

  void _clear() {
    controller.clear();
    onClear?.call();
  }
}
