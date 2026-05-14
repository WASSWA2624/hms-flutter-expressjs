# Accessibility Strategy

## Scope
Defines baseline accessibility requirements for screens, components, forms, navigation, and feedback states.

## Mandatory rules
- Add semantic labels for icon-only buttons and meaningful images.
- Keep tap/click targets at least `48px` where practical.
- Support keyboard navigation on web and desktop.
- Keep visible focus states.
- Do not rely only on color to communicate meaning.
- Keep text readable when font scaling is enabled.
- Use localized accessibility labels.
- Associate form errors with their fields where possible.
- Avoid excessive motion and provide simple transitions by default.

## Implementation standard
- Dialogs should trap focus where the platform expects it and return focus after closing.
- State views should announce meaningful loading, empty, and error messages.
- Use icons plus text for important statuses.

## Acceptance checklist
- Keyboard tab order is logical.
- Important actions have semantic labels.
- Color contrast is readable in light and dark themes.
- Text scaling does not hide important controls.

## Related rules
- [`theming.md`](./theming.md)
- [`forms.md`](./forms.md)
- [`localization_i18n.md`](./localization_i18n.md)
- [`multi_platform_input.md`](./multi_platform_input.md)
