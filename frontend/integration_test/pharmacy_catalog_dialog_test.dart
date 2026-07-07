import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

const PharmacyOrder _sampleOrder = PharmacyOrder(
  id: 'order-1',
  displayId: 'PHO-3E51507634',
  patientDisplayName: 'Noah Demo-Echo',
  location: 'OUTPATIENT',
  status: 'ORDERED',
  itemCount: 1,
  quantityPrescribedTotal: 24,
  quantityDispensedTotal: 24,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _MockPharmacyRepository repository;

  setUpAll(() {
    registerFallbackValue(const PharmacyWorkbenchQuery());
    registerFallbackValue(const PharmacyDrugQuery());
    registerFallbackValue(const PharmacyFormularyQuery());
    registerFallbackValue(const PharmacyInventoryStockQuery());
  });

  setUp(() {
    repository = _MockPharmacyRepository();
    final PharmacyWorkbench workbench = PharmacyWorkbench(
      summary: const PharmacyWorkbenchSummary(totalOrders: 1),
      orders: const AppPage<PharmacyOrder>(
        items: <PharmacyOrder>[_sampleOrder],
        request: AppPageRequest(),
      ),
    );
    when(() => repository.loadWorkbench(any())).thenAnswer(
      (_) async => Result<PharmacyWorkbench>.success(workbench),
    );
    when(() => repository.searchDrugs(any())).thenAnswer(
      (_) async => const Result<AppPage<PharmacyDrug>>.success(
        AppPage<PharmacyDrug>(
          items: <PharmacyDrug>[],
          request: AppPageRequest(),
        ),
      ),
    );
    when(() => repository.getInventoryStock(any())).thenAnswer(
      (_) async => const Result<PharmacyInventoryWorkbench>.success(
        PharmacyInventoryWorkbench(
          summary: PharmacyInventoryStockSummary(),
          stocks: AppPage<PharmacyInventoryStock>(
            items: <PharmacyInventoryStock>[],
            request: AppPageRequest(),
          ),
        ),
      ),
    );
    when(
      () => repository.loadStorageLayout(facilityId: any(named: 'facilityId')),
    ).thenAnswer(
      (_) async =>
          const Result<PharmacyStorageLayout>.success(PharmacyStorageLayout()),
    );
    when(() => repository.listFormularyItems(any())).thenAnswer(
      (_) async => const Result<AppPage<PharmacyFormularyItem>>.success(
        AppPage<PharmacyFormularyItem>(
          items: <PharmacyFormularyItem>[],
          request: AppPageRequest(),
        ),
      ),
    );
  });

  testWidgets('pharmacy catalog and stock dialog opens and dismisses', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pharmacyRepositoryProvider.overrideWithValue(repository),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PharmacyWorkspacePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catalog and stock'), findsOneWidget);
    await tester.tap(find.text('Catalog and stock'));
    await tester.pumpAndSettle();

    expect(find.text('CATALOG AND STOCK'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    expect(find.text('Pharmacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
