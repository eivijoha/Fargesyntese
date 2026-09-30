import FargeKjerne
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

/// Pipette for utplukk fra egen skjerm.
///
/// - macOS: systemets `NSColorSampler` – plukker fra hele skjermen, på tvers av apper.
/// - iOS/iPadOS: systemet tillater ikke skjermutplukk utenfor appen. Vi bruker
///   `ColorPicker` sin innebygde pipette (plukker i appens eget vindu) og utplukk
///   fra importerte bilder/skjermbilder (se `BildeFargeplukker`, planlagt).
enum Pipette {
    static var kanPlukkeFraHeleSkjermen: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    #if os(macOS)
    @MainActor
    static func plukkFraSkjerm() async -> Farge? {
        await withCheckedContinuation { fortsett in
            NSColorSampler().show { farge in
                fortsett.resume(returning: farge.flatMap { Farge(cgFarge: $0.cgColor) })
            }
        }
    }
    #endif
}

/// Knapp som viser riktig pipette-opplevelse per plattform.
struct PipetteKnapp: View {
    var valgt: (Farge) -> Void
    @State private var systemFarge: Color = .accentColor

    var body: some View {
        #if os(macOS)
        Button {
            Task { if let f = await Pipette.plukkFraSkjerm() { valgt(f) } }
        } label: {
            Label("Pipette", systemImage: "eyedropper")
        }
        .help("Plukk en farge fra hvor som helst på skjermen")
        #else
        // Systemvelgeren har pipette øverst til venstre i arket.
        ColorPicker("Fargevelger med pipette", selection: $systemFarge, supportsOpacity: true)
            .labelsHidden()
            .onChange(of: systemFarge) { _, ny in valgt(Farge(ny)) }
        #endif
    }
}
