import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI

/// Studio: rediger aktiv farge i valgfri fargemodell, se alle representasjoner.
struct FargeEditor: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var hexTekst = ""
    @State private var lagreFarger: [PalettFarge]?
    @State private var lagreNavn = ""
    @State private var beskriver = false
    @Environment(\.modelContext) private var kontekst
    @AppStorage("studioModus") private var modus: Modus = .farge
    @AppStorage("visOgsåProfil") private var visOgsåID = ICCProfil.sRGB.id
    @AppStorage("gjengivelseshensikt") private var hensikt: Gjengivelseshensikt = .relativKolorimetrisk
    @Environment(ProfilBibliotek.self) private var bibliotek

    private var visOgsåProfil: ICCProfil { bibliotek.profil(id: visOgsåID) ?? .sRGB }

    /// Når fargemodellen og valgt ICC-profil er av samme slag (CMYK + CMYK-profil, RGB + RGB-profil),
    /// angis verdiene direkte i profilen: gliderne er profilens CMYK/RGB, og fargen er alltid innenfor.
    private var kobletProfil: ICCProfil? {
        let p = visOgsåProfil
        switch (arbeidsbenk.modell, p.modell) {
        case (.cmyk, .cmyk): return p
        case (.rgb, .rgb): return p.id == ICCProfil.sRGB.id ? nil : p
        default: return nil
        }
    }

    /// Studio er delt i moduser, så harmonier og toner ikke gjemmer seg nederst i en lang liste.
    enum Modus: String, CaseIterable, Identifiable {
        case farge, toner, harmoni
        var id: String { rawValue }
        var navn: String {
            switch self {
            case .farge: String(localized: "Farge")
            case .toner: String(localized: "Toner")
            case .harmoni: String(localized: "Harmoni")
            }
        }
        var symbol: String {
            switch self {
            case .farge: "slider.horizontal.3"
            case .toner: "square.3.layers.3d"
            case .harmoni: "circle.hexagongrid"
            }
        }
    }

    var body: some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        let farge = arbeidsbenk.aktivFarge

        Form {
            Section {
                Fargeflate(farge: farge, modell: arbeidsbenk.modell, profil: visOgsåProfil, hensikt: hensikt,
                           kobletVerdier: kobletProfil.map { arbeidsbenk.profilverdier(for: $0) ?? farge.komponenter(i: $0, hensikt: hensikt) ?? [] },
                           lagre: { lagreEnkeltfarger([$0], i: kontekst) },
                           leggIPalett: { lagreNavn = ""; lagreFarger = [$0] })
                    .frame(height: 140)
                    .listRowInsets(EdgeInsets())
                HStack {
                    TextField("Hex, CSS eller beskrivelse", text: $hexTekst)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .onSubmit {
                            if let f = Fargetolk.tolk(hexTekst) {
                                arbeidsbenk.aktivFarge = f
                            } else {
                                // Ikke hex/CSS: tolk teksten som en beskrivelse («dyp havblå»), regnet ut i OKLCH.
                                let beskrivelse = hexTekst
                                beskriver = true
                                Task {
                                    defer { beskriver = false }
                                    arbeidsbenk.vis(await Fargebeskriver.farge(fra: beskrivelse))
                                }
                            }
                        }
                        .overlay(alignment: .trailing) {
                            if beskriver { ProgressView().controlSize(.small) }
                        }
                    VisOgsåMeny(valgtID: $visOgsåID, begrens: $arbeidsbenk.begrensAktiv, farge: farge)
                    #if os(macOS)
                    // Skjermpipette (hele skjermen). På iPhone/iPad brukes Utplukk-fanen.
                    PipetteKnapp {
                        arbeidsbenk.aktivFarge = $0
                        arbeidsbenk.registrerMåling($0)
                    }
                    .labelStyle(.iconOnly)
                    #endif
                }
            }

            Section {
                Picker("Modus", selection: $modus) {
                    ForEach(Modus.allCases) { Label($0.navn, systemImage: $0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            switch modus {
            case .farge: fargeModus(farge)
            case .toner: tonerModus(farge)
            case .harmoni:
                HarmoniSeksjon(grunnfarge: farge, gamut: arbeidsbenk.gamut, begrens: arbeidsbenk.begrens,
                               velg: { arbeidsbenk.aktivFarge = $0 }) { farger, navn in
                    lagreFarger = farger
                    lagreNavn = navn
                }
            }
        }
        .formStyle(.grouped)
        #if os(iOS)
        .listSectionSpacing(.compact)
        #endif
        .environment(\.defaultMinListRowHeight, 44)
        .navigationTitle("Studio")
        .sheet(isPresented: Binding(get: { lagreFarger != nil }, set: { if !$0 { lagreFarger = nil } })) {
            VelgPalettArk(farger: lagreFarger ?? [], foreslåttNavn: lagreNavn)
        }
        .onAppear {
            hexTekst = farge.hex()
            arbeidsbenk.begrensProfil = visOgsåProfil
        }
        .onChange(of: visOgsåID) { arbeidsbenk.begrensProfil = visOgsåProfil }
        .onChange(of: farge) { _, ny in hexTekst = ny.hex() }
        .dropDestination(for: Farge.self) { farger, _ in
            guard let f = farger.first else { return false }
            arbeidsbenk.aktivFarge = f
            return true
        }
    }
}

extension FargeEditor {
    @ViewBuilder
    fileprivate func fargeModus(_ farge: Farge) -> some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        Section {
            Picker("Fargemodell", selection: $arbeidsbenk.modell) {
                ForEach(Fargemodell.redigerbare) { Text($0.navn).tag($0) }
            }
            KomponentGlidere(modell: arbeidsbenk.modell, profil: kobletProfil, hensikt: hensikt,
                             farge: $arbeidsbenk.aktivFarge) { profil, verdier, farge in
                arbeidsbenk.profilverdier = .init(profilID: profil.id, verdier: verdier, farge: farge)
            }
        } footer: {
            if let p = kobletProfil {
                Text("\(arbeidsbenk.modell.navn)-verdiene angis i \(p.navn) og vises slik de gjengis i dette fargerommet.")
                    .foregroundStyle(Color.sekundærTekst)
            }
        }

        Seksjon("Verdier") {
            VerdiRad(navn: "Hex", tekst: farge.hex(medAlfa: farge.alfa < 1)) { Utklippstavle.kopier(farge) }
            ForEach(Fargemodell.allCases) { modell in
                VerdiRad(navn: modell.navn, tekst: modell.tekst(for: farge)) { Utklippstavle.kopier(farge, som: modell) }
            }
            GamutOversikt(farge: farge)
        }

        ICCSeksjon(farge: $arbeidsbenk.aktivFarge)
    }

    @ViewBuilder
    fileprivate func tonerModus(_ farge: Farge) -> some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        Section {
            let varianter = arbeidsbenk.lyshetstrinn.toner(for: farge, gamut: arbeidsbenk.gamut).map(arbeidsbenk.begrens)
            HStack(spacing: 4) {
                ForEach(Array(varianter.enumerated()), id: \.offset) { i, variant in
                    VStack(spacing: 2) {
                        FargeRute(farge: variant, visTekst: false, hjørne: 6,
                                  lagre: { lagreEnkeltfarger([PalettFarge(farge: $0, opphav: .toneskala)], i: kontekst) },
                                  leggIPalett: { lagreNavn = ""; lagreFarger = [PalettFarge(farge: $0, opphav: .toneskala)] },
                                  valgBoble: true)
                            .frame(height: 44)
                            .overlay {
                                if i == arbeidsbenk.lyshetstrinn.antallLysere {
                                    RoundedRectangle(cornerRadius: 6).strokeBorder(.primary, lineWidth: 2)
                                }
                            }
                            .onTapGesture { arbeidsbenk.aktivFarge = variant }
                        Text(variant.okLCH.l * 100, format: .number.precision(.fractionLength(0)))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.sekundærTekst)
                    }
                }
            }
            LyshetstrinnKontroller(trinn: $arbeidsbenk.lyshetstrinn)
            Button("Legg raden i palett", systemImage: "plus.square.on.square") {
                lagreNavn = String(localized: "Lysere og mørkere \(farge.hex())")
                lagreFarger = varianter.map { PalettFarge(farge: $0, opphav: .toneskala) }
            }
        } header: { Group {
            Text("Lysere og mørkere")
        }.foregroundStyle(Color.sekundærTekst) } footer: {
            Text("Tallene under hver prøve er OKLCH-lyshet i prosent. Trykk på en tone for å gjøre den til aktiv farge, eller trykk og hold for å lagre den.")
        }
    }
}

