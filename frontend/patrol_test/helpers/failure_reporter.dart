import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:patrol/patrol.dart';

import 'failure_reporter_io.dart'
    if (dart.library.html) 'failure_reporter_web.dart' as failure_storage;

export 'package:flutter_test/flutter_test.dart';

/// Root directory for Patrol failure diagnostic bundles (native/desktop targets).
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
    'gitSha': failure_storage.readPatrolGitSha(),
    'timestamp': timestamp.toIso8601String(),
    'reproCommand': reproCommand,
  };

  final String summary = '''
Patrol test failure
===================
Test: $testName
Platform: $platform
Viewport: ${viewport.width.toStringAsFixed(0)} x ${viewport.height.toStringAsFixed(0)}
Route: ${route ?? 'unknown'}
Error: $error

Repro:
$reproCommand
''';

  final Uint8List? screenshotBytes = await _captureScreenshotBytes($);

  await failure_storage.writePatrolFailureBundle(
    runId: runId,
    payload: payload,
    summary: summary,
    screenshotBytes: screenshotBytes,
  );
}

Future<Uint8List?> _captureScreenshotBytes(PatrolIntegrationTester $) async {
  final TestWidgetsFlutterBinding binding = $.tester.binding;
  if (binding is IntegrationTestWidgetsFlutterBinding) {
    await binding.convertFlutterSurfaceToImage();
    final List<int> bytes = await binding.takeScreenshot('patrol-failure');
    return Uint8List.fromList(bytes);
  }

  try {
    final Finder repaintBoundary = find.byType(RepaintBoundary).first;
    if (repaintBoundary.evaluate().isEmpty) {
      return null;
    }
    final RenderRepaintBoundary boundary = $.tester.renderObject(
      repaintBoundary,
    );
    final ui.Image image = await boundary.toImage();
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (byteData == null) {
      return null;
    }
    return byteData.buffer.asUint8List();
  } on Object {
    return null;
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

String _sanitizeFileName(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
