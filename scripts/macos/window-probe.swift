import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2, let pidValue = Int32(CommandLine.arguments[1]) else {
    fputs("usage: window-probe <pid>\n", stderr)
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

let titledAXWindows = axWindows.compactMap { window -> CGSize? in
    guard attributeString(window, kAXRoleAttribute as CFString) == (kAXWindowRole as String),
          attributeString(window, kAXTitleAttribute as CFString) == "SpotiBind" else {
        return nil
    }
    return attributeSize(window, kAXSizeAttribute as CFString)
}
guard titledAXWindows.count == 1 else {
    fputs("settings AX window is not unique\n", stderr)
    exit(1)
}

guard let windowInfo = CGWindowListCopyWindowInfo(
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

let candidates = windowInfo.compactMap { info -> Candidate? in
    guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pidValue,
          info[kCGWindowOwnerName as String] as? String == "SpotiBind",
          info[kCGWindowName as String] as? String == "SpotiBind",
          (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
          (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true,
          let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
          let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
          bounds.width >= 600,
          bounds.height >= 520,
          bounds.width <= 1600,
          bounds.height <= 1200,
          let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else {
        return nil
    }
    return Candidate(id: CGWindowID(windowID), bounds: bounds)
}

guard candidates.count == 1 else {
    fputs("settings WindowServer window is not unique\n", stderr)
    exit(1)
}

let candidate = candidates[0]
guard abs(candidate.bounds.width - titledAXWindows[0].width) <= 2,
      abs(candidate.bounds.height - titledAXWindows[0].height) <= 2 else {
    fputs("AX and WindowServer settings window sizes do not match\n", stderr)
    exit(1)
}

print(candidate.id)
