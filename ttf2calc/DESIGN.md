# TTF font to TI-84 CE font converter

## UI Mockup
```
----------------------------
|(1) [Foldername][fontname]|
||------------| |-------|  |
||Canvas area | |  (3)  |  |
||16x16 grid  | |-------|  |
||zoomable,   |            |
||pannable (2)|    (5)     |
||------------|            |
|          (4)             |
---------------------------- 
```

1.  A small folder button goes here. It brings up a browse folder
    interface. The foldername is the full path of the folder selected.
    The default value of this is the examples folder in the overall
    project's root directory.
    Add persistence to keep this where it is. The fontname is a drop-down
    containing a list of all found .ttf files in that folder. All of these
    should be on the same row.
    On the row below it should be a checkbox indicating whether or not to
    use the system fonts. If it is checked, the foldername will be replaced
    by the path to the system's font folder, wherever that may be.
    Unchecking this box should revert foldername to it last known value.
    This checkbox is not checked by default.

2.  The canvas area should show a scrollable, zoomable, and pannable grid of
    squares representing the pixels of the font with a gray border around
    but not including the pixels. If the small font checkbox is checked,
    the dimensions of each grid field should be 12x16 pixels. If the box
    is unchecked, the dimensions should be 14x12 pixels. The grid is arranged
    in a 16x16 square, with the top left square representing the first codepoint
    with respect to the calculator's font encoding (0x00), the top right square 
    representing codepoint 0x0F, the bottom left square representing codepoint
    0xF0, and the bottom right square representing codepoint 0xFF.
    What will actually populate these squares will depend on which encoding 
    the user chooses, which font they picked, and whether or not the small font 
    checkbox is checked. 
    All font entries will be drawn in black and white. Any antialiasing is
    disabled. The user can left click on a square to select it, which will
    highlight it with a red border. The right mouse button is used to
    pan the canvas area. The mouse wheel is used to zoom in and out.
    The placement of each glyph is to be vertically-centered left aligned
    inside the square as best as possible. Placement must be deterministic
    since the user will also be able to select a square and use the arrow keys
    to nudge the glyph up, down, left, or right.
    If any part of the glyph would appear outside of the square, it should be
    clipped to the square.
    Care must be taken to render these accurately; this canvas is authoritative
    with regards to the font's appearance on the calculator and will be
    used during the export process to generate the font file.

3.  A zoomed-in view of the currently selected square. The box itself should
    be large enough to accomodate the largest possible dimensions of any font
    entry (14x16) plus a small border of the appropriate dimensions. The zoom
    factor of this shall be 8.

4.  Instructions for the user. This will contain instructions on how the
    font canvas area is used. The area should be appropriately sized to
    fit twice as many instructions as needed so additional instructions
    can be added without changing the dimensions of the window.

5.  This area is used for a number of things. It will contain:
    -   A checkbox for whether or not to use the small font. Unchecked by default.
    -   A drop-down indicating the encoding to use. The default value is the
        topmost entry in the list below. The list of encodings is as follows:
        -   Alphanumeric characters only (ASCII mappings)
        -   All ASCII characters (ASCII mappings)
        -   The closest approximation of the TI-84 Plus CE character set.
        -   Custom (user-defined mappings). This will use the json file labeled
            "custom.json" in the same directory as the converter. The format
            should be the same as the one used for other encodings, which is
            an object/dict containing key-value pairs, where the key is a value
            between 0x00 and 0xFF, where the value is a string containing a single
            character. (e.g. {"0x41": "A", "0x42": "B"})
        These encodings map the position of the calculator codepoint to
        the closest matching codepoint in the font. Most of the time, these
        will be the same, but for the extended set, Unicode must be used.
        Bear in mind that codepoints 0x00-0x1F are also mapped to a displayable
        character.
    -   A checkbox indicating whether or not this font is self-installing.
        If it is checked, the font object will include the installer stub
        and its output filetype will be .8xp (protected program). If it is
        not checked, the font object will not include the installer stub and
        the output filetype will be .8xv (application variable).
        This checkbox is checked by default.
        Checking or unchecking this box will change the file name
        in the input box below but only if the user has not manually changed the
        file name. The font name is considered "changed" if  the file name does 
        not case-insensitively match the default name of the font.
    -   An input box indicating the file name that will appear on the
        calculator. The default name of the font is the name of the font file
        that was imported, subject to the same restrictions as the calculator.
        The following filename restrictions:
        -   No extensions
        -   Must be 1-8 characters long
        -   The first character must be an uppercase letter.
        -   The remaining characters must be uppercase alphanumeric
        If the self-installing checkbox is not checked (is an appvar),
        the filename restriction is loosened to allow lowercase letters as well.

