"""Run prompts/billing-and-sections/**/*.md with Cursor agents.

Processing rules:
- One folder at a time; never start the next folder until every prompt in
  the current folder has finished all iterations.
- Within a folder iteration, at most MAX_CONCURRENCY prompts run at once.
- Each folder is iterated ITERATIONS times so every prompt runs that many times.
- After each successful prompt run, commit and push to GitHub.
- Completed prompt iterations recorded in
  .run_billing_and_sections_prompts_state.json are skipped on resume; pass
  --force to clear state and re-run everything.
- Model is set to Claude Fable 5 Thinking High (claude-fable-5-thinking-high).
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
PROMPTS_ROOT = PROJECT_DIR / "prompts" / "billing-and-sections"
STATE_FILE = PROJECT_DIR / ".run_billing_and_sections_prompts_state.json"
ITERATIONS = 1
MAX_CONCURRENCY = 10
MAX_ATTEMPTS = 3
GIT_LOCK_RETRIES = 10
GIT_LOCK_BASE_DELAY_SECONDS = 0.35
BRIDGE_TIMEOUT_SECONDS = None
MODEL = "claude-fable-5-thinking-high"
GIT_EXCLUDES = (".run_billing_and_sections_prompts_state.json", "screens")
INDEX_LOCK_PATH = PROJECT_DIR / ".git" / "index.lock"


def _prompt_rel(path: Path) -> str:
    """Repo-relative posix path for a prompt file."""
    return path.relative_to(PROJECT_DIR).as_posix()


def _iteration_key(prompt_rel: str, iteration: int) -> str:
    """Stable id for state tracking of one prompt iteration."""
    return f"{prompt_rel}#{iteration}/{ITERATIONS}"


def _discover_folders() -> list[Path]:
    """Return prompt folders under billing-and-sections, sorted, one folder at a time."""
    if not PROMPTS_ROOT.is_dir():
        return []
    folders: list[Path] = []
    for child in sorted(PROMPTS_ROOT.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir():
            continue
        prompts = _folder_prompts(child)
        if prompts:
            folders.append(child)
    return folders


def _folder_prompts(folder: Path) -> list[Path]:
    """Markdown prompt files directly inside a folder (non-recursive)."""
    return sorted(
        (
            p
            for p in folder.iterdir()
            if p.is_file() and p.suffix.lower() == ".md" and not p.name.startswith("_")
        ),
        key=lambda p: p.name.lower(),
    )


def _all_jobs() -> list[tuple[Path, Path, int]]:
    """(folder, prompt_path, iteration) for every planned run, folder-major order."""
    jobs: list[tuple[Path, Path, int]] = []
    for folder in _discover_folders():
        prompts = _folder_prompts(folder)
        for iteration in range(1, ITERATIONS + 1):
            for prompt in prompts:
                jobs.append((folder, prompt, iteration))
    return jobs


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


def _mark_finished(finished: set[str], key: str) -> None:
    """Record one completed iteration and persist state immediately."""
    finished.add(key)
    _save_finished(finished)


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
    """Stage, commit, and push workspace changes after a successful prompt run."""
    last_error = ""
    for attempt in range(1, GIT_LOCK_RETRIES + 1):
        try:
            _run_git(["add", "-A"])
            for exclude in GIT_EXCLUDES:
                _run_git(["reset", "-q", "HEAD", "--", exclude], check=False)
            # Discard accidental recreation of the removed screens/ inventory.
            _run_git(["checkout", "--", "screens"], check=False)
            _run_git(["clean", "-fd", "--", "screens"], check=False)

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


async def run_prompt(
    prompt_path: Path,
    iteration: int,
    client: AsyncClient,
    finished: set[str],
    git_lock: asyncio.Lock,
    sem: asyncio.Semaphore,
) -> dict:
    """Run one billing-and-sections prompt iteration, then commit and push."""
    prompt_rel = _prompt_rel(prompt_path)
    key = _iteration_key(prompt_rel, iteration)

    if key in finished:
        return {"file": key, "status": "finished", "skipped": True}

    async with sem:
        # Re-check after waiting for a slot in case another task finished it.
        if key in finished:
            return {"file": key, "status": "finished", "skipped": True}
        print(f"[START] {key}", flush=True)
        last_error = ""
        for attempt in range(1, MAX_ATTEMPTS + 1):
            try:
                prompt_text = prompt_path.read_text(encoding="utf-8")
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

                async with git_lock:
                    git_info = await asyncio.to_thread(_commit_and_push, key)
                _mark_finished(finished, key)
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
            "Run prompts/billing-and-sections folder-by-folder with Cursor "
            f"model={MODEL}. "
            f"Max {MAX_CONCURRENCY} concurrent prompts per folder iteration; "
            f"each prompt runs {ITERATIONS} times; commit+push after each success. "
            "Resume skips completed iterations in "
            ".run_billing_and_sections_prompts_state.json."
        )
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help=(
            "Ignore .run_billing_and_sections_prompts_state.json and re-run "
            "all prompt iterations."
        ),
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print the planned folder/prompt/iteration keys and exit.",
    )
    parser.add_argument(
        "--folder",
        action="append",
        default=[],
        help=(
            "Only run the named folder under prompts/billing-and-sections "
            "(repeatable). Example: --folder billing --folder pharmacy"
        ),
    )
    return parser.parse_args(argv)


async def main(argv: list[str] | None = None):
    args = _parse_args(argv)

    if not PROMPTS_ROOT.is_dir():
        sys.exit(f"Prompts root not found: {PROMPTS_ROOT}")

    folders = _discover_folders()
    if args.folder:
        wanted = {name.strip().lower() for name in args.folder if name.strip()}
        folders = [f for f in folders if f.name.lower() in wanted]
        missing = wanted - {f.name.lower() for f in folders}
        if missing:
            sys.exit(
                "Unknown --folder value(s): "
                + ", ".join(sorted(missing))
                + f". Available: {', '.join(f.name for f in _discover_folders())}"
            )

    if not folders:
        sys.exit(f"No prompt folders found under {PROMPTS_ROOT}")

    all_keys: list[str] = []
    for folder in folders:
        for iteration in range(1, ITERATIONS + 1):
            for prompt in _folder_prompts(folder):
                all_keys.append(_iteration_key(_prompt_rel(prompt), iteration))

    if args.list:
        print(
            f"Plan: {len(folders)} folder(s), {ITERATIONS} iterations each, "
            f"max concurrency {MAX_CONCURRENCY}, model={MODEL}"
        )
        for folder in folders:
            prompts = _folder_prompts(folder)
            print(
                f"\n[{folder.name}] {len(prompts)} prompt(s) "
                f"x {ITERATIONS} = {len(prompts) * ITERATIONS} runs"
            )
            for iteration in range(1, ITERATIONS + 1):
                print(f"  iteration {iteration}/{ITERATIONS}:")
                for prompt in prompts:
                    print(f"    {_iteration_key(_prompt_rel(prompt), iteration)}")
        print(f"\nTotal planned runs: {len(all_keys)}")
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
            print(
                "Cleared .run_billing_and_sections_prompts_state.json (--force).\n",
                flush=True,
            )
    else:
        # Keep the full state set so --folder / stop-restart never wipes
        # finished iterations outside the current plan.
        finished = _load_finished()
        _save_finished(finished)

    pending_keys = [k for k in all_keys if k not in finished]
    skipped = len(all_keys) - len(pending_keys)

    print(
        f"Root={PROMPTS_ROOT.relative_to(PROJECT_DIR).as_posix()}; "
        f"folders={len(folders)}; iterations={ITERATIONS}; "
        f"concurrency={MAX_CONCURRENCY}; model={MODEL}",
        flush=True,
    )
    print(
        f"Total runs={len(all_keys)} "
        f"({skipped} already finished, {len(pending_keys)} pending).",
        flush=True,
    )
    print(
        "Commit+push after each successful prompt; one folder at a time.\n",
        flush=True,
    )

    if not pending_keys:
        print(
            "Nothing left to run. Pass --force to rerun all, "
            "or delete .run_billing_and_sections_prompts_state.json."
        )
        return

    results: list[dict] = [
        {"file": name, "status": "finished", "skipped": True}
        for name in sorted(finished & known)
    ]
    git_lock = asyncio.Lock()
    sem = asyncio.Semaphore(MAX_CONCURRENCY)
    failed = False

    try:
        async with await AsyncClient.launch_bridge(
            workspace=str(PROJECT_DIR),
            client_timeout=BRIDGE_TIMEOUT_SECONDS,
            max_retries=2,
        ) as client:
            for folder in folders:
                prompts = _folder_prompts(folder)
                folder_keys = [
                    _iteration_key(_prompt_rel(p), i)
                    for i in range(1, ITERATIONS + 1)
                    for p in prompts
                ]
                folder_pending = [k for k in folder_keys if k not in finished]
                if not folder_pending:
                    print(
                        f"[FOLDER] {folder.name}: all "
                        f"{len(folder_keys)} runs already finished; skipping.",
                        flush=True,
                    )
                    continue

                print(
                    f"[FOLDER] {folder.name}: {len(prompts)} prompt(s), "
                    f"{len(folder_pending)}/{len(folder_keys)} runs pending",
                    flush=True,
                )

                for iteration in range(1, ITERATIONS + 1):
                    batch = [
                        p
                        for p in prompts
                        if _iteration_key(_prompt_rel(p), iteration)
                        not in finished
                    ]
                    if not batch:
                        print(
                            f"[FOLDER] {folder.name} iteration "
                            f"{iteration}/{ITERATIONS}: already finished",
                            flush=True,
                        )
                        continue

                    print(
                        f"[FOLDER] {folder.name} iteration "
                        f"{iteration}/{ITERATIONS}: starting {len(batch)} "
                        f"prompt(s) (max {MAX_CONCURRENCY} concurrent)",
                        flush=True,
                    )
                    batch_results = await asyncio.gather(
                        *[
                            run_prompt(
                                prompt_path=prompt,
                                iteration=iteration,
                                client=client,
                                finished=finished,
                                git_lock=git_lock,
                                sem=sem,
                            )
                            for prompt in batch
                        ]
                    )
                    results.extend(batch_results)

                    errors = [
                        r for r in batch_results if r["status"] != "finished"
                    ]
                    if errors:
                        failed = True
                        print(
                            f"\nStopping: {len(errors)} prompt(s) failed in "
                            f"{folder.name} iteration {iteration}/{ITERATIONS}. "
                            "Re-run to resume remaining work. "
                            "Not advancing to later iterations/folders.",
                            file=sys.stderr,
                            flush=True,
                        )
                        break

                if failed:
                    break

                still_open = [k for k in folder_keys if k not in finished]
                if still_open:
                    failed = True
                    print(
                        f"\nStopping: folder {folder.name} still has "
                        f"{len(still_open)} unfinished run(s); "
                        "not proceeding to the next folder.",
                        file=sys.stderr,
                        flush=True,
                    )
                    break

                print(
                    f"[FOLDER] {folder.name}: completed all "
                    f"{len(folder_keys)} runs.\n",
                    flush=True,
                )
    except (asyncio.CancelledError, KeyboardInterrupt):
        _save_finished(finished)
        print(
            f"\nStopped. Progress saved ({len(finished & known)}/"
            f"{len(all_keys)} in-scope iterations done). "
            "Re-run to continue without repeating finished work.",
            file=sys.stderr,
            flush=True,
        )
        sys.exit(130)

    results.sort(key=lambda r: r["file"])
    this_run = [r for r in results if not r.get("skipped")]
    errors = [r for r in this_run if r["status"] != "finished"]
    finished_count = sum(1 for k in all_keys if k in finished)

    print("\n--- Summary ---")
    if this_run:
        ok = sum(1 for r in this_run if r["status"] == "finished")
        bad = sum(1 for r in this_run if r["status"] != "finished")
        committed = sum(1 for r in this_run if r.get("committed"))
        print(
            f"  this run: {ok} ok - {bad} failed - "
            f"{committed} committed - {skipped} skipped from before",
            flush=True,
        )
        for r in this_run:
            if r["status"] != "finished":
                print(
                    f"  fail   {r['file']}: {r.get('message', '')}",
                    flush=True,
                )
            else:
                extra = ""
                if r.get("committed"):
                    extra = " (committed+pushed)"
                elif r.get("committed") is False:
                    extra = " (no git changes)"
                print(f"  {r['file']}: {r['status']}{extra}", flush=True)
    else:
        print(
            f"  {finished_count}/{len(all_keys)} complete - "
            "nothing new this session",
            flush=True,
        )

    if errors or failed or finished_count < len(all_keys):
        print(
            f"\n{finished_count}/{len(all_keys)} complete. "
            "Re-run to finish the rest (already-done iterations are skipped)."
        )
        sys.exit(1)

    print(
        f"\nAll {len(all_keys)} billing-and-sections prompt runs completed "
        "successfully."
    )
    # Keep .run_billing_and_sections_prompts_state.json so a later start
    # skips completed runs. Use --force (or delete the state file) to re-run.


if __name__ == "__main__":
    asyncio.run(main())
