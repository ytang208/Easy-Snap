import AppKit
import ApplicationServices

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func frame(_ window: AXUIElement) -> CGRect? {
    guard let pos = attribute(window, kAXPositionAttribute), CFGetTypeID(pos) == AXValueGetTypeID(),
          let size = attribute(window, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
    var p = CGPoint.zero, s = CGSize.zero
    guard AXValueGetValue(pos as! AXValue, .cgPoint, &p), AXValueGetValue(size as! AXValue, .cgSize, &s) else { return nil }
    return CGRect(origin: p, size: s)
}
func fittedOrigin(request: CGRect, actualSize: CGSize, area: CGRect) -> CGPoint {
    // Keep minimum-size windows on screen and preserve right/bottom edge alignment.
    let right = request.minX > area.minX + 3 && abs(request.maxX - area.maxX) < 3
    let bottom = request.minY > area.minY + 3 && abs(request.maxY - area.maxY) < 3
    let x = right ? area.maxX - actualSize.width : request.minX
    let y = bottom ? area.maxY - actualSize.height : request.minY
    return CGPoint(x: max(area.minX, min(x, area.maxX - actualSize.width)),
                   y: max(area.minY, min(y, area.maxY - actualSize.height)))
}
final class WindowPlacer {
    private var generation = 0
    func cancel() { generation += 1 }
    func apply(_ window: AXUIElement, request: CGRect, area: CGRect, completion: @escaping (CGRect?) -> Void) {
        cancel()
        let token = generation
        func attempt(_ round: Int) {
            guard token == self.generation else { return }
            var size = request.size
            guard let value = AXValueCreate(.cgSize, &size),
                  AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value) == .success else { completion(nil); return }
            // SwiftUI windows apply AX mutations asynchronously. Back-to-back setters can undo each other.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                guard token == self.generation else { return }
                guard let sized = frame(window) else { completion(nil); return }
                var position = fittedOrigin(request: request, actualSize: sized.size, area: area)
                guard let value = AXValueCreate(.cgPoint, &position),
                      AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value) == .success else { completion(nil); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    guard token == self.generation else { return }
                    guard let actual = frame(window) else { completion(nil); return }
                    let matches = abs(actual.width-request.width) < 3 && abs(actual.height-request.height) < 3
                        && abs(actual.minX-position.x) < 3 && abs(actual.minY-position.y) < 3
                    if matches || round == 2 { completion(actual) } else { attempt(round + 1) }
                }
            }
        }
        attempt(0)
    }
}
