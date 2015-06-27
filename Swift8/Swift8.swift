
import AppKit


class Swift8 {
	
	// Program Counter (PC)
	var pc : UInt16 = 0x200 // Programs are loaded in starting at the 512th byte (0x200 in Hex).
	
	// VRAM. 64x32 beautiful pixels.
	var gfx = Array(count: 64, repeatedValue: [Int](count: 32, repeatedValue: 0))
	
	// The Stack and Stack Pointer
	var stack = [UInt16](count: 16, repeatedValue: 0)
	var sp    = 0
	
	// Registers
	// VF (register 16) is a special register that is reserved for carry operations.
	var V = [UInt8](count: 16, repeatedValue: 0)
	var VF : UInt8 {
		get {
			return V[0xF]
		}
		set {
			V[0xF] = newValue
		}
	}
	
	// Index Register (sometimes called the Address register) is 12-bits wide and is used with several opcodes that involve memory operations
	var I : UInt16 = 0

	var delayTimer : UInt8 = 0
	var soundTimer : UInt8 = 0
	
	// Keypad. Used to represent the input from a Hex keypad.
	enum KeypadStatus {
		case On
		case Off
	}
	var keypad = [UInt8:KeypadStatus]()
	
	// System Memory (4KB)
	// The first 512 bytes are reserved by the CHIP-8 system. Of which the lower 80 bytes are used to store the Fontset
	var memory : [UInt8] = {
		
		var memory = [UInt8](count: 4096, repeatedValue: 0)
		
		let fontset: [UInt8] = [
			0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
			0x20, 0x60, 0x20, 0x20, 0x70, // 1
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
	
	
	var needsDisplay = false	// Used to let the renderer (Swift8View) know when we have updated the graphics (see opcode Dxyn)
	var clockTimer	: NSTimer?
	var cpuTimer	: NSTimer?
	
	var paused : Bool {
		get {
			if cpuTimer != nil {
				return false
			}
			return true
		}
		set {
			if newValue == true {
				cpuTimer?.invalidate()
				cpuTimer = nil
				
				clockTimer?.invalidate()
				clockTimer = nil
			}
			else {
				if cpuTimer == nil {
					cpuTimer = NSTimer.scheduledTimerWithTimeInterval(1.0/600.0, target: self, selector: "step", userInfo: nil, repeats: true)
				}
				if clockTimer == nil {
					clockTimer = NSTimer.scheduledTimerWithTimeInterval(1.0/60.0, target: self, selector: "stepClock", userInfo: nil, repeats: true)
				}
			}
		}
	}
	
	
	init() {
		srandom(UInt32(time(nil))) // seed the random number generator
	}
	
	func reset() {
		
		pc = 0x200
		
		gfx = Array(count: 64, repeatedValue: [Int](count: 32, repeatedValue: 0))
		
		stack = [UInt16](count: 16, repeatedValue: 0)
		sp    = 0
		
		V = [UInt8](count: 16, repeatedValue: 0)
		
		I = 0
		
		delayTimer = 0
		soundTimer = 0
		
		keypad = [UInt8:KeypadStatus]()
	}
	
	func loadROM(path: String) {
		
		reset()
		
		/*
		The ROM is stored as 8-bit chunks on disk...
		Alloc a buffer to read the ROM into, then copy the ROM into memory.
		*/
		let buffer = UnsafeMutablePointer<UInt8>(calloc(3584, sizeof(UInt8)))
		if buffer != nil {
			let rom = fopen(path, "r")
			if rom != nil {
				fread(buffer, sizeof(UInt8), 3584, rom)
				
				for i in 0..<3584 {
					memory[512 + i] = UInt8(buffer[i])
				}
			}
			fclose(rom)
		}
		
		paused = false
	}
	
	func keydown(key: UInt8) {
		keypad[key] = .On
	}
	
	func keyup(key: UInt8) {
		keypad[key] = .Off
	}
	
	@objc func stepClock() {
		
		if delayTimer > 0 {
			delayTimer--
		}
		
		if soundTimer > 0 {
			NSBeep()
			soundTimer--
		}
	}
	
	@objc func step() {
		
		/* 
		Grab the opcode from memory
		Opcodes are 2-bytes wide. And our RAM is stored as an array of bytes.
		We can build an opcode by reading in the first byte from RAM into the opcode register, shifting it to the left, 
		and then reading in the second byte into the opcode register.
		*/
		let opcode: UInt16 = {
			var o = UInt16( self.memory[self.pc] )
			o <<= 8
			o |= UInt16( self.memory[self.pc + 1] )
			return o
			}()
		
		// We break the opcode down into nibbles (4-bit chunks).
		// Then we combine them in a Tuple to switch upon each nibble of the opcode.
		let ocn1 = (opcode & 0xF000) >> 12
		let ocn2 = (opcode & 0x0F00) >> 8
		let ocn3 = (opcode & 0x00F0) >> 4
		let ocn4 = (opcode & 0x000F)
		
		let opcodeTuple = (ocn1, ocn2, ocn3, ocn4)
		
		
		switch opcodeTuple {
			
		case (0, 0, 0xE, 0):	// 00E0		CLS
			
			for col in 0..<64 {
				for row in 0..<32 {
					gfx[col][row] = 0
				}
			}
			pc += 2
			
		case (0, 0, 0xE, 0xE):	// 00EE		RET
			
			if sp <= 0 {
				println("WARNING: Stack Underflow")
				return
			}
			sp--
			pc = stack[sp]
			
		case (0, _, _, _):		// 0nnn		SYS addr
			println("WARNING: SYS addr is not implemented")
			
		case (1, _, _, _):		// 1nnn		JP addr
			
			pc = getNNN(opcode)
			
		case (2, _, _, _):		// 2nnn		CALL addr
			
			if sp+1 > 15 {
				println("WARNING: Stack Overflow")
				return
			}
			stack[sp] = pc + 2
			sp++
			pc = getNNN(opcode)
			
		case (3, _, _, _):		// 3xnn		SE Vx, byte
			
			let x  = getX(opcode)
			let nn = getNN(opcode)
			
			if V[x] == nn {
				pc += 4
			}
			else {
				pc += 2
			}
			
		case (4, _, _, _):		// 4xnn		SNE Vx, byte
			
			let x  = getX(opcode)
			let nn = getNN(opcode)
			
			if V[x] != nn {
				pc += 4
			}
			else {
				pc += 2
			}
			
		case (5, _, _, 0):		// 5xy0		SE Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			if V[x] == V[y] {
				pc += 4
			}
			else {
				pc += 2
			}
			
		case (6, _, _, _):		// 6xnn		LD Vx, byte
			
			let x  = getX(opcode)
			let nn = getNN(opcode)
			
			V[x] = nn
			pc += 2
			
		case (7, _, _, _):		// 7xnn		ADD Vx, byte
			
			let x  = getX(opcode)
			let nn = getNN(opcode)
			
			V[x] = V[x] &+ nn	// Add with overflow
			pc += 2
			
		case (8, _, _, 0):		// 8xy0		LD Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			V[x] = V[y]
			pc += 2
			
		case (8, _, _, 1):		// 8xy1		OR Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			V[x] = V[x] | V[y]
			pc += 2
			
		case (8, _, _, 2):		// 8xy2		AND Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			V[x] = V[x] & V[y]
			pc += 2
			
		case (8, _, _, 3):		// 8xy3		XOR Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			V[x] = V[x] ^ V[y]
			pc += 2
			
		case (8, _, _, 4):		// 8xy4		ADD Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			if V[y] > (255 - V[x])  {
				VF = 1	// Set the carry bit
			}
			else {
				VF = 0
			}
			V[x] = V[x] &+ V[y]	// Add with overflow
			pc += 2
			
		case (8, _, _, 5):		// 8xy5		SUB Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			if V[x] > V[y] {
				VF = 1
			}
			else {
				VF = 0
			}
			V[x] = V[x] &- V[y]	// Subtract with underflow
			pc += 2
			
		case (8, _, _, 6):		// 8xy6		SHR Vx {, Vy}
			
			let x = getX(opcode)
			
			VF = V[x] & 0x0001
			V[x] >>= 1
			pc += 2
			
		case (8, _, _, 7):		// 8xy7		SUBN Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			if V[y] > V[x] {
				VF = 1
			}
			else {
				VF = 0
			}
			V[x] = V[y] &- V[x]	// Subtract with underflow
			pc += 2
			