/// Glidebrytere for hver komponent. Verdiene holdes lokalt mens man drar, slik at
/// kulør ikke «hopper» for grå farger (der kulør er udefinert).
struct KomponentGlidere: View {
    let modell: Fargemodell
    /// Når satt, er verdiene komponentene i denne ICC-profilen (samme antall og område 0…1 som modellen).
    var profil: ICCProfil? = nil
    var hensikt: Gjengivelseshensikt = .relativKolorimetrisk
    @Binding var farge: Farge
    /// Meldes når verdier er skrevet inn i profilen, så visningen kan vise nøyaktig de verdiene.
    var profilverdier: (ICCProfil, [Double], Farge) -> Void = { _, _, _ in }
    @State private var verdier: [Double] = []

    private func verdier(for f: Farge) -> [Double] {
        if let profil, let k = f.komponenter(i: profil, hensikt: hensikt) { return k.map { min(max($0, 0), 1) } }
        return modell.verdier(for: f)
    }

    private func farge(fra v: [Double], alfa: Double) -> Farge {
        if let profil, let f = Farge(komponenter: v, i: profil, alfa: alfa) { return f }
        return modell.farge(fra: v, alfa: alfa)
    }

    /// Lokale verdier når de hører til gjeldende modell, ellers utledet fra fargen.
    private var gjeldende: [Double] {
        verdier.count == modell.komponenter.count ? verdier : verdier(for: farge)
    }

