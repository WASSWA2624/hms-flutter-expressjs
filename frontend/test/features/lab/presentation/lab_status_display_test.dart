import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_status_display.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  testWidgets('labStatusLabel maps specific result flags', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(labStatusLabel(captured, 'CRITICAL_LOW'), 'Critical low');
    expect(labStatusLabel(captured, 'CRITICAL_HIGH'), 'Critical high');
    expect(labStatusLabel(captured, 'LOW'), 'Low');
    expect(labStatusLabel(captured, 'NORMAL'), 'Normal');
    expect(labStatusLabel(captured, 'HIGH'), 'High');
    expect(labStatusLabel(captured, 'POSITIVE'), 'Positive');
    expect(labStatusLabel(captured, 'NEGATIVE'), 'Negative');
    expect(labStatusLabel(captured, 'CRITICAL'), 'Critical');
  });
}