		case (8, _, _, 0xE):	// 8xyE		SHL Vx {, Vy}
			
			let x = getX(opcode)
			
			VF = V[x] & 0b10000000 // VF = V[x] >> 7
			V[x] <<= 1
			pc += 2
			
		case (9, _, _, 0):		// 9xy0		SNE Vx, Vy
			
			let x = getX(opcode)
			let y = getY(opcode)
			
			if V[x] != V[y] {
				pc += 4
			}
			else {
				pc += 2
			}
			
		case (0xA, _, _, _):	// Annn		LD I, addr
			
			let nnn = getNNN(opcode)
			I = nnn
			pc += 2
			
		case (0xB, _, _, _):	// Bnnn		JP V0, addr
			
			let nnn = getNNN(opcode)
			pc = nnn + UInt16( V[0] )
			
		case (0xC, _, _, _):	// Cxnn		RND Vx, byte
			
			let x = getX(opcode)
			let nn = getNN(opcode)
			let randomByte = UInt8( random() & 0x00FF ) 
			
			V[x] = randomByte & nn
			pc += 2
			
		case (0xD, _, _, _):	// Dxyn		DRW Vx, Vy, nibble
			
			let x = getX(opcode)
			let y = getY(opcode)
			let height = getN(opcode)
			
			VF = 0
			
