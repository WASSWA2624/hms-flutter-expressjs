-- Add REQUESTED to admission status enum for pending admission requests.
ALTER TABLE `admission`
  MODIFY `status` ENUM('REQUESTED', 'ADMITTED', 'DISCHARGED', 'TRANSFERRED', 'CANCELLED') NOT NULL;
