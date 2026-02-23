Font Editor - BASIC Utility (FEDITB)
=====================================

A TI-84 Plus CE assembly utility that enables BASIC programs to read and write localization hook font objects.

## Overview

FEDITB provides a simple interface for BASIC programs to edit font glyphs stored in localization hook font objects. This utility allows reading and writing both large and small font glyphs using familiar TI-BASIC variables.

## Usage

### Inputs

- **Str0**: Name of the font object to find
  - Prefix with `rowSwap(` token to locate appvars
- **[J]**: Matrix containing glyph data (required for write mode)
- **Ans**: Operation mode (see below)

### Ans Values

- `0-255`: Large font glyph to read/write
- `Ans+256`: Small font glyph to read/write
- `Ans+1000`: Enable write mode

### Outputs

- **[J]**: Matrix containing glyph data (populated in read mode)
- **Ans**: Error code (0 if successful)

### Matrix Dimensions

- **Large font glyphs**: 12×14 matrix (12 columns, 14 rows)
- **Small font glyphs**: 1–16 columns × 12 rows (width varies by glyph)

### Error Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | Out of memory when creating font |
| 2 | Invalid glyph |
| 3 | Glyph not found |
| 4 | Out of memory (other) |
| 5 | Matrix dimension mismatch |
| 6 | Matrix columns out of range |
| 7 | Font not found |
| 8 | Font file corrupted |
| 9 | String not found |
| 10 | Matrix create failed |
| 11 | Invalid string input |
| 12 | Matrix not found |
| 13 | File archived |

### Example Usage

```basic
:# Read large font glyph 65 (character 'A')
:"FONTNAME"→Str0
:65→Ans
:Asm(prgmFEDITB
:# [J] now contains the glyph data

:# Read small font glyph 65
:"FONTNAME"→Str0
:321→Ans
:Asm(prgmFEDITB
:# [J] now contains the small glyph data

:# Write large font glyph 65 from [J]
:"FONTNAME"→Str0
:1065→Ans
:Asm(prgmFEDITB

:# Write small font glyph 65 from [J]
:"FONTNAME"→Str0
:1321→Ans
:Asm(prgmFEDITB
```

### Notes on Write Mode

- The font file must be in RAM. Archived font files return error 13.
- Matrix [J] must also be in RAM.
- If the named font file does not exist, a new empty font file is created automatically.
- For small glyphs, the width is taken from the matrix column count and stored in the glyph data.
- Valid small glyph widths are 1–16 columns. Zero and values above 16 are rejected.

## Building

### Requirements

- [spasm-ng](https://github.com/alberthdev/spasm-ng) assembler (64-bit version)
- ti84pce.inc include file

### Build Instructions

Run the build script:

```batch
build.bat
```

This will compile `feditb.asm` and generate `FEDITB.8xp`.

## Installation

Transfer `FEDITB.8xp` to your TI-84 Plus CE calculator using TI Connect CE or similar software.

## License

MIT License - Copyright 2026 Rodger "Iambian" Weisman

See [LICENSE](LICENSE) for full details.

## Current Status

Ready for initial testing. Both read and write modes are implemented.

### Working Features
- Reading large and small font glyphs into matrix [J]
- Writing large and small font glyphs from matrix [J]
- Finding and validating font objects (programs and appvars)
- Creating a new empty font file if the named file does not exist
- Automatic glyph insertion and memory expansion for new glyphs
- Compacting and writing back glyph tables to the font file
- Matrix [J] creation with correct dimensions in read mode
- Comprehensive error reporting

