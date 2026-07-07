import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/pharmacy/data/repositories/pharmacy_repository_impl.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/domain/repositories/pharmacy_repository.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart';
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

void _stubBootstrap(_MockPharmacyRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer(
    (_) async => const Result<PharmacyWorkbench>.success(_workbench),
  );
  when(() => repository.searchDrugs(any())).thenAnswer(
    (_) async => const Result<AppPage<PharmacyDrug>>.success(
      AppPage<PharmacyDrug>(items: <PharmacyDrug>[], request: AppPageRequest()),
    ),
  );
  when(() => repository.getInventoryStock(any())).thenAnswer(
    (_) async =>
        const Result<PharmacyInventoryWorkbench>.success(_inventoryWorkbench),
  );
  when(
    () => repository.loadStorageLayout(
      includeInactive: any(named: 'includeInactive'),
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

Future<PharmacyWorkspaceController> _bootController(
  ProviderContainer container,
) async {
  await container.read(pharmacyWorkspaceControllerProvider.future);
  return container.read(pharmacyWorkspaceControllerProvider.notifier);
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

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        pharmacyRepositoryProvider.overrideWithValue(repository),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('deleteStorageRoom calls repository and refreshes layout', () async {
    when(
      () => repository.deleteStorageRoom(any()),
    ).thenAnswer((_) async => const Result<void>.success(null));

    final ProviderContainer container = makeContainer();
    final PharmacyWorkspaceController controller = await _bootController(
      container,
    );

    final AppFailure? failure = await controller.deleteStorageRoom('room-1');

    expect(failure, isNull);
    verify(() => repository.deleteStorageRoom('room-1')).called(1);
    verify(
      () => repository.loadStorageLayout(
        includeInactive: any(named: 'includeInactive'),
        facilityId: any(named: 'facilityId'),
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test('deleteStorageShelf calls repository and refreshes layout', () async {
    when(
      () => repository.deleteStorageShelf(any()),
    ).thenAnswer((_) async => const Result<void>.success(null));

    final ProviderContainer container = makeContainer();
    final PharmacyWorkspaceController controller = await _bootController(
      container,
    );

    final AppFailure? failure = await controller.deleteStorageShelf('shelf-1');

    expect(failure, isNull);
    verify(() => repository.deleteStorageShelf('shelf-1')).called(1);
  });

  test('deleteStorageRoom surfaces repository failure', () async {
    final AppFailure expectedFailure = AppFailure.validation();
    when(
      () => repository.deleteStorageRoom(any()),
    ).thenAnswer((_) async => Result<void>.failure(expectedFailure));

    final ProviderContainer container = makeContainer();
    final PharmacyWorkspaceController controller = await _bootController(
      container,
    );

    final AppFailure? failure = await controller.deleteStorageRoom('room-1');

    expect(failure, isNotNull);
  });
}
