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
    var aktivFarge = Farge(hex: "#2F7FD8")! {
        didSet {
            // Unngå løkke: begrens bare når fargen faktisk er utenfor.
            if let profil = begrensning, !aktivFarge.erInnenfor(profil) { aktivFarge = aktivFarge.begrenset(til: profil) }
        }
    }

    /// «Begrens nye farger til …»: alle nye og redigerte farger holdes innenfor valgt ICC-profil.
    var begrensAktiv = UserDefaults.standard.bool(forKey: "kunSRGB") {
        didSet {
            UserDefaults.standard.set(begrensAktiv, forKey: "kunSRGB")
            aktivFarge = begrens(aktivFarge)
        }
    }

    /// Profilen som velges under «Vis også» og som begrensningen gjelder. Settes av Studio.
    var begrensProfil: ICCProfil = .sRGB {
        didSet { if begrensAktiv { aktivFarge = begrens(aktivFarge) } }
    }

    var begrensning: ICCProfil? { begrensAktiv ? begrensProfil : nil }

    /// Grov gamut for beregninger i kjernen; den nøyaktige begrensningen gjøres av `begrens`.
    var gamut: Gamut { begrensAktiv && begrensProfil.id == ICCProfil.sRGB.id ? .sRGB : .displayP3 }

    func begrens(_ farge: Farge) -> Farge {
        guard let profil = begrensning else { return farge }
        return farge.begrenset(til: profil)
    }
    var modell: Fargemodell = .okLCH
    var valgtFane: Fane = .studio
    /// Lysere/mørkere-innstillinger, delt mellom Studio og Overgang og husket mellom oppstarter.
    var lyshetstrinn: Lyshetstrinn = Arbeidsbenk.lastTrinn() {
        didSet { try? UserDefaults.standard.set(JSONEncoder().encode(lyshetstrinn), forKey: "lyshetstrinn") }
    }

    private static func lastTrinn() -> Lyshetstrinn {
        UserDefaults.standard.data(forKey: "lyshetstrinn").flatMap { try? JSONDecoder().decode(Lyshetstrinn.self, from: $0) }
            ?? Lyshetstrinn()
    }

    enum Fane: Hashable { case studio, paletter, overgang, utplukk, vurdering }

    /// Siste målte farger (kamera, bilde, pipette), nyeste sist – brukes i sammenligning.
    private(set) var målinger: [Farge] = []
    /// Åpent sammenligningsark (A/B med ΔE2000), hvis noe.
    var sammenligning: Sammenligningspar?

    struct Sammenligningspar: Identifiable {
        let id = UUID()
        var a: Farge
        var b: Farge
    }

    func registrerMåling(_ farge: Farge) {
        målinger.append(farge)
        if målinger.count > 20 { målinger.removeFirst(målinger.count - 20) }
    }

    /// Åpner sammenligning; uten argumenter brukes de to siste målingene (eller aktiv farge).
    func sammenlign(_ a: Farge? = nil, _ b: Farge? = nil) {
        let siste = målinger.suffix(2)
        let fa = a ?? (siste.count == 2 ? siste.first! : aktivFarge)
        let fb = b ?? siste.last ?? Farge(hex: "#FFFFFF")!
        sammenligning = Sammenligningspar(a: fa, b: fb)
    }
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
            Tab("Vurdering", systemImage: "checkmark.seal", value: .vurdering) {
                NavigationStack { VurderingVisning() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .sheet(item: $arbeidsbenk.sammenligning) { par in
            SammenligningVisning(a: par.a, b: par.b)
        }
    }
}

extension Color {
    /// Sekundærtekst med minst 4,5:1 kontrast mot lyse og mørke bakgrunner (se Assets).
    static let sekundærTekst = Color("SekundaerTekst")
    static let tertiærTekst = Color("TertiaerTekst")
    // Statusfargene .advarsel, .suksess og .feil genereres fra Assets (minst 4,5:1 i lys og mørk modus;
    // systemets .orange/.green er ca. 2,2:1 mot hvit).
}
