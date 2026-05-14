const { HttpError } = require("@lib/errors");

jest.mock("@repositories/ipd-flow/ipd-flow.repository");
jest.mock("@lib/audit");
jest.mock("@lib/websocket", () => ({
  emitToUser: jest.fn(),
  emitToUsers: jest.fn(),
  IPD_EVENTS: {
    IPD_FLOW_UPDATED: "ipd.flow.updated",
  },
  ADMISSION_BED_EVENTS: {
    PATIENT_ADMITTED: "admission.patient_admitted",
    PATIENT_TRANSFERRED: "admission.patient_transferred",
    PATIENT_DISCHARGED: "admission.patient_discharged",
    BED_ASSIGNMENT_CHANGED: "admission.bed_assignment_changed",
  },
  NOTIFICATION_EVENTS: {
    NOTIFICATION_CREATED: "notification.created",
  },
}));
jest.mock("@prisma/client", () => ({
  $transaction: jest.fn(),
  admission: {
    findFirst: jest.fn(),
    update: jest.fn(),
    create: jest.fn(),
  },
  tenant: {
    findFirst: jest.fn(),
  },
  facility: {
    findFirst: jest.fn(),
  },
  patient: {
    findFirst: jest.fn(),
  },
  encounter: {
    findFirst: jest.fn(),
  },
  bed: {
    findFirst: jest.fn(),
    update: jest.fn(),
  },
  ward: {
    findFirst: jest.fn(),
  },
  user: {
    findFirst: jest.fn(),
  },
  staff_profile: {
    findFirst: jest.fn(),
  },
  transfer_request: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  bed_assignment: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  ward_round: {
    findFirst: jest.fn(),
    create: jest.fn(),
  },
  nursing_note: {
    findFirst: jest.fn(),
    create: jest.fn(),
  },
  medication_administration: {
    findFirst: jest.fn(),
    create: jest.fn(),
  },
  pharmacy_order_item: {
    findFirst: jest.fn(),
  },
  follow_up: {
    findFirst: jest.fn(),
    create: jest.fn(),
  },
  discharge_summary: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  icu_stay: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  icu_observation: {
    findFirst: jest.fn(),
    create: jest.fn(),
  },
  critical_alert: {
    findFirst: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  },
  user_role: {
    findMany: jest.fn(),
  },
  notification: {
    create: jest.fn(),
  },
}));

const ipdFlowRepository = require("@repositories/ipd-flow/ipd-flow.repository");
const prisma = require("@prisma/client");
const { createAuditLog } = require("@lib/audit");
const { emitToUsers } = require("@lib/websocket");
const ipdFlowService = require("@services/ipd-flow/ipd-flow.service");

const now = new Date("2026-02-01T10:00:00.000Z");

const buildActiveBedAssignment = () => ({
  id: "ba-1",
  bed_id: "bed-1",
  assigned_at: now,
  released_at: null,
  deleted_at: null,
  bed: {
    id: "bed-1",
    human_friendly_id: "BED0000001",
    label: "Bed A1",
    status: "OCCUPIED",
    ward_id: "ward-1",
    room_id: null,
    ward: {
      id: "ward-1",
      human_friendly_id: "WRD0000001",
      name: "Ward A",
      ward_type: "GENERAL",
    },
    room: null,
  },
});

const buildAdmission = (overrides = {}) => ({
  id: "adm-1",
  human_friendly_id: "ADM0000001",
  tenant_id: "tenant-1",
  facility_id: "facility-1",
  patient_id: "pat-1",
  encounter_id: null,
  status: "ADMITTED",
  admitted_at: now,
  discharged_at: null,
  created_at: now,
  updated_at: now,
  tenant: {
    id: "tenant-1",
    human_friendly_id: "TEN0000001",
    name: "Demo Tenant",
  },
  facility: {
    id: "facility-1",
    human_friendly_id: "FAC0000001",
    name: "Main Facility",
    facility_type: "HOSPITAL",
  },
  patient: {
    id: "pat-1",
    human_friendly_id: "PAT0000001",
    first_name: "John",
    last_name: "Doe",
    date_of_birth: null,
    gender: "MALE",
    tenant_id: "tenant-1",
    facility_id: "facility-1",
  },
  encounter: null,
  bed_assignments: [],
  transfer_requests: [],
  discharge_summaries: [],
  icu_stays: [],
  ward_rounds: [],
  nursing_notes: [],
  medication_administrations: [],
  ...overrides,
});

