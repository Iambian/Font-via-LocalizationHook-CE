Font-Through-Localization Hook for the CE
=========================================

A customizable font system for the TI-84 Plus CE that uses the localization hook
to replace the calculator's default fonts with your own TrueType fonts.

Build Dependencies
------------------
* [CE C Toolchain](https://github.com/CE-Programming/toolchain/)
* [Python 3.x](https://www.python.org/)
* PIL/Pillow (Python Imaging Library)

Building a Font
---------------
1. Obtain TrueType font files (.ttf) and place them in `builder/fonts/` folder.
   * Create the `fonts` folder if it doesn't exist (it's gitignored to avoid copyright issues).
   * You can use system fonts (e.g., from C:\Windows\Fonts on Windows) or download free fonts.
   * Popular choices: Courier New, Arial, Comic Sans, or any monospace font.
   * Note: Respect font licenses - only use fonts you have rights to distribute.
2. Edit `packer.py` in the `builder` folder to configure the font you want to build.
   * Assume the current directory is `builder` for all file/directory purposes.
   * Scroll to the bottom of the file. It's where all the important stuff is.
   * Set `encodings_in_my_json_file`
     - To a JSON file with encodings. See examples in `builder/encoding/` folder:
       * `asciish.json` - Full ASCII-like character set with special symbols
       * `alphanum.json` - Alphanumeric characters only
       * `upper.json` - Uppercase letters only
       * `lower.json` - Lowercase letters only
     - You can create your own to support accented characters and mathematical symbols.
     - To `None`. That'll default to mapping only alphanumeric characters.
   * Modify the two `packit()` function calls.
     - First argument is path to font file (e.g., `"fonts/cour.ttf"`)
     - Second argument is size of font, in points. This needs to be iteratively
       tweaked to get better results; this tool can't automatically do this.
3. Run `packfont.bat` in the `hook` folder. This will generate `encodings.asm`,
   `lfont.asm`, and `sfont.asm` in the `hook/obj` folder. You can manually tweak these
   files so long as you don't run this batch script again.
4. Still in the `hook` folder? Great. Open a console window in this folder. You
   can build two different font types:
   
   **Standalone Font (Self-Installing Program)**
   * Run `build_standalone.bat <NAME>` where `NAME` is up to 8 characters.
   * Creates a `.8xp` file (Protected Program) that appears in the calculator's PRGM menu.
   * When run, it installs or uninstalls itself as the active font.
   * Use if you want a simple one-file solution.
   * Output: `hook/bin/<NAME>.8xp`
   
   **Resource Font (For Use with Viewer)**
   * Run `build_resource.bat <NAME>` where `NAME` is required, up to 8 characters.
   * Creates a `.8xv` file (AppVar) that doesn't clutter your programs list.
   * Requires the Font Viewer (FONTVIEW) to preview and install.
   * Use if you want to manage multiple fonts with the viewer.
   * Output: `hook/bin/<NAME>.8xv`
   
5. Transfer the resulting file(s) from `hook/bin/` to your calculator.

Editing a Font Encoding
-----------------------
To start, here's some helpful references you should keep open. You'll need them.
- The `asciish.json` file in the `builder/encoding` folder, as a visual and example.
- [Calculator character set](https://en.wikipedia.org/wiki/TI_calculator_character_sets)
- [ASCII character set](https://en.wikipedia.org/wiki/ASCII#Character_set)
- [Mathematical symbols](https://en.wikipedia.org/wiki/Mathematical_operators_and_symbols_in_Unicode)
- [List of unicode characters](https://en.wikipedia.org/wiki/List_of_Unicode_characters)

Configure a character set by creating a JSON file containing single large array.
Inside that array may contain any number of the following items:

- String
  - Contains characters that map directly from ASCII to TI's encoding.
  - Notable exceptions include `DOLLAR SIGN` and `LEFT SQUARE BRACKET`
- Two-element array
  - First: Unicode code for character, in decimal (Note: Codes noted as U+XXXX are
    hexadecimal, even if it looks decimal. Use a calculator to convert hexadecimal
    to decimal.)
  - Second: The decimal codepoint in TI's encoding where the character defined in the
    first element will go.

Remember the name of the JSON file you created and use during step 2 of building your font.

Using the Font Viewer
---------------------
The Font Viewer (FONTVIEW.8xp) is located in `viewer/bin/`. It allows you to browse,
preview, and install font packages without running individual programs.

**Controls:**
* **Up/Down arrows** - Change file type (PROTPROG/APPVAR/GROUPPROG/GROUPAVAR)
* **Left/Right arrows** - Browse through available fonts
* **Y=** - Toggle between large font and small font preview 
* **2nd** - Change the font test view between all-characters and sentences.
* **DEL** - (Un)install the current font
* **MODE** - Exit viewer

**File Types:**
* **PROTPROG** - Standalone fonts (self-installing .8xp files)
* **APPVAR** - Resource fonts (.8xv files built with `build_resource.bat`)
* **GROUP** - Grouped font files

The viewer displays both the large and small font versions, showing how text will
appear on the calculator with that font installed.

Building the Font Viewer
-------------------------
The viewer is pre-built, but to rebuild it:
1. Ensure you have the [CE C Toolchain](https://github.com/CE-Programming/toolchain/) installed.
2. Navigate to the `viewer` folder.
3. Run `make` to build FONTVIEW.8xp.

BASIC Utilities
---------------
This repo also includes BASIC-callable assembly helper programs:

* `floadb` - Font loader utility for BASIC programs. See `floadb/readme.md`.
* `feditb` - Font glyph read/write utility for BASIC programs. See `feditb/readme.md`.

TODO
----

* Refine vertical positioning of individual converted characters.
* Stretch goal: Add full editor UI to dispense with all that
  testing and guessing.


Licenses
--------

* **My stuff**: See `LICENSE`
* **Other stuff**: Example material used without permission.

Credits
-------

*	  jacobly - thanks for all the technical help with the hooks including help on
        on pointing me in the right direction and stuff that isn't in any
        documentation anywhere. Probably not even at TI.
*	  Cemetech - A site and a community. It's a great place to be.
*	  geekboy1011 - Provider of cherries and sanity. Also wouldn't have started
				this whole let's-hook-into-all-the-things business without his initial
				suggestion for a particular homescreen hook. Also provided excellent
        rubberducking for the new encoding method and file structure. 
        And for a viewer.



