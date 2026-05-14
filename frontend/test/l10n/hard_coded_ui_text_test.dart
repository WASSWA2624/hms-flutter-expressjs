import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feature widgets do not hard-code user-facing text', () {
    final root = Directory('lib/features');
    final offenders = <String>[];

    for (final file
        in root
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();

      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index].trimLeft();

        if (_isDirective(line)) {
          continue;
        }

        for (final pattern in _patterns) {
          if (pattern.expression.hasMatch(line)) {
            offenders.add(
              '${file.path}:${index + 1} ${pattern.description}: ${line.trim()}',
            );
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Move user-facing feature text into lib/l10n/app_en.arb.',
    );
  });
}

bool _isDirective(String line) {
  return line.startsWith('import ') ||
      line.startsWith('export ') ||
      line.startsWith('part ');
}

final _patterns = <_HardCodedTextPattern>[
  _HardCodedTextPattern(
    'single-quoted Text literal',
    RegExp(r"\b(?:const\s+)?Text(?:\.rich)?\s*\(\s*r?'"),
  ),
  _HardCodedTextPattern(
    'double-quoted Text literal',
    RegExp(r'\b(?:const\s+)?Text(?:\.rich)?\s*\(\s*r?"'),
  ),
  _HardCodedTextPattern(
    'single-quoted UI property literal',
    RegExp(
      r"\b(?:label|hintText|helperText|errorText|semanticsLabel|tooltip|message)\s*:\s*r?'",
    ),
  ),
  _HardCodedTextPattern(
    'double-quoted UI property literal',
    RegExp(
      r'\b(?:label|hintText|helperText|errorText|semanticsLabel|tooltip|message)\s*:\s*r?"',
    ),
  ),
];

final class _HardCodedTextPattern {
  const _HardCodedTextPattern(this.description, this.expression);

  final String description;
  final RegExp expression;
}
