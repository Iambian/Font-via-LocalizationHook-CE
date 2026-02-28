Font Loader - BASIC Utility (FLOADB)
=====================================

`FLOADB` is a BASIC-callable assembly utility that installs a font through the
localization hook using a name provided in `Str0`.

If the font install succeeds, future strings displayed by BASIC are rendered in
the newly installed font until another font is installed.

If `Str0` is empty, `FLOADB` uninstalls any currently installed font.

Build Dependencies
------------------
* [spasm-ng](https://github.com/alberthdev/spasm-ng) assembler
* `ti84pce.inc` and project include files in `include/`

Building
--------
1. Open a terminal in the `floadb` folder.
2. Run `build.bat`.
3. Output program: `FLOADB.8xp`

Input and Output
----------------
**Input:**
* `Str0` = font name to load
* `Str0=""` = uninstall currently installed font

**Output (stored to `Ans`):**
* `0` = success (install or uninstall)
* `1` = failure (not found, invalid source, bad format, or other load failure)

Name Format
-----------
`FLOADB` supports loading from either a direct AppVar/program name or a group member path:

* Direct name (example): `"ComicSan"`
* Group path (example): `"FONTGRPT/ARIAL"`

The slash `/` separates group name and member name.

Basic Usage Example
-------------------
```
"ComicSan"->Str0
Asm(prgmFLOADB
If Ans=0
Then
 Disp "Font loaded"
 Disp "Sample: ABC abc 123"
Else
 Disp "Load failed"
 Disp Ans
End

""->Str0
Asm(prgmFLOADB
If Ans=0
Then
 Disp "Font uninstalled"
Else
 Disp "Uninstall failed"
 Disp Ans
End
```

Test Program
------------
An ASCII-only tester is provided at `tests/TESTFLO.txt`. For convenience, the
following binaries are also supplied:
* The compiled tester `tests/TESTFLO.8xp`
* The AppVar font file `tests/ComicSan.8xp`
* A group file `tests/FONTGRPT.8xg` containing the font programs `ARIAL`, `COMICSAN`, and `OPENSANS`

The tester checks:
* Missing font error path
* AppVar install (`ComicSan`)
* Group member installs (`FONTGRPT/ARIAL`, `FONTGRPT/OPENSANS`)
* Empty `Str0` uninstall path
* Missing group member error path
* Font uninstall

Expected Return Codes in Tests
------------------------------
* Success cases: `Ans=0`
* Failure cases: `Ans=1`

Notes
-----
* Each successful install replaces the previous one.
* Passing an empty `Str0` explicitly uninstalls the active font.
* Name length and format must fit TI variable naming constraints.

Related Components
------------------
* `hook/` - localization hook and font package format
* `viewer/` - visual browser/installer (`FONTVIEW`)
* `feditb/` - BASIC utility for reading/editing glyph data


