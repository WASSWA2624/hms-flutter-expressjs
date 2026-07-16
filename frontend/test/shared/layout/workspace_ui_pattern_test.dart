import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workspace pages use the shared workspace shell', () {
    final offenders = <String>[];

    for (final file in _workspacePageFiles()) {
      final source = file.readAsStringSync();
      if (!_usesSharedWorkspaceShell(source)) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Module workspace pages must use AppWorkspace or the standardized '
          'ResponsivePage + AppTabStrip/AppListTable shell.',
    );
  });

  test('feature pages do not create duplicate workspace UI primitives', () {
    final offenders = <String>[];

    for (final file in _featurePresentationPageFiles()) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        for (final pattern in _duplicatePrimitivePatterns) {
          if (pattern.expression.hasMatch(line)) {
            offenders.add(
              '${file.path}:${index + 1} ${pattern.description}: '
              '${line.trim()}',
            );
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppListTable, AppSearchBar/AppListTableSearch, AppDialog, '
          'AppTextField, and shared workspace components in feature pages.',
    );
  });
}

Iterable<File> _workspacePageFiles() {
  return _featurePresentationPageFiles().where((File file) {
    return file.path.endsWith('_workspace_page.dart') ||
        file.path.endsWith('patient_registry_page.dart') ||
        file.path.endsWith('tenant_facility_setup_page.dart');
  });
}

bool _usesSharedWorkspaceShell(String source) {
  if (source.contains('AppWorkspace(')) {
    return true;
  }
  // Reception-style tab-and-table workspaces.
  final bool hasTable = source.contains('AppListTable<');
  final bool hasTabs = source.contains('AppTabStrip(');
  final bool hasResponsivePage = source.contains('ResponsivePage(');
  return hasTable && (hasTabs || hasResponsivePage);
}

Iterable<File> _featurePresentationPageFiles() {
  final root = Directory('lib/features');
  if (!root.existsSync()) {
    return const Iterable<File>.empty();
  }

  return root.listSync(recursive: true).whereType<File>().where((File file) {
    return file.path.endsWith('.dart') &&
        file.path.contains(
          '${Platform.pathSeparator}presentation'
          '${Platform.pathSeparator}pages${Platform.pathSeparator}',
        );
  });
}

final _duplicatePrimitivePatterns = <_DuplicatePrimitivePattern>[
  _DuplicatePrimitivePattern(
    'raw Flutter dialog',
    RegExp(r'\bshowDialog\s*<|\bshowDialog\s*\('),
  ),
  _DuplicatePrimitivePattern('raw AlertDialog', RegExp(r'\bAlertDialog\s*\(')),
  _DuplicatePrimitivePattern(
    'raw DataTable',
    RegExp(r'\b(?:PaginatedDataTable|DataTable)\s*\('),
  ),
  _DuplicatePrimitivePattern(
    'raw search/text field',
    RegExp(r'\b(?:SearchBar|TextField|TextFormField)\s*\('),
  ),
];

final class _DuplicatePrimitivePattern {
  const _DuplicatePrimitivePattern(this.description, this.expression);

  final String description;
  final RegExp expression;
}
