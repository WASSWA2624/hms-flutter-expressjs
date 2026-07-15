Review all rule files in: [HMS rules](.cursor/**), [Backend rules](backend/.cursor/**), and [Frontend rules](frontend/.cursor/**).

For each rule file, apply the following steps where applicable:

1. Ensure `alwaysApply: false` is correctly set unless otherwise specified.
2. In the `meta` section:

- Confirm `globs` accurately match the rule file's intended scope.
- Verify the `description` is clear (≤21 words), concise, and states precise application conditions.

3. Remove or update only duplicate or conflicting rules to maintain consistency across the codebase.
4. Where needed, revise descriptions to be unambiguous and easily understandable.
5. Where standards for product or UI are defined (e.g., UI, sync, workflow rules), explicitly require: high performance, uniform and consistent UI, reusable components/code, real-time sync between UI and backend, full responsiveness (mobile, tablet, desktop), simple UI design, and intuitive workflows.
6. For entity reference rules between frontend and backend, where relevant, require: "Frontend must reference entities by human_friendly_id; backend maps to internal IDs. Do not expose raw table IDs in frontend or API responses."
7. Where relevant, require that themes are comprehensive and prohibit hard-coded tokens throughout the codebase.
8. Ensure all text is localized, concise, and uses appropriate terminology for its context.
9. Make changes only in those rule files or sections to which these requirements apply; leave unrelated rules unchanged.
10. For UI rules, require that reusability and consistency are prioritized. All components suitable for reuse must be implemented as reusable components and stored in the appropriate subfolder under [Shared folder](frontend/lib/shared/).
11. Where applicable (see `.cursor/access`, `.cursor/**`, `backend/.cursor/**`, `frontend/.cursor/**` RBAC/ABAC rules), require strict enforcement of Role-Based (RBAC) and Attribute-Based (ABAC) Access Control. Menus, UI components, API endpoints, and workflow actions must never be visible, rendered, or accessible to unauthorized users. Reference and harmonize with the main access control and permissions requirements in sections 12–13 and access rule files.
12. Update `.cursor/access` and related rule files to allow multiple roles and modules to be assigned to each user in the database. Enforce that a user's effective permissions are strictly the intersection of the permissions granted by their assigned roles/modules *and* those enabled by their active subscription package. Users must not access any permission, module, or functionality not included in their current subscription, regardless of direct, role-, or module-based assignment. Ensure permissions may be stored and attached at the user, role, and module levels, and are also linked to subscription packages as defined in `.cursor/access/permissions.mdc`, `.cursor/access/modules.mdc`, and `.cursor/access/subscriptions.mdc`.

13. For `.cursor/access` and related rule files:
   - Define a mandatory, source-controlled set of default modules (`.cursor/access/modules.mdc`), subscription packages (`.cursor/access/subscriptions.mdc`), user roles (`.cursor/access/default_user_roles.mdc`), and associated permissions (`.cursor/access/permissions.mdc`).
   - Each module in `.cursor/access/modules.mdc` must declare its default permissions by referencing `.cursor/access/permissions.mdc`.
   - Each subscription package in `.cursor/access/subscriptions.mdc` must enumerate its included modules and effective permissions.
   - User roles in `.cursor/access/default_user_roles.mdc` must specify default module permissions and allow authorized administrators to modify or revert them to the original defaults, with all changes versioned and auditable.
   - The system must provide an out-of-the-box, complete, and core set of modules, packages, roles, and permissions, all under source control.
   - Administrators must be able to customize, extend, or restore module, role, and package permissions to shipped defaults at any time.
   - Document and enforce all relationships and permission assignments between modules, subscriptions, roles, and users in the applicable rule files.
   - Guarantee that defaults can be restored and active changes are atomic, ensuring no user’s effective permissions can ever exceed those allowed by both their assigned roles/modules and active subscription package.
