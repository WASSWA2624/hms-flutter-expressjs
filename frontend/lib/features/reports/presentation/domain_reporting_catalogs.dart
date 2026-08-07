import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_role_tailoring.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

ModuleReportingReport _report(
  String categoryId,
  String id,
  String label, {
  ModuleReportingContentKind kind = ModuleReportingContentKind.table,
  String? datasetKey,
}) {
  return ModuleReportingReport(
    id: id,
    categoryId: categoryId,
    label: label,
    contentKind: kind,
    datasetKey: datasetKey,
  );
}

List<ModuleReportingReport> _reports(
  String categoryId,
  List<(String, String, ModuleReportingContentKind?, String?)> rows,
) {
  return rows
      .map(
        ((String, String, ModuleReportingContentKind?, String?) row) => _report(
          categoryId,
          row.$1,
          row.$2,
          kind: row.$3 ?? ModuleReportingContentKind.table,
          datasetKey: row.$4,
        ),
      )
      .toList(growable: false);
}

/// Display title for a domain Reporting pack switcher / chrome.
String reportsDomainPackTitle(ReportsDomainPack pack) {
  return switch (pack) {
    ReportsDomainPack.admin => 'Administration',
    ReportsDomainPack.finance => 'Billing & finance',
    ReportsDomainPack.pharmacy => 'Pharmacy',
    ReportsDomainPack.reception => 'Reception',
    ReportsDomainPack.clinical => 'Clinical',
    ReportsDomainPack.lab => 'Laboratory',
    ReportsDomainPack.radiology => 'Radiology',
    ReportsDomainPack.hr => 'Human resources',
    ReportsDomainPack.biomedical => 'Biomedical',
    ReportsDomainPack.operations => 'Operations',
    ReportsDomainPack.emergency => 'Emergency & ambulance',
    ReportsDomainPack.communications => 'Communications',
    ReportsDomainPack.general => 'General',
  };
}

String reportsDomainCategoryTitle(ReportsDomainPack pack, String categoryId) {
  final Map<String, String> titles =
      _categoryTitles[pack] ?? const <String, String>{};
  return titles[categoryId] ?? categoryId;
}

const Map<ReportsDomainPack, Map<String, String>> _categoryTitles =
    <ReportsDomainPack, Map<String, String>>{
      ReportsDomainPack.finance: <String, String>{
        'collections': 'Collections & balances',
        'claims': 'Insurance claims',
        'revenue': 'Revenue & adjustments',
      },
      ReportsDomainPack.reception: <String, String>{
        'registrations': 'Patient registrations',
        'appointments': 'Appointments & no-shows',
        'desk': 'Front desk operations',
      },
      ReportsDomainPack.clinical: <String, String>{
        'caseload': 'Caseload & encounters',
        'appointments': 'Appointments & follow-ups',
        'outcomes': 'Clinical outcomes',
      },
      ReportsDomainPack.lab: <String, String>{
        'volume': 'Lab volume',
        'turnaround': 'Turnaround & backlog',
        'quality': 'Quality & rejects',
      },
      ReportsDomainPack.radiology: <String, String>{
        'volume': 'Imaging volume',
        'turnaround': 'Turnaround & backlog',
        'modality': 'Modality mix',
      },
      ReportsDomainPack.hr: <String, String>{
        'staffing': 'Staffing & leave',
        'roster': 'Roster coverage',
        'attendance': 'Attendance',
      },
      ReportsDomainPack.biomedical: <String, String>{
        'incidents': 'Incidents & downtime',
        'maintenance': 'Maintenance',
        'assets': 'Asset status',
      },
      ReportsDomainPack.operations: <String, String>{
        'throughput': 'Facility throughput',
        'inventory': 'Inventory risk',
        'housekeeping': 'Housekeeping',
      },
      ReportsDomainPack.emergency: <String, String>{
        'response': 'Emergency response',
        'transport': 'Ambulance transport',
        'triage': 'Triage pressure',
      },
      ReportsDomainPack.communications: <String, String>{
        'delivery': 'Message delivery',
        'campaigns': 'Campaigns',
      },
      ReportsDomainPack.admin: <String, String>{
        'facility': 'Facility overview',
        'finance': 'Financial snapshot',
        'clinical_ops': 'Clinical operations',
        'pharmacy': 'Pharmacy snapshot',
      },
    };

