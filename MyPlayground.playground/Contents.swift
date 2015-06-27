
import Foundation




class Swift8 {
	
	var pc			= 0x200
	var I			= 0
	
	var gfx			= [[UInt8]]()
	
	var stack		= [UInt8]()
	var sp			= 0
	
	var V			= [UInt8]()
	var VF			: UInt8 { return V[0xF] }
	
	var delayTimer	= 0
	var soundTimer	= 0
	
	enum KeypadStatus {
		case On
		case Off
	}
	var keypad = [String:KeypadStatus]()
	
	var memory : [UInt8] = {
		var memory = [UInt8]()
		let fontset: [UInt8] = [
			0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
			0x20, 0x60, 0x02, 0x20, 0x70, // 1
			0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
			0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
			0x90, 0x90, 0xF0, 0x10, 0x10, // 4
			0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
			0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
			0xF0, 0x10, 0x20, 0x40, 0x40, // 7
			0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
			0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
			0xF0, 0x90, 0xF0, 0x90, 0x90, // A
			0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
			0xF0, 0x80, 0x80, 0x80, 0xF0, // C
			0xE0, 0x90, 0x90, 0x90, 0xE0, // D
			0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
			0xF0, 0x80, 0xF0, 0x80, 0x80, // F
		]
		
		for i in 0..<80 {
			memory[i] = fontset[i]
		}
		return memory
		}()
	
	
	func loadRomAtPath(path: String) {
		
		let rom = fopen(path, "r");
		
		let memoryPtr = UnsafeMutablePointer<UInt8>(memory)+512 // we offset 512 bytes from the start of memory
		
		// copy the buffer into memory...
		if (rom != nil) {
			fread(memoryPtr, sizeof(UInt8), 3584, rom)
		}
		fclose(rom)
	}
	
	func cycle() {
		
		/*  Grab the opcode from memory
		Opcodes are 2-bytes wide. And our RAM is stored as an array of bytes.
		We can build an opcode by reading in the first byte from RAM into the opcode register,
		shifting it to the left, and then reading in the second byte into the opcode register. */
		let opcode: UInt16 = {
			var o = UInt16(self.memory[self.pc])
			o <<= 8
			o |= UInt16(self.memory[self.pc + 1])
			return o
			}()
		println("opcode = 0x\(String(opcode, radix: 16, uppercase: false))") // Uncomment to print the opcode
		
		// We break the opcode down into 4-bit chunks (nibbles)
		let ocn1 = (opcode & 0xF000) >> 12
		let ocn2 = (opcode & 0x0F00) >> 8
		let ocn3 = (opcode & 0x00F0) >> 4
		let ocn4 = (opcode & 0x000F)
		
		// Then we combine them in a Tuple to switch upon each nibble of the opcode
		let opcodeTuple = (ocn1, ocn2, ocn3, ocn4)
		
		switch opcodeTuple {
			
		case (0, 0, 0xE, 0):	// 00E0
			println("CLS")
		case (0, 0, 0xE, 0xE):	// 00EE
			println("RET")
		case (0, _, _, _):		// 0nnn
			println("SYS addr")
		case (1, _, _, _):		// 1nnn
			println("JP addr")
		case (2, _, _, _):		// 2nnn
			println("CALL addr")
		case (3, _, _, _):		// 3xnn
			println("SE Vx, byte")
		case (4, _, _, _):		// 4xnn
			println("SNE Vx, byte")
		case (5, _, _, 0):		// 5xy0
			println("SE Vx, Vy")
		case (6, _, _, _):		// 6xnn
			println("LD Vx, byte")
		case (7, _, _, _):		// 7xnn
			println("ADD Vx, byte")
		case (8, _, _, 0):		// 8xy0
			println("LD Vx, Vy")
		case (8, _, _, 1):		// 8xy1
			println("OR Vx, Vy")
		case (8, _, _, 2):		// 8xy2
			println("AND Vx, Vy")
		case (8, _, _, 3):		// 8xy3
			println("XOR Vx, Vy")
		case (8, _, _, 4):		// 8xy4
			println("ADD Vx, Vy")
		case (8, _, _, 5):		// 8xy5
			println("SUB Vx, Vy")
		case (8, _, _, 6):		// 8xy6
			println("SHR Vx {, Vy}")
		case (8, _, _, 7):		// 8xy7
			println("SUBN Vx, Vy")
		case (8, _, _, 0xE):	// 8xyE
			println("SHL Vx {, Vy}")
		case (9, _, _, 0):		// 9xy0
			println("SNE Vx, Vy")
		case (0xA, _, _, _):	// Annn
			println("LD I, addr")
		case (0xB, _, _, _):	// Bnnn
			println("JP V0, addr")
		case (0xC, _, _, _):	// Cxnn
			println("RND Vx, byte")
		case (0xD, _, _, _):	// Dxyn
			println("DRW Vx, Vy, nibble")
		case (0xE, _, 9, 0xE):	// Ex9E
			println("SKP Vx")
		case (0xE, _, 0xA, 1):	// ExA1
			println("SKNP Vx")
		case (0xF, _, 0, 7):	// Fx07
			println("LD Vx, DT")
		case (0xF, _, 0, 0xA):	// Fx0A
			println("LD Vx, K")
		case (0xF, _, 1, 5):	// Fx15
			println("LD DT, Vx")
		case (0xF, _, 1, 8):	// Fx18
			println("LD ST, Vx")
		case (0xF, _, 1, 0xE):	// Fx1E
			println("ADD I, Vx")
		case (0xF, _, 2, 9):	// Fx29
			println("LD F, Vx")
		case (0xF, _, 3, 3):	// Fx33
			println("LD B, Vx")
		case (0xF, _, 5, 5):	// Fx55
			println("LD [I], Vx")
		case (0xF, _, 6, 5):	// Fx65
			println("LD Vx, [I]")
			
		default:
			println("unknown")
		}
	}

}



let chip = Swift8()

//chip.loadRomAtPath("/Users/lee/Developer/ Public Projects/Chip8/ROMs/BRIX")

//println("opcode = 0x\(String(chip.memory, radix: 16, uppercase: false))")


