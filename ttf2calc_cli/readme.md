# ttf2calc_cli

Command-line font builder for Font-via-LocalizationHook-CE.

This folder contains the reworked workflow for the **"Building a font"** process:
- Convert one TTF into TI-84 Plus CE font data (`obj/*.z80`)
- Build either a standalone installer program (`.8xp`) or resource AppVar (`.8xv`)
- Optionally generate C headers used by related tooling

## Prerequisites

- Python 3.x
- Pillow (`pip install pillow`)
- `spasm-ng` available at `../tools/spasm-ng`
- Source TTF files in `../fonts/`

## Quick start

From this folder (`ttf2calc_cli`):

1. Edit font settings in `packer.py` (see configuration below).
2. Build one of these targets:
	- Standalone installer: `build_standalone.bat <NAME>`
	- Resource AppVar: `build_resource.bat <NAME>`
3. Output is written to `../build/`:
	- `<NAME>.8xp` for standalone
	- `<NAME>.8xv` for resource

If `<NAME>` is omitted for standalone, default output is `FONTHOOK.8xp`.

## What each script does

### `build_standalone.bat`

Builds a self-installing protected program (`.8xp`) by combining:
- localization hook loader
- hook code
- generated encoding/font data from `packer.py`

Result: `../build/<NAME>.8xp` (or `../build/FONTHOOK.8xp` if name omitted)

### `build_resource.bat`

Builds a resource AppVar (`.8xv`) for viewer/manager-style workflows by combining:
- hook code (no standalone loader)
- generated encoding/font data from `packer.py`

Result: `../build/<NAME>.8xv` (name is required)

### `build_bins.bat`

Not for normal font package output. Generates binary stubs as C headers:
- `../build/resostub.h`
- `../build/stalstub.h`

These are intended for other build integrations.

## `packer.py` configuration

Only edit the variables at the top of `packer.py`:

- `USE_ENCODING_JSON`
  - Path to encoding map JSON (example: `encoding/asciish.json`)
  - Set to `None` to default to alphanumeric only (`0-9A-Za-z`)
- `LARGE_FONT_LOCATION`, `LARGE_FONT_SIZE`
- `SMALL_FONT_LOCATION`, `SMALL_FONT_SIZE`

Running `packer.py` generates:
- `obj/encodings.z80`
- `obj/lfont.z80`
- `obj/sfont.z80`

These files are consumed automatically by the batch build scripts.

## Encoding JSON format

Encoding files are JSON arrays (`ttf2calc_cli/encoding/*.json`) with items that are either:

1. **String**
	- Each character maps to its matching TI codepoint (ASCII-range only)

2. **Two-item array**
	- `[unicode_char_or_codepoint, ti_codepoint_or_char]`
	- Lets you remap characters to non-default TI positions

Example from `encoding/asciish.json`:
- `["[", 193]` maps `[` to TI codepoint `193`
- `[952, 91]` maps Unicode `952` (θ) to TI codepoint `91`

## Output locations

- Intermediate/generated assembly data: `obj/`
- Final calculator files: `../build/`

## Notes

- Character visual alignment may require iterating font sizes.
- Respect font licensing when distributing generated files.
