/// Whether Clinical Services Lab create/edit/delete controls may render.
///
/// Matches [FacilityCatalogConfigPanel] Lab-tab gating: panel must be enabled
/// and the session must pass [AppAccessPolicy.canMutateLabCatalog].
bool labCatalogMutateControlsVisible({
  required bool panelEnabled,
  required bool canMutateLabCatalog,
}) {
  return panelEnabled && canMutateLabCatalog;
}