describe("ipd-flow.service", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    createAuditLog.mockResolvedValue({});
    prisma.user_role.findMany.mockResolvedValue([]);
    prisma.follow_up.create.mockResolvedValue({ id: "fu-1" });
    prisma.notification.create.mockImplementation(async ({ data }) => ({
      id: `notif-${data.user_id}`,
      tenant_id: data.tenant_id,
      user_id: data.user_id,
      notification_type: data.notification_type,
      priority: data.priority,
      title: data.title,
      message: data.message,
      read_at: null,
      created_at: now,
      updated_at: now,
    }));
  });

  it("rejects assigning an unavailable bed", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(buildAdmission()),
      },
      bed: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ id: "bed-1", status: "OCCUPIED" }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.assignBed("ADM0000001", { bed_id: "BED0000001" }, {}),
    ).rejects.toMatchObject({
      messageKey: "errors.ipd_flow.bed_not_available",
    });
  });

  it("rejects assigning a bed when active bed assignment already exists", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(
            buildAdmission({ bed_assignments: [buildActiveBedAssignment()] }),
          ),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.assignBed("ADM0000001", { bed_id: "BED0000001" }, {}),
    ).rejects.toMatchObject({
      messageKey: "errors.ipd_flow.active_bed_exists",
    });
  });

  it("rejects invalid transfer transitions", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(
            buildAdmission({
              transfer_requests: [
                {
                  id: "tr-1",
                  status: "REQUESTED",
                  requested_at: now,
                  deleted_at: null,
                },
              ],
            }),
          ),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.updateTransfer("ADM0000001", { action: "START" }, {}),
    ).rejects.toMatchObject({
      messageKey: "errors.ipd_flow.invalid_transfer_transition",
    });
  });

  it("rejects transfer completion when destination bed is missing", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(
            buildAdmission({
              bed_assignments: [buildActiveBedAssignment()],
              transfer_requests: [
                {
                  id: "tr-1",
                  status: "IN_PROGRESS",
                  requested_at: now,
                  deleted_at: null,
                },
              ],
            }),
          ),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.updateTransfer("ADM0000001", { action: "COMPLETE" }, {}),
    ).rejects.toMatchObject({
      messageKey: "errors.ipd_flow.transfer_destination_bed_required",
    });
  });

  it("rejects discharge finalization while a transfer is still active", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(
            buildAdmission({
              transfer_requests: [
                {
                  id: "tr-1",
                  status: "IN_PROGRESS",
                  requested_at: now,
                  deleted_at: null,
                },
              ],
            }),
          ),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));

    await expect(
      ipdFlowService.finalizeDischarge(
        "ADM0000001",
        { summary: "Ready to go" },
        {},
      ),
    ).rejects.toMatchObject({
      messageKey: "errors.ipd_flow.transfer_must_be_resolved_before_discharge",
    });
  });

  it("resolves admissions by human-friendly ID", async () => {
    prisma.admission.findFirst.mockResolvedValue({ id: "adm-1" });
    ipdFlowRepository.findById.mockResolvedValue(buildAdmission());

    const result = await ipdFlowService.getIpdFlowById("adm0000001");

    expect(prisma.admission.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          human_friendly_id: "ADM0000001",
        }),
      }),
    );
    expect(result.admission.id).toBe("ADM0000001");
    expect(result.admission.tenant_id).toBeUndefined();
  });

  it("defaults queue_scope to ACTIVE when listing flows", async () => {
    ipdFlowRepository.findMany.mockResolvedValue([buildAdmission()]);
    ipdFlowRepository.count.mockResolvedValue(1);

    const result = await ipdFlowService.listIpdFlows({});

    expect(ipdFlowRepository.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        status: {
          notIn: ["DISCHARGED", "CANCELLED"],
        },
      }),
      0,
      20,
      expect.any(Object),
    );
    expect(result.items[0].id).toBe("ADM0000001");
  });

  it("resolves legacy resources to admission public id", async () => {
    prisma.admission.findFirst
      .mockResolvedValueOnce({ id: "adm-1", human_friendly_id: "ADM0000001" })
      .mockResolvedValueOnce({
        id: "adm-1",
        human_friendly_id: "ADM0000001",
        status: "ADMITTED",
      });

    const resolution = await ipdFlowService.resolveLegacyRoute(
      "admissions",
      "ADM0000001",
    );

    expect(resolution).toEqual(
      expect.objectContaining({
        admission_id: "ADM0000001",
        resource: "admissions",
        panel: "snapshot",
        action: "open_admission",
      }),
    );
  });

  it("resolves ICU legacy resources to admission public id", async () => {
    prisma.icu_observation.findFirst.mockResolvedValue({
      id: "obs-1",
      human_friendly_id: "OBS0000001",
      icu_stay: {
        admission_id: "adm-1",
      },
    });
    prisma.admission.findFirst.mockResolvedValue({
      id: "adm-1",
      human_friendly_id: "ADM0000001",
      status: "ADMITTED",
    });

    const resolution = await ipdFlowService.resolveLegacyRoute(
      "icu-observations",
      "OBS0000001",
    );

    expect(resolution).toEqual(
      expect.objectContaining({
        admission_id: "ADM0000001",
        resource: "icu-observations",
        panel: "observations",
        action: "add_icu_observation",
      }),
    );
  });

  it("starts ICU stay and returns ICU-enriched snapshot", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(buildAdmission({ icu_stays: [] })),
      },
      icu_stay: {
        create: jest.fn().mockResolvedValue({ id: "icu-1" }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: "adm-1" });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: "icu-1",
            human_friendly_id: "ICU0000001",
            started_at: now,
            ended_at: null,
            created_at: now,
            observations: [],
            alerts: [],
          },
        ],
      }),
    );

    const snapshot = await ipdFlowService.startIcuStay(
      "ADM0000001",
      {},
      { tenant_id: "tenant-1" },
    );

    expect(tx.icu_stay.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          admission_id: "adm-1",
        }),
      }),
    );
    expect(snapshot).toEqual(
      expect.objectContaining({
        icu_status: "ACTIVE",
        active_icu_stay_id: "ICU0000001",
      }),
    );
  });

  it("soft-resolves critical alert through IPD ICU action", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(
            buildAdmission({
              icu_stays: [
                {
                  id: "icu-1",
                  human_friendly_id: "ICU0000001",
                  started_at: now,
                  ended_at: null,
                  observations: [],
                  alerts: [
                    {
                      id: "alert-1",
                      human_friendly_id: "CAL0000001",
                      severity: "CRITICAL",
                      message: "Escalating trend",
                      created_at: now,
                      deleted_at: null,
                    },
                  ],
                },
              ],
            }),
          ),
      },
      critical_alert: {
        update: jest.fn().mockResolvedValue({ id: "alert-1" }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: "adm-1" });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        icu_stays: [
          {
            id: "icu-1",
            human_friendly_id: "ICU0000001",
            started_at: now,
            ended_at: null,
            observations: [],
            alerts: [],
          },
        ],
      }),
    );

    const snapshot = await ipdFlowService.resolveCriticalAlert(
      "ADM0000001",
      {},
      { tenant_id: "tenant-1" },
    );

    expect(tx.critical_alert.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: "alert-1" },
      }),
    );
    expect(snapshot).toEqual(
      expect.objectContaining({
        has_critical_alert: false,
      }),
    );
  });

  it("accepts a staff-profile public id for nursing note actions", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(buildAdmission()),
      },
      user: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
      staff_profile: {
        findFirst: jest.fn().mockResolvedValue({
          id: "sp-1",
          human_friendly_id: "STF0000001",
          user_id: "user-7",
          user: {
            id: "user-7",
            human_friendly_id: "USR0000007",
          },
        }),
      },
      nursing_note: {
        create: jest.fn().mockResolvedValue({ id: "nn-1" }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: "adm-1" });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        nursing_notes: [
          {
            id: "nn-1",
            human_friendly_id: "NUR0000001",
            note: "Stable after admission.",
            created_at: now,
            nurse: {
              id: "user-7",
              human_friendly_id: "USR0000007",
              email: "nurse@example.com",
              profile: {
                first_name: "Grace",
                middle_name: null,
                last_name: "Auma",
              },
            },
          },
        ],
      }),
    );

    const snapshot = await ipdFlowService.addNursingNote(
      "ADM0000001",
      {
        nurse_user_id: "STF0000001",
        note: "Stable after admission.",
      },
      { tenant_id: "tenant-1", facility_id: "facility-1" },
    );

    expect(tx.staff_profile.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          human_friendly_id: "STF0000001",
        }),
      }),
    );
    expect(tx.nursing_note.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          nurse_user_id: "user-7",
        }),
      }),
    );
    expect(snapshot.nursing_notes[0]).toEqual(
      expect.objectContaining({
        nurse_user_id: "USR0000007",
        nurse_name: "Grace Auma",
      }),
    );
  });

  it("creates medication reminders from a pharmacy plan and exposes them in the snapshot", async () => {
    const tx = {
      admission: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce({ id: "adm-1" })
          .mockResolvedValueOnce(
            buildAdmission({
              encounter_id: "enc-1",
            }),
          ),
      },
      encounter: {
        findFirst: jest.fn().mockResolvedValue({
          id: "enc-1",
          human_friendly_id: "ENC0000001",
        }),
      },
      pharmacy_order_item: {
        findFirst: jest.fn().mockResolvedValue({
          id: "poi-1",
          human_friendly_id: "RX0000001",
          dosage: "500 mg",
          frequency: "BID",
          route: "ORAL",
          status: "ACTIVE",
          drug: {
            id: "drug-1",
            human_friendly_id: "DRG0000001",
            name: "Paracetamol",
            form: "Tablet",
            strength: "500 mg",
          },
          pharmacy_order: {
            id: "po-1",
            human_friendly_id: "PO0000001",
            status: "ORDERED",
            ordered_at: now,
          },
        }),
      },
      medication_administration: {
        create: jest.fn().mockResolvedValue({ id: "med-1" }),
      },
      follow_up: {
        create: jest.fn().mockResolvedValue({ id: "fu-1" }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: "adm-1" });
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        encounter_id: "enc-1",
        encounter: {
          id: "enc-1",
          human_friendly_id: "ENC0000001",
          encounter_type: "INPATIENT",
          status: "IN_PROGRESS",
          started_at: now,
          ended_at: null,
          provider_user_id: "doctor-1",
          follow_ups: [
            {
              id: "fu-1",
              human_friendly_id: "FUP0000001",
              scheduled_at: new Date("2026-02-01T22:00:00.000Z"),
              status: "SCHEDULED",
              created_at: now,
              completed_at: null,
              notes:
                "Paracetamol 500 mg reminder 1/2 | BID\n" +
                'IPD_MEDICATION_REMINDER::{"kind":"IPD_MEDICATION_REMINDER","admission_public_id":"ADM0000001","encounter_public_id":"ENC0000001","prescription_public_id":"RX0000001","medication_label":"Paracetamol 500 mg","dose":"500","unit":"mg","route":"ORAL","frequency":"BID","occurrence":1,"total_occurrences":2}',
            },
          ],
          pharmacy_orders: [
            {
              id: "po-1",
              human_friendly_id: "PO0000001",
              status: "ORDERED",
              ordered_at: now,
              items: [
                {
                  id: "poi-1",
                  human_friendly_id: "RX0000001",
                  dosage: "500 mg",
                  frequency: "BID",
                  route: "ORAL",
                  status: "ACTIVE",
                  drug: {
                    id: "drug-1",
                    human_friendly_id: "DRG0000001",
                    name: "Paracetamol",
                    form: "Tablet",
                    strength: "500 mg",
                  },
                },
              ],
            },
          ],
        },
      }),
    );

    const snapshot = await ipdFlowService.addMedicationAdministration(
      "ADM0000001",
      {
        prescription_id: "RX0000001",
        medication_label: "Paracetamol 500 mg",
        dose: "500",
        unit: "mg",
        route: "ORAL",
        frequency: "BID",
        administered_at: "2026-02-01T10:00:00.000Z",
        schedule_reminders: true,
        reminder_first_at: "2026-02-01T22:00:00.000Z",
        reminder_occurrences: 2,
      },
      { tenant_id: "tenant-1", facility_id: "facility-1" },
    );

    expect(tx.medication_administration.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          prescription_id: "poi-1",
          dose: "500",
          unit: "mg",
          route: "ORAL",
        }),
      }),
    );
    expect(tx.follow_up.create).toHaveBeenCalledTimes(2);
    expect(tx.follow_up.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          encounter_id: "enc-1",
          notes: expect.stringContaining("IPD_MEDICATION_REMINDER::"),
        }),
      }),
    );
    expect(snapshot.medication_suggestions[0]).toEqual(
      expect.objectContaining({
        id: "RX0000001",
        medication_label: expect.stringContaining("Paracetamol"),
      }),
    );
    expect(snapshot.medication_reminders[0]).toEqual(
      expect.objectContaining({
        prescription_id: "RX0000001",
        medication_label: "Paracetamol 500 mg",
        frequency: "BID",
      }),
    );
    expect(snapshot.timeline).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          type: "MEDICATION_REMINDER",
        }),
      ]),
    );
  });

  it("emits ipd.flow.updated and compatibility admission events on start", async () => {
    const tx = {
      tenant: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
      facility: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
      patient: {
        findFirst: jest.fn().mockResolvedValue({
          id: "pat-1",
          tenant_id: "tenant-1",
          facility_id: "facility-1",
        }),
      },
      encounter: {
        findFirst: jest.fn().mockResolvedValue(null),
      },
      admission: {
        create: jest.fn().mockResolvedValue({ id: "adm-1" }),
      },
      bed: {
        findFirst: jest.fn().mockResolvedValue({
          id: "bed-1",
          status: "AVAILABLE",
          ward_id: "ward-1",
          tenant_id: "tenant-1",
          facility_id: "facility-1",
        }),
        update: jest.fn().mockResolvedValue({ id: "bed-1" }),
      },
      bed_assignment: {
        create: jest.fn().mockResolvedValue({ id: "ba-1" }),
      },
    };

    prisma.$transaction.mockImplementation(async (callback) => callback(tx));
    prisma.admission.findFirst.mockResolvedValue({ id: "adm-1" });
    prisma.user_role.findMany.mockResolvedValue([
      { user_id: "actor-1" },
      { user_id: "nurse-2" },
    ]);
    ipdFlowRepository.findById.mockResolvedValue(
      buildAdmission({
        bed_assignments: [buildActiveBedAssignment()],
      }),
    );

    await ipdFlowService.startIpdFlow(
      {
        patient_id: "PAT0000001",
        bed_id: "BED0000001",
      },
      {
        user_id: "actor-1",
        tenant_id: "tenant-1",
        facility_id: "facility-1",
      },
    );

    expect(emitToUsers).toHaveBeenCalledWith(
      ["nurse-2"],
      "ipd.flow.updated",
      expect.objectContaining({
        admission_id: "ADM0000001",
        action: "START",
        target_path: expect.stringContaining("/ipd?id="),
      }),
    );

    const flowEventPayload = emitToUsers.mock.calls.find(
      (call) => call[1] === "ipd.flow.updated",
    )[2];
    expect(flowEventPayload.tenant_internal_id).toBeUndefined();
    expect(flowEventPayload.facility_internal_id).toBeUndefined();

    const emittedEvents = emitToUsers.mock.calls.map((call) => call[1]);
    expect(emittedEvents).toContain("admission.patient_admitted");
    expect(emittedEvents).toContain("admission.bed_assignment_changed");
  });

  it("throws HttpError for missing flow", async () => {
    prisma.admission.findFirst.mockResolvedValue(null);
    await expect(
      ipdFlowService.getIpdFlowById("ADM404"),
    ).rejects.toBeInstanceOf(HttpError);
  });
});
