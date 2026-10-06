// Prints the window numbers of the on-screen windows owned by a process,
// frontmost first, for "screencapture -l".
//
// Usage: swift window-id.swift <pid>

import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2, let pid = Int(CommandLine.arguments[1]) else {
	FileHandle.standardError.write("Usage: swift window-id.swift <pid>\n".data(using: .utf8)!)
	exit(1)
}

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

for window in windows {
	guard (window[kCGWindowOwnerPID as String] as? Int) == pid,
		  (window[kCGWindowLayer as String] as? Int) == 0,
		  let number = window[kCGWindowNumber as String] as? Int else {
		continue
	}

	print(number)
}