/// First-dense domain catalogs (pharmacy remains in `pharmacy_reporting_catalog`).
List<ModuleReportingCategory> reportsDomainCatalog(ReportsDomainPack pack) {
  return switch (pack) {
    ReportsDomainPack.finance => _financeCatalog(),
    ReportsDomainPack.reception => _receptionCatalog(),
    ReportsDomainPack.clinical => _clinicalCatalog(),
    ReportsDomainPack.lab => _labCatalog(),
    ReportsDomainPack.radiology => _radiologyCatalog(),
    ReportsDomainPack.hr => _hrCatalog(),
    ReportsDomainPack.biomedical => _biomedCatalog(),
    ReportsDomainPack.operations => _operationsCatalog(),
    ReportsDomainPack.emergency => _emergencyCatalog(),
    ReportsDomainPack.communications => _communicationsCatalog(),
    ReportsDomainPack.admin => _adminCatalog(),
    ReportsDomainPack.pharmacy || ReportsDomainPack.general =>
      const <ModuleReportingCategory>[],
  };
}

/// Analytics insight chips (dataset id + label + icon) per pack.
List<({String datasetId, String label, IconData icon})>
reportsDomainAnalyticsInsights(ReportsDomainPack pack) {
  return switch (pack) {
    ReportsDomainPack.finance => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'billing_collections_open_balances',
        label: 'Collections & open balances',
        icon: Icons.payments_outlined,
      ),
      (
        datasetId: 'insurance_claims_aging',
        label: 'Claims aging',
        icon: Icons.policy_outlined,
      ),
    ],
    ReportsDomainPack.reception => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'patient_registrations',
        label: 'Registrations trend',
        icon: Icons.person_add_alt_1_outlined,
      ),
      (
        datasetId: 'appointment_throughput_no_shows',
        label: 'No-show pressure',
        icon: Icons.event_busy_outlined,
      ),
    ],
    ReportsDomainPack.clinical => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'patient_registrations',
        label: 'Patient volume',
        icon: Icons.groups_outlined,
      ),
      (
        datasetId: 'appointment_throughput_no_shows',
        label: 'Appointment throughput',
        icon: Icons.event_available_outlined,
      ),
    ],
    ReportsDomainPack.lab || ReportsDomainPack.radiology =>
      <({String datasetId, String label, IconData icon})>[
        (
          datasetId: 'patient_registrations',
          label: 'Linked patient volume',
          icon: Icons.biotech_outlined,
        ),
      ],
    ReportsDomainPack.hr => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'hr_staffing_leave_coverage',
        label: 'Leave coverage',
        icon: Icons.beach_access_outlined,
      ),
    ],
    ReportsDomainPack.biomedical => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'biomedical_incidents_downtime',
        label: 'Incidents & downtime',
        icon: Icons.build_circle_outlined,
      ),
    ],
    ReportsDomainPack.operations => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'appointment_throughput_no_shows',
        label: 'Facility throughput',
        icon: Icons.speed_outlined,
      ),
      (
        datasetId: 'inventory_stock_risk',
        label: 'Stock risk',
        icon: Icons.inventory_2_outlined,
      ),
    ],
    ReportsDomainPack.emergency => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'appointment_throughput_no_shows',
        label: 'Throughput pressure',
        icon: Icons.emergency_outlined,
      ),
    ],
    ReportsDomainPack.communications => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'communications_delivery_performance',
        label: 'Delivery performance',
        icon: Icons.mark_email_read_outlined,
      ),
    ],
    ReportsDomainPack.admin => <({String datasetId, String label, IconData icon})>[
      (
        datasetId: 'billing_collections_open_balances',
        label: 'Collections',
        icon: Icons.payments_outlined,
      ),
      (
        datasetId: 'patient_registrations',
        label: 'Registrations',
        icon: Icons.person_add_alt_1_outlined,
      ),
      (
        datasetId: 'pharmacy_drug_consumption',
        label: 'Pharmacy consumption',
        icon: Icons.medication_outlined,
      ),
    ],
    ReportsDomainPack.pharmacy || ReportsDomainPack.general =>
      const <({String datasetId, String label, IconData icon})>[],
  };
}

