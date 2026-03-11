"""Unified cross-platform build frontend for ttf2calc_cli.

This replaces the old batch-driven flow and can build:
- standalone 8xp package
- resource 8xv package
- C header stubs (bins)
"""

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Optional


CLI_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = CLI_DIR.parent

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from lib.spasm_runner import run_spasm_ng
import packer


QUIET = False


def _log(message: str):
    if not QUIET:
        print(message)


def _resolve_user_path(value: Optional[str]) -> Optional[str]:
    if value is None:
        return None
    path = Path(value)
    if not path.is_absolute():
        path = (CLI_DIR / path).resolve()
    return str(path)


def _sanitize_name(name: str) -> str:
    stem = Path(name).stem
    if not stem:
        raise ValueError("Output filename must not be empty.")
    return stem


def _write_combined_asm(
    output_path: Path,
    hook_lib: str,
    using_loader: bool,
    include_small_font: bool,
):
    hook_dir = PROJECT_ROOT / "lib" / hook_lib
    if not hook_dir.exists():
        raise FileNotFoundError(f"Hook library not found: {hook_dir}")

    with output_path.open("w", encoding="utf-8") as asm_file:
        if using_loader:
            asm_file.write("#define USING_LOADER\n")
        asm_file.write((hook_dir / "sahead.asm").read_text(encoding="utf-8"))
        if using_loader:
            asm_file.write((hook_dir / "loader.asm").read_text(encoding="utf-8"))
        asm_file.write((hook_dir / "hook.asm").read_text(encoding="utf-8"))
        asm_file.write((CLI_DIR / "obj" / "encodings.z80").read_text(encoding="utf-8"))
        asm_file.write((CLI_DIR / "obj" / "lfont.z80").read_text(encoding="utf-8"))
        if include_small_font:
            asm_file.write((CLI_DIR / "obj" / "sfont.z80").read_text(encoding="utf-8"))


