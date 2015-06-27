//
//  Swift8View.swift
//  Swift8
//
//  Created by Lee Morgan on 5/26/15.
//  Copyright (c) 2015 Lee Morgan. All rights reserved.
//

import AppKit


class Swift8View: NSView {
	
	var swift8 : Swift8 {
		let appDelegate = NSApplication.sharedApplication().delegate as! AppDelegate
		return appDelegate.swift8
	}
	
	override var canBecomeKeyView: Bool {
		return true
	}
	
	override var acceptsFirstResponder: Bool {
		return true
	}
	
	override func becomeFirstResponder() -> Bool {
		return true
	}
	
	override func drawRect(dirtyRect: NSRect) {
		
		let pixelWidth	= floor( self.bounds.size.width / 64 )
		let pixelHeight	= floor( self.bounds.size.height / 32 )
		
		NSColor.blackColor().setFill()
		NSRectFill(self.bounds)
		
		NSColor.whiteColor().setFill()
		
		for row in 0..<32 {
			for col in 0..<64 {
				
				if swift8.gfx[col][row] != 0 {
					let x = CGFloat(col) * pixelWidth
					let y = CGFloat(row) * pixelHeight
					
					let pixelRect = NSMakeRect(x,
						self.bounds.size.height - pixelHeight - y,
						pixelWidth,
						pixelHeight)
					NSRectFill(pixelRect)
				}
			}
		}
	}
	
	override func keyDown(theEvent: NSEvent) {
		
		if let characters = theEvent.characters {
			var firstChar = Array(characters)[0]
			
			switch firstChar {
			case "1":
				swift8.keydown(1)
			case "2":
				swift8.keydown(2)
			case "3":
				swift8.keydown(3)
			case "4":
				swift8.keydown(0xC)
			case "q":
				swift8.keydown(4)
			case "w":
				swift8.keydown(5)
			case "e":
				swift8.keydown(6)
			case "r":
				swift8.keydown(0xD)
			case "a":
				swift8.keydown(7)
			case "s":
				swift8.keydown(8)
			case "d":
				swift8.keydown(9)
			case "f":
				swift8.keydown(0xE)
			case "z":
				swift8.keydown(0xA)
			case "x":
				swift8.keydown(0)
			case "c":
				swift8.keydown(0xB)
			case "v":
				swift8.keydown(0xF)
			default:
				break
			}
		}
	}
	
	override func keyUp(theEvent: NSEvent) {
		
		if let characters = theEvent.characters {
			var firstChar = Array(characters)[0]
			
			switch firstChar {
			case "1":
				swift8.keyup(1)
			case "2":
				swift8.keyup(2)
			case "3":
				swift8.keyup(3)
			case "4":
				swift8.keyup(0xC)
			case "q":
				swift8.keyup(4)
			case "w":
				swift8.keyup(5)
			case "e":
				swift8.keyup(6)
			case "r":
				swift8.keyup(0xD)
			case "a":
				swift8.keyup(7)
			case "s":
				swift8.keyup(8)
			case "d":
				swift8.keyup(9)
			case "f":
				swift8.keyup(0xE)
			case "z":
				swift8.keyup(0xA)
			case "x":
				swift8.keyup(0)
			case "c":
				swift8.keyup(0xB)
			case "v":
				swift8.keyup(0xF)
			default:
				break
			}
		}
	}
}