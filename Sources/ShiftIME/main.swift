import AppKit

// This project intentionally has no Storyboard or Nib. NSApplicationMain alone
// therefore cannot instantiate an application delegate; retain it explicitly
// for the full lifetime of the application run loop.
let application = NSApplication.shared
let applicationDelegate = AppDelegate()
application.delegate = applicationDelegate
application.run()
