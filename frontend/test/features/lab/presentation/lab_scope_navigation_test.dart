import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/widgets/lab_scope_navigation.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

LabWorkspaceState _state({
  String search = '',
  DateTime? orderedFrom,
  DateTime? orderedTo,
  int collectionPatients = 5,
  int criticalPatients = 2,
  int completedPatients = 3,
  int totalPatients = 10,
  int worklistTotal = 5,
  int worklistLength = 5,
}) {
  return LabWorkspaceState(
    query: LabWorkbenchQuery(
      search: search,
      orderedFrom: orderedFrom,
      orderedTo: orderedTo,
      scope: LabQueueScope.collection,
    ),
    summary: LabWorkbenchSummary(
      collectionPatients: collectionPatients,
      criticalPatients: criticalPatients,
      completedPatients: completedPatients,
      totalPatients: totalPatients,
    ),
    worklist: AppPage<LabOrderSummary>(
      items: List<LabOrderSummary>.generate(
        worklistLength,
        (int i) => LabOrderSummary(id: 'o-$i'),
      ),
      request: const AppPageRequest(pageSize: 25),
      totalItemCount: worklistTotal,
    ),
  );
}

void main() {
  group('labSectionTabCount', () {
    test('uses summary totals for inactive sibling tabs', () {
      final LabWorkspaceState state = _state(search: 'ann', worklistTotal: 1);
      expect(
        labSectionTabCount(
          state,
          LabDeskSection.critical,
          activeSection: LabDeskSection.collection,
        ),
        2,
      );
      expect(
        labSectionTabCount(
          state,
          LabDeskSection.completed,
          activeSection: LabDeskSection.collection,
        ),
        3,
      );
      expect(
        labSectionTabCount(
          state,
          LabDeskSection.worklist,
          activeSection: LabDeskSection.collection,
        ),
        10,
      );
    });

    test('uses summary when active tab is not narrowed', () {
      final LabWorkspaceState state = _state();
      expect(
        labSectionTabCount(
          state,
          LabDeskSection.collection,
          activeSection: LabDeskSection.collection,
        ),
        5,
      );
    });

    test('uses worklist total when search narrows the active tab', () {
      final LabWorkspaceState state = _state(search: 'ann', worklistTotal: 1);
      expect(
        labSectionTabCount(
          state,
          LabDeskSection.collection,
          activeSection: LabDeskSection.collection,
        ),
        1,
      );
    });

    test('uses client filtered total when client filters narrow', () {
      final LabWorkspaceState state = _state(worklistTotal: 5);
      expect(
        labSectionTabCount(
          state,
          LabDeskSection.collection,
          activeSection: LabDeskSection.collection,
          activeClientFilteredTotal: 2,
        ),
        2,
      );
    });
  });

  group('labSectionCountTone', () {
    test('assigns danger/warning only to attention queues', () {
      expect(
        labSectionCountTone(LabDeskSection.critical),
        AppTabCountTone.danger,
      );
      expect(
        labSectionCountTone(LabDeskSection.collection),
        AppTabCountTone.warning,
      );
      expect(
        labSectionCountTone(LabDeskSection.completed),
        AppTabCountTone.info,
      );
      expect(
        labSectionCountTone(LabDeskSection.followUps),
        AppTabCountTone.info,
      );
      expect(
        labSectionCountTone(LabDeskSection.worklist),
        AppTabCountTone.info,
      );
    });
  });
}