    var body: some View {
        ForEach(Array(modell.komponenter.enumerated()), id: \.offset) { i, k in
            // Vern: ved bytte av modell (f.eks. CMYK → RGB) kan en rad bli tegnet før listen er oppdatert.
            // Kompakt: navn, glider og verdi på én linje, så gliderne og fargeflaten får plass samtidig.
            if i < gjeldende.count {
            HStack(spacing: 10) {
                Text(k.navn)
                    .font(.callout)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: 78, alignment: .leading)
                Slider(value: Binding(
                    get: { gjeldende[i] },
                    set: { ny in
                        var v = gjeldende
                        guard v.indices.contains(i) else { return }
                        v[i] = ny
                        verdier = v
                        let ny = farge(fra: v, alfa: farge.alfa)
                        // Meld verdiene før fargen settes, så begrensningen ser at de er angitt i profilen.
                        if let profil { profilverdier(profil, v, ny) }
                        farge = ny
                    }
                ), in: k.område)
                Text(gjeldende[i], format: .number.precision(.fractionLength(k.desimaler)))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Color.sekundærTekst)
                    .frame(width: 52, alignment: .trailing)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .accessibilityElement(children: .contain)
            }
        }
        .onChange(of: modell) { _, _ in verdier = verdier(for: farge) }
        .onChange(of: profil?.id) { _, _ in verdier = verdier(for: farge) }
        .onChange(of: farge) { _, ny in
            // Oppdater bare når endringen kom utenfra (ikke fra våre egne glidere).
            if verdier.count != modell.komponenter.count
                || farge(fra: verdier, alfa: ny.alfa).avstandOK(til: ny) > 1e-4 {
                verdier = verdier(for: ny)
            }
        }
    }
}

/// Rad i «Verdier» med egen kopieringsknapp og kort bekreftelse.
struct VerdiRad: View {
    let navn: String
    let tekst: String
    var kopier: () -> Void
    @State private var kopiert = false

    var body: some View {
        HStack {
            Text(navn)
            Spacer(minLength: 12)
            Text(tekst)
                .font(.callout.monospaced())
                .foregroundStyle(Color.sekundærTekst)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)
            Button {
                kopier()
                kopiert = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    kopiert = false
                }
            } label: {
                Image(systemName: kopiert ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 24)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(kopiert ? "Kopiert" : "Kopier \(navn)")
            .sensoryFeedback(.success, trigger: kopiert) { _, ny in ny }
        }
        .contextMenu { Button("Kopier \(navn)", systemImage: "doc.on.doc", action: kopier) }
    }
}

/// Antall og størrelse på lysere/mørkere steg – hver retning for seg.
/// Antall lysere/mørkere steg hver for seg, og én felles stegstørrelse for begge retninger.
struct LyshetstrinnKontroller: View {
    @Binding var trinn: Lyshetstrinn

    private var område: ClosedRange<Double> { trinn.modus == .fast ? 0.01...0.2 : 0.05...0.6 }

    /// Felles steg: setter begge retningene likt.
    private var steg: Binding<Double> {
        Binding(
            get: { trinn.lysereSteg },
            set: { ny in
                trinn.lysereSteg = ny
                trinn.mørkereSteg = ny
            }
        )
    }

    private var stegtekst: String {
        let v = Int((trinn.lysereSteg * 100).rounded())
        return trinn.modus == .fast ? String(localized: "±\(v) %-poeng") : String(localized: "\(v) % mot hvitt/sort")
    }

