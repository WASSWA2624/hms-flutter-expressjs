import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<bool> appListTableSaveExportFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  final FileSaveLocation? location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: const <XTypeGroup>[
      XTypeGroup(label: 'Excel', extensions: <String>['xlsx']),
    ],
  );
  if (location == null) {
    return false;
  }
  final XFile file = XFile.fromData(
    bytes,
    mimeType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    name: fileName,
  );
  await file.saveTo(location.path);
  return true;
}
