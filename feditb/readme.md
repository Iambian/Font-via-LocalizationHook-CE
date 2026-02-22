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
- **Small font glyphs**: Variable width×12 matrix (width varies by glyph, 12 rows)

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

:# Write mode (NOT YET IMPLEMENTED)
:# 1065→Ans
:# Asm(prgmFEDITB
```

## Building

### Requirements

- [spasm-ng](https://github.com/alberthdev/spasm-ng) assembler (64-bit version)
- ti84pce.inc include file

### Build Instructions

Run the build script:

```batch
build.bat
```

This will compile `main.asm` and generate `FEDITB.8xp`.

## Installation

Transfer `FEDITB.8xp` to your TI-84 Plus CE calculator using TI Connect CE or similar software.

## License

MIT License - Copyright 2026 Rodger "Iambian" Weisman

See [LICENSE](LICENSE) for full details.

## Current Status

**⚠️ This is an incomplete draft.** The write mode functionality is not yet implemented. Only read mode is currently functional.

### Working Features
- Reading large and small font glyphs
- Finding and validating font objects
- Creating matrices with glyph data
- Automatic font file creation (stub functionality)

### Planned Features
- Write mode for modifying font glyphs (in development)
- Memory management for font file updates
- Validation of write operations

## Notes

This utility is intended to be merged into the Font-Via-LocalizationHook-CE repository in the future.