    var body: some View {
        Picker("Stegtype", selection: $trinn.modus) {
            Text("Faste steg").tag(Lyshetstrinn.Modus.fast)
            Text("Mot hvitt/sort").tag(Lyshetstrinn.Modus.relativ)
        }
        .pickerStyle(.segmented)
        Stepper("Lysere: \(trinn.antallLysere) steg", value: $trinn.antallLysere, in: 0...8)
        Stepper("Mørkere: \(trinn.antallMørkere) steg", value: $trinn.antallMørkere, in: 0...8)
        HStack {
            Text("Steg")
            Slider(value: steg, in: område, step: 0.01)
                .disabled(trinn.antallLysere == 0 && trinn.antallMørkere == 0)
            Text(stegtekst)
                .font(.callout.monospacedDigit())
                .foregroundStyle(Color.sekundærTekst)
                .frame(minWidth: 96, alignment: .trailing)
        }
        .onChange(of: trinn.modus) { _, _ in
            // Hold steget innenfor det nye området, og likt i begge retninger.
            steg.wrappedValue = trinn.lysereSteg.clamped(to: område)
        }
        .onAppear {
            // Tidligere versjoner kunne ha ulike steg per retning; samkjør dem.
            if trinn.mørkereSteg != trinn.lysereSteg { steg.wrappedValue = trinn.lysereSteg }
        }
    }
}

private extension Double {
    func clamped(to r: ClosedRange<Double>) -> Double { Swift.min(Swift.max(self, r.lowerBound), r.upperBound) }
}

/// Stor fargeflate øverst i Studio, delt: Display P3 til venstre (fargen slik den er) og
/// nærmeste tilsvarende farge i valgt fargerom til høyre. Høyre side viser hex for sRGB,
/// ellers fargeverdiene i rommet (RGB 0–255, CMYK i %). Når CMYK/RGB angis direkte i profilen,
/// vises én udelt flate.
struct Fargeflate: View {
    let farge: Farge
    /// Fargemodellen som er valgt i Studio – venstre halvdel viser verdiene i den.
    let modell: Fargemodell
    let profil: ICCProfil
    var hensikt: Gjengivelseshensikt = .relativKolorimetrisk
    /// Verdiene i profilen når modellen er koblet til den (CMYK/RGB angitt direkte i profilen).
    /// Da er fargen per definisjon innenfor rommet, og begge halvdeler viser profilverdiene.
    var kobletVerdier: [Double]? = nil
    /// Lagre en halvdel som enkeltfarge, eller åpne «Legg i palett» for den.
    var lagre: (PalettFarge) -> Void = { _ in }
    var leggIPalett: (PalettFarge) -> Void = { _ in }

    /// Nærmeste farge i profilens rom og verdiene der. sRGB bruker perseptuell gamut-kartlegging
    /// (CSS Color 4), andre rom går via ICC-profilen med valgt gjengivelseshensikt.
    private var motpart: (farge: Farge, tekst: String, verdier: [Double]) {
        if let kobletVerdier { return (farge, profil.formatert(kobletVerdier), kobletVerdier) }
        if profil.id == ICCProfil.sRGB.id {
            let s = farge.gamutKartlagt(til: .sRGB)
            let v = s.sRGB
            return (s, s.hex(), [v.r, v.g, v.b])
        }
        guard let k = farge.komponenter(i: profil, hensikt: hensikt),
              let f = Farge(komponenter: k, i: profil, alfa: farge.alfa)
        else { return (farge, "–", []) }
        return (f, profil.formatert(k), k)
    }

    var body: some View {
        let høyre = motpart
        let høyreFarge = PalettFarge(farge: høyre.farge, representasjon: Fargerepresentasjon(
            rom: .icc(id: profil.id, navn: profil.navn), verdier: høyre.verdier, tekst: høyre.tekst))
        let venstre = PalettFarge(farge: farge, representasjon: Fargerepresentasjon(modell: modell, farge: farge))
        HStack(spacing: 0) {
            if kobletVerdier != nil {
                // Verdiene er angitt direkte i profilen: én flate, ingen sammenligning å vise.
                halvdel(høyreFarge, tittel: "\(modell.navn) · \(profil.navn)", tekst: høyre.tekst,
                        merknad: farge.erIDisplayP3 ? nil : String(localized: "Utenfor P3"))
            } else {
                halvdel(venstre, tittel: modell.navn, tekst: modell.tekst(for: farge),
                        merknad: farge.erIDisplayP3 ? nil : String(localized: "Utenfor P3"))
                halvdel(høyreFarge, tittel: profil.navn, tekst: høyre.tekst,
                        merknad: farge.erInnenfor(profil, hensikt: hensikt) ? nil
                            : String(localized: "Utenfor gamut · ΔE00 \(String(format: "%.1f", høyre.farge.deltaE2000(til: farge)))"))
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous))
    }

