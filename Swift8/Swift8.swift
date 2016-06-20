
import AppKit


class Swift8 {
	
	/// Program Counter (PC)
	/// Programs are loaded in starting at the 512th byte (0x200 in Hex).
	private var pc : UInt16 = 0x200
	
	/// The Stack
	private var stack = [UInt16](repeating: 0, count: 16)
	
	/// Stack Pointer
	private var sp    = 0
	
	/// Registers 0-16. Register 16 (VF) is reserved.
	private var V = [UInt8](repeating: 0, count: 16)
	
	/// Register 16. A special register that is reserved for carry operations.
	private var VF : UInt8 {
		get {
			return V[0xF]
		}
		set {
			V[0xF] = newValue
		}
	}
	
	/// Index Register (sometimes called the Address register) is 12-bits wide and is used with several opcodes that involve memory operations
	private var I : UInt16 = 0
	
	/// Delay Timer Register
	private var delayTimer : UInt8 = 0
	
	/// Sound Timer Register
	private var soundTimer : UInt8 = 0
	
	/// Keypad Register States
	enum KeypadStatus {
		case on
		case off
	}
	
	/// Keypad Registers - Used to represent the input from a Hex keypad
	private var keypad = [UInt8:KeypadStatus]()
	
	/// System Memory (4KB)
	/// The first 512 bytes are reserved by the CHIP-8 system, of which the lower 80 bytes are used to store the Fontset
	private var memory = [UInt8](repeating: 0, count: 4096)
	
	/// VRAM. 64x32 beautiful pixels.
	internal var vram = Array(repeating: [Int](repeating: 0, count: 32), count: 64)
	
	/// Flag used to indicate the VRAM contents have been updated (Set during opcode Dxyn)
	internal var needsDisplay = false
	
