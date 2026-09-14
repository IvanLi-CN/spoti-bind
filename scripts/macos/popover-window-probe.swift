import ApplicationServices
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

func attributeString(_ element: AXUIElement, _ attribute: CFString) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
        return nil
    }
    return value as? String
}

func attributeSize(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
          let value,
          CFGetTypeID(value) == AXValueGetTypeID() else {
        return nil
    }
    let axValue = value as! AXValue
    var size = CGSize.zero
    guard AXValueGetType(axValue) == .cgSize,
          AXValueGetValue(axValue, .cgSize, &size) else {
        return nil
    }
    return size
}

let axApplication = AXUIElementCreateApplication(pid)
var axValue: CFTypeRef?
guard AXUIElementCopyAttributeValue(axApplication, kAXWindowsAttribute as CFString, &axValue) == .success,
      let axWindows = axValue as? [AXUIElement] else {
    fputs("could not read Accessibility windows\n", stderr)
    exit(1)
}

let axPopoverWindows = axWindows.filter { window in
    attributeString(window, kAXRoleAttribute as CFString) == (kAXWindowRole as String)
        && attributeString(window, kAXTitleAttribute as CFString) == ""
}
guard axPopoverWindows.count == 1,
      let axPopoverSize = attributeSize(axPopoverWindows[0], kAXSizeAttribute as CFString) else {
    fputs("popover AX window is not unique\n", stderr)
    exit(1)
}

guard let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] else {
    fputs("could not read WindowServer windows\n", stderr)
    exit(1)
}

struct Candidate {
    let id: CGWindowID
    let bounds: CGRect
}

let candidates = windows.compactMap { info -> Candidate? in
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
    return Candidate(id: CGWindowID(windowID), bounds: bounds)
}

guard candidates.count == 1 else {
    fputs("menu WindowServer window is not unique\n", stderr)
    exit(1)
}

let candidate = candidates[0]
guard abs(candidate.bounds.width - axPopoverSize.width) <= 2,
      abs(candidate.bounds.height - axPopoverSize.height) <= 2 else {
    fputs("AX and WindowServer popover window sizes do not match\n", stderr)
    exit(1)
}

print(candidates[0].id)
