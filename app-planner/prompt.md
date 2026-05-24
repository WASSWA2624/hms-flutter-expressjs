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

So now, we have the radiology page. It has a patient view toggle. The button toggle is between patient view and radiology and the other view. Then we have the refresh button. We have the image request, the request imaging. That's okay. And then we also have here the table. This table is also okay. But this is what I want to have here. Similar to how we implemented the lab, the lab screen or module, I want us to have, in addition to these three action buttons we have on top, I want us to have a configuration button which when clicked, it invokes a configuration dialog. So this configuration dialog, we can create new radiology tests like imaging tests for the different equipment. We can add a new equipment. We can add a new equipment. We can add a new test. We can edit. We can configure the way we want. And then also, I also want that when you click on request imaging, this request imaging form that comes should actually reuse the model, the reusable dialog for imaging or radiology, which is already created, which is already defined inside the shared components. Actually, I want you to design all of this into reusable components, such that if somebody is calling these models and dialogues, they should be able to use to reuse these same dialogues. And then also, a request, a radiology request, can have one or more tests, imaging tests someone might request. Make it a user-friendly and make it like an expert. So this is, it should be very easy, it should be very easy. It should have very good user responsiveness, good user experience. For a given patient, you can set what to print, you can preview the print, you can decide what to print, and the print should use, should also reuse the reusable template that is already defined in the shared folder. So this shared folder actually right now, it has a lot of reusable components. Some of them are similar, some of them are not similar. So try to reorganize it. Each reusable component should be in its respective folder. folder, so that one can easily find it, one can easily locate it, and the reusability should be very easy, and make sure everything is uniform throughout. So, let's first implement that. I'll give more orders if needed. So, if anything is already predefined in a database or somewhere, I'll try to try as much as possible to prioritize the use of the reusable components. So, it should be easy to write a report. It should be easy to make a conclusion on an image. It should be easy to upload and insert images within the test, so maybe from packs or from the device itself or from the computer, whichever device. It should be easy to add images and annotation on images in the report. And then the report should be easily editable. The form should be easily editable, should be complete and dynamic, easy to use. The user interface should be stable and have a very good user experience. When somebody is typing and maybe they are searching for something, they should find it easily.