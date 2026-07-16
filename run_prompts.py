"""Run each prompt file in prompts/ as a separate Cursor agent chat."""

import asyncio
import json
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
STATE_FILE = Path(__file__).parent / ".run_prompts_state.json"
INCLUDED = {
    "08-standardize-operations.md",
    "09-standardize-pharmacy.md",
    "10-standardize-rooms-beds.md",
    "11-standardize-theater.md",
    "12-standardize-billing.md",
    "13-standardize-communications.md",
    "16-standardize-integrations.md",
    "17-standardize-nursing.md",
    "18-standardize-physiotherapy.md",
    "20-standardize-biomedical.md",
    "23-standardize-mortuary.md",
}
MAX_CONCURRENCY = 5
MAX_ATTEMPTS = 3
# Agent runs can take much longer than the SDK defaults (60s unary / 600s stream).
BRIDGE_TIMEOUT_SECONDS = None


def _load_finished() -> set[str]:
    if not STATE_FILE.exists():
        return set()
    try:
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return set()
    finished = data.get("finished", [])
    return set(finished) if isinstance(finished, list) else set()


def _save_finished(finished: set[str]) -> None:
    STATE_FILE.write_text(
        json.dumps({"finished": sorted(finished)}, indent=2) + "\n",
        encoding="utf-8",
    )


def _error_text(err: BaseException) -> str:
    if isinstance(err, CursorAgentError):
        parts = [err.message or str(err) or type(err).__name__]
        if err.code:
            parts.append(f"code={err.code}")
        if err.is_retryable:
            parts.append("retryable")
        return " | ".join(parts)
    return str(err) or type(err).__name__


def _is_retryable(err: BaseException) -> bool:
    if isinstance(err, CursorAgentError):
        return bool(err.is_retryable) or "timeout" in (err.message or "").lower()
    text = str(err).lower()
    return any(
        token in text
        for token in ("timeout", "timed out", "readtimeout", "connecttimeout")
    )


async def run_prompt(
    file: Path,
    client: AsyncClient,
    semaphore: asyncio.Semaphore,
    finished: set[str],
    finished_lock: asyncio.Lock,
) -> dict:
    """Run a single prompt file in a Cursor agent."""
    async with semaphore:
        name = file.name
        print(f"[START] {name}", flush=True)
        last_error = ""
        for attempt in range(1, MAX_ATTEMPTS + 1):
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
                    print(f"[RUN] {name}: agent={agent.agent_id} run={run.id}", flush=True)
                    result = await run.wait()
                status = result.status
                print(f"[{status.upper()}] {name}", flush=True)
                if status == "finished":
                    async with finished_lock:
                        finished.add(name)
                        _save_finished(finished)
                return {"file": name, "status": status}
            except CursorAgentError as err:
                last_error = _error_text(err)
                if attempt < MAX_ATTEMPTS and _is_retryable(err):
                    wait_s = 2 ** (attempt - 1)
                    print(
                        f"[RETRY] {name} attempt {attempt}/{MAX_ATTEMPTS}: "
                        f"{last_error} (sleep {wait_s}s)",
                        file=sys.stderr,
                        flush=True,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                print(f"[ERROR] {name}: {last_error}", file=sys.stderr, flush=True)
                return {"file": name, "status": "error", "message": last_error}
            except Exception as err:
                last_error = _error_text(err)
                if attempt < MAX_ATTEMPTS and _is_retryable(err):
                    wait_s = 2 ** (attempt - 1)
                    print(
                        f"[RETRY] {name} attempt {attempt}/{MAX_ATTEMPTS}: "
                        f"{last_error} (sleep {wait_s}s)",
                        file=sys.stderr,
                        flush=True,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                print(f"[ERROR] {name}: {last_error}", file=sys.stderr, flush=True)
                return {"file": name, "status": "error", "message": last_error}

        return {"file": name, "status": "error", "message": last_error}


async def main():
    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key or api_key == "cursor_...":
        sys.exit(
            "Error: set CURSOR_API_KEY to your actual key, not the "
            "'cursor_...' example value."
        )

    files = sorted(f for f in PROMPTS_DIR.glob("*.md") if f.name in INCLUDED)
    missing = sorted(INCLUDED - {f.name for f in files})
    if missing:
        sys.exit(f"Missing included prompt file(s): {', '.join(missing)}")
    if not files:
        sys.exit("No included .md files found in prompts/")

    finished = _load_finished() & INCLUDED
    pending = [f for f in files if f.name not in finished]
    skipped = len(files) - len(pending)

    print(
        f"Found {len(files)} included prompt files "
        f"({skipped} already finished, {len(pending)} pending). "
        f"Running with concurrency={MAX_CONCURRENCY}...\n",
        flush=True,
    )
    if not pending:
        print("Nothing left to run. Delete .run_prompts_state.json to rerun all.")
        return

    semaphore = asyncio.Semaphore(MAX_CONCURRENCY)
    finished_lock = asyncio.Lock()
    results: list[dict] = [
        {"file": name, "status": "finished"} for name in sorted(finished)
    ]

    async with await AsyncClient.launch_bridge(
        workspace=PROJECT_DIR,
        client_timeout=BRIDGE_TIMEOUT_SECONDS,
        max_retries=2,
    ) as client:
        pending_results = await asyncio.gather(
            *(
                run_prompt(file, client, semaphore, finished, finished_lock)
                for file in pending
            )
        )
        results.extend(pending_results)

    results.sort(key=lambda r: r["file"])

    print("\n--- Summary ---")
    for r in results:
        print(f"  {r['file']}: {r['status']}")

    errors = [r for r in results if r["status"] != "finished"]
    if errors:
        print(f"\n{len(errors)} prompt(s) did not finish successfully.")
        print("Re-run the same command to retry only the failed ones.")
        sys.exit(1)
    else:
        print(f"\nAll {len(results)} prompts completed successfully.")
        if STATE_FILE.exists():
            STATE_FILE.unlink()


if __name__ == "__main__":
    asyncio.run(main())
