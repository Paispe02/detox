import AppKit
import SwiftUI

/// Borderless full-screen window above everything, on every Space. Esc does nothing.
final class InterceptPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) {}
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { return }   // Esc
        super.keyDown(with: event)
    }
}

@MainActor
public final class InterceptWindowPresenter: InterceptPresenting {
    private var window: NSWindow?
    private var shownAt = Date()

    /// While true, the app refuses to quit (the screen must not be escapable by Cmd+Q).
    public private(set) var blocksTermination = false

    public init() {}

    public func present(_ content: InterceptContent, onDismiss: @escaping () -> Void) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let w = InterceptPanel(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        w.isReleasedWhenClosed = false
        w.backgroundColor = NSColor(Theme.night)
        shownAt = Date()
        blocksTermination = true
        let view = InterceptView(content: content, shownAt: shownAt) { [weak self] in
            self?.dismiss()
            onDismiss()
        }
        w.contentView = NSHostingView(rootView: view)
        w.setFrame(screen.frame, display: true)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        window = w
        // Unblock quitting once the minimum has passed even if nobody presses "Cerrar".
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(InterceptTiming.minimumSeconds * 1_000_000_000))
            self?.blocksTermination = false
        }
    }

    private func dismiss() {
        blocksTermination = false
        window?.orderOut(nil)
        window = nil
    }
}
