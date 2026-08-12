import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_duplicate_merge_workspace.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('buildPatientMergeFieldLanes', () {
    test('builds comparable fields and maps comparison status', () {
      const Patient left = Patient(
        id: 'p1',
        firstName: 'Testing',
        lastName: 'Testing',
        primaryPhone: '+256783230321',
        gender: 'MALE',
      );
      const Patient right = Patient(
        id: 'p2',
        firstName: 'testing',
        lastName: 'testing',
        primaryPhone: '+256783230321',
        gender: 'MALE',
      );

      final List<PatientMergeFieldLane> fields = buildPatientMergeFieldLanes(
        l10n: l10n,
        locale: const Locale('en'),
        left: left,
        right: right,
        comparisons: const <PatientDuplicateFieldComparison>[
          PatientDuplicateFieldComparison(
            field: 'PHONE',
            inputValue: '+256783230321',
            candidateValue: '+256783230321',
            status: 'MATCH',
            contribution: 45,
            similarityPercent: 100,
          ),
          PatientDuplicateFieldComparison(
            field: 'GENDER',
            inputValue: 'MALE',
            candidateValue: 'MALE',
            status: 'MATCH',
            contribution: 5,
            similarityPercent: 100,
          ),
        ],
      );

      expect(fields.map((PatientMergeFieldLane f) => f.key), containsAll(<String>[
        'first_name',
        'last_name',
        'date_of_birth',
        'gender',
        'phone',
        'email',
        'identifier',
        'facility_id',
      ]));
      final PatientMergeFieldLane phone = fields.firstWhere(
        (PatientMergeFieldLane field) => field.key == 'phone',
      );
      expect(phone.status, 'MATCH');
      expect(phone.score, 100);
      expect(phone.includeInSummary, isFalse);
      expect(
        fields.firstWhere((PatientMergeFieldLane f) => f.key == 'first_name')
            .includeInSummary,
        isTrue,
      );
    });
  });

  group('buildPatientMergeCommitPlan', () {
    const Patient left = Patient(
      id: 'left-id',
      firstName: 'Ada',
      lastName: 'Lovelace',
      gender: 'FEMALE',
    );
    const Patient right = Patient(
      id: 'right-id',
      firstName: 'Ada',
      lastName: 'Byron',
      gender: 'FEMALE',
      primaryPhone: '+100',
    );

    test('keep left uses left patient as primary and left summary values', () {
      final List<PatientMergeFieldLane> fields = buildPatientMergeFieldLanes(
        l10n: l10n,
        locale: const Locale('en'),
        left: left,
        right: right,
      );
      final PatientMergeCommitPlan plan = buildPatientMergeCommitPlan(
        left: left,
        right: right,
        fields: fields,
        resolution: PatientMergeResolution.keepLeft,
      );
      expect(plan.primaryPatientId, 'left-id');
      expect(plan.secondaryPatientId, 'right-id');
      expect(plan.summary['first_name'], 'Ada');
      expect(plan.summary['last_name'], 'Lovelace');
      expect(plan.summary.containsKey('phone'), isFalse);
    });

    test('keep right swaps survivor ids and uses right summary values', () {
      final List<PatientMergeFieldLane> fields = buildPatientMergeFieldLanes(
        l10n: l10n,
        locale: const Locale('en'),
        left: left,
        right: right,
      );
      final PatientMergeCommitPlan plan = buildPatientMergeCommitPlan(
        left: left,
        right: right,
        fields: fields,
        resolution: PatientMergeResolution.keepRight,
      );
      expect(plan.primaryPatientId, 'right-id');
      expect(plan.secondaryPatientId, 'left-id');
      expect(plan.summary['last_name'], 'Byron');
    });

    test('auto-merge prefers non-empty right value when left is empty', () {
      const Patient sparseLeft = Patient(id: 'left-id', firstName: 'Ada');
      const Patient richRight = Patient(
        id: 'right-id',
        firstName: 'Ada',
        lastName: 'Byron',
        gender: 'FEMALE',
      );
      final List<PatientMergeFieldLane> fields = buildPatientMergeFieldLanes(
        l10n: l10n,
        locale: const Locale('en'),
        left: sparseLeft,
        right: richRight,
      );
      final PatientMergeCommitPlan plan = buildPatientMergeCommitPlan(
        left: sparseLeft,
        right: richRight,
        fields: fields,
        resolution: PatientMergeResolution.autoMerge,
      );
      expect(plan.primaryPatientId, 'left-id');
      expect(plan.summary['last_name'], 'Byron');
      expect(plan.summary['gender'], 'FEMALE');
    });

    test('swapped field values feed keep-left summary', () {
      final List<PatientMergeFieldLane> fields = buildPatientMergeFieldLanes(
        l10n: l10n,
        locale: const Locale('en'),
        left: left,
        right: right,
      );
      final List<PatientMergeFieldLane> swapped = fields
          .map((PatientMergeFieldLane field) {
            if (field.key == 'last_name') {
              return field.swapped();
            }
            return field;
          })
          .toList(growable: false);
      final PatientMergeCommitPlan plan = buildPatientMergeCommitPlan(
        left: left,
        right: right,
        fields: swapped,
        resolution: PatientMergeResolution.keepLeft,
      );
      expect(plan.summary['last_name'], 'Byron');
    });
  });

  group('buildPatientMergeChoicePreviewLines', () {
    test('shows survivor values and empty placeholders', () {
      const Patient left = Patient(
        id: 'left-id',
        firstName: 'Ada',
        lastName: 'Lovelace',
        gender: 'FEMALE',
        primaryPhone: '+100',
      );
      const Patient right = Patient(
        id: 'right-id',
        firstName: 'Ada',
        lastName: 'Byron',
        primaryEmail: 'ada@example.com',
      );
      final List<PatientMergeFieldLane> fields = buildPatientMergeFieldLanes(
        l10n: l10n,
        locale: const Locale('en'),
        left: left,
        right: right,
      );

      final List<String> keepLeft = buildPatientMergeChoicePreviewLines(
        l10n: l10n,
        fields: fields,
        resolution: PatientMergeResolution.keepLeft,
      );
      expect(keepLeft.first, 'Ada Lovelace');
      expect(keepLeft, contains('FEMALE'));
      expect(keepLeft, contains('+100'));
      expect(keepLeft, contains(l10n.patientsMergeEmptyValueLabel));

      final List<String> keepRight = buildPatientMergeChoicePreviewLines(
        l10n: l10n,
        fields: fields,
        resolution: PatientMergeResolution.keepRight,
      );
      expect(keepRight.first, 'Ada Byron');
      expect(keepRight, contains('ada@example.com'));
    });

    test('updates after field swap', () {
      const Patient left = Patient(
        id: 'left-id',
        firstName: 'Ada',
        lastName: 'Lovelace',
      );
      const Patient right = Patient(
        id: 'right-id',
        firstName: 'Ada',
        lastName: 'Byron',
      );
      final List<PatientMergeFieldLane> fields = buildPatientMergeFieldLanes(
        l10n: l10n,
        locale: const Locale('en'),
        left: left,
        right: right,
      );
      final List<PatientMergeFieldLane> swapped = fields
          .map((PatientMergeFieldLane field) {
            if (field.key == 'last_name') {
              return field.swapped();
            }
            return field;
          })
          .toList(growable: false);

      final List<String> keepLeft = buildPatientMergeChoicePreviewLines(
        l10n: l10n,
        fields: swapped,
        resolution: PatientMergeResolution.keepLeft,
      );
      expect(keepLeft.first, 'Ada Byron');
    });

    test('typed edits feed keep-left summary and preview', () {
      const Patient left = Patient(
        id: 'left-id',
        firstName: 'Ada',
        lastName: 'Lovelace',
        primaryEmail: 'old@example.com',
      );
      const Patient right = Patient(
        id: 'right-id',
        firstName: 'Ada',
        lastName: 'Byron',
      );
      final List<PatientMergeFieldLane> fields = buildPatientMergeFieldLanes(
        l10n: l10n,
        locale: const Locale('en'),
        left: left,
        right: right,
      );
      final List<PatientMergeFieldLane> edited = fields
          .map((PatientMergeFieldLane field) {
            if (field.key == 'last_name') {
              return field.copyWith(leftValue: 'Hopper', leftRaw: 'Hopper');
            }
            if (field.key == 'email') {
              return field.copyWith(
                leftValue: 'grace@example.com',
                leftRaw: 'grace@example.com',
              );
            }
            return field;
          })
          .toList(growable: false);

      final PatientMergeCommitPlan plan = buildPatientMergeCommitPlan(
        left: left,
        right: right,
        fields: edited,
        resolution: PatientMergeResolution.keepLeft,
      );
      expect(plan.summary['last_name'], 'Hopper');

      final List<String> preview = buildPatientMergeChoicePreviewLines(
        l10n: l10n,
        fields: edited,
        resolution: PatientMergeResolution.keepLeft,
      );
      expect(preview.first, 'Ada Hopper');
      expect(preview, contains('grace@example.com'));
    });
  });
}
