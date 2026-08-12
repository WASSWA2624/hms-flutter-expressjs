import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/discharge_scope_navigation.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('dischargeSectionFromQuery / toQueryValue', () {
    test('round-trips overview aliases', () {
      expect(dischargeSectionFromQuery('all'), DischargeDeskSection.all);
      expect(dischargeSectionFromQuery('planned'), DischargeDeskSection.planned);
      expect(
        dischargeSectionFromQuery('pending'),
        DischargeDeskSection.pendingClearance,
      );
      expect(
        dischargeSectionFromQuery('pending-clearance'),
        DischargeDeskSection.pendingClearance,
      );
      expect(
        dischargeSectionFromQuery('pending_clearance'),
        DischargeDeskSection.pendingClearance,
      );
      expect(
        dischargeSectionFromQuery('pendingclearance'),
        DischargeDeskSection.pendingClearance,
      );
      expect(
        dischargeSectionFromQuery('discharged'),
        DischargeDeskSection.completed,
      );
      expect(
        dischargeSectionFromQuery('follow_ups'),
        DischargeDeskSection.followUps,
      );
      expect(
        dischargeSectionToQueryValue(DischargeDeskSection.pendingClearance),
        'pending',
      );
      expect(
        dischargeSectionToQueryValue(DischargeDeskSection.followUps),
        'follow-ups',
      );
    });
  });

  group('dischargeSectionTabCount', () {
    const IpdAdmissionSummary planned = IpdAdmissionSummary(
      id: 'adm-planned',
      stage: 'DISCHARGE_PLANNED',
      dischargeStatus: 'PLANNED',
    );
    const IpdAdmissionSummary pending = IpdAdmissionSummary(
      id: 'adm-pending',
      stage: 'ADMITTED',
      dischargeStatus: 'SUMMARY_PENDING',
    );
    const IpdAdmissionSummary completed = IpdAdmissionSummary(
      id: 'adm-done',
      stage: 'DISCHARGED',
      dischargeStatus: 'COMPLETED',
    );

    test('uses dedicated sibling totals when not narrowed', () {
      final DischargeWorkspaceState state = DischargeWorkspaceState(
        query: const DischargeWorklistQuery(),
        queue: const AppPage<IpdAdmissionSummary>(
          items: <IpdAdmissionSummary>[planned],
          request: AppPageRequest(pageSize: 12),
        ),
        sectionCounts: const DischargeSectionCounts(
          all: 5,
          planned: 2,
          pendingClearance: 2,
          completed: 1,
        ),
      );
      expect(
        dischargeSectionTabCount(state, DischargeDeskSection.planned),
        2,
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.planned,
          activeSection: DischargeDeskSection.planned,
        ),
        2,
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.all,
          activeSection: DischargeDeskSection.all,
        ),
        5,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.all),
        AppTabCountTone.info,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.planned),
        AppTabCountTone.warning,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.pendingClearance),
        AppTabCountTone.warning,
      );
    });

    test('active Pending clearance tab uses filtered membership when narrowed', () {
      final DischargeWorkspaceState state = DischargeWorkspaceState(
        query: const DischargeWorklistQuery(
          status: DischargeStatusFilter.pharmacyPending,
        ),
        queue: const AppPage<IpdAdmissionSummary>(
          items: <IpdAdmissionSummary>[planned, pending],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 2,
        ),
        sectionCounts: const DischargeSectionCounts(
          all: 5,
          planned: 2,
          pendingClearance: 3,
          completed: 1,
        ),
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.pendingClearance,
          activeSection: DischargeDeskSection.pendingClearance,
        ),
        1,
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.pendingClearance,
        ),
        3,
      );
    });

    test('active Completed tab uses filtered membership when narrowed', () {
      final DischargeWorkspaceState state = DischargeWorkspaceState(
        query: const DischargeWorklistQuery(search: 'Carol'),
        queue: const AppPage<IpdAdmissionSummary>(
          items: <IpdAdmissionSummary>[planned, pending, completed],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 3,
        ),
        sectionCounts: const DischargeSectionCounts(
          all: 5,
          planned: 2,
          pendingClearance: 2,
          completed: 4,
        ),
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.completed,
          activeSection: DischargeDeskSection.completed,
        ),
        1,
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.completed,
        ),
        4,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.completed),
        AppTabCountTone.info,
      );
    });

    test('Follow-ups uses followUpsCount override; tone is info', () {
      final DischargeWorkspaceState state = DischargeWorkspaceState(
        query: const DischargeWorklistQuery(),
        queue: const AppPage<IpdAdmissionSummary>(
          items: <IpdAdmissionSummary>[planned],
          request: AppPageRequest(pageSize: 12),
        ),
        sectionCounts: const DischargeSectionCounts(
          all: 5,
          planned: 2,
          pendingClearance: 2,
          completed: 1,
        ),
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.followUps,
          followUpsCount: 7,
        ),
        7,
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.followUps,
          activeSection: DischargeDeskSection.followUps,
          followUpsCount: 2,
        ),
        2,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.followUps),
        AppTabCountTone.info,
      );
    });

    test('active All tab uses filtered queue length when narrowed', () {
      final DischargeWorkspaceState state = DischargeWorkspaceState(
        query: const DischargeWorklistQuery(search: 'Alice'),
        queue: const AppPage<IpdAdmissionSummary>(
          items: <IpdAdmissionSummary>[planned, pending],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 2,
        ),
        sectionCounts: const DischargeSectionCounts(
          all: 5,
          planned: 2,
          pendingClearance: 2,
          completed: 1,
        ),
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.all,
          activeSection: DischargeDeskSection.all,
        ),
        2,
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.completed,
          activeSection: DischargeDeskSection.all,
        ),
        1,
      );
    });

    test('active tab uses filtered queue length when narrowed', () {
      final DischargeWorkspaceState state = DischargeWorkspaceState(
        query: const DischargeWorklistQuery(search: 'Alice'),
        queue: const AppPage<IpdAdmissionSummary>(
          items: <IpdAdmissionSummary>[planned, pending],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 2,
        ),
        sectionCounts: const DischargeSectionCounts(
          all: 5,
          planned: 2,
          pendingClearance: 2,
          completed: 1,
        ),
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.planned,
          activeSection: DischargeDeskSection.planned,
        ),
        1,
      );
      expect(
        dischargeSectionTabCount(
          state,
          DischargeDeskSection.pendingClearance,
          activeSection: DischargeDeskSection.planned,
        ),
        2,
      );
    });
  });

  group('dischargeSectionCountTone', () {
    test('warning for attention queues; info otherwise', () {
      expect(
        dischargeSectionCountTone(DischargeDeskSection.planned),
        AppTabCountTone.warning,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.pendingClearance),
        AppTabCountTone.warning,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.all),
        AppTabCountTone.info,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.completed),
        AppTabCountTone.info,
      );
      expect(
        dischargeSectionCountTone(DischargeDeskSection.followUps),
        AppTabCountTone.info,
      );
    });
  });
}
