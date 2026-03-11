# Font-via-LocalizationHook-CE

Font tooling for the TI-84 Plus CE based on the localization hook. This repository
contains multiple coordinated tools: font pack builders, a viewer/installer,
and BASIC-callable helper utilities.

## Overview

The project centers on a shared hook format stored in calculator variables.
The tools in this repository either:

- Generate font packs from TTF files (`.8xp` standalone or `.8xv` resource)
- Preview and install/uninstall font packs on-calc
- Let TI-BASIC programs load or edit font data

## Tools at a Glance

| Tool | Purpose | Typical input | Typical output | Details |
|---|---|---|---|---|
| `ttf2calc_cli` | Scripted font pack builder | `.ttf` + encoding JSON | `.8xp` / `.8xv` in `build/` | `ttf2calc_cli/readme.md` |
| `ttf2calc_gui` | Interactive font editor/exporter | `.ttf` + project (`.cefont`) | `.8xp` / `.8xv` in `build/` | `ttf2calc_gui/README.md` |
| `viewer` | On-calc browser/preview/install tool | Archived font variables | `viewer/bin/FONTVIEW.8xp` | `viewer/readme.md` |
| `floadb` | BASIC-callable font installer/uninstaller | `Str0` font name/path | `Ans` result code | `floadb/readme.md` |
| `feditb` | BASIC-callable glyph read/write utility | `Str0`, `Ans`, `[J]` | updated `[J]`, `Ans` | `feditb/readme.md` |

## Quick Start

### 1) Build a font package from TTF (CLI)

```bash
cd ttf2calc_cli
python builder.py MYFONT
python builder.py --resource MYFONT
```

`MYFONT` is required. `builder.py` defaults to standalone `.8xp` mode when no
mode flag is provided. You can override packer defaults with builder flags.

### 2) Build a font package with GUI

```bat
cd ttf2calc_gui
python main.py
```

Use the UI to configure large/small variants and export.

### 3) Preview/install packs on calculator

Transfer `viewer/bin/FONTVIEW.8xp` and your generated font files, then run
`FONTVIEW` on calculator.

### 4) Use from TI-BASIC

- Install/uninstall a font from BASIC: `floadb`
- Read/write glyph bitmaps from BASIC: `feditb`

See each tool README for full I/O and examples.

## Repository Layout

| Folder | Purpose |
|---|---|
| `build/` | Shared output directory for generated calculator files |
| `examples/` | Example prebuilt font files (`.8xp`, `.8xv`) |
| `fonts/` | Source TTF inputs used by builder tools |
| `include/` | Assembly include headers (`ti84pce.inc`, macros) |
| `lib/` | Shared assembly components |
| `tools/` | Shared helper scripts and bundled assembler executables |
| `ttf2calc_cli/` | Command-line TTF-to-pack workflow |
| `ttf2calc_gui/` | GUI workflow for editing/exporting packs |
| `viewer/` | CE C viewer/installer application |
| `floadb/` | BASIC-callable font loader utility |
| `feditb/` | BASIC-callable font glyph editor utility |

## Common Prerequisites

- Python 3.10+ (CLI/GUI scripts)
- Pillow (`pip install pillow`)
- fontTools (`pip install fonttools`) for GUI
- CE C Toolchain (for rebuilding `viewer`, verified buildable with v12.1)
- `spasm-ng` for pack assembly:
  - Bundled paths include:
    - Windows: `tools/spasm/win/spasm.exe`
    - Linux: `tools/spasm/linux/spasm`
    - macOS (x64): `tools/spasm/osx/spasm`
  - Optional override: `SPASM_NG_PATH`
  - Fallback accepted by GUI export: `spasm-ng` or `spasm` from `PATH`

## Build and Test Notes.

- Most generated artifacts are written to `build/` at repository root.
  (Notably, the artifacts for `viewer` do not appear in that folder.)
- `feditb` and `floadb` include TI-BASIC hardware test programs in each
  project's `tests/` folder.
- `viewer` and calculator-facing programs should be validated on real hardware
  (or emulator) after transfer.

## Status

- CLI and GUI export to `.8xp` and `.8xv` are implemented.
- GUI C export targets are placeholders.

## License

See `LICENSE`.
