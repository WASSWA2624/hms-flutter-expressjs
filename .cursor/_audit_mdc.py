import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
files = sorted(
    p
    for p in root.rglob("*.mdc")
    if ".cursor" in p.parts and "dev-plan" not in p.parts
)

stats = {
    "ok": 0,
    "over": 0,
    "no_fm": 0,
    "no_h1": 0,
    "no_h2": 0,
    "no_purpose": 0,
    "bad_fm_order": 0,
    "globs_aa": 0,
    "scoped_no_globs": 0,
    "no_modal": 0,
}
issues = []

for p in files:
    raw = p.read_text(encoding="utf-8")
    text = raw.replace("\r\n", "\n").replace("\r", "\n")
    rel = p.relative_to(root).as_posix()
    words = len(re.findall(r"\S+", text))
    fi = []

    fm = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.S)
    if not fm:
        fi.append("NO_FM")
        stats["no_fm"] += 1
        body = text
    else:
        front, body = fm.group(1), fm.group(2)
        keys = [m.group(1) for m in re.finditer(r"^([a-zA-Z]+):", front, re.M)]
        desc = re.search(r"^description:\s*(.+)$", front, re.M) or re.search(
            r"^description:\s*>", front, re.M
        )
        aa = re.search(r"^alwaysApply:\s*(true|false)\s*$", front, re.M)
        has_globs = bool(re.search(r"^globs:", front, re.M))
        if not desc:
            fi.append("NO_DESC")
        if not aa:
            fi.append("NO_AA")
        else:
            if aa.group(1) == "true" and has_globs:
                fi.append("GLOBS+AA")
                stats["globs_aa"] += 1
            if aa.group(1) == "false" and not has_globs:
                fi.append("SCOPED_NO_GLOBS")
                stats["scoped_no_globs"] += 1
        if keys and keys[0] != "description":
            fi.append("DESC_NOT_FIRST")
            stats["bad_fm_order"] += 1
        if "alwaysApply" in keys and keys[-1] != "alwaysApply":
            fi.append("AA_NOT_LAST")

    if not re.search(r"^#\s+\S", body, re.M):
        fi.append("NO_H1")
        stats["no_h1"] += 1
    h2s = re.findall(r"^##\s+.+", body, re.M)
    if len(h2s) == 0:
        fi.append("NO_H2")
        stats["no_h2"] += 1

    h1 = re.search(r"^#\s+.+$", body, re.M)
    if h1:
        after = body[h1.end() :].lstrip("\n")
        first = after.split("\n")[0] if after else ""
        if (
            not first
            or first.startswith("#")
            or first.startswith("-")
            or first.startswith("|")
            or first.startswith("*")
            or first.startswith("`")
        ):
            fi.append("NO_PURPOSE")
            stats["no_purpose"] += 1

    if words > 251:
        fi.append(f"OVER:{words}")
        stats["over"] += 1
    if not re.search(r"\b(must|must not|should|may)\b", body, re.I):
        fi.append("NO_MODAL")
        stats["no_modal"] += 1

    if fi:
        issues.append((words, rel, fi))
    else:
        stats["ok"] += 1

print("TOTAL", len(files))
print("STATS", stats)
print("NONCOMPLIANT", len(issues))
for w, rel, fi in issues:
    print(f"{w:4d} | {rel} | {'; '.join(fi)}")
