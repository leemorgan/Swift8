# CHIP-8 Architecture

##Registers

CHIP-8 doesn't have any interupt or hardware registers.

There are two timer registers that count at 60Hz. When set above zero they will count down to zero.
The system's buzzer sounds whenever the sound timer reaches zero.
Fifteen 8-bit general purpose registers named V0,V1...VE

One 1-bit register (VF) used for the 'carry flag' in math operations

Index Register (I) and Program Counter (PC) can have a value from 0x000 - 0xFFF (0 - 4095). That is to say, they can point at any location in the 4KB of memory.

## System Memory Map
4KB memory

0x000 - 0x1FF : Where the CHIP-8 interpreter is stored

0x000 - 0x080 : Built in 4x5 pixel hex fontset (0,1,2...9,A,B...F)

0x200 - 0xFFF : Used for program ROM and RAM

**Note:** Historicaly the CHIP-8 interpreter itself occupies the first 512 bytes (0x000-0x1FF) of the memory space.
For this reason, programs written for the original system begin at memory location 512 (0x200) and do not access any of the memory below that location.

## Stack
It is important to note that the CHIP-8 instruction set has opcodes that allow the program to jump to a certain address, or call a subroutine.

The stack is used to remember the current location before a jump is performed. So anytime we perform a jump, or call a subroutine, we must store the program counter in the stack before proceeding.

The system has up to 16 levels of stack and in order to remember which level of the stack is used, we need to implement a stack pointer (sp).

## Keypad Input
The CHIP-8 system has a HEX based keypad (0x0 - 0xF)

## Graphics
CHIP-8 has one instruction that draws sprite to the screen.
Drawing is done in XOR mode and if a pixel is turned off as a result of drawing, the VF register is set. This is used for collision detection.

The graphics of the CHIP-8 are black and white and the screen has a total of 2048 pixels (64 x 32).
Graphics are drawn to the screen solely by drawing sprites, which are 8 pixels wide and may be from 1 to 15 pixels in height. 

Sprite pixels that are set flip the color of the corresponding screen pixel, while unset sprite pixels do nothing. 
The carry flag (VF) is set to 1 if any screen pixels are flipped from set to unset when a sprite is drawn and set to 0 otherwise.

## Opcodes

35 opcodes

All opcodes are two bytes long. The most significant byte is stored first.

**NNN** : 12-bit address

**NN** : 8-bit constant

**N** : 4-bit constant

**X** : 4-bit register identifer

**Y** : 4-bit register identifier

#### Opcode Table

**0NNN** : Calls RCA 1802 program at address NNN. (not implemented)

**00E0** : Clears the screen.

**00EE** : Returns from a subroutine.

**1NNN** : Jumps to address NNN.

**2NNN** : Calls subroutine at NNN.

**3XNN** : Skips the next instruction if VX equals NN.

**4XNN** : Skips the next instruction if VX doesn't equal NN.

**5XY0** : Skips the next instruction if VX equals VY.

**6XNN** : Sets VX to NN.

**7XNN** : Adds NN to VX.

**8XY0** : Sets VX to the value of VY.

**8XY1** : Sets VX to VX or VY.

**8XY2** : Sets VX to VX and VY.

**8XY3** : Sets VX to VX xor VY.

**8XY4** : Adds VY to VX. VF is set to 1 when there's a carry, and to 0 when there isn't.

**8XY5** : VY is subtracted from VX. VF is set to 0 when there's 
a borrow, and 1 when there isn't.

**8XY6** : Shifts VX right by one. VF is set to the value of the least significant bit of VX before the shift.

**8XY7** : Sets VX to VY minus VX. VF is set to 0 when there's a borrow, and 1 when there isn't.

**8XYE** : Shifts VX left by one. VF is set to the value of the most significant bit of VX before the shift.

**9XY0** : Skips the next instruction if VX doesn't equal VY.

**ANNN** : Sets I to the address NNN.

**BNNN** : Jumps to the address NNN plus V0.

**CXNN** : Sets VX to a random number and NN.

**DXYN** : Draws a sprite at coordinate (VX, VY) that has a width of 8 pixels and a height of N pixels. Each row of 8 pixels is read as bit-coded starting from memory location I; I value doesn't change after the execution of this instruction. VF is set to 1 if any screen pixels are flipped from set to unset when the sprite is drawn, and to 0 if that doesn't happen

**EX9E** : Skips the next instruction if the key stored in VX is pressed.

**EXA1** : Skips the next instruction if the key stored in VX isn't pressed.

**FX07** : Sets VX to the value of the delay timer.

**FX0A** : A key press is awaited, and then stored in VX.

**FX15** : Sets the delay timer to VX.

**FX18** : Sets the sound timer to VX.

**FX1E** : Adds VX to I.

**FX29** : Sets I to the location of the sprite for the character in VX. Characters 0-F (in hexadecimal) are represented by a 4x5 font.

**FX33** : Stores the Binary-coded decimal representation of VX, with the most significant of three digits at the address in I, the middle digit at I plus 1, and the least significant digit at I plus 2. (In other words, take the decimal representation of VX, place the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.)

**FX55** : Stores V0 - VX in memory starting at address I.

**FX65** : Fills V0 - VX with values from memory starting at address I.