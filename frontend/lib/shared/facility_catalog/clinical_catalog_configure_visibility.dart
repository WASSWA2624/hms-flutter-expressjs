/// Whether Clinical Services Diagnoses **Configure** may render.
///
/// Matches [FacilityCatalogConfigPanel] Diagnoses-tab gating: panel must be
/// enabled and the session must pass [AppAccessPolicy.canMutateClinicalCatalog].
bool clinicalCatalogConfigureVisible({
  required bool panelEnabled,
  required bool canMutateClinicalCatalog,
}) {
  return panelEnabled && canMutateClinicalCatalog;
}
