//
//  AppDelegate.swift
//  Swift8
//
//  Created by Lee Morgan on 2/24/15.
//  Copyright (c) 2015 Lee Morgan. All rights reserved.
//

import Cocoa

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
	
	@IBOutlet weak var pauseResumeMenuItem: NSMenuItem!
	@IBOutlet weak var window: NSWindow!
	@IBOutlet weak var swift8view: Swift8View!
	
	
	var swift8 = Swift8()
	var paused = false
	var displayTimer: Timer?
	
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		
		openROM(nil)
		
		displayTimer = Timer.scheduledTimer(timeInterval: 1.0/60.0, target: self, selector: #selector(AppDelegate.updateDisplay), userInfo: nil, repeats: true)
		
		_ = swift8view.becomeFirstResponder()
	}
	
	
	@IBAction func openROM(_ sender: AnyObject?) {
		
		pause()
		
		let openPanel = NSOpenPanel()
		
		openPanel.begin {
			result in
			
			if result == NSFileHandlingPanelOKButton {
				
				if let path = openPanel.url?.path {
					
					self.swift8.loadROM(path: path)
					self.resume()
				}
			}
		}
	}
	
	
	@IBAction func togglePauseResume(_ sender: AnyObject?) {
		if paused {
			resume()
		}
		else {
			pause()
		}
	}
	
	
	func pause() {
		
		paused = true
		swift8.paused = paused
		
		pauseResumeMenuItem.title = "Resume"
	}
	
	
	func resume() {
		
		paused = false
		swift8.paused = paused
		
		pauseResumeMenuItem.title = "Pause"
	}
	
	
	func updateDisplay() {
		
		if swift8.needsDisplay {
			swift8view.needsDisplay = true
			swift8.needsDisplay = false
		}
	}
	
	
	func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
		
		let windowWidth = floor(frameSize.width / 64) * 64
		return NSSize(width: windowWidth, height: frameSize.height)
	}
}

