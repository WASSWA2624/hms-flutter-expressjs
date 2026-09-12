import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User detail access mutations report inline', () {
    late String detailDialogSource;

    setUpAll(() {
      final String source = File(
        'lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart',
      ).readAsStringSync();
      final int start = source.indexOf(
        'class _AccessAdminUserDetailDialogState',
      );
      expect(start, greaterThanOrEqualTo(0));
      final int end = source.indexOf('\nclass ', start + 10);
      expect(end, greaterThan(start));
      detailDialogSource = source.substring(start, end);
    });

    test('no SnackBar is raised from inside the modal', () {
      // A SnackBar from a modal renders behind it, so role / permission
      // failures were invisible to the admin.
      expect(detailDialogSource.contains('ScaffoldMessenger'), isFalse);
      expect(detailDialogSource.contains('SnackBar('), isFalse);
    });

    test('failures and notices render as inline banners', () {
      expect(
        detailDialogSource.contains('AppFormInformationBanner.failure('),
        isTrue,
      );
      expect(
        detailDialogSource.contains('AppFormInformationBanner.message('),
        isTrue,
      );
      expect(detailDialogSource.contains('_reportAccessFailure'), isTrue);
      expect(detailDialogSource.contains('_reportAccessNotice'), isTrue);
    });

    test('a successful reload clears stale feedback', () {
      expect(detailDialogSource.contains('_accessFailure = null;'), isTrue);
      expect(detailDialogSource.contains('_clearAccessFeedback()'), isTrue);
    });
  });
}
