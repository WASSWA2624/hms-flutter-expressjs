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

The coding agent must return a zipped archive containing only the files and folders that were created or updated. All files must be placed in their correct relative project directories.

If any files or folders must be deleted or renamed, the coding agent must also include one or more `.ps1` PowerShell scripts that safely perform those delete or rename operations. The scripts must use correct relative paths and must not delete unrelated files.

Final output requirements:

* Return only the polished, actionable prompt.
* Do not include explanations, commentary, or analysis.
* Do not invent project details that are not supported by the archive.
* If the raw task is incomplete or unclear, preserve the known requirements and explicitly mark the missing details that the coding agent must verify from the codebase.

## Raw implementation task

Review the clinical screen and improve the design for the table because I can see on the table how color-coded the queues, the queues are color-coded and the status is also color-coded, but there is a status, the values which are within cards and borders are not looking nicely. It's just simply display the text and you have the text color-coded. When you display, when you open, when you click on the patients on the clinical menu, I see the clinical screen, the details, the patient details screen is not nicely styled. I can see still it has things designed in cards. Those cards are not needed. We should simply write the parameter and then its value, maybe on a row until the row is full, then we can go to the next. I can see also this triage region is also not nicely styled, so we can improve it. The vital signs are also not nicely styled. I think it's because, it's because we are displaying them on a column. And we're not utilizing the horizontal space nicely. This section which shows whether a value is low or high, this, I think they are not needed. Instead, we should color code the vital signs that are not looking nice. The clinical actions, they look okay, but first double-check and make sure that we are reusing the clinical actions which are defined in the shared folder and prioritize those ones that are already used in the OPD and patient screens. Lab orders are also not displayed nicely because of easy statuses like ordered, which are covered in cards. We should get rid of those cards completely because the borders are not showing nicely. Let's simply use maybe color-coded texts. Down here also, the lab requests are also not nicely styled. The same applies to the radiology orders and even the title for the radiology orders. Announced is not appropriate. It's an order, but then what? This should be radiology order. I can see pharmacy is not displaying what order we ordered for in pharmacy. I only see the order ID. This is not a good thing, so we need to display information nicely. And I think we should do organize this so that the sections which are empty are displayed down or they are hidden because this is going to be on a report. So let's, and on all these things, let's, on all these results sections, let's have a way to hide, to edit or cancel something or delete. So all these sections which are empty, hide them and only display those sections which have information. Basically, this is how the patient detail screen in the clinical section, the patient's detail dialogue, this is how it should be designed.
