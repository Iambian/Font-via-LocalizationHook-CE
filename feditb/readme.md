# FEDITB

## Overview

`FEDITB` is a BASIC-callable assembly utility for reading and writing glyph data
inside localization-hook font objects.

## At a Glance

| Item | Value |
|---|---|
| Program name | `FEDITB` |
| Inputs | `Str0`, `Ans`, `[J]` (write mode) |
| Outputs | `Ans` status, `[J]` glyph matrix (read mode) |
| Build artifact | `../build/FEDITB.8xp` |

## Quick Start

1. Build from `feditb/`:

```bat
build.bat
```

2. Transfer `build/FEDITB.8xp` to calculator.
3. Set `Str0` and `Ans` in BASIC, then run `Asm(prgmFEDITB`.

## Inputs

- `Str0`: name of target font object
- `Ans`: mode selector
- `[J]`: glyph matrix for write operations

### Mode encoding (`Ans`)

- `1..255`: read/write large glyph index
- `257..511`: read/write small glyph index (`glyph+256`)
- `+1000` offset: write mode flag

Examples:

- `65` = read large glyph 65
- `321` = read small glyph 65
- `1065` = write large glyph 65
- `1321` = write small glyph 65

## Outputs

- `Ans`: result/error code
- `[J]`: populated during successful read operations

### Matrix dimensions

- Large glyph read: 14 rows × 12 columns
- Small glyph read: 12 rows × (1..16) columns

### Error codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Out of memory while creating font |
| 2 | Invalid glyph |
| 3 | Glyph not found |
| 4 | Out of memory (general) |
| 5 | Matrix dimension mismatch |
| 6 | Matrix columns out of range |
| 7 | Font not found |
| 8 | Font file corrupted |
| 9 | String not found |
| 10 | Matrix create failed |
| 11 | Invalid string input |
| 12 | Matrix not found |
| 13 | File archived (write requires RAM) |

## Usage

```basic
:"FONTNAME"→Str0
:65→Ans
:Asm(prgmFEDITB

:"FONTNAME"→Str0
:321→Ans
:Asm(prgmFEDITB

:"FONTNAME"→Str0
:1065→Ans
:Asm(prgmFEDITB

:"FONTNAME"→Str0
:1321→Ans
:Asm(prgmFEDITB
```

Write-mode rules:

- target font and `[J]` must be in RAM
- small glyph width is taken from `[J]` columns and must be `1..16`
- missing target font may be created automatically

## Build

### Requirements

- `spasm-ng` (project expects `../tools/spasm-ng.exe`)
- include files in `../include/`

### Build command

```bat
build.bat
```

Produces `../build/FEDITB.8xp`.

## Test

Test sources and binaries are in `tests/`.

| Source | Program | Compiled | Focus |
|---|---|---|---|
| `TESTFED.txt` | `TESTFED` | `FEDTBTST.8xp` | Functional/error/read-write checks |
| `TESTFE2.txt` | `TESTFE2` | `FEDTBTS2.8xp` | Graphics + data-integrity checks |

Key coverage:

- error-path handling
- large/small glyph reads into `[J]`
- large/small write roundtrips
- dimensions and pixel-level verification
- visual rendering checks on graph screen

Prerequisites for hardware testing:

- `FEDITB.8xp` installed
- `tests/OPENSANS.8xp` transferred and unarchived

## Troubleshooting

- `Ans=13` on write: unarchive target font and keep `[J]` in RAM.
- Dimension errors (`5`/`6`): verify `[J]` shape matches glyph type.
- Unexpected `3`: glyph may not be mapped in selected font encoding.

## Related Files

- `feditb.asm`
- `build.bat`
- `tests/TESTFED.txt`
- `tests/TESTFE2.txt`

## License

See repository root `LICENSE`.

