# Date, Time, and Formatting Strategy

## Scope
Defines storage, transfer, and display formatting for dates, times, numbers, and units.

## Mandatory rules
- Store timestamps consistently, preferably UTC for backend communication unless the domain requires local time.
- Display dates and times using the user locale.
- Do not format dates manually inside widgets.
- Use shared formatting utilities for dates, times, numbers, currency, and units.
- Do not concatenate formatted values with translated text when interpolation is needed.
- Be explicit about time zones in API contracts and documentation.

## Implementation standard
- Use ISO-like backend formats and localized display formats.
- Keep formatting utilities in `core/utils` or a clearly named shared formatter folder.

## Acceptance checklist
- Date/time display is consistent across screens.
- Tests cover important formatting utilities.
- Localization changes update formatting correctly.

## Related rules
- [`localization_i18n.md`](./localization_i18n.md)
- [`data_modeling.md`](./data_modeling.md)
- [`validation.md`](./validation.md)
