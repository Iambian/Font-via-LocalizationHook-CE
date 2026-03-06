# viewer

## Overview

`viewer` contains software that allows you to browse, preview, and (un)install 
font files in-system on the TI-84 Plus CE.

## At a Glance

| Item | Value |
|---|---|
| Program name | `FONTVIEW` |
| Input | Archived font pack variables (`.8xp`, `.8xv`, group members) |
| Output artifact | `FONTVIEW.8xp` |
| Build system | CE C Toolchain (`make`) |

## Quick Start

1. Build `FONTVIEW` from this folder:

```sh
make
```

2. Transfer `FONTVIEW.8xp` and font pack files to calculator.
3. Run `FONTVIEW` from `[PRGM]`.

## Inputs

- Archived font pack variables detected from filesystem
- Supported browsing categories:
	- protected programs (`PRGM`)
	- appvars (`AVAR`)
	- group-contained programs (`GRPP`)
	- group-contained appvars (`GRPV`)

## Outputs

- Visual font preview (large or small)
- Hook installation state changes:
	- install selected pack
	- uninstall current pack

## Usage

Controls in `FONTVIEW`:

- Left/Right: previous/next font in current category
- Up/Down: change category (`PRGM`, `AVAR`, `GRPP`, `GRPV`)
- `Y=`: toggle large/small preview
- `2nd`: toggle preview text mode
- `DEL`: install/uninstall selected font pack
- `MODE`: exit

## Build

### Requirements

- CE C Toolchain (verified builds on toolchain v12.1)

### Build command

```sh
make
```

Expected output is the calculator program `FONTVIEW.8xp` (prebuilt copy is also
present in `bin/`).

## Test

No separate automated test suite is defined in this folder.
Recommended validation flow:

1. Transfer `FONTVIEW.8xp` + sample packs from `../examples/`
2. Verify category scanning and font switching
3. Verify install/uninstall behavior with `DEL`

## Troubleshooting

- No fonts shown: ensure candidate variables are archived and valid font packs.
- Install appears to fail: test with known-good examples from `../examples/`.
- Build errors: verify CE toolchain installation and shell environment.

## Related Files

- `src/main.c`
- `src/util.asm`
- `src/extern.h`
- `makefile`
- `bin/FONTVIEW.8xp`

## License

See repository root `LICENSE`.

