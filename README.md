Swift8
=====
A CHIP-8 emulator for Mac, written in Swift.

By [Lee Morgan](http://shiftybit.net). If you find this useful please let me know. I'm [@leemorgan](https://twitter.com/leemorgan) on twitter.

The screen rendering and input handling are intentionally done with simple Cocoa methods.

If you're looking for a version in C please check out [Chip8](https://github.com/leemorgan/Chip8)

Input
=====
Keyboard input uses the following layout<br/>
1 2 3 4<br/>
Q W E R<br/>
A S D F<br/>
Z X C V<br/>

These map to the following CHIP-8 hex keypad inputs<br/>
1 2 3 C<br/>
4 5 6 D<br/>
7 8 9 E<br/>
A 0 B F<br/>


ROMs
====
In the 'ROMs' folder you can find a few public domain CHIP-8 ROMs.


Screenshots
===========

![Alt text](/screenshots/brix.png "BRIX Screenshot")

![Alt text](/screenshots/pong.png "PONG Screenshot")

Useful References
=================

[Chip8 - My CHIP-8 Emulator written in C](https://github.com/leemorgan/Chip8)

[CHIP-8 Wikipedia entry](https://en.wikipedia.org/wiki/CHIP-8)

[Mastering CHIP-8](http://mattmik.com/chip8.html)

[Chip-8 Technical Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)

[How to write an emulator (CHIP-8 interpreter)](http://www.multigesture.net/articles/how-to-write-an-emulator-chip-8-interpreter/)


License
=======
The license is contained in the "License.txt" file.
