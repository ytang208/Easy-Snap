import AppKit
import ApplicationServices

// AppKit and Accessibility use opposite vertical origins. Always anchor to the primary display.
func flip(_ r: CGRect, primaryTop: CGFloat) -> CGRect {
    CGRect(x: r.minX, y: primaryTop - r.maxY, width: r.width, height: r.height)
}
func destination(point p: CGPoint, screen: CGRect, usable: CGRect) -> CGRect? {
    guard screen.insetBy(dx: -1, dy: -1).contains(p) else { return nil }
    let edge: CGFloat = 18, corner: CGFloat = 72
    let left = p.x <= screen.minX + edge, right = p.x >= screen.maxX - edge
    let top = p.y >= screen.maxY - edge, bottom = p.y <= screen.minY + edge
    let nearLeft = p.x <= screen.minX + corner, nearRight = p.x >= screen.maxX - corner
    let nearTop = p.y >= screen.maxY - corner, nearBottom = p.y <= screen.minY + corner
    let w = usable.width / 2, h = usable.height / 2
    if (left && nearTop) || (top && nearLeft) { return CGRect(x: usable.minX, y: usable.minY + h, width: w, height: h) }
    if (right && nearTop) || (top && nearRight) { return CGRect(x: usable.minX + w, y: usable.minY + h, width: w, height: h) }
    if (left && nearBottom) || (bottom && nearLeft) { return CGRect(x: usable.minX, y: usable.minY, width: w, height: h) }
    if (right && nearBottom) || (bottom && nearRight) { return CGRect(x: usable.minX + w, y: usable.minY, width: w, height: h) }
    if left { return CGRect(x: usable.minX, y: usable.minY, width: w, height: usable.height) }
    if right { return CGRect(x: usable.minX + w, y: usable.minY, width: w, height: usable.height) }
    return top ? usable : nil
}
final class Preview: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; ignoresMouseEvents = true
        level = .floating; hasShadow = false; hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let v = NSView(); v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.17).cgColor
        v.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.8).cgColor
        v.layer?.borderWidth = 3; v.layer?.cornerRadius = 12
        contentView = v
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    func show(_ rect: CGRect) { setFrame(rect.insetBy(dx: 4, dy: 4), display: true); orderFrontRegardless() }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!
    let preview = Preview()
    var monitor: Any?
    let placer = WindowPlacer()
    var permissionTimer: Timer?
    var previouslyTrusted = false
    var enabled = !UserDefaults.standard.bool(forKey: "paused")
    var window: AXUIElement?
    var initial: CGRect?
    var moved = false
    var target: CGRect?
    var lastSample: TimeInterval = 0
    var saved: [(window: AXUIElement, original: CGRect, snapped: CGRect)] = []
    var lastMessage = "Drag a window to an edge to snap"
    var primaryTop: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Easy Snap")
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged]) { [weak self] event in self?.handle(event) }
        refreshPermission()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        if !UserDefaults.standard.bool(forKey: "welcomed") { welcome(); UserDefaults.standard.set(true, forKey: "welcomed") }
    }
    func menuWillOpen(_ menu: NSMenu) {
        refreshPermission()
        menu.removeAllItems()
        let title = NSMenuItem(title: "Easy Snap", action: nil, keyEquivalent: ""); title.isEnabled = false; menu.addItem(title)
        let status = NSMenuItem(title: AXIsProcessTrusted() ? lastMessage : "Accessibility permission needed", action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status)
        menu.addItem(.separator())
        add(menu, enabled ? "✓ Snapping enabled" : "Enable snapping", #selector(toggle))
        add(menu, "Enable Accessibility…", #selector(permission))
        add(menu, "Repair permission after an update…", #selector(repairPermission))
        add(menu, "How to use Easy Snap…", #selector(welcome))
        menu.addItem(.separator()); add(menu, "Quit Easy Snap", #selector(quit))
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector) { let entry = NSMenuItem(title: title, action: action, keyEquivalent: ""); entry.target = self; menu.addItem(entry) }
    @objc func toggle() { enabled.toggle(); UserDefaults.standard.set(!enabled, forKey: "paused"); placer.cancel(); cancel(); refreshPermission() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func permission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        item.button?.image = NSImage(systemSymbolName: trusted ? "rectangle.split.2x1" : "exclamationmark.triangle", accessibilityDescription: trusted ? "Easy Snap" : "Easy Snap needs Accessibility permission")
        item.button?.toolTip = trusted ? (enabled ? "Easy Snap is ready" : "Easy Snap is paused") : "Easy Snap needs Accessibility permission. Open the menu for repair steps."
        if trusted && !previouslyTrusted {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .flagsChanged]) { [weak self] event in self?.handle(event) }
        }
        previouslyTrusted = trusted
        if trusted { permissionTimer?.invalidate(); permissionTimer = nil }
        else if permissionTimer == nil {
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshPermission() }
        }
    }
    @objc func repairPermission() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Reconnect Easy Snap to Accessibility"
        alert.informativeText = "After a locally built app is updated, macOS can keep an approval for its old version. Toggling the switch may not replace that approval.\n\n1. In Accessibility settings, select the old Easy Snap entry and remove it with the minus button.\n2. Use the plus button to add Easy Snap from your home Applications folder.\n3. Turn its switch on. If needed, quit and reopen Easy Snap.\n\nThe warning icon changes back to the window icon when access is available."
        alert.addButton(withTitle: "Open Settings"); alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { permission() }
    }
    @objc func welcome() {

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "Make room with Easy Snap"
        alert.informativeText = "Drag a window by its title bar to a screen edge, then release.\n\nLeft or right → half screen\nTop → fill the available screen\nCorners → quarter screen\nDrag a snapped window away and release → restore its size\nHold Option → skip snapping and restoring\n\nEnable Easy Snap in System Settings → Privacy & Security → Accessibility. Easy Snap lives in your menu bar. It works locally and sends no data."
        alert.addButton(withTitle: "Got it"); alert.addButton(withTitle: "Enable Accessibility")
        if alert.runModal() == .alertSecondButtonReturn { permission() }
    }
    @objc func screenChanged() { placer.cancel(); cancel() }
    @objc func cancel() { preview.orderOut(nil); window = nil; initial = nil; target = nil; moved = false }
    func handle(_ event: NSEvent) {
        guard enabled, AXIsProcessTrusted() else { placer.cancel(); cancel(); refreshPermission(); return }
        if event.type == .leftMouseDown { begin(); return }
        if event.modifierFlags.contains(.option) { placer.cancel(); cancel(); return }
        if event.type == .leftMouseDragged {
            guard event.timestamp - lastSample > 1.0 / 30 else { return }
            lastSample = event.timestamp; update()
        }
        if event.type == .leftMouseUp { update(); finish() }
    }
    func begin() {
        placer.cancel()
        cancel()
        let p = NSEvent.mouseLocation
        var hit: AXUIElement?
        let system = AXUIElementCreateSystemWide(); AXUIElementSetMessagingTimeout(system, 0.15)
        guard AXUIElementCopyElementAtPosition(system, Float(p.x), Float(primaryTop - p.y), &hit) == .success, let element = hit else { return }
        let candidate: AXUIElement
        if (attribute(element, kAXRoleAttribute) as? String) == kAXWindowRole { candidate = element }
        else if let value = attribute(element, kAXWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() { candidate = value as! AXUIElement }
        else { return }
        AXUIElementSetMessagingTimeout(candidate, 0.15)
        var pid: pid_t = 0; AXUIElementGetPid(candidate, &pid)
        guard pid != ProcessInfo.processInfo.processIdentifier,
              (attribute(candidate, kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole,
              (attribute(candidate, "AXFullScreen") as? Bool) != true,
              let rect = frame(candidate) else { return }
        var positionSettable = DarwinBoolean(false), sizeSettable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(candidate, kAXPositionAttribute as CFString, &positionSettable)
        AXUIElementIsAttributeSettable(candidate, kAXSizeAttribute as CFString, &sizeSettable)
        guard positionSettable.boolValue, sizeSettable.boolValue else { return }
        window = candidate; initial = rect
    }
    func update() {
        guard let window, let initial, let current = frame(window) else { preview.orderOut(nil); target = nil; return }
        // Resizing a window or dragging content must never count as moving it.
        guard abs(current.width - initial.width) < 2, abs(current.height - initial.height) < 2 else { cancel(); return }
        if hypot(current.minX - initial.minX, current.minY - initial.minY) > 4 { moved = true }
        guard moved else { return }
        let p = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) else { target = nil; preview.orderOut(nil); return }
        target = destination(point: p, screen: screen.frame, usable: screen.visibleFrame)
        if let target { preview.show(target) } else { preview.orderOut(nil) }
    }
    func finish() {
        defer { cancel() }
        guard moved, let window, let initial else { return }
        let index = saved.firstIndex { CFEqual($0.window, window) }
        if let target {
            let original = index.map { saved[$0].original } ?? initial
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) else { return }
            let request = flip(target, primaryTop: primaryTop)
            placer.apply(window, request: request, area: flip(screen.visibleFrame, primaryTop: primaryTop)) { [weak self] actual in
                guard let self else { return }
                guard let actual else { self.lastMessage = "This app did not allow its window to resize"; return }
                self.saved.removeAll { CFEqual($0.window, window) }
                self.saved.append((window, original, actual)); if self.saved.count > 100 { self.saved.removeFirst() }
                let constrained = abs(actual.width-request.width) > 3 || abs(actual.height-request.height) > 3
                self.lastMessage = constrained ? "Snapped as close as this app’s size limits allow" : "Snapped • hold Option to skip"
            }
        } else if let index, let current = frame(window) {
            let record = saved.remove(at: index)
            guard abs(initial.width - record.snapped.width) < 3, abs(initial.height - record.snapped.height) < 3 else { return }
            let p = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(p) }) else { return }
            let area = flip(screen.visibleFrame, primaryTop: primaryTop)
            let size = CGSize(width: min(record.original.width, area.width), height: min(record.original.height, area.height))
            let fraction = min(1, max(0, (p.x - current.minX) / current.width))
            let x = min(max(p.x - size.width * fraction, area.minX), area.maxX - size.width)
            let y = min(max(current.minY, area.minY), area.maxY - size.height)
            placer.apply(window, request: CGRect(origin: CGPoint(x: x, y: y), size: size), area: area) { [weak self] actual in
                if actual == nil { self?.lastMessage = "This app did not allow its window to restore" }
            }

        }
    }
    func applicationWillTerminate(_ notification: Notification) { placer.cancel(); permissionTimer?.invalidate(); if let monitor { NSEvent.removeMonitor(monitor) }; preview.orderOut(nil) }
}

