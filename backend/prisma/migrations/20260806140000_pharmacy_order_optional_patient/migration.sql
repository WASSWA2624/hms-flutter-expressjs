-- Allow pharmacy walk-in / anonymous orders without a linked patient record.
ALTER TABLE `pharmacy_order`
  MODIFY `patient_id` VARCHAR(36) NULL;
