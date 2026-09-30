import FargeKjerne
import SwiftData
import SwiftUI

/// Studio: rediger aktiv farge i valgfri fargemodell, se alle representasjoner.
struct FargeEditor: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var hexTekst = ""
    @State private var lagreFarger: [PalettFarge]?
    @State private var lagreNavn = ""
    @State private var lagret = false
    @Environment(\.modelContext) private var kontekst

    var body: some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        let farge = arbeidsbenk.aktivFarge

        Form {
            Section {
                FargeRute(farge: farge, visTekst: false, hjørne: 20)
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                HStack {
                    TextField("Hex eller CSS-farge", text: $hexTekst)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .onSubmit {
                            if let f = Fargetolk.tolk(hexTekst) { arbeidsbenk.aktivFarge = f } else { hexTekst = farge.hex() }
                        }
                    PipetteKnapp {
                        arbeidsbenk.aktivFarge = $0
                        arbeidsbenk.registrerMåling($0)
                    }
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
                VerdiRad(navn: "Hex", tekst: farge.hex(medAlfa: farge.alfa < 1)) { Utklippstavle.kopier(farge) }
                ForEach(Fargemodell.allCases) { modell in
                    VerdiRad(navn: modell.navn, tekst: modell.tekst(for: farge)) { Utklippstavle.kopier(farge, som: modell) }
                }
                LabeledContent("Gamut") {
                    Text(farge.erISRGB ? "sRGB" : farge.erIDisplayP3 ? "Display P3" : "Utenfor P3")
                }
            }

            KontrastSeksjon(forgrunn: $arbeidsbenk.aktivFarge)

            ICCSeksjon(farge: $arbeidsbenk.aktivFarge)

            Section {
                let varianter = arbeidsbenk.lyshetstrinn.toner(for: farge)
                HStack(spacing: 4) {
                    ForEach(Array(varianter.enumerated()), id: \.offset) { i, variant in
                        VStack(spacing: 2) {
                            FargeRute(farge: variant, visTekst: false, hjørne: 6)
                                .frame(height: 44)
                                .overlay {
                                    if i == arbeidsbenk.lyshetstrinn.antallLysere {
                                        RoundedRectangle(cornerRadius: 6).strokeBorder(.primary, lineWidth: 2)
                                    }
                                }
                                .onTapGesture { arbeidsbenk.aktivFarge = variant }
                            Text(variant.okLCH.l * 100, format: .number.precision(.fractionLength(0)))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                LyshetstrinnKontroller(trinn: $arbeidsbenk.lyshetstrinn)
                Button("Legg raden i palett", systemImage: "plus.square.on.square") {
                    lagreNavn = "Lysere og mørkere \(farge.hex())"
                    lagreFarger = varianter.map { PalettFarge(farge: $0, opphav: .toneskala) }
                }
            } header: {
                Text("Lysere og mørkere")
            } footer: {
                Text("Tallene under hver prøve er OKLCH-lyshet i prosent.")
            }

            HarmoniSeksjon(grunnfarge: farge, velg: { arbeidsbenk.aktivFarge = $0 }) { farger, navn in
                lagreFarger = farger
                lagreNavn = navn
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Studio")
        .toolbar {
            ToolbarItemGroup {
                Button("Lim inn", systemImage: "doc.on.clipboard") {
                    if let f = Utklippstavle.limInn() { arbeidsbenk.aktivFarge = f }
                }
                Button("Sammenlign (ΔE2000)", systemImage: "square.split.2x1") { arbeidsbenk.sammenlign(farge, nil) }
                Button("Lagre farge", systemImage: lagret ? "bookmark.fill" : "bookmark") {
                    lagreEnkeltfarger([PalettFarge(farge: farge)], i: kontekst)
                    lagret = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); lagret = false }
                }
                .sensoryFeedback(.success, trigger: lagret) { _, ny in ny }
                .help("Lagre som enkeltfarge (uten palett)")
                Button("Legg i palett", systemImage: "plus.square.on.square") {
                    lagreNavn = ""
                    lagreFarger = [PalettFarge(farge: farge)]
                }
            }
        }
        .sheet(isPresented: Binding(get: { lagreFarger != nil }, set: { if !$0 { lagreFarger = nil } })) {
            VelgPalettArk(farger: lagreFarger ?? [], foreslåttNavn: lagreNavn)
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
            // Vern: ved bytte av modell (f.eks. CMYK → RGB) kan en rad bli tegnet før listen er oppdatert.
            if i < gjeldende.count {
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
                        guard v.indices.contains(i) else { return }
                        v[i] = ny
                        verdier = v
                        farge = modell.farge(fra: v, alfa: farge.alfa)
                    }
                ), in: k.område)
            }
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
                .foregroundStyle(.secondary)
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
struct LyshetstrinnKontroller: View {
    @Binding var trinn: Lyshetstrinn

    var body: some View {
        Picker("Stegtype", selection: $trinn.modus) {
            Text("Faste steg").tag(Lyshetstrinn.Modus.fast)
            Text("Mot hvitt/sort").tag(Lyshetstrinn.Modus.relativ)
        }
        .pickerStyle(.segmented)
        stegRad(tittel: "Lysere", antall: $trinn.antallLysere, steg: $trinn.lysereSteg, lysere: true)
        stegRad(tittel: "Mørkere", antall: $trinn.antallMørkere, steg: $trinn.mørkereSteg, lysere: false)
    }

    private func stegRad(tittel: String, antall: Binding<Int>, steg: Binding<Double>, lysere: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Stepper("\(tittel): \(antall.wrappedValue) steg", value: antall, in: 0...8)
            HStack {
                Slider(value: steg, in: trinn.modus == .fast ? 0.01...0.2 : 0.05...0.6, step: 0.01)
                    .disabled(antall.wrappedValue == 0)
                Text(trinn.stegtekst(lysere: lysere))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 110, alignment: .trailing)
            }
        }
        .onChange(of: trinn.modus) { _, ny in
            // Hold stegene innenfor det nye området.
            let område = ny == .fast ? 0.01...0.2 : 0.05...0.6
            steg.wrappedValue = steg.wrappedValue.clamped(to: område)
        }
    }
}

private extension Double {
    func clamped(to r: ClosedRange<Double>) -> Double { Swift.min(Swift.max(self, r.lowerBound), r.upperBound) }
}
