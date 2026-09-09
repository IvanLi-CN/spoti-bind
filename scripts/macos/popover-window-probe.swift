import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let pidValue = Int32(CommandLine.arguments[1]),
      let expectedWindowID = UInt32(CommandLine.arguments[2]) else {
    fputs("usage: popover-window-probe <pid> <window-id>\n", stderr)
    exit(2)
}

let pid = pid_t(pidValue)
guard let application = NSRunningApplication(processIdentifier: pid),
      application.localizedName == "SpotiBind",
      application.bundleIdentifier == "cc.ivanli.spotibind" else {
    fputs("target process identity mismatch\n", stderr)
    exit(1)
}

guard let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] else {
    fputs("could not read WindowServer windows\n", stderr)
    exit(1)
}

let candidates = windows.compactMap { info -> CGWindowID? in
    guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pidValue,
          info[kCGWindowOwnerName as String] as? String == "SpotiBind",
          info[kCGWindowName as String] as? String == "",
          (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true,
          let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
          let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
          bounds.width >= 360,
          bounds.width <= 520,
          bounds.height >= 280,
          bounds.height <= 680,
          let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
          windowID == expectedWindowID else {
        return nil
    }
    return CGWindowID(windowID)
}

guard candidates.count == 1 else {
    fputs("menu WindowServer window is not unique\n", stderr)
    exit(1)
}

print(candidates[0])
