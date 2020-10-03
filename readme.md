Font Packager Script
====================

TODO: Write an actual readme.

Basic rundown of script functions and other todos.
*   Create three files during packing. (1) encodings.z80 (2) lfont.z80 (3) sfont.z80
*   Encodings is either filled in automagically or from input .json file which
    specifies which encodings go where. Make this separate from packit.
*   The encoder should spit out a unicode string containing all the computer-y characters
    in the order they will appear in the file.
*   packit (commentable out if all you want to do is rebuild w/o 
    overwriting lfont/sfont if you're iterating over fine adjustments)
*   allow pause (commentable out) to allow time for user to manually adjust file
*   autobuild z80 to .8xp file with shell command spasm-ng.exe things.

Actually, you should do just seperate the packer and the builder as we did before.
There's no need to combine them.





