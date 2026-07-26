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

/// Whether Edit/Delete may render for a specific lab catalog item.
///
/// Standard catalog rows are read-only; omit controls rather than disabling.
bool labCatalogItemMutateActionsVisible({
  required bool canMutateLabCatalog,
  required bool isStandard,
}) {
  return canMutateLabCatalog && !isStandard;
}
