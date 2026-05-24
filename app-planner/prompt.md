Review the attached `hms.zip` archive containing the Hospital Management System codebase. The archive includes the main project folders:

* `app-planner`
* `backend`
* `frontend`

It may also include screenshots and an appended raw implementation task.

Your job is to inspect the archive carefully and convert the raw implementation task into a clear, precise, implementation-ready prompt for a coding agent.

The refined prompt must be grounded in the actual project codebase. Use the existing project structure, architecture, naming conventions, coding style, UI patterns, and any provided screenshots as the source of truth.

Important: The coding agent that receives the refined prompt will have access to the HMS codebase, but may not have access to the screenshots. Therefore, convert any important screenshot-based UI/UX details into explicit written requirements.

The refined prompt must include:

1. A clear description of the problem to solve.
2. The relevant areas of the project to inspect or modify, including frontend, backend, and `app-planner` files where applicable.
3. Instructions to preserve the existing architecture, folder structure, naming conventions, and coding style.
4. Written UI/UX requirements based on both the raw task and any screenshots.
5. Specific implementation requirements.
6. Testing and verification expectations.
7. Clear limits on scope: avoid unnecessary rewrites, unrelated refactors, or changes outside the requested task.
8. An instruction to modify only the files required for the requested change.
9. Ensure all linter issues are cleared.
10. Reuse components in `frontend\lib\shared\*` folder before creating new ones.
11. Ensure 100% localization(l10n).

The coding agent must return a zipped archive containing only the files and folders that were created or updated. All files must be placed in their correct relative project directories.

If any files or folders must be deleted or renamed, the coding agent must also include one or more `.ps1` PowerShell scripts that safely perform those delete or rename operations. The scripts must use correct relative paths and must not delete unrelated files.

Final output requirements:

* Return only the polished, actionable prompt.
* Do not include explanations, commentary, or analysis.
* Do not invent project details that are not supported by the archive.
* If the raw task is incomplete or unclear, preserve the known requirements and explicitly mark the missing details that the coding agent must verify from the codebase.

## Raw implementation task

Review the current implementation of the pharmacy module and see There should be a way for pharmacy to add new drugs. The form for adding drugs should be comprehensive, whereby you can add the drug details, quantity, units, and so on and so forth. Then there should be also a way to receive orders, to see orders, pharmacy orders from different departments, and then also dispense them. The stock management should also be possible, printing, and so it should be a complete pharmacy module that everybody, that is complete, user-friendly, and every action should be completed in a modal dialog, and there should be as few steps as possible. So that's how to accomplish tasks and actions easily, very simple and easy.