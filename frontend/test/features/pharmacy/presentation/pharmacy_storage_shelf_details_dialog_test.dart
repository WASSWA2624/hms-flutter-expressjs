import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_storage_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockPharmacyRepository extends Mock implements PharmacyRepository {}

void _stubBootstrap(_MockPharmacyRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer(
    (_) async => const Result<PharmacyWorkbench>.success(
      PharmacyWorkbench(
        summary: PharmacyWorkbenchSummary(),
        orders: AppPage<PharmacyOrder>(
          items: <PharmacyOrder>[],
          request: AppPageRequest(),
        ),
      ),
    ),
  );
  when(() => repository.searchDrugs(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyDrug>>.success(
      AppPage<PharmacyDrug>(items: <PharmacyDrug>[], request: AppPageRequest()),
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
    () => repository.loadStorageLayout(
      includeInactive: any(named: 'includeInactive'),
      includeDeleted: any(named: 'includeDeleted'),
      facilityId: any(named: 'facilityId'),
    ),
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

void main() {
  late _MockPharmacyRepository repository;

  setUpAll(() {
    registerFallbackValue(const PharmacyWorkbenchQuery());
    registerFallbackValue(const PharmacyDrugQuery());
    registerFallbackValue(const PharmacyFormularyQuery());
    registerFallbackValue(const PharmacyInventoryStockQuery());
  });

  setUp(() {
    repository = _MockPharmacyRepository();
    _stubBootstrap(repository);
  });

  testWidgets(
    'shelf details dialog uses Shelf Details title and inline meta rows',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const PharmacyStorageShelf shelf = PharmacyStorageShelf(
        id: 'shelf-1',
        displayId: 'PSS-TEST',
        shelfCode: 'A-01',
        label: 'Aisle A, shelf 1',
      );
      const PharmacyStorageRoom room = PharmacyStorageRoom(
        id: 'room-1',
        name: 'Room 1',
        code: 'RM001',
        shelves: <PharmacyStorageShelf>[shelf],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pharmacyRepositoryProvider.overrideWithValue(repository),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (BuildContext context, WidgetRef ref, _) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      await openPharmacyStorageShelfDetailsDialog(
                        context,
                        ref,
                        room: room,
                        shelf: shelf,
                        writeRequirement: const AccessRequirement(),
                      );
                    },
                    child: const Text('Open shelf details'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open shelf details'));
      await tester.pumpAndSettle();

      expect(find.text('SHELF DETAILS'), findsOneWidget);
      expect(find.textContaining('Shelf code:'), findsOneWidget);
      expect(find.textContaining('Shelf label:'), findsOneWidget);
      expect(find.textContaining('Storage room:'), findsOneWidget);
      expect(find.byType(AppInfoTileGrid), findsNothing);
      expect(find.text('A-01'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    },
  );
}
