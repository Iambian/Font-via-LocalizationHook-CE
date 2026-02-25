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

## Testing

TI-BASIC test programs are provided in the `tests/` directory to verify FEDITB correctness on hardware. The ASCII source files (`.txt`) are the authoritative source of record; pre-compiled `.8xp` files are included for convenience.

### Test Programs

| Source file | Program name | Compiled file | Description |
|---|---|---|---|
| `TESTFED.txt` | `TESTFED` | `FEDTBTST.8xp` | Core functional test suite |
| `TESTFE2.txt` | `TESTFE2` | `FEDTBTS2.8xp` | Graphics and extended data-integrity tests |

**TESTFED** — 12 automated tests covering:
- Error condition handling (font not found, invalid glyph ID, unmapped glyph)
- Reading large and small font glyphs into matrix `[J]`
- Verifying returned matrix dimensions and binary cell values
- Large and small glyph write-back roundtrips
- Automatic creation of a new font file (`TESTFNT`) when the target does not exist
- Readback dimension verification after a write

**TESTFE2** — 14 tests combining automated data checks with visual graph-screen output:
- Rendering individual large and small glyphs (`A`, `O`)
- Pixel-density sanity check (glyph is neither blank nor fully filled)
- Side-by-side rendering of two glyphs for comparison
- Writing a glyph to a non-ASCII codepoint (129) and comparing byte-for-byte on readback
- Single-pixel and full-row modification roundtrips with exact-match verification
- Visual rendering of modified glyphs alongside originals
- Small glyph write/readback roundtrip
- Synthetic checkerboard pattern write and verification
- Graph-screen render of the checkerboard pattern

Both programs track a running pass/fail count and display a summary at the end.

### Prerequisites

- `FEDITB.8xp` installed on the calculator (see [Building](#building) and [Installation](#installation))
- `OPENSANS.8xp` transferred to the calculator and **unarchived** — this font appvar is read by both test programs; a copy is provided in `tests/OPENSANS.8xp`
- For roundtrip write tests (`TESTFED` T9/T10), `OPENSANS` must be in RAM (not archived)

### Compiling the Source Files with SourceCoder 3

The `.txt` source files use ASCII TI-BASIC syntax compatible with [SourceCoder 3](https://sc.cemetech.net), an online tool by Cemetech.

1. Open [https://sc.cemetech.net](https://sc.cemetech.net) in a browser.
2. Click **Open/New** and select the `.txt` source file (`TESTFED.txt` or `TESTFE2.txt`).
3. SourceCoder reads the `PROGRAM:name` header at the top of the file and sets the program name automatically.
4. Click **Export** to download the compiled `.8xp` file.
5. Transfer the resulting `.8xp` to the calculator using TI Connect CE or similar software.

The pre-compiled files already present in `tests/` were produced using this process.

### Running the Tests

1. Transfer all required files to the calculator (see Prerequisites above).
2. On the calculator, press `[PRGM]`, select `TESTFED`, and press `[ENTER]`.
3. Follow the on-screen prompts — each test pauses for review before continuing.
4. Note the final pass/fail summary.
5. Repeat with `TESTFE2`. This program uses the graph screen for visual output; inspect each rendered glyph before pressing `[ENTER]` to advance.

> **Note:** `TESTFE2` creates and modifies a temporary font appvar named `TESTFNT` during its run. This variable is left on the calculator after the test completes and can be deleted manually.

## License

MIT License - Copyright 2026 Rodger "Iambian" Weisman

See [LICENSE](LICENSE) for full details.

## Current Status

Implementation complete. TI-BASIC test programs have been written and compiled to verify correctness on hardware.

### Working Features
- Reading large and small font glyphs into matrix [J]
- Writing large and small font glyphs from matrix [J]
- Finding and validating font objects (programs and appvars)
- Creating a new empty font file if the named file does not exist
- Automatic glyph insertion and memory expansion for new glyphs
- Compacting and writing back glyph tables to the font file
- Matrix [J] creation with correct dimensions in read mode
- Comprehensive error reporting

### Tests Added
- `tests/TESTFED.txt` — 12-test functional suite covering error codes, read/write, and roundtrip correctness (compiled: `FEDTBTST.8xp`)
- `tests/TESTFE2.txt` — 14-test graphics and data-integrity suite with graph-screen visual output (compiled: `FEDTBTS2.8xp`)