List<ModuleReportingCategory> _financeCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'collections',
      icon: Icons.payments_outlined,
      reports: _reports('collections', <(String, String, ModuleReportingContentKind?, String?)>[
        ('collections_open_balances', 'Collections & open balances', null, 'billing_collections_open_balances'),
        ('net_collections_trend', 'Net collections trend', ModuleReportingContentKind.chart, 'billing_collections_open_balances'),
        ('refunds_write_offs', 'Refunds & write-offs', null, 'billing_collections_open_balances'),
        ('cashier_productivity', 'Cashier productivity', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'claims',
      icon: Icons.policy_outlined,
      reports: _reports('claims', <(String, String, ModuleReportingContentKind?, String?)>[
        ('claims_aging', 'Claims aging', null, 'insurance_claims_aging'),
        ('claims_status_mix', 'Claims status mix', ModuleReportingContentKind.chart, 'insurance_claims_aging'),
        ('denied_claims', 'Denied claims', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'revenue',
      icon: Icons.trending_up_outlined,
      reports: _reports('revenue', <(String, String, ModuleReportingContentKind?, String?)>[
        ('issued_vs_open_invoices', 'Issued vs open invoices', null, 'billing_collections_open_balances'),
        ('price_list_changes', 'Price list changes', null, null),
        ('payer_mix', 'Payer mix', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _receptionCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'registrations',
      icon: Icons.person_add_alt_1_outlined,
      reports: _reports('registrations', <(String, String, ModuleReportingContentKind?, String?)>[
        ('registrations_volume', 'Registration volume', null, 'patient_registrations'),
        ('registrations_by_facility', 'Registrations by facility', null, 'patient_registrations'),
        ('new_vs_returning', 'New vs returning patients', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'appointments',
      icon: Icons.event_available_outlined,
      reports: _reports('appointments', <(String, String, ModuleReportingContentKind?, String?)>[
        ('appointment_throughput', 'Appointment throughput', null, 'appointment_throughput_no_shows'),
        ('no_shows', 'No-shows', null, 'appointment_throughput_no_shows'),
        ('completed_vs_scheduled', 'Completed vs scheduled', ModuleReportingContentKind.chart, 'appointment_throughput_no_shows'),
      ]),
    ),
    ModuleReportingCategory(
      id: 'desk',
      icon: Icons.support_agent_outlined,
      reports: _reports('desk', <(String, String, ModuleReportingContentKind?, String?)>[
        ('desk_queue_pressure', 'Desk queue pressure', null, null),
        ('payment_gate_pending', 'Payment gate pending', null, null),
        ('high_priority_intake', 'High-priority intake', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _clinicalCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'caseload',
      icon: Icons.medical_services_outlined,
      reports: _reports('caseload', <(String, String, ModuleReportingContentKind?, String?)>[
        ('patient_volume', 'Patient volume', null, 'patient_registrations'),
        ('active_encounters', 'Active encounters', null, null),
        ('discharge_volume', 'Discharge volume', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'appointments',
      icon: Icons.event_outlined,
      reports: _reports('appointments', <(String, String, ModuleReportingContentKind?, String?)>[
        ('appointment_throughput', 'Appointment throughput', null, 'appointment_throughput_no_shows'),
        ('no_show_follow_ups', 'No-show follow-ups', null, 'appointment_throughput_no_shows'),
        ('clinic_mix', 'Clinic mix', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'outcomes',
      icon: Icons.monitor_heart_outlined,
      reports: _reports('outcomes', <(String, String, ModuleReportingContentKind?, String?)>[
        ('readmissions', 'Readmissions', null, null),
        ('length_of_stay', 'Length of stay', null, null),
        ('prescription_volume', 'Prescription volume', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _labCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'volume',
      icon: Icons.biotech_outlined,
      reports: _reports('volume', <(String, String, ModuleReportingContentKind?, String?)>[
        ('linked_patient_volume', 'Linked patient volume', null, 'patient_registrations'),
        ('orders_created', 'Orders created', null, null),
        ('results_released', 'Results released', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'turnaround',
      icon: Icons.timer_outlined,
      reports: _reports('turnaround', <(String, String, ModuleReportingContentKind?, String?)>[
        ('average_tat', 'Average turnaround', null, null),
        ('backlog', 'Backlog', null, null),
        ('stat_vs_routine', 'STAT vs routine', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'quality',
      icon: Icons.verified_outlined,
      reports: _reports('quality', <(String, String, ModuleReportingContentKind?, String?)>[
        ('rejected_samples', 'Rejected samples', null, null),
        ('critical_results', 'Critical results', null, null),
        ('recollects', 'Recollects', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _radiologyCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'volume',
      icon: Icons.photo_camera_outlined,
      reports: _reports('volume', <(String, String, ModuleReportingContentKind?, String?)>[
        ('linked_patient_volume', 'Linked patient volume', null, 'patient_registrations'),
        ('studies_completed', 'Studies completed', null, null),
        ('pending_reads', 'Pending reads', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'turnaround',
      icon: Icons.timer_outlined,
      reports: _reports('turnaround', <(String, String, ModuleReportingContentKind?, String?)>[
        ('report_tat', 'Report turnaround', null, null),
        ('backlog', 'Backlog', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'modality',
      icon: Icons.camera_alt_outlined,
      reports: _reports('modality', <(String, String, ModuleReportingContentKind?, String?)>[
        ('modality_mix', 'Modality mix', null, null),
        ('contrast_usage', 'Contrast usage', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _hrCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'staffing',
      icon: Icons.badge_outlined,
      reports: _reports('staffing', <(String, String, ModuleReportingContentKind?, String?)>[
        ('leave_coverage', 'Staffing & leave coverage', null, 'hr_staffing_leave_coverage'),
        ('headcount', 'Headcount', null, null),
        ('open_positions', 'Open positions', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'roster',
      icon: Icons.calendar_month_outlined,
      reports: _reports('roster', <(String, String, ModuleReportingContentKind?, String?)>[
        ('roster_gaps', 'Roster gaps', null, null),
        ('overtime', 'Overtime', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'attendance',
      icon: Icons.how_to_reg_outlined,
      reports: _reports('attendance', <(String, String, ModuleReportingContentKind?, String?)>[
        ('attendance_rate', 'Attendance rate', null, null),
        ('absences', 'Absences', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _biomedCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'incidents',
      icon: Icons.report_problem_outlined,
      reports: _reports('incidents', <(String, String, ModuleReportingContentKind?, String?)>[
        ('incidents_downtime', 'Incidents & downtime', null, 'biomedical_incidents_downtime'),
        ('open_incidents', 'Open incidents', null, 'biomedical_incidents_downtime'),
        ('mttr', 'Mean time to repair', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'maintenance',
      icon: Icons.build_outlined,
      reports: _reports('maintenance', <(String, String, ModuleReportingContentKind?, String?)>[
        ('pm_compliance', 'PM compliance', null, null),
        ('work_orders', 'Work orders', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'assets',
      icon: Icons.devices_other_outlined,
      reports: _reports('assets', <(String, String, ModuleReportingContentKind?, String?)>[
        ('asset_status', 'Asset status', null, null),
        ('warranty_expiry', 'Warranty expiry', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _operationsCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'throughput',
      icon: Icons.speed_outlined,
      reports: _reports('throughput', <(String, String, ModuleReportingContentKind?, String?)>[
        ('appointment_throughput', 'Appointment throughput', null, 'appointment_throughput_no_shows'),
        ('no_shows', 'No-shows', null, 'appointment_throughput_no_shows'),
      ]),
    ),
    ModuleReportingCategory(
      id: 'inventory',
      icon: Icons.inventory_2_outlined,
      reports: _reports('inventory', <(String, String, ModuleReportingContentKind?, String?)>[
        ('stock_risk', 'Stock risk', null, 'inventory_stock_risk'),
        ('expiry_alerts', 'Expiry alerts', null, 'inventory_stock_risk'),
      ]),
    ),
    ModuleReportingCategory(
      id: 'housekeeping',
      icon: Icons.cleaning_services_outlined,
      reports: _reports('housekeeping', <(String, String, ModuleReportingContentKind?, String?)>[
        ('room_turnaround', 'Room turnaround', null, null),
        ('open_tasks', 'Open housekeeping tasks', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _emergencyCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'response',
      icon: Icons.emergency_outlined,
      reports: _reports('response', <(String, String, ModuleReportingContentKind?, String?)>[
        ('throughput_pressure', 'Throughput pressure', null, 'appointment_throughput_no_shows'),
        ('case_volume', 'Emergency case volume', null, null),
        ('acuity_mix', 'Acuity mix', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'transport',
      icon: Icons.airport_shuttle_outlined,
      reports: _reports('transport', <(String, String, ModuleReportingContentKind?, String?)>[
        ('trips_completed', 'Trips completed', null, null),
        ('response_time', 'Response time', null, null),
      ]),
    ),
    ModuleReportingCategory(
      id: 'triage',
      icon: Icons.priority_high_outlined,
      reports: _reports('triage', <(String, String, ModuleReportingContentKind?, String?)>[
        ('triage_backlog', 'Triage backlog', null, null),
        ('left_without_being_seen', 'Left without being seen', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _communicationsCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'delivery',
      icon: Icons.mark_email_read_outlined,
      reports: _reports('delivery', <(String, String, ModuleReportingContentKind?, String?)>[
        ('delivery_performance', 'Delivery performance', null, 'communications_delivery_performance'),
        ('failed_deliveries', 'Failed deliveries', null, 'communications_delivery_performance'),
      ]),
    ),
    ModuleReportingCategory(
      id: 'campaigns',
      icon: Icons.campaign_outlined,
      reports: _reports('campaigns', <(String, String, ModuleReportingContentKind?, String?)>[
        ('campaign_reach', 'Campaign reach', null, null),
        ('opt_outs', 'Opt-outs', null, null),
      ]),
    ),
  ];
}

List<ModuleReportingCategory> _adminCatalog() {
  return <ModuleReportingCategory>[
    ModuleReportingCategory(
      id: 'facility',
      icon: Icons.apartment_outlined,
      reports: _reports('facility', <(String, String, ModuleReportingContentKind?, String?)>[
        ('registrations', 'Patient registrations', null, 'patient_registrations'),
        ('appointment_throughput', 'Appointment throughput', null, 'appointment_throughput_no_shows'),
      ]),
    ),
    ModuleReportingCategory(
      id: 'finance',
      icon: Icons.account_balance_outlined,
      reports: _reports('finance', <(String, String, ModuleReportingContentKind?, String?)>[
        ('collections', 'Collections & open balances', null, 'billing_collections_open_balances'),
        ('claims_aging', 'Claims aging', null, 'insurance_claims_aging'),
      ]),
    ),
    ModuleReportingCategory(
      id: 'clinical_ops',
      icon: Icons.local_hospital_outlined,
      reports: _reports('clinical_ops', <(String, String, ModuleReportingContentKind?, String?)>[
        ('staffing_leave', 'Staffing & leave coverage', null, 'hr_staffing_leave_coverage'),
        ('biomed_incidents', 'Biomed incidents', null, 'biomedical_incidents_downtime'),
      ]),
    ),
    ModuleReportingCategory(
      id: 'pharmacy',
      icon: Icons.local_pharmacy_outlined,
      reports: _reports('pharmacy', <(String, String, ModuleReportingContentKind?, String?)>[
        ('drug_consumption', 'Drug consumption', null, 'pharmacy_drug_consumption'),
        ('dispense_throughput', 'Dispense throughput', null, 'pharmacy_dispense_throughput'),
        ('stock_risk', 'Stock risk', null, 'inventory_stock_risk'),
      ]),
    ),
  ];
}
