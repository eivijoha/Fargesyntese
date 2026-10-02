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
    @AppStorage("renCMYK") private var renCMYK = false
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


    /// Fargeflaten med feltet for verdi og «Vis også» – fast øverst mens resten ruller.
    @ViewBuilder
    private func fargepanel(_ farge: Farge, bred: Bool) -> some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        VStack(spacing: 0) {
            Fargeflate(farge: farge, modell: arbeidsbenk.modell, profil: visOgsåProfil, hensikt: hensikt,
                       kobletVerdier: kobletProfil.map { arbeidsbenk.profilverdier(for: $0) ?? farge.komponenter(i: $0, hensikt: hensikt) ?? [] },
                       renCMYK: renCMYK,
                       stablet: bred,
                       lagre: { lagreEnkeltfarger([$0], i: kontekst) },
                       leggIPalett: { lagreNavn = ""; lagreFarger = [$0] })
                // Smal visning: fast høyde øverst. Bred visning: fyller høyden til venstre.
                .frame(height: bred ? nil : 140)
                .frame(maxHeight: bred ? .infinity : nil)
            HStack {
                TextField("Hex, CSS eller beskrivelse", text: $hexTekst)
                    .font(.body.monospaced())
                    .frame(minWidth: 96)
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
                // Menyen får plass først; profilnavnet kortes ned når feltet ellers ville blitt for smalt.
                VisOgsåMeny(valgtID: $visOgsåID, begrens: $arbeidsbenk.begrensAktiv, farge: farge)
                    .layoutPriority(1)
                #if os(macOS)
                // Skjermpipette (hele skjermen). På iPhone/iPad brukes Utplukk-fanen.
                PipetteKnapp {
                    arbeidsbenk.aktivFarge = $0
                    arbeidsbenk.registrerMåling($0)
                }
                .labelStyle(.iconOnly)
                #endif
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
        }
        .frame(maxWidth: .infinity)
        .background(Color.kortbakgrunn, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.leading, 16)
        .padding(.trailing, bred ? 0 : 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color.skjemabakgrunn)
    }

    /// Bred visning (iPad i landskap, åpen foldetelefon i landskap): fargeflatene får venstre halvdel,
    /// over/under hverandre, og kontrollene ligger til høyre.
    private func erBred(_ størrelse: CGSize) -> Bool {
        #if os(iOS)
        størrelse.width > størrelse.height && størrelse.width >= 700
        #else
        false
        #endif
    }

    var body: some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        let farge = arbeidsbenk.aktivFarge

        GeometryReader { geo in
        let bred = erBred(geo.size)
        // AnyLayout bevarer skjemaets tilstand (rulleposisjon, glidere) når enheten roteres.
        let oppsett = bred ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        oppsett {
        fargepanel(farge, bred: bred)
            .frame(width: bred ? geo.size.width / 2 : nil)
        Form {
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
        .contentMargins(.top, 0, for: .scrollContent)
        }
        .background(Color.skjemabakgrunn)
        }
        .navigationTitle("Studio")
        #if os(iOS)
        // Liten tittel: fargepanelet står fast øverst og trenger plassen.
        .navigationBarTitleDisplayMode(.inline)
        // iPhone: ingen tittellinje – fanen sier allerede «Studio», og fargeflaten får plassen.
        .toolbar(UIDevice.current.userInterfaceIdiom == .phone ? .hidden : .automatic, for: .navigationBar)
        #endif
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
            VStack(alignment: .leading, spacing: 6) {
                if let p = kobletProfil {
                    Text("\(arbeidsbenk.modell.navn)-verdiene angis i \(p.navn) og vises slik de gjengis i dette fargerommet.")
                        .foregroundStyle(Color.sekundærTekst)
                }
                MetodeHenvisning(.cssColor4, .oklab, .cieLab, .icc)
            }
        }

        Seksjon("Verdier") {
            VerdiRad(navn: "Hex", tekst: farge.hex(medAlfa: farge.alfa < 1)) { Utklippstavle.kopier(farge) }
            ForEach(Fargemodell.allCases) { modell in
                VerdiRad(navn: modell.navn, tekst: modell.tekst(for: farge)) { Utklippstavle.kopier(farge, som: modell) }
            }
            GamutOversikt(farge: farge)
        }

        ICCSeksjon(farge: $arbeidsbenk.aktivFarge, profilID: $visOgsåID)
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
            LyshetstrinnKontroller(trinn: $arbeidsbenk.lyshetstrinn, grunnlyshet: farge.okLCH.l)
            Button("Legg raden i palett", systemImage: "plus.square.on.square") {
                lagreNavn = String(localized: "Lysere og mørkere \(farge.hex())")
                lagreFarger = varianter.map { PalettFarge(farge: $0, opphav: .toneskala) }
            }
        } header: { Group {
            Text("Lysere og mørkere")
        }.foregroundStyle(Color.sekundærTekst) } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tallene under hver prøve er OKLCH-lyshet i prosent. Trykk på en tone for å gjøre den til aktiv farge, eller trykk og hold for å lagre den.")
                MetodeHenvisning(.oklab, .cssColor4)
            }
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

    /// Fargene langs sporet for komponent `i`: de andre komponentene holdes fast, så sporet viser
    /// nøyaktig hva gliden gir. Farger utenfor skjermens gamut kartlegges ved visning.
    private func spor(for i: Int, område: ClosedRange<Double>, prøver: Int = 24) -> [Color] {
        let basis = gjeldende
        guard basis.indices.contains(i) else { return [] }
        return (0..<prøver).map { n in
            var v = basis
            v[i] = område.lowerBound + (område.upperBound - område.lowerBound) * Double(n) / Double(prøver - 1)
            return farge(fra: v, alfa: 1).swiftUI
        }
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
                FargeGlider(verdi: Binding(
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
                ), område: k.område, spor: spor(for: i, område: k.område), gjeldende: farge.swiftUI,
                   tittel: Text(k.navn),
                   verdiTekst: gjeldende[i].formatted(.number.precision(.fractionLength(k.desimaler))))
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
    /// OKLCH-lysheten skalaen regnes fra (grunnfargen).
    var grunnlyshet: Double = 0.6

    private let område: ClosedRange<Double> = 0.01...0.2

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

    var body: some View {
        Lyshetsstige(lysheter: trinn.lysheter(fra: grunnlyshet), grunnindeks: trinn.antallLysere)
            .frame(height: 34)
            .padding(.vertical, 2)
        Stepper("Lysere: \(trinn.antallLysere) steg", value: $trinn.antallLysere, in: 0...8)
        Stepper("Mørkere: \(trinn.antallMørkere) steg", value: $trinn.antallMørkere, in: 0...8)
        HStack {
            Text("Steg")
            Slider(value: steg, in: område, step: 0.01)
                .disabled(trinn.antallLysere == 0 && trinn.antallMørkere == 0)
            Text("±\(Int((trinn.lysereSteg * 100).rounded())) %-poeng")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.callout.monospacedDigit())
                .foregroundStyle(Color.sekundærTekst)
                .frame(minWidth: 96, alignment: .trailing)
        }
        .onAppear {
            // Bare like steg: «mot hvitt/sort» er tatt ut. Gjør om et lagret relativt steg
            // til omtrent samme første tone, og samkjør retningene.
            if trinn.modus == .relativ {
                trinn.modus = .fast
                steg.wrappedValue = ((trinn.lysereSteg * max(1 - grunnlyshet, 0.1)) * 100).rounded() / 100
            }
            steg.wrappedValue = trinn.lysereSteg.clamped(to: område)
        }
    }
}

