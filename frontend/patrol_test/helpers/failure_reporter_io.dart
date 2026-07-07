import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<void> writePatrolFailureBundle({
  required String runId,
  required Map<String, Object?> payload,
  required String summary,
  Uint8List? screenshotBytes,
}) async {
  const String patrolReportsRoot = 'build/patrol_reports';
  final Directory reportDir = Directory('$patrolReportsRoot/$runId');
  await reportDir.create(recursive: true);

  await File(
    '${reportDir.path}/diagnostics.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  await File('${reportDir.path}/summary.txt').writeAsString(summary);

  if (screenshotBytes != null) {
    await File(
      '${reportDir.path}/screenshot.png',
    ).writeAsBytes(screenshotBytes);
  } else {
    await File('${reportDir.path}/screenshot.txt').writeAsString(
      'Screenshot capture was unavailable on this platform binding.',
    );
  }

  await Directory(patrolReportsRoot).create(recursive: true);
  await File('$patrolReportsRoot/latest.txt').writeAsString(reportDir.path);
}

String? readPatrolGitSha() {
  const String fromDefine = String.fromEnvironment('PATROL_GIT_SHA');
  if (fromDefine.isNotEmpty) {
    return fromDefine;
  }
  try {
    final ProcessResult result = Process.runSync('git', <String>[
      'rev-parse',
      'HEAD',
    ], workingDirectory: Directory.current.path);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
  } on Object {
    return null;
  }
  return null;
}
