import SwiftUI
import AppKit

/// The menu bar dropdown view.
struct MenuBarView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Label("Pin", systemImage: "pin.fill")

        Divider()

        Button {
            openSettings()
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        } label: {
            Label("Settings...", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Pin", systemImage: "xmark.circle")
        }
        .keyboardShortcut("q")
    }
}
