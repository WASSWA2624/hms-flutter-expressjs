# Asset and Branding Strategy

## Scope
Defines asset folders, naming, branding, icons, splash screens, and image quality.

## Mandatory rules
- Keep asset file names lowercase with underscores.
- Do not duplicate the same asset under multiple names.
- Compress images before committing them.
- Use appropriately sized raster images for each context.
- Use vector assets for simple scalable icons and illustrations when supported.
- Keep logos in a dedicated folder.
- Register assets explicitly in `pubspec.yaml`.
- Represent brand colors through the theme system, not raw widget colors.

## Implementation standard
- Recommended folders: `assets/images`, `assets/icons`, `assets/logos`, `assets/illustrations`, `assets/fonts` only when needed.
- Keep launcher icon and splash setup documented and repeatable.
- Provide light/dark variants only when required by the design.

## Acceptance checklist
- Assets load on all supported platforms.
- Large images are not committed without compression.
- Asset paths are centralized when reused.

## Related rules
- [`theming.md`](./theming.md)
- [`accessibility.md`](./accessibility.md)
- [`dependencies.md`](./dependencies.md)
- [`ci_cd_quality_gates.md`](./ci_cd_quality_gates.md)
