import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI

/// Vurdering: kontrast (WCAG), forskjell (ΔE2000) og fargesyn (CVD). Hele paletter vurderes fra paletten selv.
struct VurderingVisning: View {
    enum Del: String, CaseIterable, Identifiable {
        case kontrast, sammenlign, fargesyn
        var id: String { rawValue }
        var navn: String {
            switch self {
            case .kontrast: String(localized: "Kontrast")
            case .sammenlign: String(localized: "Forskjell")
            case .fargesyn: String(localized: "Fargesyn")
            }
        }
    }

    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @AppStorage("vurderingDel") private var del: Del = .kontrast

    var body: some View {
        Group {
            switch del {
            case .kontrast: KontrastVurdering()
            case .sammenlign:
                // Ny identitet ved hver visning, slik at A/B hentes fra aktiv farge og siste måling.
                SammenligningVisning(a: arbeidsbenk.aktivFarge,
                                     b: arbeidsbenk.målinger.last(where: { $0 != arbeidsbenk.aktivFarge }) ?? Farge(hex: "#FFFFFF")!,
                                     innebygd: true)
            case .fargesyn: FargesynVurdering()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Vurdering", selection: $del) {
                    ForEach(Del.allCases) { Text($0.navn).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}

/// WCAG-kontrast for aktiv farge mot en valgt bakgrunn.
private struct KontrastVurdering: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var innstillinger = Panelinnstillinger.delt
    @AppStorage("kontrastBakgrunn") private var bakgrunnHex = "#FFFFFF"

    var body: some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        Form {
            KontrastFargerSeksjon(forgrunn: $arbeidsbenk.aktivFarge)
            // Panelene i brukerens rekkefølge; begge bruker fargene over.
            ForEach(innstillinger.paneler(for: .kontrast)) { panel in
                switch panel {
                case .wcag: KontrastSeksjon(forgrunn: $arbeidsbenk.aktivFarge)
                case .lrv: FlatekontrastSeksjon(flate: $arbeidsbenk.aktivFarge, bakgrunn: Fargetolk.tolk(bakgrunnHex) ?? Farge(hex: "#FFFFFF")!)
                default: EmptyView()
                }
            }
            TilpassKnapp(skjerm: .kontrast)
        }
        .formStyle(.grouped)
        .navigationTitle("Kontrast")
    }
}

/// Resultatet av en palettvurdering som seksjoner i en liste/et skjema. Brukes både i
/// Vurdering › Palett og i vurderingsarket fra en palett, så de ser like ut.
struct PalettVurderingInnhold: View {
    let vurdering: PalettVurdering

    var body: some View {
        // Hva vurderingen bygger på – før selve vurderingen, så det er tydelig hva den sier noe om.
        Section {
            grunnlagsrad("circle.lefthalf.filled", "Kontrast", "WCAG 2.2-kontrast mellom alle fargepar, og hvor mange som kan brukes til tekst (4,5:1).")
            grunnlagsrad("sun.max", "Lyshet", "Spennet i lyshet (OKLCH) – om paletten har lyse og mørke farger nok til hierarki og lesbarhet.")
            grunnlagsrad("circle.hexagongrid", "Kulører", "Hvilke kulører paletten består av, og om det bare er nøytrale.")
            grunnlagsrad("eye", "Fargesyn", "Fargepar som er tydelig ulike med normalt syn, men blir vanskelige å skille med protan-, deutan- eller tritanavvik eller akromatopsi (ΔE2000 under 10).")
            grunnlagsrad("square.dashed", "Fargerom", "Farger utenfor sRGB, som bare vises riktig på P3-skjermer.")
        } header: { Group {
            Text("Grunnlag for vurderingen")
        }.foregroundStyle(Color.sekundærTekst) } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(vurdering.kilde == .appleIntelligence
                     ? "Tallene regnes ut nøyaktig i appen. Apple Intelligence på enheten skriver vurderingen ut fra dem, og regner ikke selv."
                     : "Tallene regnes ut nøyaktig i appen, og vurderingen lages etter faste regler: lyshetsspenn minst 0,50, minst ett fargepar på 4,5:1, og ingen fargepar som forveksles ved rød-grønt fargesynsavvik.")
                Text("Vurderingen sier ikke noe om smak, stemning eller om fargene passer til et formål – bare om kontrast, lesbarhet og skillbarhet.")
                MetodeHenvisning(.wcag, .oklab, .machado, .ciede2000)
            }
            .foregroundStyle(Color.sekundærTekst)
        }
        Seksjon("Oppsummering") { Text(vurdering.oppsummering) }
        punkter(String(localized: "Styrker"), vurdering.styrker, "plus.circle.fill", Color.suksess)
        punkter(String(localized: "Svakheter"), vurdering.svakheter, "minus.circle.fill", Color.advarsel)
        punkter(String(localized: "Forslag"), vurdering.forslag, "arrow.right.circle.fill", Color.accentColor)
        Section {
            DisclosureGroup("Tallene for denne paletten") {
                ForEach(vurdering.fakta, id: \.self) { Text($0).font(.callout) }
            }
        } footer: { Group {
            Text(vurdering.kilde == .appleIntelligence
                 ? "Laget med Apple Intelligence på enheten. Kontrast og fargesyn er beregnet eksakt."
                 : "Regelbasert vurdering (Apple Intelligence er ikke tilgjengelig). Kontrast og fargesyn er beregnet eksakt.")
        }.foregroundStyle(Color.sekundærTekst) }
    }

    private func grunnlagsrad(_ symbol: String, _ tittel: LocalizedStringKey, _ tekst: LocalizedStringKey) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(tittel).font(.callout.weight(.semibold))
                Text(tekst).font(.callout).foregroundStyle(Color.sekundærTekst)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Color.accentColor)
        }
    }

    @ViewBuilder
    private func punkter(_ tittel: String, _ liste: [String], _ symbol: String, _ farge: Color) -> some View {
        if !liste.isEmpty {
            Seksjon(tittel) {
                ForEach(liste, id: \.self) { p in
                    Label { Text(p) } icon: { Image(systemName: symbol).foregroundStyle(farge) }
                }
            }
        }
    }
}
