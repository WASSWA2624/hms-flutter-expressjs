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
    'room details dialog uses Room Details title, inline meta, and shelves table',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const PharmacyStorageRoom room = PharmacyStorageRoom(
        id: 'room-1',
        displayId: 'PSR-TEST',
        name: 'Room 1',
        code: 'RM001',
        shelves: <PharmacyStorageShelf>[
          PharmacyStorageShelf(
            id: 'shelf-1',
            shelfCode: 'A-01',
            label: 'Aisle A, shelf 1',
          ),
        ],
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
                      await openPharmacyStorageRoomDetailsDialog(
                        context,
                        ref,
                        room: room,
                        writeRequirement: const AccessRequirement(),
                      );
                    },
                    child: const Text('Open details'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();

      expect(find.text('ROOM DETAILS'), findsOneWidget);
      expect(find.text('Room 1'), findsWidgets);
      expect(find.textContaining('Room name:'), findsOneWidget);
      expect(find.textContaining('Room code:'), findsOneWidget);
      expect(find.byType(AppInfoTileGrid), findsNothing);
      expect(find.text('Add shelf'), findsOneWidget);
      expect(find.byType(AppListTable<PharmacyStorageShelf>), findsOneWidget);
      expect(find.text('A-01'), findsOneWidget);
      expect(find.text('Aisle A, shelf 1'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    },
  );
}
