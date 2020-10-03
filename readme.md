Font-Through-Localization Hook for the CE
=========================================

**THIS BRANCH OF THE PROJECT IS INCOMPLETE. DOCUMENTATION MAY EITHER
BE NON-EXISTANT OR INCORRECT**

Build Dependencies
------------------
* [CE C Toolchain](https://github.com/CE-Programming/toolchain/)
* [Python 3.x](https://www.python.org/)
* PIL/Pillow (Python Imaging Library)

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



