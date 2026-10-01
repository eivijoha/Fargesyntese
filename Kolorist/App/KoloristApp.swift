import AppIntents
import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI

@main
struct KoloristApp: App {
    @State private var arbeidsbenk = Arbeidsbenk.delt
    @State private var profiler = ProfilBibliotek.delt

    init() {
        KoloristSnarveier.updateAppShortcutParameters()
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
    /// Verdiene brukeren sist skrev inn direkte i en ICC-profil (CMYK/RGB-gliderne koblet til
    /// valgt profil i Studio). Gjelder bare så lenge aktiv farge er nettopp den fargen –
    /// en rundtur gjennom profilen kan ellers gi andre (likeverdige) verdier, f.eks. annen sortgenerering.
    struct Profilverdier: Equatable {
        var profilID: String
        var verdier: [Double]
        var farge: Farge
    }
    var profilverdier: Profilverdier?

    func profilverdier(for profil: ICCProfil) -> [Double]? {
        guard let p = profilverdier, p.profilID == profil.id, p.farge == aktivFarge else { return nil }
        return p.verdier
    }

    var aktivFarge = Farge(hex: "#2F7FD8")! {
        didSet {
            // Unngå løkke: begrens bare når fargen faktisk er utenfor.
            // Verdier angitt direkte i begrensningsprofilen er innenfor per definisjon (en rundtur kan
            // likevel gi små avvik, særlig i mørke CMYK-farger).
            if let profil = begrensning, profilverdier(for: profil) == nil, !aktivFarge.erInnenfor(profil) {
                aktivFarge = aktivFarge.begrenset(til: profil)
            }
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

    /// Én arbeidsbenk for hele appen, så App Intents («Beskriv en farge») kan vise resultatet.
    static let delt = Arbeidsbenk()

    /// En nylig lagret enkeltfarge som skal få navn (ark i roten av appen).
    var nyEnkeltfarge: LagretFarge?
    /// Farger som venter på navnearket (lagret mens et annet ark/en annen boble var oppe).
    @ObservationIgnored private var navnekø: [LagretFarge] = []
    @ObservationIgnored private var venterPåNavneark = false

    /// Ber om navn på en nylagret enkeltfarge. Arket vises når ingen andre ark eller bobler er oppe;
    /// lagres flere farger raskt, får de navn etter tur i stedet for å avbryte hverandre.
    func navngiNy(_ farge: LagretFarge) {
        navnekø.append(farge)
        visNesteNavneark()
    }

    /// Kalles også når navnearket lukkes, så neste i køen vises.
    func visNesteNavneark() {
        guard nyEnkeltfarge == nil, !venterPåNavneark, !navnekø.isEmpty else { return }
        venterPåNavneark = true
        Task {
            defer { venterPåNavneark = false }
            // Minst en kort pause (bobler og menyer lukkes), så vent til ingen presentasjon er oppe.
            try? await Task.sleep(for: .milliseconds(350))
            for _ in 0..<50 where Self.noeErPresentert() {
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard nyEnkeltfarge == nil, !navnekø.isEmpty else { return }
            nyEnkeltfarge = navnekø.removeFirst()
        }
    }

    private static func noeErPresentert() -> Bool {
        #if canImport(UIKit)
        let vinduer = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return vinduer.contains { $0.isKeyWindow && $0.rootViewController?.presentedViewController != nil }
        #else
        return NSApp.windows.contains { $0.isVisible && ($0.attachedSheet != nil || $0.sheetParent != nil) }
        #endif
    }

    /// Viser en beskrevet farge i Studio, i OKLCH (fargen er regnet ut der).
    func vis(_ beskrevet: BeskrevetFarge) {
        profilverdier = nil
        aktivFarge = beskrevet.farge
        modell = .okLCH
        UserDefaults.standard.set("farge", forKey: "studioModus")
        valgtFane = .studio
    }

    /// Åpner en lagret gradient i Overgang (endepunktene huskes via `@AppStorage` der).
    func åpne(_ gradient: Gradientoppsett) {
        let d = UserDefaults.standard
        d.set(OvergangVisning.lagringstekst(gradient.fra), forKey: "overgangFra")
        d.set(OvergangVisning.lagringstekst(gradient.til), forKey: "overgangTil")
        d.set(gradient.antall, forKey: "overgangAntall")
        lyshetstrinn = gradient.trinn
        valgtFane = .overgang
    }

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
        .sheet(item: $arbeidsbenk.nyEnkeltfarge, onDismiss: { arbeidsbenk.visNesteNavneark() }) { lagret in
            NavngiArk(farge: lagret.palettFarge, tittel: "Ny enkeltfarge", avbryt: "Hopp over") { navn in
                var f = lagret.palettFarge
                f.navn = navn
                lagret.palettFarge = f
            }
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