if CommandLine.arguments.contains("--self-test") {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let usable = CGRect(x: 0, y: 60, width: 1440, height: 815)
    assert(destination(point: CGPoint(x: 0, y: 450), screen: screen, usable: usable) == CGRect(x: 0, y: 60, width: 720, height: 815))
    assert(destination(point: CGPoint(x: 1439, y: 450), screen: screen, usable: usable)?.minX == 720)
    assert(destination(point: CGPoint(x: 700, y: 899), screen: screen, usable: usable) == usable)
    for p in [CGPoint(x: 1, y: 1), CGPoint(x: 1439, y: 1), CGPoint(x: 1, y: 899), CGPoint(x: 1439, y: 899)] {
        let r = destination(point: p, screen: screen, usable: usable)!
        assert(r.width == 720 && r.height == 407.5 && usable.contains(r))
    }
    assert(destination(point: CGPoint(x: 700, y: 400), screen: screen, usable: usable) == nil)
    assert(destination(point: CGPoint(x: 700, y: 0), screen: screen, usable: usable) == nil)
    assert(destination(point: CGPoint(x: -2000, y: 400), screen: screen, usable: usable) == nil)
    for origin in [CGPoint(x: -1920, y: 0), CGPoint(x: 0, y: 900), CGPoint(x: 1440, y: -1080)] {
        let secondary = CGRect(origin: origin, size: CGSize(width: 1920, height: 1080))
        let r = destination(point: CGPoint(x: secondary.minX + 1, y: secondary.midY), screen: secondary, usable: secondary)!
        assert(r.minX == secondary.minX && r.width == 960)
        assert(flip(flip(r, primaryTop: 900), primaryTop: 900) == r)
    }
    print("Passed: halves, four corners, maximize, neutral areas, and multi-display coordinate conversion.")
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate(); app.delegate = delegate; app.run()
}