	// Internal timers used to step the system
	private var clockTimer	: Timer?
	private var cpuTimer	: Timer?
	
	
	/// Toggles the system's CPU and Clock timers
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
					cpuTimer = Timer.scheduledTimer(timeInterval: 1.0/600.0, target: self, selector: #selector(Swift8.step), userInfo: nil, repeats: true)
				}
				if clockTimer == nil {
					clockTimer = Timer.scheduledTimer(timeInterval: 1.0/60.0, target: self, selector: #selector(Swift8.stepClock), userInfo: nil, repeats: true)
				}
			}
		}
	}
	
	
	init() {
		// seed the random number generator
		srandom(UInt32(time(nil)))
	}
	
	/// Resets the system. Clears RAM and VRAM contents; resets the Program Counter, Index and other registers; clears the stack.
	func reset() {
		
		pc = 0x200
		
		vram = Array(repeating: [Int](repeating: 0, count: 32), count: 64)
		
		memory = [UInt8](repeating: 0, count: 4096)
		loadFontSet()
		
		stack = [UInt16](repeating: 0, count: 16)
		sp    = 0
		
		V = [UInt8](repeating: 0, count: 16)
		
		I = 0
		
		delayTimer = 0
		soundTimer = 0
		
		keypad = [UInt8:KeypadStatus]()
	}
	
	/// Load the system font into RAM
	private func loadFontSet() {
		
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
	}
	
	/// Resets the system. Then reads the ROM from disk into memory. If the system is paused it will be unpaused upon success
	func loadROM(path: String) {
		
		reset()
		
		/*
		The ROM is stored as 8-bit chunks on disk...
		We read the ROM into memory starting at location 0x200
		*/
		let rom = fopen(path, "r")
		if rom != nil {
			
			fread(&memory + 512, sizeof(UInt8), 3584, rom)
			
			fclose(rom)
			
			paused = false
		}
	}
	
	/// Set the key register to .On
	func keydown(_ key: UInt8) {
		keypad[key] = .on
	}
	
	/// Set the key register to .Off
	func keyup(_ key: UInt8) {
		keypad[key] = .off
	}
	
	/// Update the internal delay & sound timers
	@objc func stepClock() {
		
		if delayTimer > 0 {
			delayTimer -= 1
		}
		
		if soundTimer > 0 {
			NSBeep()
			soundTimer -= 1
		}
	}
	
	/// Process the next opcode
	@objc func step() {
		
		/* 
		Grab the opcode from memory
		Opcodes are 2-bytes wide. And our RAM is stored as an array of bytes.
		We can build an opcode by reading in the first byte from RAM into the opcode register, 
		shifting it to the left, and then reading in the second byte into the opcode register.
		*/
		let opcode: UInt16 = {
			var o = UInt16( self.memory[self.pc] )
			o <<= 8
			o |= UInt16( self.memory[self.pc + 1] )
			return o
		}()
		
		// Break the opcode down into nibbles (4-bit chunks).
		// Then combine them in a Tuple to switch upon each nibble of the opcode.
		let ocn1 = (opcode & 0xF000) >> 12
		let ocn2 = (opcode & 0x0F00) >> 8
		let ocn3 = (opcode & 0x00F0) >> 4
		let ocn4 = (opcode & 0x000F)
		
		let opcodeTuple = (ocn1, ocn2, ocn3, ocn4)
		
		
		switch opcodeTuple {
			
		case (0, 0, 0xE, 0):	// 00E0		CLS
			
			for col in 0..<64 {
				for row in 0..<32 {
					vram[col][row] = 0
				}
			}
			pc += 2
			
		case (0, 0, 0xE, 0xE):	// 00EE		RET
			
			if sp <= 0 {
				print("WARNING: Stack Underflow")
				return
			}
			sp -= 1
			pc = stack[sp]
			
		case (0, _, _, _):		// 0nnn		SYS addr
			print("WARNING: SYS addr is not implemented")
			
		case (1, _, _, _):		// 1nnn		JP addr
			
			pc = getNNN(opcode)
			
		case (2, _, _, _):		// 2nnn		CALL addr
			
			if sp+1 > 15 {
				print("WARNING: Stack Overflow")
				return
			}
			stack[sp] = pc + 2
			sp += 1
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
			let randomByte = UInt8( arc4random() & 0x00FF )
			
			V[x] = randomByte & nn
			pc += 2
			
		case (0xD, _, _, _):	// Dxyn		DRW Vx, Vy, nibble
			
			let x = getX(opcode)
			let y = getY(opcode)
			let height = getN(opcode)
			
			VF = 0
			
			for yLine in 0..<height {
				
				let row = yLine + V[y]
				if row > 31 {
					break
				}
				
				for xLine : UInt8 in 0..<8 {
					// Each pixel is one bit.
					// Each sprite is 1 byte wide.
					// So we step through each bit checking if it is set.
					let pixel = memory[I + UInt16(yLine)] & UInt8( (0x80 >> xLine) )
					
					if pixel != 0 {
						let col = xLine + V[x]
						if col > 63 {
							break
						}
						if vram[col][row] == 1 {
							VF = 1
						}
						vram[col][row] = vram[col][row] ^ 1
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
				case .on:
					pc += 4
				case .off:
					pc += 2
				}
			}
			
		case (0xE, _, 0xA, 1):	// ExA1		SKNP Vx
			
			let x = getX(opcode)
			let vx = V[x]
			
			if let keypadStatus = keypad[vx] {
				switch keypadStatus {
				case .on:
					pc += 2
				case .off:
					pc += 4
				}
			}
			
		case (0xF, _, 0, 7):	// Fx07		LD Vx, DT
			
			let x = getX(opcode)
			
			V[x] = delayTimer
			pc += 2
			
		case (0xF, _, 0, 0xA):	// Fx0A		LD Vx, K
			
			let x = getX(opcode)
			
			for (key, state) in keypad {
				if state == .on {
					V[x] = key
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
			print("Unknown Opcode: 0x\(String(opcode, radix: 16, uppercase: false))")
		}
	}
	
	/// Returns register X. X is stored in the second nibble in the opcode.
	func getX(_ opcode: UInt16) -> UInt8 {
		return UInt8((opcode & 0x0F00) >> 8)
	}
	
	/// Returns register Y. Y is stored in the third nibble in the opcode.
	func getY(_ opcode: UInt16) -> UInt8 {
		return UInt8((opcode & 0x00F0) >> 4)
	}
	
	/// Returns constant N. N is a nibble stored in the last nibble of the opcode.
	func getN(_ opcode: UInt16) -> UInt8 {
		return UInt8(opcode & 0x00F)
	}
	
	/// Returns constant NN. NN is a byte stored in the lower byte of the opcode.
	func getNN(_ opcode: UInt16) -> UInt8 {
		return UInt8(opcode & 0x00FF)
	}
	
	/// Returns address NNN. NNN is a memory address stored in the lower 12 bits of the opcode.
	func getNNN(_ opcode: UInt16) -> UInt16 {
		return opcode & 0x0FFF
	}
	
	/// Prints the given opcode in Hex format
	func printOpcode(_ opcode: UInt16) {
		print("opcode = 0x\(String(opcode, radix: 16, uppercase: false))")
	}
}




// Extend Array so we can access the elements using UInt8 and UInt16 subscripting
extension Array {
	
	subscript(index: UInt8) -> Element {
		get {
			return self[ Int(index) ]
		}
		set {
			self[ Int(index) ] = newValue
		}
	}
	
	subscript(index: UInt16) -> Element {
		get {
			return self[ Int(index) ]
		}
		set {
			self[ Int(index) ] = newValue
		}
	}
}
