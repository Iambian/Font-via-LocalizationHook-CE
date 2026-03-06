# ttf2calc_cli

## Overview

`ttf2calc_cli` is the script-driven font pack builder. It converts TTF fonts into
localization-hook-compatible data and produces calculator files for deployment.

## At a Glance

| Item | Value |
|---|---|
| Primary scripts | `build_standalone.bat`, `build_resource.bat` |
| Input | TTF files, encoding JSON, font size settings |
| Output | `.8xp` (standalone) or `.8xv` (viewer resource) |
| Output folder | `../build/` |

## Quick Start

From `ttf2calc_cli/`:

```bat
build_standalone.bat MYFONT
build_resource.bat MYFONT
```

Before building, edit `packer.py` configuration values.

## Inputs

- Font source files: typically in `../fonts/`
- Encoding map: `encoding/*.json` or `None` for alphanumeric default
- Build config in `packer.py`:
	- `USE_ENCODING_JSON`
	- `LARGE_FONT_LOCATION`, `LARGE_FONT_SIZE`
	- `SMALL_FONT_LOCATION`, `SMALL_FONT_SIZE`

### Encoding JSON format

Top-level JSON array containing either:

1. String entries (direct character mapping)
2. Two-item arrays: `[unicode_char_or_codepoint, ti_codepoint_or_char]`

Examples:

- `["[", 193]`
- `[952, 91]`

## Outputs

- Intermediate generated assembly data:
	- `obj/encodings.z80`
	- `obj/lfont.z80`
	- `obj/sfont.z80`
- Final calculator files in `../build/`:
	- `<NAME>.8xp` from `build_standalone.bat`
	- `<NAME>.8xv` from `build_resource.bat`
	- Default standalone name if omitted: `FONTHOOK.8xp`

## Usage

### `build_standalone.bat <NAME>`

Builds a self-installing protected program (`.8xp`) including loader + hook +
packed font data.

### `build_resource.bat <NAME>`

Builds a resource AppVar (`.8xv`) containing hook + packed font data.
`<NAME>` is required.

### `build_bins.bat`

Builds C header stubs for integration scenarios:

- `../build/resostub.h`
- `../build/stalstub.h`

Not needed for normal `.8xp`/`.8xv` output.

## Build

### Requirements

- Python 3.x
- Pillow (`pip install pillow`)
- `spasm-ng` (expected at `../tools/spasm-ng` / `../tools/spasm-ng.exe`)

### Build process summary

Each batch script runs `packer.py`, composes assembly source from shared hook
parts in `../lib/lhook/`, assembles with `spasm-ng`, then packages with
`../tools/binconv.py`.

## Test

No dedicated automated test suite is currently defined for this folder.
Recommended validation is to transfer output to calculator and verify in
`viewer` and/or BASIC workflows.

## Troubleshooting

- Missing assembler: verify `../tools/spasm-ng` path.
- Empty or bad output: confirm TTF paths and sizes in `packer.py`.
- Encoding issues: validate JSON syntax and codepoint mappings.
- Name errors for `.8xv`: ensure you pass a basename to `build_resource.bat`.

## Related Files

- `packer.py`
- `build_standalone.bat`
- `build_resource.bat`
- `build_bins.bat`
- `encoding/*.json`

## License

See repository root `LICENSE`.
