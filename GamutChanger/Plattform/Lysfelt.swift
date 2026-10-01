#if os(macOS)
import AppKit
import SwiftUI

/// Hvitt lysfelt på Mac-skjermen – lyskilde for fargeutplukk med innebygd kamera eller
/// Continuity Camera. Legger seg først øverst på skjermen i full bredde; kan flyttes og
/// endres i størrelse, og husker plassering. Esc eller lukkeknappen skjuler det.
@MainActor
@Observable
final class Lysfelt: NSObject, NSWindowDelegate {
    static let delt = Lysfelt()

    private(set) var erSynlig = false
    /// 0…1 – lavere verdier gir et dempet, nøytralt grått lys.
    var lysstyrke: Double = 1

    @ObservationIgnored private var vindu: NSWindow?

    func veksle() { erSynlig ? skjul() : vis() }

    func vis() {
        let vindu = self.vindu ?? lagVindu()
        self.vindu = vindu
        vindu.orderFrontRegardless()
        erSynlig = true
    }

    func skjul() {
        vindu?.orderOut(nil)
        erSynlig = false
    }

    func windowWillClose(_ notification: Notification) { erSynlig = false }

    private func lagVindu() -> NSWindow {
        let skjerm = NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let høyde: CGFloat = 220
        let ramme = NSRect(x: skjerm.frame.minX, y: skjerm.visibleFrame.maxY - høyde,
                           width: skjerm.frame.width, height: høyde)
        let v = NSWindow(contentRect: ramme, styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        v.title = "Lysfelt"
        v.titleVisibility = .hidden
        v.titlebarAppearsTransparent = true
        v.isMovableByWindowBackground = true
        v.backgroundColor = .white
        v.level = .floating
        v.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        v.isReleasedWhenClosed = false
        v.minSize = NSSize(width: 120, height: 60)
        v.delegate = self
        v.contentView = NSHostingView(rootView: LysfeltInnhold(lysfelt: self))
        // Første gang: øverst i full bredde. Senere: brukerens egen plassering og størrelse.
        if !v.setFrameUsingName("GamutChanger.Lysfelt") { v.setFrame(ramme, display: true) }
        v.setFrameAutosaveName("GamutChanger.Lysfelt")
        return v
    }
}

private struct LysfeltInnhold: View {
    @Bindable var lysfelt: Lysfelt
    @State private var peker = false

    var body: some View {
        Color(white: lysfelt.lysstyrke)
            .ignoresSafeArea()
            .overlay(alignment: .bottomTrailing) {
                if peker {
                    HStack(spacing: 10) {
                        Image(systemName: "sun.min")
                        Slider(value: $lysfelt.lysstyrke, in: 0.3...1).frame(width: 140)
                        Image(systemName: "sun.max.fill")
                        Button("Skjul") { lysfelt.skjul() }
                    }
                    .padding(8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(10)
                    .transition(.opacity)
                }
            }
            .onHover { inne in withAnimation(.easeInOut(duration: 0.2)) { peker = inne } }
            .onKeyPress(.escape) { lysfelt.skjul(); return .handled }
            .focusable()
            .focusEffectDisabled()
    }
}
#endif
