# FLOADB

## Overview

`FLOADB` is a BASIC-callable assembly utility that installs or uninstalls a
font through the localization hook.

## At a Glance

| Item | Value |
|---|---|
| Program name | `FLOADB` |
| Input variable | `Str0` |
| Output variable | `Ans` |
| Build artifact | `../build/FLOADB.8xp` |

## Quick Start

1. Build `FLOADB.8xp` from this folder:

```bat
build.bat
```

2. Transfer `../build/FLOADB.8xp` to calculator.
3. In TI-BASIC, set `Str0` and run `Asm(prgmFLOADB`.

## Inputs

- `Str0` = font source selector
	- direct variable name (example: `"ComicSan"`)
	- group path (example: `"FONTGRPT/ARIAL"`)
- `Str0=""` = uninstall active font

## Outputs

- `Ans=0` success
- `Ans=1` failure (not found, invalid source/type/format, or other load error)

## Usage

```basic
:"ComicSan"→Str0
:Asm(prgmFLOADB
:If Ans=0
:Then
: Disp "Font loaded"
:Else
: Disp "Load failed"
: Disp Ans
:End

:""→Str0
:Asm(prgmFLOADB
:If Ans=0
:Then
: Disp "Font uninstalled"
:Else
: Disp "Uninstall failed"
: Disp Ans
:End
```

## Build

### Requirements

- `spasm-ng` Windows binary at `../tools/spasm/win/spasm.exe`
- repository include files in `../include/`

### Build command

```bat
build.bat
```

Produces `../build/FLOADB.8xp`.

## Test

Test assets are in `tests/`:

- `TESTFLO.txt` (source)
- `TESTFLO.8xp` (compiled tester)
- `ComicSan.8xv` (AppVar font test asset)
- `FONTGRPT.8cg` (group test asset containing multiple fonts)

`TESTFLO` checks:

- Missing font path (`Ans=1`)
- AppVar load (`Ans=0`)
- Group-member loads (`Ans=0`)
- Empty `Str0` uninstall (`Ans=0`)
- Missing group member (`Ans=1`)

## Troubleshooting

- `Ans=1` unexpectedly: verify source variable is archived and has valid font pack data.
- Group path issues: ensure format is exactly `GROUPNAME/MEMBERNAME`.
- No visible change after success: run text display tests or switch to home screen output.

## Related Files

- `floadb.asm`
- `build.bat`
- `tests/TESTFLO.txt`

## License

See repository root `LICENSE`.
