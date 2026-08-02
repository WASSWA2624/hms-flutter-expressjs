import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_catalog_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

const PharmacyWorkbench _workbench = PharmacyWorkbench(
  summary: PharmacyWorkbenchSummary(),
  orders: AppPage<PharmacyOrder>(
    items: <PharmacyOrder>[],
    request: AppPageRequest(),
  ),
);

const PharmacyInventoryWorkbench _inventoryWorkbench =
    PharmacyInventoryWorkbench(
      summary: PharmacyInventoryStockSummary(),
      stocks: AppPage<PharmacyInventoryStock>(
        items: <PharmacyInventoryStock>[],
        request: AppPageRequest(),
      ),
    );

AppPage<PharmacyDrug> _drugPage() {
  return AppPage<PharmacyDrug>(
    items: <PharmacyDrug>[
      for (int i = 0; i < 12; i++)
        PharmacyDrug(
          id: 'drug-$i',
          name: 'Drug $i',
          code: 'DRG-$i',
          form: 'Tablet',
          strength: '${(i + 1) * 50}mg',
          unitPrice: 100 + i,
          pharmacyUnitPrice: 100 + i,
          facilityUnitPrice: 90 + i,
          stockStatus: 'IN_STOCK',
          storageLocationLabel: 'Room A / Shelf $i',
        ),
    ],
    request: const AppPageRequest(),
    totalItemCount: 12,
  );
}

void _stubPharmacyBootstrap(_MockPharmacyRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer(
    (_) async => const Result<PharmacyWorkbench>.success(_workbench),
  );
  when(
    () => repository.searchDrugs(any()),
  ).thenAnswer((_) async => Result<AppPage<PharmacyDrug>>.success(_drugPage()));
  when(() => repository.getInventoryStock(any())).thenAnswer(
    (_) async =>
        const Result<PharmacyInventoryWorkbench>.success(_inventoryWorkbench),
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
}

class _CatalogDialogLauncher extends ConsumerStatefulWidget {
  const _CatalogDialogLauncher();

  @override
  ConsumerState<_CatalogDialogLauncher> createState() =>
      _CatalogDialogLauncherState();
}

class _CatalogDialogLauncherState
    extends ConsumerState<_CatalogDialogLauncher> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(pharmacyWorkspaceControllerProvider.future);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => openPharmacyCatalogDialog(context, ref),
      child: const Text('Open catalog'),
    );
  }
}

void main() {
  late _MockPharmacyRepository repository;

  setUp(() {
    repository = _MockPharmacyRepository();
  });

  setUpAll(() {
    registerFallbackValue(const PharmacyWorkbenchQuery());
    registerFallbackValue(const PharmacyDrugQuery());
    registerFallbackValue(const PharmacyFormularyQuery());
    registerFallbackValue(const PharmacyInventoryStockQuery());
  });

  testWidgets(
    'catalog dialog lays out populated table with semantics enabled',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _stubPharmacyBootstrap(repository);

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
            home: Scaffold(body: _CatalogDialogLauncher()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Open catalog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('CATALOG AND STOCK'), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      // Confirms the populated table (with action-button cells) laid out.
      expect(find.text('DRG-0'), findsOneWidget);
      expect(tester.takeException(), isNull);

      handle.dispose();
    },
  );
}
