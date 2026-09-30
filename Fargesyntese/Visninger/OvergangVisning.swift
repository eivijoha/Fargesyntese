import FargeKjerne
import SwiftUI

/// Overgangstoner i like OKLab-steg mellom to farger, med lysere/mørkere rader.
struct OvergangVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    // Lagres som CSS-tekst (hex, eller Display P3 utenfor sRGB), så endepunktene huskes.
    @AppStorage("overgangFra") private var startTekst = "#1B3A6B"
    @AppStorage("overgangTil") private var sluttTekst = "#F2B84B"

    private var start: Farge {
        get { Fargetolk.tolk(startTekst) ?? Farge(hex: "#1B3A6B")! }
        nonmutating set { startTekst = Self.lagringstekst(newValue) }
    }
    private var slutt: Farge {
        get { Fargetolk.tolk(sluttTekst) ?? Farge(hex: "#F2B84B")! }
        nonmutating set { sluttTekst = Self.lagringstekst(newValue) }
    }

    private static func lagringstekst(_ f: Farge) -> String {
        f.erISRGB ? f.hex() : Fargemodell.displayP3.tekst(for: f)
    }
    @State private var antall = 7
    @State private var visLagre = false

    private var toner: [Farge] { Overgang.toner(fra: start, til: slutt, antall: antall).map(arbeidsbenk.begrens) }

    /// Rader fra lysest til mørkest; midtraden er selve overgangen.
    private var rader: [[Farge]] {
        let trinn = arbeidsbenk.lyshetstrinn
        let variasjoner = toner.map { trinn.toner(for: $0, gamut: arbeidsbenk.gamut).map(arbeidsbenk.begrens) }
        return (0..<(trinn.antallLysere + trinn.antallMørkere + 1)).map { rad in variasjoner.map { $0[rad] } }
    }

    private func endepunkt(_ tittel: String, _ farge: Farge, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            Text(tittel).font(.caption.weight(.semibold))
            Text(farge.hex()).font(.caption2.monospaced()).foregroundStyle(Color.sekundærTekst)
        }
    }

    var body: some View {
        Form {
            Seksjon("Endepunkter") {
                FargeValgRad(tittel: String(localized: "Fra"), farge: Binding(get: { start }, set: { start = $0 }))
                FargeValgRad(tittel: String(localized: "Til"), farge: Binding(get: { slutt }, set: { slutt = $0 }))
                Button("Bytt om", systemImage: "arrow.left.arrow.right") {
                    let a = start
                    start = slutt
                    slutt = a
                }
            }
            Seksjon("Overgang") {
                Stepper("Toner: \(antall)", value: $antall, in: 2...24)
            }
            Seksjon("Lysere og mørkere rader") {
                @Bindable var arbeidsbenk = arbeidsbenk
                LyshetstrinnKontroller(trinn: $arbeidsbenk.lyshetstrinn)
            }
            // Selve overgangen: venstre ende er nøyaktig «Fra», høyre ende nøyaktig «Til».
            Section {
                HStack(spacing: 3) {
                    ForEach(Array(toner.enumerated()), id: \.offset) { _, farge in
                        FargeRute(farge: farge, visTekst: false, hjørne: 4)
                            .frame(height: 56)
                            .onTapGesture { arbeidsbenk.aktivFarge = farge }
                    }
                }
                HStack(alignment: .top) {
                    endepunkt(String(localized: "Fra"), start)
                    Spacer()
                    endepunkt(String(localized: "Til"), slutt, trailing: true)
                }
            } header: { Group {
                Text("Overgang i OKLab – \(antall) toner")
            }.foregroundStyle(Color.sekundærTekst) }

            // Lysere og mørkere varianter av hver tone; overgangsraden er markert med ramme.
            if rader.count > 1 {
                Section {
                    Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                        let midtrad = arbeidsbenk.lyshetstrinn.antallLysere
                        ForEach(Array(rader.enumerated()), id: \.offset) { r, rad in
                            GridRow {
                                ForEach(Array(rad.enumerated()), id: \.offset) { _, farge in
                                    FargeRute(farge: farge, visTekst: false, hjørne: 4)
                                        .frame(minHeight: 36)
                                        .overlay {
                                            if r == midtrad {
                                                RoundedRectangle(cornerRadius: 4).strokeBorder(.primary, lineWidth: 2)
                                            }
                                        }
                                        .onTapGesture { arbeidsbenk.aktivFarge = farge }
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                } header: { Group {
                    Text("Med lysere og mørkere rader")
                }.foregroundStyle(Color.sekundærTekst) } footer: {
                    Text("Raden med ramme er selve overgangen. Radene over er lysere, radene under mørkere.")
                }
            }

            CSSGradientSeksjon(start: start, slutt: slutt, toner: toner)
        }
        .formStyle(.grouped)
        .navigationTitle("Overgang")
        .toolbar {
            Button("Lagre som palett", systemImage: "square.and.arrow.down") { visLagre = true }
        }
        .sheet(isPresented: $visLagre) {
            VelgPalettArk(farger: rader.flatMap { $0 }.map { PalettFarge(farge: $0, opphav: .overgang) },
                          foreslåttNavn: String(localized: "Overgang \(start.hex()) → \(slutt.hex())"))
        }
    }
}

/// Overgangen som CSS-gradient: forhåndsvisning, valg og kopiering.
struct CSSGradientSeksjon: View {
    let start: Farge
    let slutt: Farge
    let toner: [Farge]
    @AppStorage("gradientForm") private var form: CSSGradient.Form = .lineær
    @AppStorage("gradientVinkel") private var vinkel = 90.0
    @AppStorage("gradientTrinnvis") private var trinnvis = false
    @State private var kopiert = false

    /// Glidende: bare endepunktene (CSS interpolerer selv i OKLab). Trinnvis: hver tone som et bånd.
    private var gradient: CSSGradient {
        CSSGradient(farger: trinnvis ? toner : [start, slutt], form: form, vinkel: vinkel, trinnvis: trinnvis)
    }

    private var stopp: [Gradient.Stop] {
        if trinnvis {
            let n = Double(toner.count)
            return toner.enumerated().flatMap { i, f in
                [Gradient.Stop(color: f.swiftUI, location: Double(i) / n), Gradient.Stop(color: f.swiftUI, location: Double(i + 1) / n)]
            }
        }
        let prøver = Overgang.toner(fra: start, til: slutt, antall: 24)
        return prøver.enumerated().map { Gradient.Stop(color: $1.swiftUI, location: Double($0) / 23) }
    }

    var body: some View {
        Section {
            forhåndsvisning
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            Picker("Form", selection: $form) {
                ForEach(CSSGradient.Form.allCases) { Text($0.navn).tag($0) }
            }
            .pickerStyle(.segmented)
            if form != .radiell {
                HStack {
                    Text(form == .lineær ? "Retning" : "Start")
                    Slider(value: $vinkel, in: 0...360, step: 15)
                    Text("\(Int(vinkel))°").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
            Toggle("Trinnvis (harde overganger, \(toner.count) bånd)", isOn: $trinnvis)
            Text(gradient.deklarasjon)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .foregroundStyle(Color.sekundærTekst)
            HStack {
                Button(kopiert ? "Kopiert" : "Kopier CSS", systemImage: kopiert ? "checkmark" : "doc.on.doc") {
                    Utklippstavle.kopierTekst(gradient.deklarasjon)
                    kopiert = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); kopiert = false }
                }
                Spacer()
                Menu("Mer") {
                    Button("Kopier bare moderne verdi") { Utklippstavle.kopierTekst(gradient.moderne) }
                    Button("Kopier bare reserve (sRGB)") { Utklippstavle.kopierTekst(gradient.reserve) }
                }
            }
            .buttonStyle(.borderless)
        } header: { Group {
            Text("CSS-gradient")
        }.foregroundStyle(Color.sekundærTekst) } footer: {
            Text("Moderne nettlesere bruker `in oklab` og viser nøyaktig samme overgang som her. Eldre nettlesere får tette sRGB-stopp som etterligner den.")
        }
    }

    @ViewBuilder private var forhåndsvisning: some View {
        let g = Gradient(stops: stopp)
        switch form {
        case .lineær:
            // CSS: 0° = opp, 90° = mot høyre. SwiftUI: enhetspunkter.
            let r = (vinkel - 90) * .pi / 180
            let dx = cos(r) / 2, dy = sin(r) / 2
            LinearGradient(gradient: g, startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy), endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
        case .radiell:
            GeometryReader { geo in
                RadialGradient(gradient: g, center: .center, startRadius: 0,
                               endRadius: hypot(geo.size.width, geo.size.height) / 2)
            }
        case .konisk:
            AngularGradient(gradient: g, center: .center, angle: .degrees(vinkel - 90))
        }
    }
}
