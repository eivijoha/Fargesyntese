import SwiftUI

/// Metodene appen bygger på, med kilde, forklaring og hvordan Kolorist bruker dem.
/// Vises per seksjon («Metode: …») og samlet under «Metoder og kilder», så brukeren alltid kan se
/// hva tallene og fargene bygger på – også hva som er utviklet for appen og hva som er etablert fag.
enum Metode: String, CaseIterable, Identifiable {
    case oklab, cssColor4, cieLab, ciede2000, wcag, machado, icc, renCMYK, harmonier, kunnskapsbase

    var id: String { rawValue }

    /// Kort navn i henvisningen under en seksjon.
    var kortnavn: String {
        switch self {
        case .oklab: "OKLab/OKLCH"
        case .cssColor4: "CSS Color 4"
        case .cieLab: "CIELab D50"
        case .ciede2000: "CIEDE2000"
        case .wcag: "WCAG 2.2"
        case .machado: String(localized: "Machado mfl. 2009")
        case .icc: "ICC/ColorSync"
        case .renCMYK: String(localized: "UCR/GCR")
        case .harmonier: String(localized: "Fargesirkler")
        case .kunnskapsbase: String(localized: "Kunnskapsbase")
        }
    }

    var tittel: String {
        switch self {
        case .oklab: String(localized: "OKLab og OKLCH")
        case .cssColor4: String(localized: "CSS Color Module Level 4")
        case .cieLab: String(localized: "CIELab, CIE LCH og Bradford-tilpasning")
        case .ciede2000: String(localized: "CIEDE2000 (ΔE00)")
        case .wcag: String(localized: "WCAG 2.2 kontrast")
        case .machado: String(localized: "Simulering av fargesynsavvik")
        case .icc: String(localized: "ICC-profiler og fargestyring")
        case .renCMYK: String(localized: "Rene CMYK-verdier (UCR/GCR)")
        case .harmonier: String(localized: "Fargesirkler og harmonier")
        case .kunnskapsbase: String(localized: "Fargesemantikk og KI")
        }
    }

    /// Hvem som står bak, eller at metoden er laget for Kolorist.
    var kilde: String {
        switch self {
        case .oklab: "Björn Ottosson: «A perceptual color space for image processing» (2020)"
        case .cssColor4: "W3C: CSS Color Module Level 4 (Candidate Recommendation)"
        case .cieLab: "CIE 15:2018 Colorimetry; K. M. Lam (1985), Bradford-transformasjonen"
        case .ciede2000: "G. Sharma, W. Wu, E. N. Dalal: Color Research & Application 30(1), 2005; CIE 142-2001"
        case .wcag: "W3C: Web Content Accessibility Guidelines 2.2, suksesskriterium 1.4.3, 1.4.6 og 1.4.11"
        case .machado: "G. M. Machado, M. M. Oliveira, L. A. F. Fernandes: IEEE TVCG 15(6), 2009"
        case .icc: "International Color Consortium (ICC.1); Apple ColorSync via Core Graphics"
        case .renCMYK: String(localized: "Etablert trykkteknikk; søket er utviklet for Kolorist")
        case .harmonier: String(localized: "Klassisk fargelære (Johannes Itten for RYB); avbildningene er utviklet for Kolorist")
        case .kunnskapsbase: String(localized: "Utviklet for Kolorist; språkmodell fra Apple (Foundation Models)")
        }
    }