    private func halvdel(_ pf: PalettFarge, tittel: String, tekst: String, merknad: String? = nil) -> some View {
        let f = pf.farge
        return FargeRute(farge: f, visTekst: false, hjørne: 0, visMerke: false)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tittel).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(tekst).font(.caption.monospaced()).lineLimit(2).minimumScaleFactor(0.6)
                    if let merknad {
                        Label(merknad, systemImage: "exclamationmark.triangle.fill").font(.caption2)
                    }
                }
                .foregroundStyle(f.lesbarTekstfarge.swiftUI)
                .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                LagreMeny(lagre: { lagre(pf) }, leggIPalett: { leggIPalett(pf) })
                    .font(.body.weight(.semibold))
                    .foregroundStyle(f.lesbarTekstfarge.swiftUI)
                    .padding(6)
            }
            .contextMenu {
                Button("Lagre som enkeltfarge", systemImage: "plus.square") { lagre(pf) }
                Button("Legg i palett …", systemImage: "plus.square.on.square") { leggIPalett(pf) }
                Button("Kopier verdier", systemImage: "doc.on.doc") { Utklippstavle.kopierTekst(tekst) }
                Button("Kopier hex", systemImage: "number") { Utklippstavle.kopier(f) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(tittel): \(tekst)")
    }
}

/// «Vis også: …» – velg fargerommet som vises til høyre i fargeflaten.
struct VisOgsåMeny: View {
    @Binding var valgtID: String
    @Binding var begrens: Bool
    let farge: Farge
    @Environment(ProfilBibliotek.self) private var bibliotek

    private var standard: [ICCProfil] { ICCProfil.innebygde.filter { $0.id != ICCProfil.displayP3.id } }
    private var valgtNavn: String { bibliotek.profil(id: valgtID)?.navn ?? ICCProfil.sRGB.navn }

    /// Menyvalg med varsel når fargen er utenfor rommets gamut.
    @ViewBuilder private func valg(_ p: ICCProfil) -> some View {
        if farge.erInnenfor(p) {
            Text(p.navn).tag(p.id)
        } else {
            Text(String(localized: "\(p.navn) – utenfor gamut")).tag(p.id)
        }
    }

    var body: some View {
        Menu {
            Picker("Standard", selection: $valgtID) {
                ForEach(standard) { valg($0) }
            }
            .pickerStyle(.inline)
            if !bibliotek.importerte.isEmpty {
                Picker("Installerte ICC-profiler", selection: $valgtID) {
                    ForEach(bibliotek.importerte) { valg($0) }
                }
                .pickerStyle(.inline)
            }
            Divider()
            Toggle("Begrens nye farger til \(valgtNavn)", isOn: $begrens)
        } label: {
            HStack(spacing: 4) {
                // Eksplisitte farger: menyetiketter tones ellers i aksentfarge, og «sekundær» av
                // aksenten ga bare 1,9:1 kontrast.
                Text("Vis også:").foregroundStyle(Color.sekundærTekst)
                Text(valgtNavn).lineLimit(1).foregroundStyle(Color.accentColor)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
            }
            .font(.callout)
        }
        .fixedSize()
        .menuIndicator(.hidden)
        .help("Velg fargerommet som vises ved siden av Display P3")
    }
}

/// Status for fargen i alle standardrom og installerte ICC-profiler.
struct GamutOversikt: View {
    let farge: Farge
    @Environment(ProfilBibliotek.self) private var bibliotek

    var body: some View {
        DisclosureGroup {
            ForEach(bibliotek.alle) { p in
                let innenfor = farge.erInnenfor(p)
                HStack {
                    Text(p.navn).font(.callout)
                    Spacer()
                    Text(innenfor ? "Innenfor" : "Utenfor")
                        .font(.callout)
                        .foregroundStyle(innenfor ? Color.suksess : Color.advarsel)
                }
            }
        } label: {
            let utenfor = bibliotek.alle.filter { !farge.erInnenfor($0) }
            LabeledContent("Gamut") {
                if utenfor.isEmpty {
                    Text("Innenfor alle").foregroundStyle(Color.suksess)
                } else {
                    Text("Utenfor \(utenfor.count) av \(bibliotek.alle.count)")
                        .foregroundStyle(Color.advarsel)
                }
            }
        }
    }
}
