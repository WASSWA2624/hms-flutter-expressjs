# Forms Strategy

## Scope
Defines form layout, validation, field components, submission states, and error display.

## Mandatory rules
- Use shared form components for text, select, date, radio, checkbox, and switch inputs.
- Keep form validation rules out of raw widgets when they are reused or business-relevant.
- Display field-level errors beside the field where possible.
- Display form-level errors for server or cross-field failures.
- Localize all labels, hints, helper text, and validation messages.
- Prevent duplicate submissions while a submit action is running.
- Preserve form input on recoverable errors.
- Use appropriate keyboard types and input formatters.
- Avoid giant ungrouped forms; group related fields into clear sections.

## Validation timing
- Required fields may validate on blur or submit.
- Format errors may validate after the user has interacted with the field.
- Server validation errors must map back to fields when possible.

## Acceptance checklist
- Every form has loading, success, validation error, and server error behavior.
- Required fields are obvious.
- Forms are usable on mobile and desktop.

## Related rules
- [`validation.md`](./validation.md)
- [`reusable_components.md`](./reusable_components.md)
- [`localization_i18n.md`](./localization_i18n.md)
- [`accessibility.md`](./accessibility.md)
