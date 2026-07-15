"""Run each prompt file in prompts/ as a separate Cursor agent chat."""

import asyncio
import os
import sys
from pathlib import Path

from cursor_sdk import (
    AgentOptions,
    AsyncClient,
    CursorAgentError,
    LocalAgentOptions,
)


PROMPTS_DIR = Path(__file__).parent / "prompts"
PROJECT_DIR = str(PROMPTS_DIR.parent)
EXCLUDED = {"01-patients-screen.md", "02-standardize-opd.md", "TEMP_01-patients-screen.md"}


async def run_prompt(file: Path, client: AsyncClient) -> dict:
    """Run a single prompt file in a Cursor agent."""
    name = file.name
    print(f"[START] {name}")
    try:
        prompt_text = file.read_text(encoding="utf-8")
        async with await client.create_agent(
            AgentOptions(
                api_key=os.environ["CURSOR_API_KEY"],
                model="auto",
                local=LocalAgentOptions(cwd=PROJECT_DIR),
            )
        ) as agent:
            run = await agent.send(prompt_text)
            result = await run.wait()
        status = result.status
        print(f"[{status.upper()}] {name}")
        return {"file": name, "status": status}
    except CursorAgentError as err:
        print(f"[ERROR] {name}: {err.message}", file=sys.stderr)
        return {"file": name, "status": "error", "message": err.message}
    except Exception as err:
        print(f"[ERROR] {name}: {err}", file=sys.stderr)
        return {"file": name, "status": "error", "message": str(err)}


async def main():
    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key or api_key == "cursor_...":
        sys.exit(
            "Error: set CURSOR_API_KEY to your actual key, not the "
            "'cursor_...' example value."
        )

    files = sorted(f for f in PROMPTS_DIR.glob("*.md") if f.name not in EXCLUDED)
    if not files:
        sys.exit("No .md files found in prompts/")

    print(f"Found {len(files)} prompt files. Running sequentially...\n")

    results = []
    async with await AsyncClient.launch_bridge(workspace=PROJECT_DIR) as client:
        for file in files:
            results.append(await run_prompt(file, client))

    print("\n--- Summary ---")
    for r in results:
        print(f"  {r['file']}: {r['status']}")

    errors = [r for r in results if r["status"] != "finished"]
    if errors:
        print(f"\n{len(errors)} prompt(s) did not finish successfully.")
        sys.exit(1)
    else:
        print(f"\nAll {len(results)} prompts completed successfully.")


if __name__ == "__main__":
    asyncio.run(main())
