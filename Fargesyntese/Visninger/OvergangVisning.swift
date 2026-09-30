import FargeKjerne
import SwiftUI

/// Overgangstoner i like OKLab-steg mellom to farger, med lysere/mørkere rader.
struct OvergangVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var start = Farge(hex: "#1B3A6B")!
    @State private var slutt = Farge(hex: "#F2B84B")!
    @State private var antall = 7
    @State private var visLagre = false

    private var toner: [Farge] { Overgang.toner(fra: start, til: slutt, antall: antall) }

    /// Rader fra lysest til mørkest; midtraden er selve overgangen.
    private var rader: [[Farge]] {
        let trinn = arbeidsbenk.lyshetstrinn
        let variasjoner = toner.map { trinn.toner(for: $0) }
        return (0..<(trinn.antallLysere + trinn.antallMørkere + 1)).map { rad in variasjoner.map { $0[rad] } }
    }

    var body: some View {
        Form {
            Section("Endepunkter") {
                FargeVelgerRad(tittel: "Fra", farge: $start)
                FargeVelgerRad(tittel: "Til", farge: $slutt)
                Button("Bytt om", systemImage: "arrow.left.arrow.right") { swap(&start, &slutt) }
            }
            Section("Overgang") {
                Stepper("Toner: \(antall)", value: $antall, in: 2...24)
            }
            Section("Lysere og mørkere rader") {
                @Bindable var arbeidsbenk = arbeidsbenk
                LyshetstrinnKontroller(trinn: $arbeidsbenk.lyshetstrinn)
            }
            Section {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    let midtrad = arbeidsbenk.lyshetstrinn.antallLysere
                    ForEach(Array(rader.enumerated()), id: \.offset) { r, rad in
                        GridRow {
                            ForEach(Array(rad.enumerated()), id: \.offset) { _, farge in
                                FargeRute(farge: farge, visTekst: false, hjørne: 4)
                                    .frame(minHeight: r == midtrad ? 56 : 36)
                                    .onTapGesture { arbeidsbenk.aktivFarge = farge }
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            } header: {
                Text("Interpolert i OKLab")
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
                          foreslåttNavn: "Overgang \(start.hex()) → \(slutt.hex())")
        }
    }
}

struct FargeVelgerRad: View {
    let tittel: String
    @Binding var farge: Farge
    @Environment(Arbeidsbenk.self) private var arbeidsbenk

    var body: some View {
        HStack {
            ColorPicker(tittel, selection: Binding(get: { farge.swiftUI }, set: { farge = Farge($0) }))
            Text(farge.hex()).font(.callout.monospaced()).foregroundStyle(.secondary)
            Menu("Mer", systemImage: "ellipsis.circle") {
                Button("Bruk aktiv farge") { farge = arbeidsbenk.aktivFarge }
                Button("Lim inn") { if let f = Utklippstavle.limInn() { farge = f } }
            }
            .labelStyle(.iconOnly)
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
                .foregroundStyle(.secondary)
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
        } header: {
            Text("CSS-gradient")
        } footer: {
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
