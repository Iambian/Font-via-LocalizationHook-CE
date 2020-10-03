Font-Through-Localization Hook for the CE
=========================================

**THIS BRANCH OF THE PROJECT IS INCOMPLETE. DOCUMENTATION MAY EITHER
BE NON-EXISTANT OR INCORRECT**

Build Dependencies
------------------
* [CE C Toolchain](https://github.com/CE-Programming/toolchain/)
* [Python 3.x](https://www.python.org/)
* PIL/Pillow (Python Imaging Library)

Building a Font
---------------
1. Edit `packer.py` in the `builder` folder to configure the font you want to build.
   * Assume the current directory is `builder` for all file/directory purposes.
   * Scroll to the bottom of the file. It's where all the important stuff is.
   * Set `encodings_in_my_json_file`
     - To a JSON file with encodings. See examples in `builder/fonts`. You can make
       your own to get more support for such things as accented characters and
       mathematical symbols.
     - To `None`. That'll default mapping in only alphanumeric characters.
   * Modify the two `packit()` function calls.
     - First argument is name of font file. I keep mine in `builder/fonts`
     - Second argument is size of font, in points. This needs to be iteratively
       tweaked to get better results; this tool can't automatically do this.
2. Run `packfont.bat` in the `hook` folder. This will generate `encodings.asm`,
   `lfont.asm`, and `sfont.asm` in the `hook/obj` folder. You can manually tweak these
   files so long as you don't run this batch script again.
3. Still in the `hook` folder? Great. Open a console window in this folder. You
   can build two different font types:
   * A font that can install itself, just like things were before this change.
     - Run `build_standalone.bat <NAME>` where `NAME` is up to 8 characters, all
       characters are uppercase, contains no non-alphanumeric characters, and does
       not start with a number.
   * A font that requires use of a font viewing program to install. Use this if
     you have a viewer and don't want files to clutter your programs list.
     - Run `build_resource.bat [NAME]` where `NAME` is a valid file name for
       use on the calculator. You *must* supply a name. The name can be nearly
       anything 8 characters or less. It must not contain spaces.
4. Collect the resulting `.8xp` or `.8xv` file from the `hook/bin` folder.

Editing a Font Encoding
-----------------------
To start, here's some helpful references you should keep open. You'll need them.
- The `asciish.json` file in the `builder/font` folder, as a visual and example.
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

Remember the name of the JSON file you created and use during step 1 of building your font


Basic rundown of the TODO list
------------------------------

* Write docs for tools in `builder`. Added modified encoding settings via
  JSON scripts in the `builder/fonts` folder. Also aiming to remove all the
  non-free .ttf/.otf/other font files to help avoid running afoul of copyright.
* Possibly rename `builder` to `packer` but windows is preventing me right now.
* Write docs for using the tools in `hook` directory. Sufficient docs exist
  in the batch file comments. Long and short: run `packfont.bat` first and
  run `build_standalone.bat` to mimic old behavior.
* Examples may include copyrighted material. Unsure of the details there.
  They'll remain until I find suitable free fonts to replace them.
* `packer.py` still needs work. A refined method of height adjustments and
  perhaps storing per-character offsets for each font? Need some help there.
* The real purpose of this branch was to add a font (pre)viewer tool and to
  allow easier ways to load more than one different font onto the calculator
  at the same time. Requiring every font to be named "FONTHOOK" was getting old.
* Turns out the catalog help is getting corrupted. Gotta go fish around the
  OS to figure out what event that's triggered on and handle it too. Because
  all the special newfangled things require all the special handling.

Licenses
--------

For my stuff: Do what you want.

For the other stuff: This time, it's Courier New that's being used. Can't find
any copyright information on them but the internet suggests that IBM let
this one go.

Credits
-------

*	jacobly - thanks for all the technical help with the hooks including help on
				pointing me in the right direction and stuff that isn't in
				any documentation anywhere. Probably not even at TI.
*	Cemetech - A site and a community. It's a great place to be.
*	geekboy1011 - Provider of cherries and sanity. Also wouldn't have started
				this whole let's-hook-into-all-the-things business without his
				initial suggestion for a particular homescreen hook.
                        Also provided excellent rubberducking for the new encoding
                        method and file structure. And for a viewer.



