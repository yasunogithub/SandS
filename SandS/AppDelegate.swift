import Cocoa

var statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))

func interceptCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let r = refcon {
        let hook = Unmanaged<Interceptor>.fromOpaque(r).takeUnretainedValue()
        return hook.intercept(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var windowController : NSWindowController?

    private var interceptor: Interceptor!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // MENU
        let menu = NSMenu()
        if let button = statusItem.button {
            button.image = createStatusBarIcon()
            button.image?.isTemplate = true
        }
        statusItem.menu = menu
        menu.addItem(withTitle: "Quit", action: #selector(AppDelegate.quit(_:)), keyEquivalent: "")

        // INTERCEPTER for SandS
        self.interceptor = Interceptor()
        let axTrustedCheckOptionPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        if AXIsProcessTrustedWithOptions([axTrustedCheckOptionPrompt: true] as CFDictionary) {
            activate()
            return
        }
        Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(AppDelegate.checkAXIsProcessTrusted(_:)),
            userInfo: nil,
            repeats: true
        )
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { return false }

    @objc func checkAXIsProcessTrusted(_ timer: Timer) {
        if AXIsProcessTrusted() {
            timer.invalidate()
            activate()
        }
    }

    func activate() {
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(
                (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
            ),
            callback: interceptCGEvent,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(interceptor).toOpaque())
            ) else {
                print("failed to create event tap")
                exit(1)
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    @objc func quit(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }

    private func createStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let font = NSFont.boldSystemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let str = "S"
        let strSize = str.size(withAttributes: attributes)
        let point = NSPoint(
            x: (size.width - strSize.width) / 2,
            y: (size.height - strSize.height) / 2
        )
        str.draw(at: point, withAttributes: attributes)

        image.unlockFocus()
        return image
    }
}
