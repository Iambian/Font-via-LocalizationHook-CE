"""Shared SPASM-ng resolution and invocation helpers.

This module centralizes cross-platform assembler lookup and subprocess
execution so multiple tools can reuse the same behavior.
"""

import os
import platform
import shutil
import subprocess
from pathlib import Path
from typing import Iterable, Optional, Sequence


def resolve_spasm_ng_path(project_root: Path) -> Path:
    """Resolve an assembler executable path for the current platform.

    Resolution order:
    1) SPASM_NG_PATH env var
    2) Bundled platform-specific path under tools/spasm/
    3) Legacy bundled paths kept for compatibility
    4) PATH lookup for spasm-ng/spasm
    """

    env_override = os.environ.get("SPASM_NG_PATH", "").strip()
    if env_override:
        override_path = Path(env_override).expanduser()
        if not override_path.exists() or not override_path.is_file():
            raise FileNotFoundError(
                "SPASM_NG_PATH is set but does not point to a valid file: "
                f"{override_path}"
            )
        return override_path

    system_name = platform.system().lower()
    bundled_candidates = []
    if system_name == "windows":
        bundled_candidates = [
            project_root / "tools" / "spasm" / "win" / "spasm.exe",
            project_root / "tools" / "spasm-ng.exe",
            project_root / "tools" / "spasm-ng",
        ]
    elif system_name == "linux":
        bundled_candidates = [
            project_root / "tools" / "spasm" / "linux" / "spasm",
            project_root / "tools" / "spasm-ng_0.5-beta.3_linux_amd64" / "spasm",
            project_root / "tools" / "spasm-ng",
        ]
    elif system_name == "darwin":
        bundled_candidates = [
            project_root / "tools" / "spasm" / "osx" / "spasm",
            project_root / "tools" / "spasm" / "osx" / "spasm_noappsign",
            project_root / "tools" / "spasm_osx_x64" / "spasm",
            project_root / "tools" / "spasm-ng",
        ]
    else:
        bundled_candidates = [project_root / "tools" / "spasm-ng"]

    for candidate in bundled_candidates:
        if not candidate.exists() or not candidate.is_file():
            continue
        if system_name != "windows" and not os.access(candidate, os.X_OK):
            raise PermissionError(
                "Assembler exists but is not executable: "
                f"{candidate}. Run chmod +x on this file."
            )
        return candidate

    path_candidate = shutil.which("spasm-ng") or shutil.which("spasm")
    if path_candidate:
        return Path(path_candidate)

    candidates_text = "\n".join(str(path) for path in bundled_candidates)
    raise FileNotFoundError(
        "Assembler not found for this platform. Checked bundled paths:\n"
        f"{candidates_text}\n"
        "and PATH entries for 'spasm-ng'/'spasm'."
    )


def run_spasm_ng(
    project_root: Path,
    input_asm_path: Path,
    output_path: Path,
    include_dirs: Optional[Iterable[Path]] = None,
    extra_args: Optional[Sequence[str]] = None,
) -> Path:
    """Run SPASM-ng and return output_path on success."""

    tool_path = resolve_spasm_ng_path(project_root)

    command = [str(tool_path), "-E", "-A"]
    for include_dir in include_dirs or []:
        command.extend(["-I", str(include_dir)])
    command.extend(list(extra_args or []))
    command.extend([str(input_asm_path), str(output_path)])

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError as exc:
        raise RuntimeError(f"Failed to execute assembler at {tool_path}: {exc}") from exc

    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        detail = stderr or stdout or f"spasm-ng exited with {result.returncode}"
        raise RuntimeError(f"spasm-ng failed: {detail}")

    return output_path
