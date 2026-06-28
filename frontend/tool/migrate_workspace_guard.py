import pathlib
import re

root = pathlib.Path(__file__).resolve().parents[1] / "lib" / "features"
import_line = "import 'package:hosspi_hms/core/workspace/workspace_session_guard.dart';\n"

controller_files = list(root.rglob("*_workspace_controller.dart")) + [
    root / "patients" / "presentation" / "controllers" / "patient_registry_controller.dart",
]

for path in controller_files:
    text = path.read_text(encoding="utf-8")
    if "runWorkspaceInitialLoad" in text:
        continue
    if "Future<Result" not in text or "build()" not in text:
        continue

    original = text
    if import_line.strip() not in text:
        text = text.replace(
            "import 'package:hosspi_hms/core/errors/result.dart';\n",
            "import 'package:hosspi_hms/core/errors/result.dart';\n" + import_line,
        )

    text = re.sub(
        r"final Result<([^>]+)> result = await _loadInitialState\(\);",
        r"final Result<\1> result = await runWorkspaceInitialLoad(ref, _loadInitialState);",
        text,
    )
    text = re.sub(
        r"return _loadInitialState\(\);",
        r"return runWorkspaceInitialLoad(ref, _loadInitialState);",
        text,
        count=1,
    )
    text = re.sub(
        r"return _repository\.getWorkspace\(([^)]*)\);",
        r"return runWorkspaceInitialLoad(ref, () => _repository.getWorkspace(\1));",
        text,
        count=1,
    )

    if text != original:
        path.write_text(text, encoding="utf-8")
        print(f"updated {path.relative_to(root.parent)}")
