import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_report_preview_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LabReportPreviewPreferences', () {
    test('reads defaults when unset', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LabReportPreviewSettings settings =
          LabReportPreviewPreferences.read(prefs);

      expect(settings.decimalPlaces, 2);
      expect(settings.showRangeGender, isTrue);
      expect(settings.showRangeAge, isTrue);
      expect(
        settings.metadataKeys,
        containsAll(<String>[
          LabReportMetadataKeys.patientId,
          LabReportMetadataKeys.encounter,
        ]),
      );
    });

    test('persists and restores custom settings', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final LabReportPreviewSettings custom = LabReportPreviewSettings.defaults
          .copyWith(
            decimalPlaces: 0,
            showRangeGender: false,
            showRangeAge: false,
            showRangeMethod: false,
            metadataKeys: <String>{
              LabReportMetadataKeys.orderIds,
              LabReportMetadataKeys.patientAge,
            },
          );

      await LabReportPreviewPreferences.write(prefs, custom);
      final LabReportPreviewSettings restored =
          LabReportPreviewPreferences.read(prefs);

      expect(restored.decimalPlaces, 0);
      expect(restored.showRangeGender, isFalse);
      expect(restored.showRangeAge, isFalse);
      expect(restored.showRangeMethod, isFalse);
      expect(restored.metadataKeys, <String>{
        LabReportMetadataKeys.orderIds,
        LabReportMetadataKeys.patientAge,
      });
    });
  });
}