    var forklaring: String {
        switch self {
        case .oklab:
            String(localized: "Et perseptuelt fargerom der like tallsteg oppleves som like store fargeforskjeller. Kolorist regner overganger i OKLab, og toneskalaer, lysere/mørkere trinn, harmonier og metning i OKLCH (lyshet, kroma, kulør).")
        case .cssColor4:
            String(localized: "Standarden for farger på nettet. Kolorist bruker spesifikasjonens matriser og overføringsfunksjoner for sRGB, Display P3, Adobe RGB, Lab og OKLab, dens gamut-kartlegging (kroma reduseres i OKLCH mens lyshet og kulør bevares) og dens tekstsyntaks for farger.")
        case .cieLab:
            String(localized: "CIEs fargerom basert på menneskets fargesyn. Kolorist oppgir Lab og LCH med hvitpunkt D50, som ICC-profiler og Photoshop, og bruker Bradford-transformasjonen mellom D65 og D50.")
        case .ciede2000:
            String(localized: "CIEs formel for opplevd fargeforskjell. Brukes ved sammenligning av farger, gamutavvik og i analysen av farger som blir vanskelige å skille med fargesynsavvik. Implementasjonen er kontrollert mot testdataene i Sharma mfl.")
        case .wcag:
            String(localized: "W3Cs krav til kontrast mellom tekst/grafikk og bakgrunn, regnet ut fra relativ luminans. «Rett opp» endrer bare lysheten (OKLCH) til kravet er oppfylt.")
        case .machado:
            String(localized: "Fysiologisk basert modell for protan-, deutan- og tritanavvik, med matriser i lineær sRGB og alvorlighetsgrad som blanding med normalt syn. Akromatopsi vises som luminans alene. Brukes i Vurdering › Fargesyn, kontrastforhåndsvisningen og kamerafilteret. Simuleringen er en tilnærming; opplevelsen varierer mellom personer.")
        case .icc:
            String(localized: "Konvertering mellom fargerom via ICC-profiler, med valgt gjengivelseshensikt. Gjøres av Apples fargestyring (ColorSync). Profiler følger ikke med appen; Kolorist bruker systemets profiler og profiler du importerer.")
        case .renCMYK:
            String(localized: "Felles grått innslag i C, M og Y flyttes til sort, og Kolorist søker etter separasjonen med færrest trykkfarger som holder seg innenfor 1 ΔE00 av profilens egen separasjon.")
        case .harmonier:
            String(localized: "Komplementær, split-komplementær, analog og jevn fordeling beregnes som vinkler på valgt fargesirkel: OKLCH, CIE LCH, HSL eller RYB. RYB-sirkelen er en stykkevis lineær avbildning til RGB-kulør laget for appen.")
        case .kunnskapsbase:
            String(localized: "Paletter fra verdiord og «Beskriv en farge» bygger på en kunnskapsbase med fargebegreper laget for appen. Språkmodellen på enheten velger kulørfamilie, lyshet og metning, og fargene regnes ut i OKLCH. Tekst om fargebetydning er konvensjoner, ikke vitenskapelige fakta.")
        }
    }

    var lenke: URL? {
        switch self {
        case .oklab: URL(string: "https://bottosson.github.io/posts/oklab/")
        case .cssColor4: URL(string: "https://www.w3.org/TR/css-color-4/")
        case .cieLab: URL(string: "https://cie.co.at/publications/colorimetry-4th-edition")
        case .ciede2000: URL(string: "https://doi.org/10.1002/col.20070")
        case .wcag: URL(string: "https://www.w3.org/TR/WCAG22/")
        case .machado: URL(string: "https://doi.org/10.1109/TVCG.2009.113")
        case .icc: URL(string: "https://www.color.org/specification/ICC.1-2022-05.pdf")
        case .renCMYK, .harmonier, .kunnskapsbase: nil
        }
    }
}

/// «Metode: OKLab/OKLCH · CSS Color 4 ⓘ» under en seksjon. Trykk viser kilde og forklaring.
struct MetodeHenvisning: View {
    let metoder: [Metode]
    @State private var vis = false

    init(_ metoder: Metode...) { self.metoder = metoder }

    var body: some View {
        Button { vis = true } label: {
            // Én tekst, så navnene flyter over flere linjer sammen med ledeteksten.
            let navn = Text(metoder.map(\.kortnavn).joined(separator: " · ")).underline()
            let info = Text(Image(systemName: "info.circle"))
            Group {
                if metoder.count == 1 { Text("Metode: \(navn) \(info)") } else { Text("Metoder: \(navn) \(info)") }
            }
            .font(.footnote)
            .foregroundStyle(Color.sekundærTekst)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Metoder: \(metoder.map(\.tittel).joined(separator: ", "))"))
        .accessibilityHint("Viser kilder og forklaring")
        .sheet(isPresented: $vis) { MetoderArk(metoder: metoder) }
    }
}

/// Kilde og forklaring for utvalgte metoder, med lenke til alle.
struct MetoderArk: View {
    var metoder: [Metode] = Metode.allCases
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            List {
                ForEach(metoder) { MetodeRad(metode: $0) }
                if metoder.count < Metode.allCases.count {
                    Section {
                        NavigationLink("Alle metoder og kilder") {
                            List { ForEach(Metode.allCases) { MetodeRad(metode: $0) } }
                                .navigationTitle("Metoder og kilder")
                        }
                    }
                }
            }
            .navigationTitle(metoder.count == Metode.allCases.count ? "Metoder og kilder" : metoder.count == 1 ? "Metode" : "Metoder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Ferdig") { lukk() } } }
        }
        .presentationDetents([.medium, .large])
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }
}

private struct MetodeRad: View {
    let metode: Metode

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(metode.forklaring)
                Text(metode.kilde)
                    .font(.footnote)
                    .foregroundStyle(Color.sekundærTekst)
                    .textSelection(.enabled)
                if let lenke = metode.lenke {
                    Link(destination: lenke) {
                        Label("Les kilden", systemImage: "arrow.up.right.square")
                    }
                    .font(.footnote)
                }
            }
            .padding(.vertical, 2)
        } header: {
            Text(metode.tittel).foregroundStyle(Color.sekundærTekst)
        }
    }
}
