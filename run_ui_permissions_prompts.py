"""Run prompts/ui-permissions/**/*.md with Cursor agents.

Processing rules:
- Up to MAX_CONCURRENCY prompts run at once, drawn from any folder
  (folder boundaries do not throttle concurrency).
- Each prompt runs ITERATIONS times sequentially in its worker slot.
- After a prompt finishes all ITERATIONS successfully, commit and push
  its results to GitHub.
- Completed prompt iterations recorded in
  .run_ui_permissions_prompts_state.json are skipped on resume; pass
  --force to clear state and re-run everything.
- Model is always "auto".
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
PROMPTS_ROOT = PROJECT_DIR / "prompts" / "ui-permissions"
STATE_FILE = PROJECT_DIR / ".run_ui_permissions_prompts_state.json"
ITERATIONS = 2
MAX_CONCURRENCY = 10
MAX_ATTEMPTS = 3
GIT_LOCK_RETRIES = 10
GIT_LOCK_BASE_DELAY_SECONDS = 0.35
BRIDGE_TIMEOUT_SECONDS = None
MODEL = "auto"
GIT_EXCLUDES = (".run_ui_permissions_prompts_state.json", "screens")
INDEX_LOCK_PATH = PROJECT_DIR / ".git" / "index.lock"


def _prompt_rel(path: Path) -> str:
    """Repo-relative posix path for a prompt file."""
    return path.relative_to(PROJECT_DIR).as_posix()


def _iteration_key(prompt_rel: str, iteration: int) -> str:
    """Stable id for state tracking of one prompt iteration."""
    return f"{prompt_rel}#{iteration}/{ITERATIONS}"


def _prompt_complete_key(prompt_rel: str) -> str:
    """Label used when committing after all iterations finish."""
    return f"{prompt_rel}#{ITERATIONS}/{ITERATIONS}"


def _discover_folders() -> list[Path]:
    """Return prompt folders under ui-permissions, sorted."""
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


def _all_prompts(folders: list[Path]) -> list[Path]:
    """All prompt files across the selected folders, folder then name order."""
    prompts: list[Path] = []
    for folder in folders:
        prompts.extend(_folder_prompts(folder))
    return prompts


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


def _log(message: str, *, err: bool = False) -> None:
    """Print one flushable progress line."""
    print(message, file=sys.stderr if err else sys.stdout, flush=True)


def _display_name(prompt_path: Path, iteration: int) -> str:
    """Human label like 'clinical/all.md (2/2)'."""
    try:
        rel = prompt_path.relative_to(PROMPTS_ROOT).as_posix()
    except ValueError:
        rel = prompt_path.name
    return f"{rel} ({iteration}/{ITERATIONS})"


def _display_key(iteration_key: str) -> str:
    """Turn 'prompts/ui-permissions/clinical/all.md#2/2' into 'clinical/all.md (2/2)'."""
    path_part, _, iter_part = iteration_key.partition("#")
    prefix = f"prompts/{PROMPTS_ROOT.name}/"
    short = path_part[len(prefix) :] if path_part.startswith(prefix) else Path(path_part).name
    if "/" in iter_part:
        return f"{short} ({iter_part})"
    return short or iteration_key


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
        _log("Git: cleared stale index.lock")
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
                _log(
                    f"Git: index.lock busy - retry {attempt}/{GIT_LOCK_RETRIES} "
                    f"in {delay:.1f}s"
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


def _commit_and_push(commit_key: str) -> dict:
    """Stage, commit, and push workspace changes after a prompt completes all iterations."""
    label = _display_key(commit_key)
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
                return {"committed": False, "pushed": False}

            message = f"Apply prompt: {commit_key}"
            try:
                _run_git(["commit", "-m", message])
            except subprocess.CalledProcessError as err:
                detail = _git_detail(err)
                if "nothing to commit" in detail.lower():
                    return {"committed": False, "pushed": False}
                if _is_index_lock_error(detail) and attempt < GIT_LOCK_RETRIES:
                    last_error = detail
                    _clear_stale_index_lock()
                    delay = GIT_LOCK_BASE_DELAY_SECONDS * (2 ** (attempt - 1))
                    _log(
                        f"Git: commit lock busy for {label} - "
                        f"retry {attempt}/{GIT_LOCK_RETRIES} in {delay:.1f}s"
                    )
                    time.sleep(delay)
                    continue
                raise RuntimeError(f"git commit failed: {detail}") from err

            try:
                _run_git(["push", "-u", "origin", "HEAD"])
            except subprocess.CalledProcessError as err:
                detail = _git_detail(err)
                raise RuntimeError(f"git push failed: {detail}") from err

            return {"committed": True, "pushed": True}
        except RuntimeError as err:
            detail = str(err)
            if _is_index_lock_error(detail) and attempt < GIT_LOCK_RETRIES:
                last_error = detail
                _clear_stale_index_lock()
                delay = GIT_LOCK_BASE_DELAY_SECONDS * (2 ** (attempt - 1))
                _log(
                    f"Git: lock busy for {label} - "
                    f"retry {attempt}/{GIT_LOCK_RETRIES} in {delay:.1f}s"
                )
                time.sleep(delay)
                continue
            raise

    raise RuntimeError(
        f"git commit failed after {GIT_LOCK_RETRIES} lock retries: {last_error}"
    )


async def _run_one_iteration(
    *,
    prompt_path: Path,
    prompt_rel: str,
    iteration: int,
    client: AsyncClient,
) -> dict:
    """Run a single prompt iteration (agent only; no git)."""
    key = _iteration_key(prompt_rel, iteration)
    label = _display_name(prompt_path, iteration)
    _log(f"  start  {label}")
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
                result = await run.wait()
            status = result.status
            if status != "finished":
                last_error = f"agent status={status}"
                result_id = getattr(result, "id", None)
                if result_id:
                    last_error = f"{last_error} run={result_id}"
                if attempt < MAX_ATTEMPTS:
                    wait_s = 2 ** (attempt - 1)
                    _log(
                        f"  retry  {label} - attempt {attempt}/{MAX_ATTEMPTS} "
                        f"({last_error}), wait {wait_s}s",
                        err=True,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                _log(f"  fail   {label} - {last_error}", err=True)
                return {"file": key, "status": "error", "message": last_error}

            _log(f"  done   {label}")
            return {"file": key, "status": "finished"}
        except CursorAgentError as err:
            last_error = _error_text(err)
            if attempt < MAX_ATTEMPTS and _is_retryable(err):
                wait_s = 2 ** (attempt - 1)
                _log(
                    f"  retry  {label} - attempt {attempt}/{MAX_ATTEMPTS} "
                    f"({last_error}), wait {wait_s}s",
                    err=True,
                )
                await asyncio.sleep(wait_s)
                continue
            _log(f"  fail   {label} - {last_error}", err=True)
            return {"file": key, "status": "error", "message": last_error}
        except Exception as err:
            last_error = _error_text(err)
            if attempt < MAX_ATTEMPTS and _is_retryable(err):
                wait_s = 2 ** (attempt - 1)
                _log(
                    f"  retry  {label} - attempt {attempt}/{MAX_ATTEMPTS} "
                    f"({last_error}), wait {wait_s}s",
                    err=True,
                )
                await asyncio.sleep(wait_s)
                continue
            _log(f"  fail   {label} - {last_error}", err=True)
            return {"file": key, "status": "error", "message": last_error}

    return {"file": key, "status": "error", "message": last_error}


async def run_prompt(
    prompt_path: Path,
    client: AsyncClient,
    finished: set[str],
    git_lock: asyncio.Lock,
    sem: asyncio.Semaphore,
) -> dict:
    """Run all remaining iterations for one prompt, then commit and push once."""
    prompt_rel = _prompt_rel(prompt_path)
    complete_key = _prompt_complete_key(prompt_rel)
    try:
        short = prompt_path.relative_to(PROMPTS_ROOT).as_posix()
    except ValueError:
        short = prompt_path.name

    pending_iterations = [
        iteration
        for iteration in range(1, ITERATIONS + 1)
        if _iteration_key(prompt_rel, iteration) not in finished
    ]

    if not pending_iterations:
        return {
            "file": complete_key,
            "status": "finished",
            "committed": False,
            "pushed": False,
            "skipped": True,
        }

    async with sem:
        # Refresh after waiting — another resume path may have recorded work.
        pending_iterations = [
            iteration
            for iteration in range(1, ITERATIONS + 1)
            if _iteration_key(prompt_rel, iteration) not in finished
        ]
        if not pending_iterations:
            return {
                "file": complete_key,
                "status": "finished",
                "committed": False,
                "pushed": False,
                "skipped": True,
            }

        _log(
            f"  prompt {short}: running iteration(s) "
            f"{pending_iterations} of {ITERATIONS}"
        )
        iteration_results: list[dict] = []
        for iteration in pending_iterations:
            key = _iteration_key(prompt_rel, iteration)
            if key in finished:
                iteration_results.append(
                    {"file": key, "status": "finished", "skipped": True}
                )
                continue

            result = await _run_one_iteration(
                prompt_path=prompt_path,
                prompt_rel=prompt_rel,
                iteration=iteration,
                client=client,
            )
            iteration_results.append(result)
            if result["status"] != "finished":
                return {
                    "file": complete_key,
                    "status": "error",
                    "message": result.get("message", "iteration failed"),
                    "failed_iteration": result["file"],
                }

            _mark_finished(finished, result["file"])

        still_open = [
            _iteration_key(prompt_rel, iteration)
            for iteration in range(1, ITERATIONS + 1)
            if _iteration_key(prompt_rel, iteration) not in finished
        ]
        if still_open:
            return {
                "file": complete_key,
                "status": "error",
                "message": f"unfinished iterations: {', '.join(still_open)}",
            }

        async with git_lock:
            git_info = await asyncio.to_thread(_commit_and_push, complete_key)

        if git_info.get("committed"):
            outcome = "committed & pushed"
        else:
            outcome = "no code changes"
        _log(f"  prompt {short}: all {ITERATIONS} iterations done - {outcome}")
        return {
            "file": complete_key,
            "status": "finished",
            "iterations": [r["file"] for r in iteration_results],
            **git_info,
        }


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run prompts/ui-permissions with Cursor model=auto. "
            f"Always up to {MAX_CONCURRENCY} prompts concurrent across folders; "
            f"each prompt runs {ITERATIONS} times then commit+push. "
            "Resume skips completed iterations in "
            ".run_ui_permissions_prompts_state.json."
        )
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help=(
            "Ignore .run_ui_permissions_prompts_state.json and re-run "
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
            "Only run the named folder under prompts/ui-permissions "
            "(repeatable). Example: --folder icu --folder opd"
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

    prompts = _all_prompts(folders)
    all_keys: list[str] = [
        _iteration_key(_prompt_rel(prompt), iteration)
        for prompt in prompts
        for iteration in range(1, ITERATIONS + 1)
    ]

    if args.list:
        _log(
            f"Plan: {len(folders)} folders - {len(prompts)} prompts - "
            f"{ITERATIONS} iterations each - "
            f"up to {MAX_CONCURRENCY} concurrent (any folder) - model={MODEL}"
        )
        for folder in folders:
            folder_prompts = _folder_prompts(folder)
            total = len(folder_prompts) * ITERATIONS
            _log(f"\n{folder.name}: {len(folder_prompts)} prompts x {ITERATIONS} = {total}")
            for prompt in folder_prompts:
                _log(f"  {_prompt_rel(prompt)}")
        _log(
            f"\nTotal: {len(all_keys)} runs "
            f"({len(prompts)} prompts, commit+push after each completes "
            f"{ITERATIONS}/{ITERATIONS})"
        )
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
            _log("Cleared saved progress (--force).\n")
    else:
        # Keep the full state set so --folder / stop-restart never wipes
        # finished iterations outside the current plan.
        finished = _load_finished()
        _save_finished(finished)

    pending_prompts = [
        prompt
        for prompt in prompts
        if any(
            _iteration_key(_prompt_rel(prompt), iteration) not in finished
            for iteration in range(1, ITERATIONS + 1)
        )
    ]
    pending_keys = [k for k in all_keys if k not in finished]
    skipped = len(all_keys) - len(pending_keys)

    _log(
        f"UI permissions - {len(folders)} folders - {len(prompts)} prompts - "
        f"{ITERATIONS} passes - up to {MAX_CONCURRENCY} concurrent (any folder)"
    )
    _log(
        f"{len(all_keys)} runs total - {skipped} already done - "
        f"{len(pending_keys)} left across {len(pending_prompts)} prompt(s)"
    )
    _log(
        f"Commit+push after each prompt completes all {ITERATIONS} iterations.\n"
    )

    if not pending_prompts:
        _log("Nothing left to run. Use --force to start over.")
        return

    results: list[dict] = [
        {
            "file": _prompt_complete_key(_prompt_rel(prompt)),
            "status": "finished",
            "skipped": True,
        }
        for prompt in prompts
        if all(
            _iteration_key(_prompt_rel(prompt), iteration) in finished
            for iteration in range(1, ITERATIONS + 1)
        )
    ]
    git_lock = asyncio.Lock()
    sem = asyncio.Semaphore(MAX_CONCURRENCY)

    try:
        async with await AsyncClient.launch_bridge(
            workspace=str(PROJECT_DIR),
            client_timeout=BRIDGE_TIMEOUT_SECONDS,
            max_retries=2,
        ) as client:
            _log(
                f"Pool: starting {len(pending_prompts)} prompt(s) "
                f"(max {MAX_CONCURRENCY} concurrent, any folder)"
            )
            batch_results = await asyncio.gather(
                *[
                    run_prompt(
                        prompt_path=prompt,
                        client=client,
                        finished=finished,
                        git_lock=git_lock,
                        sem=sem,
                    )
                    for prompt in pending_prompts
                ]
            )
            results.extend(batch_results)
    except (asyncio.CancelledError, KeyboardInterrupt):
        _save_finished(finished)
        _log(
            f"\nStopped. Progress saved ({len(finished & known)}/"
            f"{len(all_keys)} in-scope iterations done). "
            "Re-run to continue without repeating finished work.",
            err=True,
        )
        sys.exit(130)

    results.sort(key=lambda r: r["file"])
    this_run = [r for r in results if not r.get("skipped")]
    errors = [r for r in results if r["status"] != "finished"]
    finished_count = sum(1 for k in all_keys if k in finished)

    _log("\nSummary")
    if this_run:
        ok = sum(1 for r in this_run if r["status"] == "finished")
        bad = sum(1 for r in this_run if r["status"] != "finished")
        committed = sum(1 for r in this_run if r.get("committed"))
        _log(
            f"  this run: {ok} ok - {bad} failed - "
            f"{committed} committed - {skipped} skipped from before"
        )
        for r in this_run:
            if r["status"] != "finished":
                _log(f"  fail   {_display_key(r['file'])} - {r.get('message', '')}")
    else:
        _log(f"  {finished_count}/{len(all_keys)} complete - nothing new this session")

    if errors or finished_count < len(all_keys):
        _log(
            f"\n{finished_count}/{len(all_keys)} complete. "
            "Re-run to finish the rest (already-done iterations are skipped)."
        )
        sys.exit(1)

    _log(f"\nAll {len(all_keys)} runs complete.")
    # Keep .run_ui_permissions_prompts_state.json so a later start skips
    # completed runs. Use --force (or delete the state file) to re-run
    # everything.


if __name__ == "__main__":
    asyncio.run(main())
