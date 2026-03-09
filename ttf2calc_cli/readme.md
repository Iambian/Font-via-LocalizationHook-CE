# ttf2calc_cli

## Overview

`ttf2calc_cli` is the script-driven font pack builder. It converts TTF fonts into
localization-hook-compatible data and produces calculator files for deployment.

## At a Glance

| Item | Value |
|---|---|
| Primary script | `builder.py` |
| Input | TTF files, encoding JSON, font size settings |
| Output | `.8xp` (standalone) or `.8xv` (viewer resource) |
| Output folder | `../build/` |

## Quick Start

From `ttf2calc_cli/`:

```bash
python builder.py MYFONT
python builder.py --resource MYFONT
```

`MYFONT` is required for all modes.
If no mode flag is given, `builder.py` defaults to standalone `.8xp` output.

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
	- `<NAME>.8xp` from `python builder.py <NAME>`
	- `<NAME>.8xv` from `python builder.py --resource <NAME>`

## Usage

### `python builder.py <NAME>`

Builds a self-installing protected program (`.8xp`) including loader + hook +
packed font data.

### `python builder.py --resource <NAME>`

Builds a resource AppVar (`.8xv`) containing hook + packed font data.

### `python builder.py --bins <NAME>`

Builds C header stubs in `../build/`:

- `<NAME>_resostub.h`
- `<NAME>_stalstub.h`

### Optional overrides

`builder.py` uses the built-in defaults from `packer.py` unless overridden.

- `--encoding`
- `--large-font`, `--large-size`
- `--small-font`, `--small-size`
- `--hook {lhook,fhook}` (standalone mode)
- `--quiet`

## Legacy scripts

`build_standalone.bat`, `build_resource.bat`, and `build_bins.bat` are
deprecated wrapper scripts.
CLI build workflows are now officially supported through `builder.py` +
`packer.py` only.

## Build

### Requirements

- Python 3.x
- Pillow (`pip install pillow`)
- `spasm-ng` (resolved via `SPASM_NG_PATH`, bundled tools, or `PATH`)

### Build process summary

`builder.py` runs `packer.py` functions, composes assembly source from shared
hook parts in `../lib/`, assembles with the shared cross-platform SPASM runner,
then packages with `../tools/binconv.py` or `../tools/bin2c.py`.

## Test

No dedicated automated test suite is currently defined for this folder.
Recommended validation is to transfer output to calculator and verify in
`viewer` and/or BASIC workflows.

## Troubleshooting

- Missing assembler: verify bundled `../tools/spasm/` paths for your platform.
- Missing assembler: set `SPASM_NG_PATH`, or verify bundled tools are present and executable.
- Empty or bad output: confirm TTF paths and sizes in `packer.py`.
- Encoding issues: validate JSON syntax and codepoint mappings.
- Name errors: ensure you pass `<NAME>` (required for all modes).

## Related Files

- `packer.py`
- `builder.py`
- `encoding/*.json`

## License

See repository root `LICENSE`.