			for yLine in 0..<height {
				
				var row = yLine + V[y]
				if row > 31 {
					break
				}
				
				for xLine : UInt8 in 0..<8 {
					// Each pixel is one bit.
					// Each sprite is 1 byte wide.
					// So we step through each bit checking if it is set.
					var pixel = memory[I + UInt16(yLine)] & UInt8( (0x80 >> xLine) )
					
					if pixel != 0 {
						var col = xLine + V[x]
						if col > 63 {
							break
						}
						if gfx[col][row] == 1 {
							VF = 1
						}
						gfx[col][row] = gfx[col][row] ^ 1
					}
				}
			}
			needsDisplay = true
			pc += 2
			
		case (0xE, _, 9, 0xE):	// Ex9E		SKP Vx
			
			let x = getX(opcode)
			let vx = V[x]
			
			if let keypadStatus = keypad[vx] {
				switch keypadStatus {
				case .On:
					pc += 4
				case .Off:
					pc += 2
				}
			}
			
		case (0xE, _, 0xA, 1):	// ExA1		SKNP Vx
			
			let x = getX(opcode)
			let vx = V[x]
			
			if let keypadStatus = keypad[vx] {
				switch keypadStatus {
				case .On:
					pc += 2
				case .Off:
					pc += 4
				}
			}
			
		case (0xF, _, 0, 7):	// Fx07		LD Vx, DT
			
			let x = getX(opcode)
			
			V[x] = delayTimer
			pc += 2
			
		case (0xF, _, 0, 0xA):	// Fx0A		LD Vx, K
			
			let x = getX(opcode)
			var keypress = false
			
			for (key, state) in keypad {
				if state == .On {
					V[x] = key
					keypress = true
					pc += 2
					return
				}
			}
			// We didn't receive a keypress.
			// Don't advance the pc, just let it loop back to this opcode again next cycle.
			
		case (0xF, _, 1, 5):	// Fx15		LD DT, Vx
			
			let x = getX(opcode)
			
			delayTimer = V[x]
			pc += 2
			
		case (0xF, _, 1, 8):	// Fx18		LD ST, Vx
			
			let x = getX(opcode)
			
			soundTimer = V[x]
			pc += 2
			
		case (0xF, _, 1, 0xE):	// Fx1E		ADD I, Vx
			
			let x = getX(opcode)
			
			I += UInt16( V[x] )
			pc += 2
			
		case (0xF, _, 2, 9):	// Fx29		LD F, Vx
			
			let x = getX(opcode)
			
			// Font's are 5 bytes wide and loaded starting at address 0x0. So we multiply by 5 to move to the start of the desired font.
			I = UInt16( V[x] ) * 5
			pc += 2
			
		case (0xF, _, 3, 3):	// Fx33		LD B, Vx
			
			let x = getX(opcode)
			
			memory[I]	=  V[x] / 100
			memory[I+1]	= (V[x] / 10) % 10
			memory[I+2]	=  V[x] % 10
			
			pc += 2
			
		case (0xF, _, 5, 5):	// Fx55		LD [I], Vx
			
			let x = getX(opcode)
			
			for r in 0...x {
				let address = I + UInt16(r)
				memory[address] = V[r]
			}
			// On the original interpreter, when the operation is done, I=I+x+1. On current implementations, I is left unchanged.
			pc += 2
			
		case (0xF, _, 6, 5):	// Fx65		LD Vx, [I]
			
			let x = getX(opcode)
			
			for r in 0...x {
				let address = I + UInt16(r)
				V[r] = memory[address]
			}
			// On the original interpreter, when the operation is done, I=I+x+1. On current implementations, I is left unchanged.
			pc += 2
			
		default:
			println("Unknown Opcode: 0x\(String(opcode, radix: 16, uppercase: false))")
		}
	}
	
	// X is a register identifier. It is stored in the second nibble in the opcode.
	func getX(opcode: UInt16) -> UInt8 {
		return UInt8((opcode & 0x0F00) >> 8)
	}
	
	// Y is a register identifier. It is stored in the third nibble in the opcode.
	func getY(opcode: UInt16) -> UInt8 {
		return UInt8((opcode & 0x00F0) >> 4)
	}
	
	// N is a nibble constant stored in the last nibble of the opcode.
	func getN(opcode: UInt16) -> UInt8 {
		return UInt8(opcode & 0x00F)
	}
	
	// NN is a byte constant stored in the lower byte of the opcode.
	func getNN(opcode: UInt16) -> UInt8 {
		return UInt8(opcode & 0x00FF)
	}
	
	// NNN is a memory address stored in the lower 12 bits of the opcode.
	func getNNN(opcode: UInt16) -> UInt16 {
		return opcode & 0x0FFF
	}
	
	// Print the given opcode in Hex format
	func printOpcode(opcode: UInt16) {
		println("opcode = 0x\(String(opcode, radix: 16, uppercase: false))")
	}
}




// Extend Array so we can access the elements using UInt8 and UInt16 subscripting
extension Array {
	subscript (index: UInt8) -> T {
		get {
			return self[ Int(index) ]
		}
		set {
			self[ Int(index) ] = newValue
		}
	}
	
	subscript (index: UInt16) -> T {
		get {
			return self[ Int(index) ]
		}
		set {
			self[ Int(index) ] = newValue
		}
	}
}
