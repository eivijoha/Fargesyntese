import FargeKjerne
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if os(macOS)
/// Skjermpipette på Mac: systemets `NSColorSampler` plukker fra hele skjermen, på tvers av apper.
/// (iOS og iPadOS tillater ikke skjermutplukk utenfor appen; der brukes Utplukk med kamera og bilder.)
enum Pipette {
    @MainActor
    static func plukkFraSkjerm() async -> Farge? {
        await withCheckedContinuation { fortsett in
            NSColorSampler().show { farge in
                fortsett.resume(returning: farge.flatMap { Farge(cgFarge: $0.cgColor) })
            }
        }
    }
}

/// Knapp for skjermpipetten.
struct PipetteKnapp: View {
    var valgt: (Farge) -> Void

    var body: some View {
        Button {
            Task { if let f = await Pipette.plukkFraSkjerm() { valgt(f) } }
        } label: {
            Label("Pipette", systemImage: "eyedropper")
        }
        .help("Plukk en farge fra hvor som helst på skjermen")
    }
}
#endif