/// Lyshetsskala fra sort til hvitt med et merke for hver tone, så avstanden mellom stegene synes:
/// like steg gir jevne mellomrom, avtagende steg tettere merker mot endene.
private struct Lyshetsstige: View {
    let lysheter: [Double]
    let grunnindeks: Int

    /// Tall som får plass uten å overlappe: grunnfargen alltid, så utover fra den.
    private func synligeEtiketter(bredde: CGFloat) -> Set<Int> {
        let x = lysheter.map { min(max($0, 0), 1) * bredde }
        var vist: Set<Int> = [grunnindeks]
        let rekkefølge = lysheter.indices.sorted { abs($0 - grunnindeks) < abs($1 - grunnindeks) }
        for i in rekkefølge where i != grunnindeks {
            if vist.allSatisfy({ abs(x[$0] - x[i]) >= 24 }) { vist.insert(i) }
        }
        return vist
    }

    var body: some View {
        GeometryReader { geo in
            let b = geo.size.width
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [.black, .white], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 10)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.sekundærTekst.opacity(0.4), lineWidth: 0.5))
                let synlige = synligeEtiketter(bredde: b)
                ForEach(Array(lysheter.enumerated()), id: \.offset) { i, l in
                    let x = min(max(l, 0), 1) * b
                    let erGrunn = i == grunnindeks
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(erGrunn ? Color.accentColor : Color.primary)
                            .frame(width: erGrunn ? 3 : 2, height: 16)
                        Text(Int((l * 100).rounded()), format: .number)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(erGrunn ? Color.primary : Color.sekundærTekst)
                            .fixedSize()
                            .opacity(synlige.contains(i) ? 1 : 0)
                    }
                    .position(x: x, y: 16)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lyshet for tonene")
        .accessibilityValue(lysheter.map { String(Int(($0 * 100).rounded())) }.joined(separator: ", "))
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
    /// CMYK-profil: vis «rene» verdier (færrest mulig trykkfarger, grått i sort) i stedet for profilens egen separasjon.
    var renCMYK = false
    /// Halvdelene over/under hverandre i stedet for side ved side (bred visning, f.eks. iPad i landskap).
    var stablet = false
    /// Lagre en halvdel som enkeltfarge, eller åpne «Legg i palett» for den.
    var lagre: (PalettFarge) -> Void = { _ in }
    var leggIPalett: (PalettFarge) -> Void = { _ in }

    /// Rene CMYK-verdier for gjeldende farge og profil. Søket er for tungt til å kjøre ved hver
    /// tegning (glidere), så det gjøres i bakgrunnen etter en kort pause og vises når det er klart.
    @State private var ren: (nøkkel: String, verdier: [Double])?

    private var renNøkkel: String? {
        guard renCMYK, kobletVerdier == nil, profil.modell == .cmyk else { return nil }
        return "\(farge.r),\(farge.g),\(farge.b)|\(profil.id)|\(hensikt.rawValue)"
    }

    /// Nærmeste farge i profilens rom og verdiene der. sRGB bruker perseptuell gamut-kartlegging
    /// (CSS Color 4), andre rom går via ICC-profilen med valgt gjengivelseshensikt.
    private var motpart: (farge: Farge, tekst: String, verdier: [Double]) {
        if let kobletVerdier { return (farge, profil.formatert(kobletVerdier), kobletVerdier) }
        if profil.id == ICCProfil.sRGB.id {
            let s = farge.gamutKartlagt(til: .sRGB)
            let v = s.sRGB
            return (s, s.hex(), [v.r, v.g, v.b])
        }
        if let nøkkel = renNøkkel, let ren, ren.nøkkel == nøkkel,
           let f = Farge(komponenter: ren.verdier, i: profil, alfa: farge.alfa) {
            return (f, profil.formatert(ren.verdier), ren.verdier)
        }
        guard let k = farge.komponenter(i: profil, hensikt: hensikt),
              let f = Farge(komponenter: k, i: profil, alfa: farge.alfa)
        else { return (farge, "–", []) }
        return (f, profil.formatert(k), k)
    }

    private var profiltittel: String {
        renCMYK && profil.modell == .cmyk ? String(localized: "\(profil.navn) · rene farger") : profil.navn
    }

    var body: some View {
        let høyre = motpart
        let høyreFarge = PalettFarge(farge: høyre.farge, representasjon: Fargerepresentasjon(
            rom: .icc(id: profil.id, navn: profil.navn), verdier: høyre.verdier, tekst: høyre.tekst))
        let venstre = PalettFarge(farge: farge, representasjon: Fargerepresentasjon(modell: modell, farge: farge))
        let oppsett = stablet ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
        oppsett {
            if kobletVerdier != nil {
                // Verdiene er angitt direkte i profilen: én flate, ingen sammenligning å vise.
                halvdel(høyreFarge, tittel: "\(modell.navn) · \(profil.navn)", tekst: høyre.tekst,
                        merknad: farge.erIDisplayP3 ? nil : String(localized: "Utenfor P3"))
            } else {
                halvdel(venstre, tittel: modell.navn, tekst: modell.tekst(for: farge),
                        merknad: farge.erIDisplayP3 ? nil : String(localized: "Utenfor P3"))
                halvdel(høyreFarge, tittel: profiltittel, tekst: høyre.tekst,
                        merknad: farge.erInnenfor(profil, hensikt: hensikt) ? nil
                            : String(localized: "Utenfor gamut · ΔE00 \(String(format: "%.1f", høyre.farge.deltaE2000(til: farge)))"))
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20, style: .continuous))
        .task(id: renNøkkel) {
            guard let nøkkel = renNøkkel else { return }
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let (f, p, h) = (farge, profil, hensikt)
            let resultat = await Task.detached(priority: .userInitiated) { RenCMYK.separer(f, i: p, hensikt: h) }.value
            if !Task.isCancelled, let resultat { ren = (nøkkel, resultat.verdier) }
        }
    }

    private func halvdel(_ pf: PalettFarge, tittel: String, tekst: String, merknad: String? = nil) -> some View {
        let f = pf.farge
        return FargeRute(farge: f, visTekst: false, hjørne: 0, visMerke: false, palettFarge: pf)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tittel).font(.caption.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.85)
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
                KopierTilMeny(farger: [pf])
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
    @AppStorage("renCMYK") private var renCMYK = false
    @Environment(ProfilBibliotek.self) private var bibliotek
    @State private var importerer = false
    @State private var importfeil: String?

    /// Standardrommene: sRGB, Display P3, Adobe RGB, Rec. 2020, ProPhoto RGB og Generic CMYK.
    private var standard: [ICCProfil] { ICCProfil.innebygde }
    private var valgtNavn: String { bibliotek.profil(id: valgtID).map(bibliotek.visningsnavn) ?? ICCProfil.sRGB.navn }

    #if os(macOS)
    /// Installerte profiler gruppert etter mappe: Systemet og Maskinen først, så mappene alfabetisk, Brukeren sist.
    private func installertGrupper(_ profiler: [ICCProfil]) -> [(navn: String, profiler: [ICCProfil])] {
        let grupper = Dictionary(grouping: profiler) { bibliotek.installertGruppe[$0.id] ?? String(localized: "Andre") }
        let først = [String(localized: "Systemet"), String(localized: "Maskinen")], sist = String(localized: "Brukeren")
        return grupper.keys.sorted { a, b in
            func rang(_ n: String) -> Int { først.firstIndex(of: n) ?? (n == sist ? 3 : 2) }
            return rang(a) != rang(b) ? rang(a) < rang(b) : a.localizedStandardCompare(b) == .orderedAscending
        }
        .map { ($0, grupper[$0]!) }
    }
    #endif

    /// Menyvalg med varsel når fargen er utenfor rommets gamut.
    @ViewBuilder private func valg(_ p: ICCProfil) -> some View {
        let navn = bibliotek.visningsnavn(p)
        if farge.erInnenfor(p) {
            Text(navn).tag(p.id)
        } else {
            Text(String(localized: "\(navn) – utenfor gamut")).tag(p.id)
        }
    }

    var body: some View {
        Menu {
            // Innstillinger for valgt profil øverst, så profilvalg og «+ ICC-profil», så listene.
            Toggle("Begrens nye farger til \(valgtNavn)", isOn: $begrens)
            if bibliotek.profil(id: valgtID)?.modell == .cmyk {
                // UCR/GCR: færrest mulig trykkfarger, med det grå innslaget flyttet til sort, så lenge
                // fargen holder seg innenfor 1 ΔE00 av profilens egen separasjon.
                Toggle("Rene CMYK-farger (UCR/GCR)", isOn: $renCMYK)
            }
            Divider()
            Button("ICC-profil", systemImage: "plus") { importerer = true }
            Divider()
            Picker("Standard", selection: $valgtID) {
                ForEach(standard) { valg($0) }
            }
            .pickerStyle(.inline)
            if !bibliotek.importerte.isEmpty {
                Picker("Mine profiler", selection: $valgtID) {
                    ForEach(bibliotek.importerte) { valg($0) }
                }
                .pickerStyle(.inline)
            }
            #if os(macOS)
            let installerte = bibliotek.installerte.filter { p in !bibliotek.importerte.contains { $0.id == p.id } }
            if !installerte.isEmpty {
                // Én undermeny per mappe; innen hver mappe RGB, CMYK og gråtone hver for seg.
                Menu("Installert på denne Macen") {
                    ForEach(installertGrupper(installerte), id: \.navn) { gruppe in
                        Menu("\(gruppe.navn) (\(gruppe.profiler.count))") {
                            let typer: [(LocalizedStringKey, CGColorSpaceModel)] = [("RGB", .rgb), ("CMYK", .cmyk), ("Gråtone", .monochrome)]
                            ForEach(typer, id: \.1.rawValue) { tittel, modell in
                                let utvalg = gruppe.profiler.filter { $0.modell == modell }
                                if !utvalg.isEmpty {
                                    // Uten gamutsjekk: det kan være hundrevis av installerte profiler, og menyen skal åpnes
                                    // raskt. Varselet vises i fargeflaten når profilen er valgt.
                                    Picker(tittel, selection: $valgtID) {
                                        ForEach(utvalg) { Text(bibliotek.visningsnavn($0)).tag($0.id) }
                                    }
                                    .pickerStyle(.inline)
                                }
                            }
                        }
                    }
                }
            }
            #endif
        } label: {
            HStack(spacing: 4) {
                // Eksplisitte farger: menyetiketter tones ellers i aksentfarge, og «sekundær» av
                // aksenten ga bare 1,9:1 kontrast.
                Text("Vis også:").foregroundStyle(Color.sekundærTekst).fixedSize()
                // Lange profilnavn kortes ned i stedet for å presse panelet utenfor skjermen.
                Text(valgtNavn).lineLimit(1).truncationMode(.tail).foregroundStyle(Color.accentColor)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
            }
            .font(.callout)
        }
        .menuIndicator(.hidden)
        // Fast rekkefølge: ellers snur iPadOS lista når menyen åpnes oppover, og bryterne havner nederst.
        .menuOrder(.fixed)
        .help("Velg fargerommet som vises ved siden av fargen")
        // En installert Mac-profil som velges, kopieres til «Mine profiler» og synkes til de andre enhetene.
        .onChange(of: valgtID) { _, ny in
            if let p = bibliotek.profil(id: ny) { bibliotek.taMedTilMineProfiler(p) }
        }
        .fileImporter(isPresented: $importerer, allowedContentTypes: ICCSeksjon.profiltyper, allowsMultipleSelection: true) { resultat in
            do {
                let profiler = try resultat.get().map { try bibliotek.importer(fra: $0) }
                // Siste importerte profil vises med en gang.
                if let siste = profiler.last { valgtID = siste.id }
            } catch {
                importfeil = error.localizedDescription
            }
        }
        .alert("Kunne ikke legge til profilen", isPresented: Binding(get: { importfeil != nil }, set: { if !$0 { importfeil = nil } })) {
            Button("OK") {}
        } message: {
            Text(importfeil ?? "")
        }
    }
}

/// Status for fargen i standardrommene og egne ICC-profiler.
struct GamutOversikt: View {
    let farge: Farge
    @Environment(ProfilBibliotek.self) private var bibliotek

    /// Standardrommene og egne profiler – ikke alle installerte på Macen (kan være hundrevis).
    private var profiler: [ICCProfil] { ICCProfil.innebygde + bibliotek.importerte }

    var body: some View {
        DisclosureGroup {
            ForEach(profiler) { p in
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
            let utenfor = profiler.filter { !farge.erInnenfor($0) }
            LabeledContent("Gamut") {
                if utenfor.isEmpty {
                    Text("Innenfor alle").foregroundStyle(Color.suksess)
                } else {
                    Text("Utenfor \(utenfor.count) av \(profiler.count)")
                        .foregroundStyle(Color.advarsel)
                }
            }
        }
    }
}

extension Color {
    /// Bakgrunnen i grupperte skjemaer, og kortene oppå den.
    static var skjemabakgrunn: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    static var kortbakgrunn: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
