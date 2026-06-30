import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_hero_panel.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

void main() {
  group('HomeHeroPanel', () {
    testWidgets('hides below md breakpoint', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(500, 800)),
            child: HomeHeroPanel(
              subtitle: 'Operational snapshot',
              contextLine: homeDashboardContextLine(
                role: AppRole.hr,
                context: const HomeDashboardContext(
                  facilityName: 'DemoCare General Hospital',
                  facilityType: 'Hospital',
                ),
              ),
              generatedAt: DateTime(2026, 6, 30, 15, 12),
              usesFallbackData: false,
              fullWidth: true,
            ),
          ),
        ),
      );

      expect(find.byType(HomeHeroPanel), findsOneWidget);
      expect(find.text('Operational snapshot'), findsNothing);
    });

    testWidgets('shows full-width row on desktop', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 800)),
            child: HomeHeroPanel(
              subtitle: 'Operational snapshot',
              contextLine: homeDashboardContextLine(
                role: AppRole.hr,
                context: const HomeDashboardContext(
                  facilityName: 'DemoCare General Hospital',
                  facilityType: 'Hospital',
                ),
              ),
              generatedAt: DateTime(2026, 6, 30, 15, 12),
              usesFallbackData: false,
              fullWidth: true,
            ),
          ),
        ),
      );

      expect(find.text('Operational snapshot'), findsOneWidget);
      expect(find.byType(AppWorkspaceStatusBadge), findsOneWidget);
    });

    test('homeDashboardContextLine hides facility for HR role', () {
      const HomeDashboardContext context = HomeDashboardContext(
        facilityName: 'DemoCare General Hospital',
        facilityType: 'Hospital',
        tenantId: 'tenant-1',
      );

      expect(
        homeDashboardContextLine(role: AppRole.hr, context: context),
        'Tenant tenant-1',
      );
      expect(
        homeDashboardContextLine(role: AppRole.tenantAdmin, context: context),
        contains('DemoCare General Hospital'),
      );
    });
  });
}
