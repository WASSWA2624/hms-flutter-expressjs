const IPD_MEDICATION_REMINDER_PREFIX = "IPD_MEDICATION_REMINDER::";

const MEDICATION_FREQUENCIES = new Set([
  "ONCE",
  "BID",
  "TID",
  "QID",
  "PRN",
  "STAT",
  "CUSTOM",
]);

const sanitize = (value) => String(value || "").trim();

const normalizeMedicationFrequency = (value, fallback = "ONCE") => {
  const normalized = sanitize(value).toUpperCase();
  if (MEDICATION_FREQUENCIES.has(normalized)) return normalized;
  return fallback;
};

const resolveMedicationFrequencyIntervalHours = (
  frequency,
  customHours = null,
) => {
  const normalized = normalizeMedicationFrequency(frequency);
  if (normalized === "BID") return 12;
  if (normalized === "TID") return 8;
  if (normalized === "QID") return 6;
  if (normalized === "CUSTOM") {
    const parsed = Number(customHours);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }
  return null;
};

const buildMedicationDisplayLabel = ({
  medicationLabel,
  dose,
  unit,
  route,
}) => {
  const primary = sanitize(medicationLabel);
  if (primary) return primary;

  const doseLabel = [sanitize(dose), sanitize(unit)].filter(Boolean).join(" ");
  const routeLabel = sanitize(route);
  return [doseLabel, routeLabel].filter(Boolean).join(" | ").trim();
};

const buildIpdMedicationReminderNote = ({
  medicationLabel,
  dose,
  unit,
  route,
  frequency,
  admissionPublicId,
  encounterPublicId,
  prescriptionPublicId,
  occurrence,
  totalOccurrences,
}) => {
  const label =
    buildMedicationDisplayLabel({ medicationLabel, dose, unit, route }) ||
    "Medication";
  const normalizedFrequency = normalizeMedicationFrequency(frequency, "");
  const summary = `${label} reminder ${occurrence}/${totalOccurrences}${
    normalizedFrequency ? ` | ${normalizedFrequency}` : ""
  }`;
  const metadata = {
    kind: "IPD_MEDICATION_REMINDER",
    admission_public_id: sanitize(admissionPublicId) || null,
    encounter_public_id: sanitize(encounterPublicId) || null,
    prescription_public_id: sanitize(prescriptionPublicId) || null,
    medication_label: sanitize(medicationLabel) || null,
    dose: sanitize(dose) || null,
    unit: sanitize(unit) || null,
    route: sanitize(route) || null,
    frequency: normalizedFrequency || null,
    occurrence: Number(occurrence || 0),
    total_occurrences: Number(totalOccurrences || 0),
  };

  return `${summary}\n${IPD_MEDICATION_REMINDER_PREFIX}${JSON.stringify(metadata)}`;
};

const parseIpdMedicationReminderNote = (note) => {
  const text = String(note || "");
  if (!text.includes(IPD_MEDICATION_REMINDER_PREFIX)) return null;

  const lines = text.split(/\r?\n/);
  const metadataLine = lines.find((line) =>
    line.startsWith(IPD_MEDICATION_REMINDER_PREFIX),
  );
  if (!metadataLine) return null;

  try {
    const parsed = JSON.parse(
      metadataLine.slice(IPD_MEDICATION_REMINDER_PREFIX.length),
    );
    if (sanitize(parsed?.kind).toUpperCase() !== "IPD_MEDICATION_REMINDER") {
      return null;
    }

    const displayNote = lines
      .filter((line) => !line.startsWith(IPD_MEDICATION_REMINDER_PREFIX))
      .join("\n")
      .trim();

    return {
      ...parsed,
      kind: "IPD_MEDICATION_REMINDER",
      admission_public_id: sanitize(parsed?.admission_public_id) || null,
      encounter_public_id: sanitize(parsed?.encounter_public_id) || null,
      prescription_public_id: sanitize(parsed?.prescription_public_id) || null,
      medication_label: sanitize(parsed?.medication_label) || null,
      dose: sanitize(parsed?.dose) || null,
      unit: sanitize(parsed?.unit) || null,
      route: sanitize(parsed?.route) || null,
      frequency: normalizeMedicationFrequency(parsed?.frequency, ""),
      occurrence: Number(parsed?.occurrence || 0),
      total_occurrences: Number(parsed?.total_occurrences || 0),
      display_note: displayNote || null,
    };
  } catch (_error) {
    return null;
  }
};

module.exports = {
  IPD_MEDICATION_REMINDER_PREFIX,
  normalizeMedicationFrequency,
  resolveMedicationFrequencyIntervalHours,
  buildIpdMedicationReminderNote,
  parseIpdMedicationReminderNote,
};
