"""Run each prompt file in prompts/ as a separate Cursor agent chat.

Discovers all .md prompts under prompts/ recursively (excluding prompts/.cursor).
After each prompt finishes successfully, commits and pushes any resulting changes.
"""

import asyncio
import json
import os
import subprocess
import sys
from pathlib import Path

from cursor_sdk import (
    AgentOptions,
    AsyncClient,
    CursorAgentError,
    LocalAgentOptions,
)


PROMPTS_DIR = Path(__file__).parent / "prompts"
PROJECT_DIR = Path(__file__).parent
STATE_FILE = Path(__file__).parent / ".run_prompts_state.json"
# Sequential: each prompt commits/pushes against the shared workspace.
MAX_CONCURRENCY = 1
MAX_ATTEMPTS = 3
# Agent runs can take much longer than the SDK defaults (60s unary / 600s stream).
BRIDGE_TIMEOUT_SECONDS = None
SKIP_DIR_NAMES = {".cursor"}


def _list_prompt_files() -> list[Path]:
    """All .md files under prompts/, excluding anything under prompts/.cursor."""
    files: list[Path] = []
    for path in sorted(PROMPTS_DIR.rglob("*.md")):
        try:
            relative = path.relative_to(PROMPTS_DIR)
        except ValueError:
            continue
        if any(part in SKIP_DIR_NAMES for part in relative.parts):
            continue
        files.append(path)
    return files


def _prompt_key(file: Path) -> str:
    """Stable id for state tracking (relative path with forward slashes)."""
    return file.relative_to(PROMPTS_DIR).as_posix()


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


def _run_git(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=PROJECT_DIR,
        check=check,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def _git_has_changes() -> bool:
    staged = _run_git(["diff", "--cached", "--quiet"], check=False)
    unstaged = _run_git(["diff", "--quiet"], check=False)
    untracked = _run_git(
        ["ls-files", "--others", "--exclude-standard"],
        check=True,
    )
    return (
        staged.returncode != 0
        or unstaged.returncode != 0
        or bool(untracked.stdout.strip())
    )


def _commit_and_push(prompt_key: str) -> dict:
    """Stage, commit, and push workspace changes after a successful prompt run."""
    _run_git(["add", "-A"])

    if not _git_has_changes():
        print(f"[GIT] {prompt_key}: no changes to commit", flush=True)
        return {"committed": False, "pushed": False}

    message = f"Apply prompt: {prompt_key}"
    try:
        _run_git(["commit", "-m", message])
    except subprocess.CalledProcessError as err:
        detail = (err.stderr or err.stdout or str(err)).strip()
        raise RuntimeError(f"git commit failed: {detail}") from err

    print(f"[GIT] {prompt_key}: committed", flush=True)

    try:
        _run_git(["push"])
    except subprocess.CalledProcessError as err:
        detail = (err.stderr or err.stdout or str(err)).strip()
        raise RuntimeError(f"git push failed: {detail}") from err

    print(f"[GIT] {prompt_key}: pushed", flush=True)
    return {"committed": True, "pushed": True}


async def run_prompt(
    file: Path,
    client: AsyncClient,
    semaphore: asyncio.Semaphore,
    finished: set[str],
    finished_lock: asyncio.Lock,
) -> dict:
    """Run a single prompt file in a Cursor agent, then commit and push."""
    async with semaphore:
        key = _prompt_key(file)
        print(f"[START] {key}", flush=True)
        last_error = ""
        for attempt in range(1, MAX_ATTEMPTS + 1):
            try:
                prompt_text = file.read_text(encoding="utf-8")
                async with await client.create_agent(
                    AgentOptions(
                        api_key=os.environ["CURSOR_API_KEY"],
                        model="auto",
                        local=LocalAgentOptions(cwd=str(PROJECT_DIR)),
                    )
                ) as agent:
                    run = await agent.send(prompt_text)
                    print(
                        f"[RUN] {key}: agent={agent.agent_id} run={run.id}",
                        flush=True,
                    )
                    result = await run.wait()
                status = result.status
                print(f"[{status.upper()}] {key}", flush=True)
                if status != "finished":
                    return {"file": key, "status": status}

                git_info = await asyncio.to_thread(_commit_and_push, key)
                async with finished_lock:
                    finished.add(key)
                    _save_finished(finished)
                return {
                    "file": key,
                    "status": "finished",
                    **git_info,
                }
            except CursorAgentError as err:
                last_error = _error_text(err)
                if attempt < MAX_ATTEMPTS and _is_retryable(err):
                    wait_s = 2 ** (attempt - 1)
                    print(
                        f"[RETRY] {key} attempt {attempt}/{MAX_ATTEMPTS}: "
                        f"{last_error} (sleep {wait_s}s)",
                        file=sys.stderr,
                        flush=True,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                print(f"[ERROR] {key}: {last_error}", file=sys.stderr, flush=True)
                return {"file": key, "status": "error", "message": last_error}
            except Exception as err:
                last_error = _error_text(err)
                if attempt < MAX_ATTEMPTS and _is_retryable(err):
                    wait_s = 2 ** (attempt - 1)
                    print(
                        f"[RETRY] {key} attempt {attempt}/{MAX_ATTEMPTS}: "
                        f"{last_error} (sleep {wait_s}s)",
                        file=sys.stderr,
                        flush=True,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                print(f"[ERROR] {key}: {last_error}", file=sys.stderr, flush=True)
                return {"file": key, "status": "error", "message": last_error}

        return {"file": key, "status": "error", "message": last_error}


async def main():
    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key or api_key == "cursor_...":
        sys.exit(
            "Error: set CURSOR_API_KEY to your actual key, not the "
            "'cursor_...' example value."
        )

    files = _list_prompt_files()
    if not files:
        sys.exit(f"No .md files found in {PROMPTS_DIR}/ (excluding .cursor)")

    known = {_prompt_key(f) for f in files}
    finished = _load_finished() & known
    pending = [f for f in files if _prompt_key(f) not in finished]
    skipped = len(files) - len(pending)

    print(
        f"Found {len(files)} prompt file(s) under prompts/ "
        f"(excluding .cursor; {skipped} already finished, {len(pending)} pending). "
        f"Running with concurrency={MAX_CONCURRENCY}, model=auto; "
        f"commit+push after each success...\n",
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
        workspace=str(PROJECT_DIR),
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
        extra = ""
        if r.get("committed"):
            extra = " (committed+pushed)"
        elif r.get("committed") is False:
            extra = " (no git changes)"
        print(f"  {r['file']}: {r['status']}{extra}")

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