def _run_python_tool(script_path: Path, source_path: Path, output_path: Path):
    result = subprocess.run(
        [sys.executable, str(script_path), str(source_path), str(output_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        detail = (result.stderr or "").strip() or (result.stdout or "").strip()
        raise RuntimeError(f"{script_path.name} failed: {detail}")


def _configure_packer_from_args(args: argparse.Namespace):
    if args.encoding is not None:
        packer.USE_ENCODING_JSON = _resolve_user_path(args.encoding)
    else:
        packer.USE_ENCODING_JSON = _resolve_user_path(packer.USE_ENCODING_JSON)

    if args.large_font is not None:
        packer.LARGE_FONT_LOCATION = _resolve_user_path(args.large_font)
    else:
        packer.LARGE_FONT_LOCATION = _resolve_user_path(packer.LARGE_FONT_LOCATION)

    if args.small_font is not None:
        packer.SMALL_FONT_LOCATION = _resolve_user_path(args.small_font)
    else:
        packer.SMALL_FONT_LOCATION = _resolve_user_path(packer.SMALL_FONT_LOCATION)

    if args.large_size is not None:
        packer.LARGE_FONT_SIZE = int(args.large_size)
    if args.small_size is not None:
        packer.SMALL_FONT_SIZE = int(args.small_size)


def _run_packer_generation():
    obj_dir = CLI_DIR / "obj"
    obj_dir.mkdir(parents=True, exist_ok=True)
    _log(f"[packer] Generating packed font sources in {obj_dir}")

    encoding = packer.reencode(packer.USE_ENCODING_JSON, str(obj_dir / "encodings.z80"))
    packer.packit(
        packer.LARGE_FONT_LOCATION,
        packer.LARGE_FONT_SIZE,
        encoding,
        str(obj_dir / "lfont.z80"),
        packer.largefontsource,
    )
    packer.packit(
        packer.SMALL_FONT_LOCATION,
        packer.SMALL_FONT_SIZE,
        encoding,
        str(obj_dir / "sfont.z80"),
        packer.smallfontsource,
    )
    _log("[packer] Wrote encodings.z80, lfont.z80, and sfont.z80")


def _build_standalone(name: str, hook_lib: str):
    obj_dir = CLI_DIR / "obj"
    build_dir = PROJECT_ROOT / "build"
    include_dir = PROJECT_ROOT / "include"
    build_dir.mkdir(parents=True, exist_ok=True)

    main_asm = obj_dir / "main.asm"
    main_bin = obj_dir / "main.bin"
    _log(f"[build] Mode=standalone, hook={hook_lib}, name={name}")
    _write_combined_asm(
        output_path=main_asm,
        hook_lib=hook_lib,
        using_loader=True,
        include_small_font=(hook_lib.lower() != "fhook"),
    )

    run_spasm_ng(
        project_root=PROJECT_ROOT,
        input_asm_path=main_asm,
        output_path=main_bin,
        include_dirs=[include_dir],
    )
    output_path = build_dir / f"{name}.8xp"
    _run_python_tool(PROJECT_ROOT / "tools" / "binconv.py", main_bin, output_path)
    _log(f"[done] Wrote {output_path}")


def _build_resource(name: str):
    obj_dir = CLI_DIR / "obj"
    build_dir = PROJECT_ROOT / "build"
    include_dir = PROJECT_ROOT / "include"
    build_dir.mkdir(parents=True, exist_ok=True)

    main_asm = obj_dir / "main.asm"
    main_bin = obj_dir / "main.bin"
    _log(f"[build] Mode=resource, hook=lhook, name={name}")
    _write_combined_asm(
        output_path=main_asm,
        hook_lib="lhook",
        using_loader=False,
        include_small_font=True,
    )

    run_spasm_ng(
        project_root=PROJECT_ROOT,
        input_asm_path=main_asm,
        output_path=main_bin,
        include_dirs=[include_dir],
    )
    output_path = build_dir / f"{name}.8xv"
    _run_python_tool(PROJECT_ROOT / "tools" / "binconv.py", main_bin, output_path)
    _log(f"[done] Wrote {output_path}")


def _build_bins(name: str):
    obj_dir = CLI_DIR / "obj"
    build_dir = PROJECT_ROOT / "build"
    include_dir = PROJECT_ROOT / "include"
    hook_dir = PROJECT_ROOT / "lib" / "lhook"
    build_dir.mkdir(parents=True, exist_ok=True)
    _log(f"[build] Mode=bins, hook=lhook, name={name}")

    reso_asm = obj_dir / "resostub.asm"
    reso_bin = obj_dir / "resostub.bin"
    reso_asm.write_text(
        (hook_dir / "sahead.asm").read_text(encoding="utf-8")
        + (hook_dir / "hook.asm").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    run_spasm_ng(
        project_root=PROJECT_ROOT,
        input_asm_path=reso_asm,
        output_path=reso_bin,
        include_dirs=[include_dir],
    )
    reso_header = build_dir / f"{name}_resostub.h"
    _run_python_tool(PROJECT_ROOT / "tools" / "bin2c.py", reso_bin, reso_header)

    stal_asm = obj_dir / "stalstub.asm"
    stal_bin = obj_dir / "stalstub.bin"
    stal_asm.write_text(
        "#define USING_LOADER\n"
        + (hook_dir / "sahead.asm").read_text(encoding="utf-8")
        + (hook_dir / "loader.asm").read_text(encoding="utf-8")
        + (hook_dir / "hook.asm").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    run_spasm_ng(
        project_root=PROJECT_ROOT,
        input_asm_path=stal_asm,
        output_path=stal_bin,
        include_dirs=[include_dir],
    )
    stal_header = build_dir / f"{name}_stalstub.h"
    _run_python_tool(PROJECT_ROOT / "tools" / "bin2c.py", stal_bin, stal_header)
    _log(f"[done] Wrote {reso_header}")
    _log(f"[done] Wrote {stal_header}")


def _build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Cross-platform builder for ttf2calc_cli.")
    parser.add_argument("name", help="Required output base filename (no extension needed).")

    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument("--standalone", action="store_true", help="Build standalone protected program (.8xp).")
    mode_group.add_argument("--resource", action="store_true", help="Build viewer resource appvar (.8xv).")
    mode_group.add_argument("--bins", action="store_true", help="Build C header stubs via bin2c.")

    parser.add_argument("--hook", choices=["lhook", "fhook"], default="lhook", help="Hook library for standalone mode.")
    parser.add_argument("--encoding", help="Override packer USE_ENCODING_JSON path.")
    parser.add_argument("--large-font", help="Override packer LARGE_FONT_LOCATION path.")
    parser.add_argument("--large-size", type=int, help="Override packer LARGE_FONT_SIZE.")
    parser.add_argument("--small-font", help="Override packer SMALL_FONT_LOCATION path.")
    parser.add_argument("--small-size", type=int, help="Override packer SMALL_FONT_SIZE.")
    parser.add_argument("--quiet", action="store_true", help="Suppress non-error status output.")
    return parser


def main() -> int:
    global QUIET
    parser = _build_arg_parser()
    args = parser.parse_args()
    QUIET = bool(args.quiet)

    output_name = _sanitize_name(args.name)

    _configure_packer_from_args(args)
    _run_packer_generation()

    if args.resource:
        _build_resource(output_name)
    elif args.bins:
        _build_bins(output_name)
    else:
        # Default mode when no mode flag is passed.
        _build_standalone(output_name, args.hook)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)











