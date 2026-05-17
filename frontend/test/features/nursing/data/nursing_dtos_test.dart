import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/nursing/data/dtos/nursing_dtos.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  test('NursingPatientSummaryPageDto decodes ward patient cards', () {
    final NursingPatientSummaryPageDto dto =
        NursingPatientSummaryPageDto.fromResponse(<String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'adm-1',
              'admission_id': 'adm-1',
              'patient_display_id': 'PAT-1',
              'patient_display_name': 'Jane Doe',
              'encounter_display_id': 'ENC-1',
              'ward_display_name': 'Ward A',
              'bed_display_label': 'B12',
              'has_critical_alert': true,
              'medication_due_count': 2,
              'flow_summary': <String, Object?>{
                'stage': 'ADMITTED_IN_BED',
                'next_step': 'NURSING_REVIEW',
                'has_active_bed': true,
              },
            },
          ],
          'pagination': <String, Object?>{'total': 1},
        }, const AppPageRequest(pageSize: 25));

    final AppPage<NursingPatientSummary> page = dto.page;
    final NursingPatientSummary summary = page.items.single;

    expect(page.totalItemCount, 1);
    expect(summary.displayTitle, 'Jane Doe');
    expect(summary.locationLabel, 'Ward A | B12');
    expect(summary.stage, 'ADMITTED_IN_BED');
    expect(summary.hasMedicationDue, isTrue);
    expect(summary.isUrgent, isTrue);
  });

  test('NursingPatientDetailDto decodes IPD snapshot nursing context', () {
    const NursingPatientSummary fallback = NursingPatientSummary(
      id: 'adm-1',
      admissionId: 'adm-1',
      patientDisplayName: 'Jane Doe',
    );

    final NursingPatientDetail detail = NursingPatientDetailDto.fromResponse(
      <String, Object?>{
        'data': <String, Object?>{
          'admission': <String, Object?>{
            'id': 'adm-1',
            'status': 'ADMITTED',
            'admitted_at': '2026-05-17T06:00:00.000Z',
          },
          'patient': <String, Object?>{
            'id': 'pat-1',
            'first_name': 'Jane',
            'last_name': 'Doe',
            'gender': 'FEMALE',
          },
          'encounter': <String, Object?>{
            'id': 'enc-1',
            'status': 'OPEN',
            'encounter_type': 'IPD',
          },
          'facility': <String, Object?>{'name': 'Central Hospital'},
          'flow': <String, Object?>{
            'stage': 'ADMITTED_IN_BED',
            'next_step': 'NURSING_REVIEW',
            'has_active_bed': true,
          },
          'active_bed_assignment': <String, Object?>{
            'bed': <String, Object?>{
              'id': 'bed-1',
              'label': 'B12',
              'ward': <String, Object?>{'name': 'Ward A'},
            },
          },
          'open_transfer_request': <String, Object?>{
            'id': 'tr-1',
            'status': 'REQUESTED',
            'from_ward': <String, Object?>{'name': 'Ward A'},
            'to_ward': <String, Object?>{'name': 'ICU'},
          },
          'latest_discharge_summary': <String, Object?>{
            'id': 'dis-1',
            'status': 'PLANNED',
            'summary': 'Discharge tomorrow',
          },
          'nursing_notes': <Object?>[
            <String, Object?>{
              'id': 'note-1',
              'nurse_name': 'Nurse A',
              'note': 'Stable overnight',
              'created_at': '2026-05-17T07:00:00.000Z',
            },
          ],
          'medication_administrations': <Object?>[
            <String, Object?>{
              'id': 'ma-1',
              'dose': '500',
              'unit': 'mg',
              'route': 'ORAL',
              'administered_at': '2026-05-17T08:00:00.000Z',
            },
          ],
          'medication_suggestions': <Object?>[
            <String, Object?>{
              'id': 'rx-1',
              'drug_name': 'Paracetamol',
              'dose': '500',
              'unit': 'mg',
              'route': 'ORAL',
              'frequency': 'BID',
            },
          ],
          'medication_reminders': <Object?>[
            <String, Object?>{
              'id': 'rem-1',
              'status': 'PENDING',
              'medication_label': 'Paracetamol',
              'scheduled_at': '2026-05-17T12:00:00.000Z',
            },
          ],
          'timeline': <Object?>[
            <String, Object?>{
              'type': 'NURSING_NOTE',
              'label': 'Routine round completed',
              'at': '2026-05-17T09:00:00.000Z',
            },
          ],
          'icu': <String, Object?>{
            'status': 'WATCH',
            'has_critical_alert': true,
            'critical_severity': 'HIGH',
            'recent_observations': <Object?>[
              <String, Object?>{
                'observation': 'SpO2 dropping',
                'observed_at': '2026-05-17T10:00:00.000Z',
              },
            ],
            'recent_alerts': <Object?>[
              <String, Object?>{
                'id': 'alert-1',
                'severity': 'HIGH',
                'message': 'Review oxygen support',
                'created_at': '2026-05-17T10:05:00.000Z',
              },
            ],
          },
        },
      },
      fallback,
    ).toEntity();

    expect(detail.summary.admissionId, 'adm-1');
    expect(detail.summary.locationLabel, 'Ward A | B12');
    expect(detail.activeTransfer?.id, 'tr-1');
    expect(detail.latestDischarge?.status, 'PLANNED');
    expect(detail.nursingNotes.single.note, 'Stable overnight');
    expect(detail.medicationAdministrations.single.route, 'ORAL');
    expect(detail.medicationDueCount, 2);
    expect(detail.criticalAlerts.single.message, 'Review oxygen support');
    expect(detail.enrichedSummary.lastObservation, 'SpO2 dropping');
  });

  test('decodeNursingHandovers keeps admission IDs from items_json', () {
    final List<NursingHandover> handovers = decodeNursingHandovers(
      <String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'handover-1',
            'status': 'PENDING',
            'to_user_id': 'nurse-2',
            'items_json': <String, Object?>{'admission_id': 'adm-1'},
            'created_at': '2026-05-17T11:00:00.000Z',
          },
        ],
      },
    );

    expect(handovers.single.id, 'handover-1');
    expect(handovers.single.isPending, isTrue);
    expect(handovers.single.admissionId, 'adm-1');
  });
}
