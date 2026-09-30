import AppIntents
import FargeKjerne
import SwiftData
import SwiftUI

@main
struct FargesynteseApp: App {
    @State private var arbeidsbenk = Arbeidsbenk()
    @State private var profiler = ProfilBibliotek()

    init() {
        FargesynteseSnarveier.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            InnholdsVisning()
                .environment(arbeidsbenk)
                .environment(profiler)
        }
        .modelContainer(Lagring.container)
        #if os(macOS)
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("Kopier aktiv farge som OKLCH") { Utklippstavle.kopier(arbeidsbenk.aktivFarge, som: .okLCH) }
                    .keyboardShortcut("c", modifiers: [.command, .option])
                Button("Lim inn farge") { if let f = Utklippstavle.limInn() { arbeidsbenk.aktivFarge = f } }
                    .keyboardShortcut("v", modifiers: [.command, .option])
            }
        }
        #endif
    }
}

/// Delt arbeidstilstand på tvers av faner: fargen man jobber med nå og foretrukket modell.
@Observable
final class Arbeidsbenk {
    var aktivFarge = Farge(hex: "#2F7FD8")!
    var modell: Fargemodell = .okLCH
    var valgtFane: Fane = .studio

    enum Fane: Hashable { case studio, paletter, overgang, utplukk, verdiord }
}

struct InnholdsVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk

    var body: some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        TabView(selection: $arbeidsbenk.valgtFane) {
            Tab("Studio", systemImage: "slider.horizontal.3", value: .studio) {
                NavigationStack { FargeEditor() }
            }
            Tab("Paletter", systemImage: "swatchpalette", value: .paletter) {
                PalettListe()
            }
            Tab("Overgang", systemImage: "square.stack.3d.forward.dottedline", value: .overgang) {
                NavigationStack { OvergangVisning() }
            }
            Tab("Utplukk", systemImage: "eyedropper.halffull", value: .utplukk) {
                NavigationStack { UtplukkVisning() }
            }
            Tab("Verdiord", systemImage: "sparkles", value: .verdiord) {
                NavigationStack { VerdiordVisning() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
