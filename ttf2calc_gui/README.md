# ttf2calc_gui

A graphical TTF-to-TI-84 CE font pack converter.

## What this tool is for

`ttf2calc_gui` lets you:
- Load a font and map it through one of the supported TI encodings.
- Build **large** and **small** variants separately (font path/name/size/aliasing per variant).
- Preview glyphs in a zoomable/pannable grid.
- Nudge individual glyph placement.
- Export TI font artifacts (currently `.8xp` and `.8xv` paths are implemented).

This is intended for creating calculator font packs compatible with the localization-hook-based workflow in this repository.

## Requirements

- Python 3.10+
- Pillow (`PIL`)
- `fontTools` (imported by `core.py`)
- Windows environment for export toolchain (uses `tools/spasm-ng.exe`)

## How to run

From the `ttf2calc_gui` folder:

```bash
python main.py
```

## How to use

1. **Project controls**
   - Use the folder/save buttons to load/save `.cefont` project files.
   - Project state is stored in `ttf2calc_gui/projects` by default.

2. **Choose encoding and view**
   - Select an encoding from the dropdown.
   - Toggle between `Large` and `Small` view to edit each variant.

3. **Configure font variant**
   - Set font folder + filename.
   - Set point size.
   - Choose aliasing mode.
   - Changes update rendering state automatically.

4. **Inspect and edit glyphs**
   - Click a glyph in the canvas to select it.
   - Mouse wheel = zoom, left-drag = pan.
   - Arrow keys nudge selected glyph position.
   - `Reset Nudging` clears nudges for the active variant.

5. **Export**
   - Select output target:
     - `Standalone (8xp)`
     - `Viewer Only (8xv)`
     - `Standalone (C)` (not implemented)
     - `Viewer Only (C)` (not implemented)
   - Enter output basename.
   - Click export.
   - Status message under the button reports success/failure.

## What to expect

- Exported artifacts are written to the repository-level `build` folder.
- `.8xp` naming is sanitized to uppercase alphanumeric, max 8 chars, and cannot start with a digit.
- `.8xv` naming requires ASCII characters.
- Some encoding entries may map to multi-codepoint Unicode strings; exporter handles this in comments/metadata.
- If both large and small variants lack drawable pixels for a mapped codepoint, that mapping is omitted in packed output.

## Current limitations

- C export targets are placeholders (`NotImplementedError`).
- Packing/export logic is functional but still evolving with project requirements.
- Visual/debug formatting and some UI details are development-oriented.

## Related files

- Entry point: `ttf2calc_gui/main.py`
- UI: `ttf2calc_gui/src/ui.py`
- Core/render/export: `ttf2calc_gui/src/core.py`
- Design notes: `ttf2calc_gui/DESIGN.md`
