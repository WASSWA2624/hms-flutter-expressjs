import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

Future<void> writePatrolFailureBundle({
  required String runId,
  required Map<String, Object?> payload,
  required String summary,
  Uint8List? screenshotBytes,
}) async {
  debugPrint('PATROL_FAILURE_DIAGNOSTICS ($runId): ${jsonEncode(payload)}');
  debugPrint(summary);
  if (screenshotBytes != null) {
    debugPrint(
      'PATROL_FAILURE_SCREENSHOT ($runId): ${screenshotBytes.length} bytes',
    );
  }
}

String? readPatrolGitSha() {
  const String fromDefine = String.fromEnvironment('PATROL_GIT_SHA');
  if (fromDefine.isNotEmpty) {
    return fromDefine;
  }
  return null;
}
