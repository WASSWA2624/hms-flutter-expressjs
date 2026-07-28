import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_list_table_text_policy.dart';

const Set<String> appDefaultIdentifierPlaceholders = <String>{
  'unknown',
  'n/a',
  'na',
  'missing',
  'unavailable',
  'not available',
  '-',
  '--',
  '—',
};

bool isCopyableIdentifierValue(
  String? value, {
  Iterable<String> placeholderValues = const <String>[],
}) {
  final String normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return false;
  }

  final String lower = normalized.toLowerCase();
  final Set<String> placeholders = <String>{
    ...appDefaultIdentifierPlaceholders,
    for (final String placeholder in placeholderValues)
      placeholder.trim().toLowerCase(),
  }..removeWhere((String placeholder) => placeholder.isEmpty);

  return !placeholders.contains(lower);
}

class AppCopyableIdentifier extends StatefulWidget {
  const AppCopyableIdentifier({
    required this.value,
    this.tooltip,
    this.copiedTooltip,
    this.copiedMessage,
    this.semanticLabel,
    this.placeholderValues = const <String>{},
    this.showCopyIcon = true,
    this.maxLines = 1,
    this.textStyle,
    this.onCopied,
    super.key,
  });

  final String? value;
  final String? tooltip;
  final String? copiedTooltip;
  final String? copiedMessage;
  final String? semanticLabel;
  final Set<String> placeholderValues;
  final bool showCopyIcon;
  final int maxLines;
  final TextStyle? textStyle;
  final VoidCallback? onCopied;

  @override
  State<AppCopyableIdentifier> createState() => _AppCopyableIdentifierState();
}

class _AppCopyableIdentifierState extends State<AppCopyableIdentifier> {
  static const Duration _successDuration = Duration(milliseconds: 1300);

  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _canCopy {
    return isCopyableIdentifierValue(
      widget.value,
      placeholderValues: <String>{
        ..._localizedPlaceholders(context),
        ...widget.placeholderValues,
      },
    );
  }

  Future<void> _copy() async {
    final String visibleValue = (widget.value ?? '').trim();
    if (!_canCopy) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: visibleValue));
    widget.onCopied?.call();

    if (!mounted) {
      return;
    }

    setState(() {
      _copied = true;
    });
    _timer?.cancel();
    _timer = Timer(_successDuration, () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });

    final String message =
        widget.copiedMessage ?? context.l10n.identifierCopiedMessage;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String visibleValue = (widget.value ?? '').trim();
    final TextStyle? effectiveTextStyle =
        widget.textStyle ??
        theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final bool wrap = AppListTableTextPolicy.wrapOf(context);
    final int? maxLines = wrap ? null : widget.maxLines;
    final TextOverflow overflow = wrap
        ? TextOverflow.visible
        : TextOverflow.ellipsis;

    if (!_canCopy) {
      return Text(
        visibleValue,
        maxLines: maxLines,
        softWrap: wrap || widget.maxLines != 1,
        overflow: overflow,
        style: effectiveTextStyle,
      );
    }

    final String tooltip = _copied
        ? widget.copiedTooltip ??
              widget.copiedMessage ??
              context.l10n.identifierCopiedMessage
        : widget.tooltip ?? context.l10n.copyIdentifierAction;
    final String semanticLabel =
        widget.semanticLabel ?? '$tooltip: $visibleValue';
    final Color iconColor = _copied
        ? theme.statusColors.success
        : colorScheme.primary;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Semantics(
        button: true,
        enabled: true,
        label: semanticLabel,
        onTap: _copy,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _copy,
              borderRadius: BorderRadius.circular(theme.radius.sm),
              child: Row(
                crossAxisAlignment: wrap
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      visibleValue,
                      maxLines: maxLines,
                      softWrap: wrap || widget.maxLines != 1,
                      overflow: overflow,
                      style: effectiveTextStyle?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (widget.showCopyIcon) ...<Widget>[
                    SizedBox(width: theme.spacing.xs),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        _copied ? Icons.check : Icons.copy_outlined,
                        key: ValueKey<bool>(_copied),
                        size: theme.appTokens.listIconSize,
                        color: iconColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Set<String> _localizedPlaceholders(BuildContext context) {
  final l10n = context.l10n;
  return <String>{
    l10n.profileUnknownValue,
    l10n.patientsGenderUnknown,
    l10n.housekeepingStatusUnknown,
    l10n.pharmacyUnknownStatusLabel,
    l10n.pharmacyStockUnknown,
    l10n.physiotherapyUnknownStatusLabel,
  };
}
