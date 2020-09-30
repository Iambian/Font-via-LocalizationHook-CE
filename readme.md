Font-Through-Localization Hook for the CE
=========================================

Not sure why I wanted this on a CE, but the more I worked at it the more
fun it got. If you're tired of the default font that the calculator displays
most things in, you can use this to change that.

This was originally a font hook, but small font support was removed for some
reason. The localization hook needed to be used instead in order to access
the small font as well as the large font.

Usage
-----
1.	Send `FONTHOOK.8xp` to the calculator.
2.	Run it from the homescreen with the `Asm(` token found in the catalog. It
	should look like `Asm(prgmFONTHOOK)`
3.	You're done.
4.	If you want to uninstall it, run it again. You may need to unarchive it
	first.

Limitations
-----------
*	Only changes alphanumeric characters (both upper and lower case). The source
	can be modified to accept a wider range but you'll have to encode those
	yourself.
*	The hook only persists until the next `Garbage Collect`. Re-run the hook if
	you need do this.
*	The program MUST be named `FONTHOOK` since it self-references for
	hook install. If you have to change the name, you also have to change the
	reference under the `fh_FileName` label in `main.z80`.
	
Build Dependencies
------------------
*	[Python 3.x](https://www.python.org/)
*	PIL/Pillow (Python Imaging Library)

How to Build
------------
*	Open up the `tools/fontpacker` directory
*	Copy the fonts you want to use into that folder
*	Modify the final few lines in `packer.py` to use the fonts you chose
*	Run the packer from the command line. (e.g. `> py packer.py`)
*	Examine output.txt and output2.txt to make manual modifications if needed
*	Open up the project root directory
*	Run `build.bat`
*	If it all went well, `FONTHOOK.8xp` should be in the `bin` folder. Try it
	out and see if the text needs further adjustments.

Troubleshooting
---------------
*	I can't find the `Asm(` token.
	*	It should be near the top of the catalog. Get to the catalog by pushing
		<kbd>2nd</kbd> then <kbd>0</kbd>.
	*	If you still can't find it, then it was probably removed and you'll need
		a jailbreak/os downgrade to get it back again.
*	Where can I find fonts?
	*	You can grab them from the Fonts directory somewhere on your computer.
		For example, on my Windows 7 install, I have mine in `C:\Windows\Fonts`.
	*	Find them online at the other end of a Google search. I like using
		[DaFont](https://www.dafont.com/). There are many other places.


Licenses
--------

For my stuff: Do what you want.

For the other stuff: Comic Sans belongs to Microsoft, used without permission.


