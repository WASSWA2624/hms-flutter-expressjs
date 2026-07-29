"""Run prompts/billing-and-sections/**/*.md with Cursor agents.

Processing rules:
- One folder at a time; never start the next until every prompt in the
  current folder has finished.
- Within a folder, at most MAX_CONCURRENCY prompts run at once.
- Each prompt runs once.
- After each successful prompt, commit and push to GitHub.
- Completed prompt files in .run_billing_and_sections_prompts_state.json
  are skipped on resume; pass --force to clear state and re-run everything.
- Model is Composer 2.5 (composer-2.5).
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
MAX_CONCURRENCY = 10
MAX_ATTEMPTS = 3
GIT_LOCK_RETRIES = 10
GIT_LOCK_BASE_DELAY_SECONDS = 0.35
BRIDGE_TIMEOUT_SECONDS = None
MODEL = "composer-2.5"
GIT_EXCLUDES = (".run_billing_and_sections_prompts_state.json", "screens")
INDEX_LOCK_PATH = PROJECT_DIR / ".git" / "index.lock"


def _prompt_rel(path: Path) -> str:
    """Repo-relative posix path for a prompt file."""
    return path.relative_to(PROJECT_DIR).as_posix()


def _short_name(prompt_path: Path) -> str:
    """Folder-relative label like '_screens/home.md'."""
    try:
        return prompt_path.relative_to(PROMPTS_ROOT).as_posix()
    except ValueError:
        return prompt_path.name


def _is_finished(prompt_rel: str, finished: set[str]) -> bool:
    """True if this prompt file is recorded done (bare path or legacy #N/M)."""
    if prompt_rel in finished:
        return True
    prefix = f"{prompt_rel}#"
    return any(entry.startswith(prefix) for entry in finished)


def _discover_folders() -> list[Path]:
    """Return prompt folders under billing-and-sections, sorted."""
    if not PROMPTS_ROOT.is_dir():
        return []
    folders: list[Path] = []
    for child in sorted(PROMPTS_ROOT.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir():
            continue
        if _folder_prompts(child):
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


def _mark_finished(finished: set[str], prompt_rel: str) -> None:
    """Record one completed prompt and persist state immediately."""
    finished.add(prompt_rel)
    # Drop legacy iteration keys for the same file.
    stale = [e for e in finished if e.startswith(f"{prompt_rel}#")]
    for entry in stale:
        finished.discard(entry)
    _save_finished(finished)


def _log(message: str, *, err: bool = False) -> None:
    print(message, file=sys.stderr if err else sys.stdout, flush=True)


def _error_text(err: BaseException) -> str:
    if isinstance(err, CursorAgentError):
        msg = err.message or str(err) or type(err).__name__
        return msg
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
        _log("  git    cleared stale lock")
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
                _log(f"  git    lock busy, retry in {delay:.1f}s")
                time.sleep(delay)
                continue
            raise
    assert last_err is not None
    raise last_err


def _git_has_staged_changes() -> bool:
    """True when the index has staged changes ready to commit."""
    staged = _run_git(["diff", "--cached", "--quiet"], check=False)
    return staged.returncode != 0


def _commit_and_push(prompt_rel: str) -> dict:
    """Stage, commit, and push workspace changes after a successful prompt run."""
    short = prompt_rel
    prefix = f"prompts/{PROMPTS_ROOT.name}/"
    if short.startswith(prefix):
        short = short[len(prefix) :]

    last_error = ""
    for attempt in range(1, GIT_LOCK_RETRIES + 1):
        try:
            _run_git(["add", "-A"])
            for exclude in GIT_EXCLUDES:
                _run_git(["reset", "-q", "HEAD", "--", exclude], check=False)
            _run_git(["checkout", "--", "screens"], check=False)
            _run_git(["clean", "-fd", "--", "screens"], check=False)

            if not _git_has_staged_changes():
                return {"committed": False, "pushed": False}

            message = f"Apply prompt: {prompt_rel}"
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
                    _log(f"  git    commit lock busy, retry in {delay:.1f}s")
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
                _log(f"  git    lock busy, retry in {delay:.1f}s")
                time.sleep(delay)
                continue
            raise

    raise RuntimeError(
        f"git commit failed after {GIT_LOCK_RETRIES} lock retries: {last_error}"
    )


async def run_prompt(
    prompt_path: Path,
    client: AsyncClient,
    finished: set[str],
    git_lock: asyncio.Lock,
    sem: asyncio.Semaphore,
) -> dict:
    """Run one prompt once, then commit and push."""
    prompt_rel = _prompt_rel(prompt_path)
    short = _short_name(prompt_path)

    if _is_finished(prompt_rel, finished):
        return {"file": prompt_rel, "status": "finished", "skipped": True}

    async with sem:
        if _is_finished(prompt_rel, finished):
            return {"file": prompt_rel, "status": "finished", "skipped": True}

        _log(f"  start  {short}")
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
                    if attempt < MAX_ATTEMPTS:
                        wait_s = 2 ** (attempt - 1)
                        _log(
                            f"  retry  {short} ({attempt}/{MAX_ATTEMPTS})",
                            err=True,
                        )
                        await asyncio.sleep(wait_s)
                        continue
                    _log(f"  fail   {short} - {last_error}", err=True)
                    return {
                        "file": prompt_rel,
                        "status": "error",
                        "message": last_error,
                    }

                async with git_lock:
                    git_info = await asyncio.to_thread(_commit_and_push, prompt_rel)
                _mark_finished(finished, prompt_rel)
                if git_info.get("committed"):
                    _log(f"  done   {short} - committed")
                else:
                    _log(f"  done   {short} - no changes")
                return {
                    "file": prompt_rel,
                    "status": "finished",
                    **git_info,
                }
            except CursorAgentError as err:
                last_error = _error_text(err)
                if attempt < MAX_ATTEMPTS and _is_retryable(err):
                    wait_s = 2 ** (attempt - 1)
                    _log(
                        f"  retry  {short} ({attempt}/{MAX_ATTEMPTS})",
                        err=True,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                _log(f"  fail   {short} - {last_error}", err=True)
                return {"file": prompt_rel, "status": "error", "message": last_error}
            except Exception as err:
                last_error = _error_text(err)
                if attempt < MAX_ATTEMPTS and _is_retryable(err):
                    wait_s = 2 ** (attempt - 1)
                    _log(
                        f"  retry  {short} ({attempt}/{MAX_ATTEMPTS})",
                        err=True,
                    )
                    await asyncio.sleep(wait_s)
                    continue
                _log(f"  fail   {short} - {last_error}", err=True)
                return {"file": prompt_rel, "status": "error", "message": last_error}

        return {"file": prompt_rel, "status": "error", "message": last_error}


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run prompts/billing-and-sections folder-by-folder with Cursor "
            f"model={MODEL}. Each prompt once; commit+push after success. "
            "Resume skips finished files in "
            ".run_billing_and_sections_prompts_state.json."
        )
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Clear saved progress and re-run all prompts.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Print the planned folders/prompts and exit.",
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

    prompts_by_folder = {folder: _folder_prompts(folder) for folder in folders}
    all_prompts = [p for folder in folders for p in prompts_by_folder[folder]]
    all_rels = [_prompt_rel(p) for p in all_prompts]

    if args.list:
        _log(f"{len(folders)} folders - {len(all_prompts)} prompts - {MODEL}")
        for folder in folders:
            prompts = prompts_by_folder[folder]
            _log(f"\n{folder.name} ({len(prompts)})")
            for prompt in prompts:
                _log(f"  {_short_name(prompt)}")
        return

    api_key = os.environ.get("CURSOR_API_KEY", "").strip()
    if not api_key or api_key == "cursor_...":
        sys.exit(
            "Error: set CURSOR_API_KEY to your actual key, not the "
            "'cursor_...' example value."
        )

    if args.force:
        finished: set[str] = set()
        if STATE_FILE.exists():
            STATE_FILE.unlink()
            _log("Cleared saved progress (--force).\n")
    else:
        finished = _load_finished()
        _save_finished(finished)

    pending_prompts = [
        p for p in all_prompts if not _is_finished(_prompt_rel(p), finished)
    ]
    skipped = len(all_prompts) - len(pending_prompts)

    _log(
        f"Billing & sections - {len(folders)} folders - "
        f"{len(all_prompts)} prompts - {MODEL}"
    )
    _log(f"{skipped} done - {len(pending_prompts)} left - up to {MAX_CONCURRENCY} at once\n")

    if not pending_prompts:
        _log("Nothing left to run. Use --force to start over.")
        return

    results: list[dict] = [
        {"file": rel, "status": "finished", "skipped": True}
        for rel in all_rels
        if _is_finished(rel, finished)
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
                prompts = prompts_by_folder[folder]
                batch = [
                    p
                    for p in prompts
                    if not _is_finished(_prompt_rel(p), finished)
                ]
                if not batch:
                    continue

                _log(f"{folder.name} ({len(batch)} left)")
                batch_results = await asyncio.gather(
                    *[
                        run_prompt(
                            prompt_path=prompt,
                            client=client,
                            finished=finished,
                            git_lock=git_lock,
                            sem=sem,
                        )
                        for prompt in batch
                    ]
                )
                results.extend(batch_results)

                errors = [r for r in batch_results if r["status"] != "finished"]
                if errors:
                    failed = True
                    _log(
                        f"\nStopped in {folder.name} "
                        f"({len(errors)} failed). Re-run to continue.",
                        err=True,
                    )
                    break

                still_open = [
                    p
                    for p in prompts
                    if not _is_finished(_prompt_rel(p), finished)
                ]
                if still_open:
                    failed = True
                    _log(
                        f"\nStopped: {folder.name} still has "
                        f"{len(still_open)} unfinished. Re-run to continue.",
                        err=True,
                    )
                    break

                _log("")
    except (asyncio.CancelledError, KeyboardInterrupt):
        _save_finished(finished)
        done = sum(1 for rel in all_rels if _is_finished(rel, finished))
        _log(
            f"\nStopped. Saved {done}/{len(all_rels)}. Re-run to continue.",
            err=True,
        )
        sys.exit(130)

    results.sort(key=lambda r: r["file"])
    this_run = [r for r in results if not r.get("skipped")]
    errors = [r for r in this_run if r["status"] != "finished"]
    finished_count = sum(1 for rel in all_rels if _is_finished(rel, finished))

    _log("Summary")
    if this_run:
        ok = sum(1 for r in this_run if r["status"] == "finished")
        bad = sum(1 for r in this_run if r["status"] != "finished")
        committed = sum(1 for r in this_run if r.get("committed"))
        _log(
            f"  {ok} ok - {bad} failed - {committed} committed - "
            f"{skipped} skipped"
        )
        for r in this_run:
            if r["status"] != "finished":
                name = r["file"]
                prefix = f"prompts/{PROMPTS_ROOT.name}/"
                if name.startswith(prefix):
                    name = name[len(prefix) :]
                _log(f"  fail   {name} - {r.get('message', '')}")
    else:
        _log(f"  {finished_count}/{len(all_rels)} complete - nothing new")

    if errors or failed or finished_count < len(all_rels):
        _log(f"\n{finished_count}/{len(all_rels)} complete. Re-run for the rest.")
        sys.exit(1)

    _log(f"\nAll {len(all_rels)} prompts done.")


if __name__ == "__main__":
    asyncio.run(main())
