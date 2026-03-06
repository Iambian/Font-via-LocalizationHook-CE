# TTF font to TI-84 CE font converter

## UI Mockup
```
---------------------------------------
||------------| [L][S][Project name]  |
||            |       |-------|       |
||Font Canvas |       |Preview|       |
||            |       |-------|       |
||            |    [Encodings: v]     |
||Zoomable    |  View:[Large][Small]  |
||Pannable    |-----------------------|
||Selectable  |[_][Fontpath][Fontname]|
||            |[Fontsize][Aliasing: v]|
||            |-----------------------|
||            | [Output Target: v]    |
||            | [Output basename]     |
||------------|       [EXPORT]        |
---------------------------------------
```
## UI Specification

-   Font Canvas: Displays the current FontData object's glyph array image.
    This image is zoomable using the mouse wheel. Minimum zoom is x1, maximum
    zoom is x8. Panning is done via dragging with the left mouse button.
    Selecting is done via left click. Selections overlay a red box based on
    the font variant, and the underlying image's position and zoom level.
-   Project name is the full path and name of this project. Default location is
    in the `projects` folder inside this one. Create it if it doesn't exist.
    Add a load button and a save button. Default project name is "UNTITLED".
    Recognized extension is ".cefont". Internally, this is a JSON file.
-   Preview: A preview designed to show the currently selected glyph
    at x8 zoom.
-   Encodings: A drop-down populated by the contents of `src\encodings.json`.
-   View: Two buttons "Large" and "Small". Pressing one will keep it pressed
    while unpressing the other. The section below this maps to one or the other.
-   Fontpath/Fontname: Path and name, separate. Add a folder button to allow
    filesystem navigation. Default value is `../fonts` and `OpenSans.ttf`.
-   Fontsize: In points. Large font default is 12, small font default is 11.
-   Aliasing: A drop-down containing bi-level rendering algorithms.
    This list should contain at least these:
    -   Direct 1-Bit
    -   Hinted 1-Bit
    -   Downsampling
    -   Thresholding
-   Output target: Affects what the this application will export. Allows
    export to "Standalone (8xp)", "Viewer Only (8xv)", "Standalone (C)"
    and "Viewer Only (C)". Other modes may be added as needed.
-   Output basename: Limit 8 characters, no extension. The default value is
    the same as 
-   Export button: Performs the export process using the large and small font
    datasets that have been loaded. Export will be specified in a separate document.

## Data Specification

-   AppState: All data-carrying UI elements update this. This tracks:
    -   Name and location of this project
    -   Which encoding is being used
    -   Which font variant is being viewed (large or small)
        -   Name and location of this font variant
        -   Size (in points) of this font variant
        -   Aliasing algorithm of this font variant
        -   Nudging data for this font variant
    -   Currently selected glyph
    -   Current output target
    -   Current output basename
    -   Current FontData instance
    -   Cached FontData instances
    -   Font canvas view transform
        -   Scale
        -   pan_x
        -   pan_y
    Any time an input that would change FontData identity changes, the current
    FontData object is put into cache and a lookup attempt on the cache is
    made for the new input. If one is not found, a new FontData instance using
    that data is generated.


-   FontData: Contains all the data needed by the UI to render and the data
    needed by the export function to export the data. The identity of this
    object is dictated by these hashable/immutable objects:
    -   Encoding used (name only)
    -   Name and location of both the large and small font variants
    -   Size of both the large and small font variants
    -   Aliasing algorithm of the large and small font variants
    This object additionally tracks but does not own:
    -   Nudging data for all mapped glyphs for the small and large font variants
    This class generates the following using the above input:
    -   Base image data for each glyph
    -   Nudged image data for each glyph (optional/cached)
    -   Ready-to-display 16x16 glyph grid 
    When initialized with the parameters above, this class generates a base
    image for each mapped glyph according to the bi-level algorithm specified.
    This image is adjusted such that the glyph is vertically-centered and 
    left-aligned. This step does not use nudging data.
    The allowed space for each glyph is as follows:
    -   Large font: 12 by 14 pixels
    -   Small font: 16 by 12 pixels
    Glyph data outside this space is cropped out.
    After glyph image generation is done, a 16x16 glyph grid containing all
    mapped glyphs is created with a 1 pixel wide gray border around each
    cell in the grid. The upper-left cell represents glyph 0x00 and
    the bottom-right cell represents glyph 0xFF. The contents of each cell is
    adjusted by the per-glyph nudging data. This image is modified each time
    nudging data is changed. The image retrieved depends on whether the large
    or small font variant is being asked for.
    During export, it is expected that the base image data for the
    large and small font data is exposed for examination.

-   Encodings: Read from `encodings.json`. Top-level object lists the names
    of each encoding. The property of each encoding is an object containing
    key-value pairs of all mapped codepoints. The key is the codepoint that
    the TI-84 Plus CE uses while the value is the unicode character that
    represents that codepoint.

-   ProjectData: Contains the identity information and the nudging data
    from the project's last known FontData class instance.





## Additional Notes

`encodings.json` in the `src` folder can be regenerated using the `generate.py` standalone script.

