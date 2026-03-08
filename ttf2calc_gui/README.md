# ttf2calc_gui

## Overview

`ttf2calc_gui` is the interactive PC-side font editor/exporter for this
repository. It builds large and small font variants from TTF sources, 
supports per-glyph nudging, and exports calculator font packs.

## At a Glance

| Item | Value |
|---|---|
| Entry point | `main.py` |
| Primary input | `.ttf` files + selected encoding |
| Project format | `.cefont` |
| Export targets | `Standalone (8xp)`, `Viewer Only (8xv)` |
| Output folder | repository root `build/` |

## Quick Start

From `ttf2calc_gui/`:

```bat
python main.py
```

Then select encoding, configure font variants, and click **EXPORT FONT FILE**.

## Inputs

- Font variant settings (for both large and small views):
  - font directory
  - font filename
  - point size
  - aliasing mode
- Encoding selection from `src/encodings.json`
- Optional project file (`.cefont`) for saved state
- Output target + output basename

## Outputs

- Exported calculator files in root `build/`:
  - `<NAME>.8xp` for standalone target
  - `<NAME>.8xv` for viewer-only target
- Project save files in `projects/` (default location)

### Name validation behavior

- `.8xp` basename: sanitized to alphanumeric, max 8 chars, uppercase in output;
  cannot begin with a digit
- `.8xv` basename: must be non-empty ASCII

## Usage

1. Load or create a project (`.cefont`).
2. Choose encoding and active view (`Large` or `Small`).
3. Configure font path/name, size, aliasing.
4. Select glyph in canvas; zoom/pan; nudge with arrow keys.
5. Repeat for both variants as needed.
6. Choose export target and basename, then export.

## Build

### Requirements

- Python 3.10+
- Tkinter (usually bundled with standard Python on Windows)
- Pillow (`pip install pillow`)
- fontTools (`pip install fonttools`)
- `spasm-ng` available by one of these methods (used for `.8xp` / `.8xv` export):
  - Set `SPASM_NG_PATH` to a specific assembler binary
  - Bundled tool in this repository:
    - Windows: `tools/spasm-ng.exe`
    - Linux: `tools/spasm-ng_0.5-beta.3_linux_amd64/spasm`
    - macOS (x64): `tools/spasm_osx_x64/spasm`
  - `spasm-ng` or `spasm` available in your shell `PATH`

### Assembler resolution order

At export time, the GUI resolves assembler location in this order:

1. `SPASM_NG_PATH`
2. Platform-specific bundled binary in `tools/`
3. `spasm-ng` / `spasm` from `PATH`

On Linux and macOS, bundled binaries must be executable (`chmod +x ...`).

### Implementation notes

Export composes temporary assembly using shared hook components in `lib/lhook/`,
assembles with `spasm-ng`, and writes final artifacts to root `build/`.

## Test

No formal automated test suite is currently defined for this folder.
Recommended validation is export + transfer + verification in `viewer` or on-calc.

## Troubleshooting

- Export fails immediately: verify assembler resolution in the order above.
- Linux/macOS permission error: run `chmod +x` on bundled `tools/.../spasm`.
- Wrong assembler chosen: set `SPASM_NG_PATH` to force a specific binary.
- Font load errors: verify font path and filename are valid.
- Unexpected glyph mapping: confirm selected encoding and mapped characters.
- C export target selected: C targets are placeholders and currently not implemented.

## Related Files

- `main.py`
- `src/ui.py`
- `src/core.py`
- `src/canvas.py`
- `src/encodings.json`
- `DESIGN.md`

## License

See repository root `LICENSE`.
