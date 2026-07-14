Review all rule files in: [HMS rules](.cursor/**), [Backend rules](backend/.cursor/**), and [Frontend rules](frontend/.cursor/**).

For each rule file, perform the following for only those rules where the requirement or change is applicable:

1. Confirm `alwaysApply: false` is present.
2. In the `meta` section:
  - Verify `globs` correctly represent the file's intended scope.
  - Ensure the `description` is concise (≤21 words), clearly stating when and where the rule should be applied.
3. Update or remove only those rules that are duplicates or produce conflicts, ensuring consistency across files.
4. Check that all descriptions, where changes are needed, are clear and easy to understand.
5. For rules mandating product or UI standards (such as for UI, sync, or workflow), update those applicable rules to explicitly require: high performance, uniform and consistent UI, reusable components/code, real-time UI-to-backend sync, complete responsiveness (mobile, tablet, desktop), simple UI design, and intuitive workflows.
6. For rules governing entity references between frontend and backend, ensure only those relevant rules include: "The frontend must reference entities by human_friendly_id; the backend must map these to internal IDs. Never expose raw database table ids in frontend or API responses."
7. For applicable rules, require that the theme is comprehensive and prohibits hard-coded tokens anywhere in the codebase.
8. Ensure all text is fully localized, concise, and uses context-appropriate terminology.
9. Only update rules and sections to which these requirements or clarifications apply; leave other rules unchanged.
10. UI rules must require prioritizing reusability and consistency. Any component that may be reused should be implemented as a reusable component and placed in the appropriate subfolder under [Shared folder](frontend/lib/shared/).