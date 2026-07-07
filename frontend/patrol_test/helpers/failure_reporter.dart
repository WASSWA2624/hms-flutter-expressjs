import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';

/// Root directory for Patrol failure diagnostic bundles.
const String patrolReportsRoot = 'build/patrol_reports';

/// Wraps [patrolTest] and writes a diagnostic bundle on failure.
void patrolTestWithDiagnostics(
  String description,
  Future<void> Function(PatrolIntegrationTester $) callback, {
  bool? skip,
  Timeout? timeout,
  bool semanticsEnabled = true,
  TestVariant<Object?> variant = const DefaultTestVariant(),
  dynamic tags,
  PatrolTesterConfig config = const PatrolTesterConfig(printLogs: true),
  String? targetFile,
  String platform = 'unknown',
}) {
  patrolTest(
    description,
    ($) async {
      try {
        await callback($);
      } catch (error, stackTrace) {
        await capturePatrolFailureDiagnostics(
          $: $,
          testName: description,
          error: error,
          stackTrace: stackTrace,
          targetFile: targetFile,
          platform: platform,
        );
        rethrow;
      }
    },
    skip: skip,
    timeout: timeout,
    semanticsEnabled: semanticsEnabled,
    variant: variant,
    tags: tags,
    config: config,
  );
}

/// Captures screenshot, summary, and structured JSON for a failed Patrol test.
Future<void> capturePatrolFailureDiagnostics({
  required PatrolIntegrationTester $,
  required String testName,
  required Object error,
  required StackTrace stackTrace,
  String? targetFile,
  String platform = 'unknown',
}) async {
  final DateTime timestamp = DateTime.now().toUtc();
  final String safeName = _sanitizeFileName(testName);
  final String runId =
      '${timestamp.toIso8601String().replaceAll(':', '-')}_$safeName';
  final Directory reportDir = Directory('$patrolReportsRoot/$runId');
  await reportDir.create(recursive: true);

  final Size viewport = $.tester.view.physicalSize;
  final String? route = _currentRoute($);
  final String reproTarget = targetFile ?? 'patrol_test';
  final String reproCommand =
      'patrol test -t $reproTarget --platform $platform';

  final Map<String, Object?> payload = <String, Object?>{
    'testName': testName,
    'assertionMessage': error.toString(),
    'platform': platform,
    'viewport': <String, double>{
      'width': viewport.width,
      'height': viewport.height,
      'devicePixelRatio': $.tester.view.devicePixelRatio,
    },
    'route': route,
    'finderChain': <String>[],
    'semanticsSummary': _semanticsSummary($),
    'stackTrace': stackTrace.toString(),
    'gitSha': _readGitSha(),
    'timestamp': timestamp.toIso8601String(),
    'reproCommand': reproCommand,
  };

  await File('${reportDir.path}/diagnostics.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(payload),
  );

  await File('${reportDir.path}/summary.txt').writeAsString('''
Patrol test failure
===================
Test: $testName
Platform: $platform
Viewport: ${viewport.width.toStringAsFixed(0)} x ${viewport.height.toStringAsFixed(0)}
Route: ${route ?? 'unknown'}
Error: $error

Repro:
$reproCommand
''');

  final bool screenshotSaved = await _captureScreenshot(
    $,
    File('${reportDir.path}/screenshot.png'),
  );
  if (!screenshotSaved) {
    await File('${reportDir.path}/screenshot.txt').writeAsString(
      'Screenshot capture was unavailable on this platform binding. '
      'For web runs, inspect Playwright artifacts under build/patrol_web_results/.',
    );
  }

  await File('${reportDir.path}/latest.txt').writeAsString(reportDir.path);
  await Directory(patrolReportsRoot).create(recursive: true);
  await File('$patrolReportsRoot/latest.txt').writeAsString(reportDir.path);
}

Future<bool> _captureScreenshot(
  PatrolIntegrationTester $,
  File outputFile,
) async {
  final TestWidgetsFlutterBinding binding = $.tester.binding;
  if (binding is IntegrationTestWidgetsFlutterBinding) {
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot(outputFile.path);
    return outputFile.existsSync();
  }

  try {
    final Finder repaintBoundary = find.byType(RepaintBoundary).first;
    if (repaintBoundary.evaluate().isEmpty) {
      return false;
    }
    final RenderRepaintBoundary boundary = $.tester.renderObject(
      repaintBoundary,
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) {
      return false;
    }
    await outputFile.writeAsBytes(byteData.buffer.asUint8List());
    return true;
  } on Object {
    return false;
  }
}

String? _currentRoute(PatrolIntegrationTester $) {
  try {
    final Element context = $.tester.element(find.byType(Scaffold).first);
    return GoRouter.of(context).state.uri.toString();
  } on Object {
    return null;
  }
}

List<String> _semanticsSummary(PatrolIntegrationTester $) {
  return find
      .byType(Semantics)
      .evaluate()
      .map((Element element) => element.toStringShort())
      .take(40)
      .toList();
}

String? _readGitSha() {
  final String? fromEnv = Platform.environment['PATROL_GIT_SHA'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  if (kIsWeb) {
    return null;
  }
  try {
    final ProcessResult result = Process.runSync(
      'git',
      <String>['rev-parse', 'HEAD'],
      workingDirectory: Directory.current.path,
    );
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } on Object {
    return null;
  }
  return null;
}

String _sanitizeFileName(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
