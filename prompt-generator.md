Carefully review the application improvement requirements described in [prompt.md](prompt.md). For each distinct requirement, create a focused, precise, and contextually aware markdown prompt file in the [prompts](prompts) directory. Name files sequentially (e.g., 00-[descriptive-name].md, 01-[descriptive-name].md) to ensure clarity and ease of navigation.

Ensure each prompt transforms the corresponding requirement into clear, stepwise instructions that enable accurate implementation across backend, database, and frontend systems when needed. Emphasize reusability and modularity of logic and components. For any data or schema adjustments, outline all necessary database migrations and specify removal of outdated data and obsolete code arising from these updates.

Throughout, rigorously follow all relevant .cursor/** guidelines, including those under [HMS rules](.cursor), [Backend rules](.cursor/backend), and [Frontend rules](.cursor/frontend).
