import SwiftUI

/// Applies a tinted glass effect to a small icon.
struct GlassIconModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 5))
    }
}
