from __future__ import annotations

import re
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "backend" / "prisma" / "schema.prisma"
text = path.read_text(encoding="utf-8")

text = text.replace("  branches                        branch[]\n", "")
text = re.sub(r"\nmodel branch \{.*?\n\}\n", "\n", text, count=1, flags=re.S)

removals = [
    r"  branch_id\s+String\?\s+@db\.VarChar\(36\)\n",
    r"  branch\s+branch\?\s+@relation\(fields: \[branch_id\], references: \[id\]\)\n",
    r'  branch\s+branch\?\s+@relation\("branch_address", fields: \[branch_id\], references: \[id\]\)\n',
    r'  branch\s+branch\?\s+@relation\("branch_contact", fields: \[branch_id\], references: \[id\]\)\n',
    r'  branch\s+branch\?\s+@relation\("kpi_snapshot_branch", fields: \[branch_id\], references: \[id\]\)\n',
    r'  branch\s+branch\?\s+@relation\("analytics_event_branch", fields: \[branch_id\], references: \[id\]\)\n',
    r"  @@index\(\[branch_id\]\)\n",
]
for pat in removals:
    text = re.sub(pat, "", text)

path.write_text(text, encoding="utf-8")
left = [
    (i + 1, line)
    for i, line in enumerate(text.splitlines())
    if re.search(r"\bbranch\b", line, re.I)
]
print(f"remaining branch lines: {len(left)}")
for n, line in left[:50]:
    print(f"{n}: {line[:120]}")
