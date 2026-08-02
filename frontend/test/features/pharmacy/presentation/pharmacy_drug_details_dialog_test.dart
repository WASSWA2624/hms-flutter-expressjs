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
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_drug_details_dialog.dart';
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
    'drug details dialog uses Drug Details title and inline meta rows',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const PharmacyDrug drug = PharmacyDrug(
        id: 'drug-1',
        displayId: 'DRG-TEST',
        brandName: 'BrandX',
        genericName: 'Acyclovir',
        code: 'ACV400',
        form: 'Tablet',
        strength: '400 mg',
        stockStatus: 'IN_STOCK',
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
                      await openPharmacyDrugDetailsDialog(
                        context,
                        ref,
                        drug: drug,
                        writeRequirement: const AccessRequirement(),
                        onDelete: (_) async => false,
                      );
                    },
                    child: const Text('Open drug details'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open drug details'));
      await tester.pumpAndSettle();

      expect(find.text('DRUG DETAILS'), findsOneWidget);
      expect(find.textContaining('Brand name:'), findsOneWidget);
      expect(find.textContaining('Generic name:'), findsOneWidget);
      expect(find.textContaining('Drug code:'), findsOneWidget);
      expect(find.byType(AppInfoTileGrid), findsNothing);
      expect(find.text('Acyclovir'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    },
  );
}
