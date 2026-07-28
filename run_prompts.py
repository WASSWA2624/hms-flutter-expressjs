"""Run prompts/dashboard.md 10 times sequentially with Cursor agents.

Each iteration is a fresh agent chat. After every successful iteration,
commits and pushes any resulting changes to GitHub before starting the next.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import subprocess
import sys
import time
from pathlib import Path

from cursor_sdk import (
    AgentOptions,
    AsyncClient,
    CursorAgentError,
    LocalAgentOptions,
)


PROJECT_DIR = Path(__file__).parent
PROMPT_FILE = PROJECT_DIR / "prompts" / "dashboard.md"
PROMPT_KEY = "dashboard.md"
STATE_FILE = PROJECT_DIR / ".run_prompts_state.json"
# How many times to run dashboard.md, one after another.
ITERATIONS = 10
MAX_ATTEMPTS = 3
# Cursor agents may also touch git; retry through index.lock races.
GIT_LOCK_RETRIES = 10
GIT_LOCK_BASE_DELAY_SECONDS = 0.35
# Agent runs can take much longer than the SDK defaults (60s unary / 600s stream).
BRIDGE_TIMEOUT_SECONDS = None
# Let Cursor pick the best available model for each run.
MODEL = "auto"
# Never commit runner bookkeeping into prompt-driven commits.
GIT_EXCLUDES = (".run_prompts_state.json",)
INDEX_LOCK_PATH = PROJECT_DIR / ".git" / "index.lock"


def _iteration_key(iteration: int) -> str:
    """Stable id for state tracking of one sequential dashboard run."""
    return f"{PROMPT_KEY}#{iteration}/{ITERATIONS}"


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


def _git_detail(err: subprocess.CalledProcessError) -> str:
    return (err.stderr or err.stdout or str(err)).strip()


def _is_index_lock_error(detail: str) -> bool:
    lower = detail.lower()
    return "index.lock" in lower or (
        "unable to create" in lower and ".lock" in lower
    )


def _clear_stale_index_lock(*, max_age_seconds: float = 30.0) -> bool:
    """Remove a leftover index.lock when it looks abandoned."""
    try:
        if not INDEX_LOCK_PATH.exists():
            return False
        age = time.time() - INDEX_LOCK_PATH.stat().st_mtime
        if age < max_age_seconds:
            return False
    except OSError:
        return False

    try:
        INDEX_LOCK_PATH.unlink(missing_ok=True)
        print("[GIT] removed stale .git/index.lock", flush=True)
        return True
    except OSError:
        return False


def _run_git(args: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    last_err: subprocess.CalledProcessError | None = None
    for attempt in range(1, GIT_LOCK_RETRIES + 1):
        try:
            return subprocess.run(
                ["git", *args],
                cwd=PROJECT_DIR,
                check=check,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
        except subprocess.CalledProcessError as err:
            last_err = err
            detail = _git_detail(err)
            if check and _is_index_lock_error(detail) and attempt < GIT_LOCK_RETRIES:
                _clear_stale_index_lock()
                delay = GIT_LOCK_BASE_DELAY_SECONDS * (2 ** (attempt - 1))
                print(
                    f"[GIT] index.lock busy on `git {' '.join(args)}`; "
                    f"retry {attempt}/{GIT_LOCK_RETRIES} in {delay:.1f}s",
                    flush=True,
                )
                time.sleep(delay)
                continue
            raise
    assert last_err is not None
    raise last_err


def _git_has_staged_changes() -> bool:
    """True when the index has staged changes ready to commit."""
    staged = _run_git(["diff", "--cached", "--quiet"], check=False)
    return staged.returncode != 0


def _commit_and_push(iteration_key: str) -> dict:
    """Stage, commit, and push workspace changes after a successful iteration."""
    last_error = ""
    for attempt in range(1, GIT_LOCK_RETRIES + 1):
        try:
            _run_git(["add", "-A"])
            for exclude in GIT_EXCLUDES:
                _run_git(["reset", "-q", "HEAD", "--", exclude], check=False)

            if not _git_has_staged_changes():
                leftover = _run_git(
                    ["ls-files", "--others", "--exclude-standard"],
                    check=True,
                ).stdout.strip()
                if leftover:
                    print(
                        f"[GIT] {iteration_key}: no staged changes "
                        f"(untracked still present; skipped commit)",
                        flush=True,
                    )
                else:
                    print(f"[GIT] {iteration_key}: no changes to commit", flush=True)
                return {"committed": False, "pushed": False}

            message = f"Apply prompt: {iteration_key}"
            try:
                _run_git(["commit", "-m", message])
            except subprocess.CalledProcessError as err:
                detail = _git_detail(err)
                if "nothing to commit" in detail.lower():
                    print(f"[GIT] {iteration_key}: no changes to commit", flush=True)
                    return {"committed": False, "pushed": False}
                if _is_index_lock_error(detail) and attempt < GIT_LOCK_RETRIES:
                    last_error = detail
                    _clear_stale_index_lock()
                    delay = GIT_LOCK_BASE_DELAY_SECONDS * (2 ** (attempt - 1))
                    print(
                        f"[GIT] {iteration_key}: commit lock busy; "
                        f"retry {attempt}/{GIT_LOCK_RETRIES} in {delay:.1f}s",
                        flush=True,
                    )
                    time.sleep(delay)
                    continue
                raise RuntimeError(f"git commit failed: {detail}") from err

            print(f"[GIT] {iteration_key}: committed", flush=True)

            try:
                _run_git(["push", "-u", "origin", "HEAD"])
            except subprocess.CalledProcessError as err:
                detail = _git_detail(err)
                raise RuntimeError(f"git push failed: {detail}") from err

            print(f"[GIT] {iteration_key}: pushed", flush=True)
            return {"committed": True, "pushed": True}
        except RuntimeError as err:
            detail = str(err)
            if _is_index_lock_error(detail) and attempt < GIT_LOCK_RETRIES:
                last_error = detail
                _clear_stale_index_lock()
                delay = GIT_LOCK_BASE_DELAY_SECONDS * (2 ** (attempt - 1))
                print(
                    f"[GIT] {iteration_key}: lock busy; "
                    f"retry {attempt}/{GIT_LOCK_RETRIES} in {delay:.1f}s",
                    flush=True,
                )
                time.sleep(delay)
                continue
            raise

    raise RuntimeError(
        f"git commit failed after {GIT_LOCK_RETRIES} lock retries: {last_error}"
    )


async def run_iteration(
    iteration: int,
    client: AsyncClient,
    finished: set[str],
) -> dict:
    """Run one dashboard.md iteration, then commit and push before returning."""
    key = _iteration_key(iteration)
    print(f"[START] {key}", flush=True)
    last_error = ""
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            prompt_text = PROMPT_FILE.read_text(encoding="utf-8")
            async with await client.create_agent(
                AgentOptions(
                    api_key=os.environ["CURSOR_API_KEY"],
                    model=MODEL,
                    local=LocalAgentOptions(cwd=str(PROJECT_DIR)),
                )
            ) as agent:
                run = await agent.send(prompt_text)
                print(
                    f"[RUN] {key}: agent={agent.agent_id} run={run.id} "
                    f"model={MODEL}",
                    flush=True,
                )
                result = await run.wait()
            status = result.status
            print(f"[{status.upper()}] {key}", flush=True)
            if status != "finished":
                last_error = f"agent status={status}"
                result_id = getattr(result, "id", None)
                if result_id:
                    last_error = f"{last_error} run={result_id}"
                if attempt < MAX_ATTEMPTS:
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
                return {
                    "file": key,
                    "status": "error",
                    "message": last_error,
                }

            git_info = await asyncio.to_thread(_commit_and_push, key)
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


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            f"Run {PROMPT_KEY} {ITERATIONS} times sequentially with Cursor "
            "model=auto, committing and pushing after each successful iteration."
        )
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Ignore .run_prompts_state.json and re-run all iterations from 1.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print the planned iteration keys and exit without running agents.",
    )
    return parser.parse_args(argv)


async def main(argv: list[str] | None = None):
    args = _parse_args(argv)

    if not PROMPT_FILE.is_file():
        sys.exit(f"Prompt file not found: {PROMPT_FILE}")

    all_keys = [_iteration_key(i) for i in range(1, ITERATIONS + 1)]
    if args.list:
        print(
            f"Plan: run {PROMPT_FILE.relative_to(PROJECT_DIR).as_posix()} "
            f"{ITERATIONS} times sequentially:"
        )
        for key in all_keys:
            print(f"  {key}")
        return

    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key or api_key == "cursor_...":
        sys.exit(
            "Error: set CURSOR_API_KEY to your actual key, not the "
            "'cursor_...' example value."
        )

    known = set(all_keys)
    if args.force:
        finished: set[str] = set()
        if STATE_FILE.exists():
            STATE_FILE.unlink()
            print("Cleared .run_prompts_state.json (--force).\n", flush=True)
    else:
        finished = _load_finished() & known
        _save_finished(finished)

    pending = [i for i in range(1, ITERATIONS + 1) if _iteration_key(i) not in finished]
    skipped = ITERATIONS - len(pending)

    print(
        f"Prompt={PROMPT_FILE.relative_to(PROJECT_DIR).as_posix()}; "
        f"iterations={ITERATIONS} sequential "
        f"({skipped} already finished, {len(pending)} pending).",
        flush=True,
    )
    print(
        f"Model={MODEL}; concurrency=1; commit+push after each success.",
        flush=True,
    )
    print("Iterations to run:", flush=True)
    for iteration in pending:
        print(f"  - {_iteration_key(iteration)}", flush=True)
    print(flush=True)

    if not pending:
        print(
            "Nothing left to run. Pass --force to rerun all, "
            "or delete .run_prompts_state.json."
        )
        return

    results: list[dict] = [
        {"file": name, "status": "finished"} for name in sorted(finished)
    ]

    async with await AsyncClient.launch_bridge(
        workspace=str(PROJECT_DIR),
        client_timeout=BRIDGE_TIMEOUT_SECONDS,
        max_retries=2,
    ) as client:
        # Strictly sequential: finish iteration N (including git push)
        # before starting iteration N+1.
        for iteration in pending:
            result = await run_iteration(iteration, client, finished)
            results.append(result)
            if result["status"] != "finished":
                print(
                    f"\nStopping after failed iteration {_iteration_key(iteration)}. "
                    "Re-run to resume remaining iterations.",
                    file=sys.stderr,
                    flush=True,
                )
                break

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
        print(f"\n{len(errors)} iteration(s) did not finish successfully.")
        print("Re-run the same command to retry only the failed/remaining ones.")
        sys.exit(1)

    if len([r for r in results if r["status"] == "finished"]) < ITERATIONS:
        print("\nRun incomplete; remaining iterations were not started.")
        sys.exit(1)

    print(f"\nAll {ITERATIONS} dashboard iterations completed successfully.")
    if STATE_FILE.exists():
        STATE_FILE.unlink()


if __name__ == "__main__":
    asyncio.run(main())
