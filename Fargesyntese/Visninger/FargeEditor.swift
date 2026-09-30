import FargeKjerne
import SwiftUI

/// Studio: rediger aktiv farge i valgfri fargemodell, se alle representasjoner.
struct FargeEditor: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var hexTekst = ""
    @State private var cmykProfil: ICCProfil = .genericCMYK
    @State private var visLagreTilPalett = false

    var body: some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        let farge = arbeidsbenk.aktivFarge

        Form {
            Section {
                FargeRute(farge: farge, visTekst: false, hjørne: 20)
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                HStack {
                    TextField("Hex", text: $hexTekst)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .onSubmit { if let f = Farge(hex: hexTekst) { arbeidsbenk.aktivFarge = f } }
                    PipetteKnapp { arbeidsbenk.aktivFarge = $0 }
                        .labelStyle(.iconOnly)
                }
            }

            Section {
                Picker("Fargemodell", selection: $arbeidsbenk.modell) {
                    ForEach(Fargemodell.allCases) { Text($0.navn).tag($0) }
                }
                KomponentGlidere(modell: arbeidsbenk.modell, farge: $arbeidsbenk.aktivFarge)
            }

            Section("Verdier") {
                ForEach(Fargemodell.allCases) { modell in
                    LabeledContent(modell.navn) {
                        Text(modell.tekst(for: farge))
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }
                    .contextMenu { Button("Kopier") { Utklippstavle.kopier(farge, som: modell) } }
                }
                LabeledContent("Gamut") {
                    Text(farge.erISRGB ? "sRGB" : farge.erIDisplayP3 ? "Display P3" : "Utenfor P3")
                }
            }

            Section("Trykk (ICC)") {
                Picker("Profil", selection: $cmykProfil) {
                    ForEach(ICCProfil.innebygde.filter { $0.antallKomponenter == 4 }) { Text($0.navn).tag($0) }
                }
                if let k = farge.komponenter(i: cmykProfil) {
                    LabeledContent("CMYK") {
                        Text(k.map { String(format: "%.0f", $0 * 100) }.joined(separator: " / "))
                            .font(.callout.monospaced())
                    }
                }
                // TODO: import av egne .icc-profiler via fileImporter (FOGRA39, GRACoL …)
            }

            Section("Lysere og mørkere") {
                let varianter = Toneskala.variasjoner(av: farge, lysere: 3, mørkere: 3)
                HStack(spacing: 4) {
                    ForEach(varianter.indices, id: \.self) { i in
                        FargeRute(farge: varianter[i], visTekst: false, hjørne: 6)
                            .frame(height: 44)
                            .onTapGesture { arbeidsbenk.aktivFarge = varianter[i] }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Studio")
        .toolbar {
            ToolbarItemGroup {
                Menu("Kopier", systemImage: "doc.on.doc") { KopierMeny(farge: farge) }
                Button("Lim inn", systemImage: "doc.on.clipboard") {
                    if let f = Utklippstavle.limInn() { arbeidsbenk.aktivFarge = f }
                }
                Button("Legg i palett", systemImage: "plus.square.on.square") { visLagreTilPalett = true }
            }
        }
        .sheet(isPresented: $visLagreTilPalett) {
            VelgPalettArk(farger: [PalettFarge(farge: farge)])
        }
        .onAppear { hexTekst = farge.hex() }
        .onChange(of: farge) { _, ny in hexTekst = ny.hex() }
        .dropDestination(for: Farge.self) { farger, _ in
            guard let f = farger.first else { return false }
            arbeidsbenk.aktivFarge = f
            return true
        }
    }
}

/// Glidebrytere for hver komponent. Verdiene holdes lokalt mens man drar, slik at
/// kulør ikke «hopper» for grå farger (der kulør er udefinert).
struct KomponentGlidere: View {
    let modell: Fargemodell
    @Binding var farge: Farge
    @State private var verdier: [Double] = []

    /// Lokale verdier når de hører til gjeldende modell, ellers utledet fra fargen.
    private var gjeldende: [Double] {
        verdier.count == modell.komponenter.count ? verdier : modell.verdier(for: farge)
    }

    var body: some View {
        ForEach(Array(modell.komponenter.enumerated()), id: \.offset) { i, k in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(k.navn)
                    Spacer()
                    Text(gjeldende[i], format: .number.precision(.fractionLength(k.desimaler)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { gjeldende[i] },
                    set: { ny in
                        var v = gjeldende
                        v[i] = ny
                        verdier = v
                        farge = modell.farge(fra: v, alfa: farge.alfa)
                    }
                ), in: k.område)
            }
        }
        .onChange(of: modell) { _, ny in verdier = ny.verdier(for: farge) }
        .onChange(of: farge) { _, ny in
            // Oppdater bare når endringen kom utenfra (ikke fra våre egne glidere).
            if verdier.count != modell.komponenter.count
                || modell.farge(fra: verdier, alfa: ny.alfa).avstandOK(til: ny) > 1e-4 {
                verdier = modell.verdier(for: ny)
            }
        }
    }
}
