import FargeKjerne
import SwiftUI

/// WCAG-kontrasttest i Studio: aktiv farge som forgrunn mot en valgt bakgrunn.
struct KontrastSeksjon: View {
    @Binding var forgrunn: Farge
    @AppStorage("kontrastBakgrunn") private var bakgrunnHex = "#FFFFFF"
    /// Vis forhåndsvisningen slik den ser ut med et fargesynsavvik («normalt» = ingen simulering).
    @AppStorage("kontrastFargesyn") private var fargesyn = "normalt"

    private var fargesynstype: Fargesynstype? { Fargesynstype(rawValue: fargesyn) }

    private var bakgrunn: Farge { Fargetolk.tolk(bakgrunnHex) ?? Farge(hex: "#FFFFFF")! }

    var body: some View {
        let test = Kontrasttest(forgrunn: forgrunn, bakgrunn: bakgrunn)
        Section {
            // Lagres som CSS-tekst i Display P3, så P3-bakgrunner ikke rundes av til sRGB-hex.
            FargeValgRad(tittel: String(localized: "Bakgrunn"), farge: Binding(
                get: { bakgrunn },
                set: { bakgrunnHex = $0.erISRGB ? $0.hex() : Fargemodell.displayP3.tekst(for: $0) }
            ))
            HStack(spacing: 8) {
                Button("Hvit") { bakgrunnHex = "#FFFFFF" }
                Button("Sort") { bakgrunnHex = "#000000" }
                Spacer()
                Button("Bytt", systemImage: "arrow.up.arrow.down") {
                    let gammel = bakgrunn
                    bakgrunnHex = forgrunn.erISRGB ? forgrunn.hex() : Fargemodell.displayP3.tekst(for: forgrunn)
                    forgrunn = gammel
                }
                .help("Bytt tekstfarge og bakgrunn")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Picker("Vis med", selection: $fargesyn) {
                Text("Normalt syn").tag("normalt")
                ForEach(Fargesynstype.allCases) { Text($0.navn).tag($0.rawValue) }
            }
            if let type = fargesynstype {
                let f = forgrunn.simulert(type), b = bakgrunn.simulert(type)
                KontrastForhåndsvisning(forgrunn: f, bakgrunn: b, test: Kontrasttest(forgrunn: f, bakgrunn: b),
                                        merknad: type.navn)
            } else {
                KontrastForhåndsvisning(forgrunn: forgrunn, bakgrunn: bakgrunn, test: test)
            }

            ForEach(WCAGKrav.allCases) { krav in
                KravRad(krav: krav, test: test) { forgrunn = test.rettet(for: krav) }
            }
        } header: { Group {
            Text("Kontrast (WCAG 2.2)")
        }.foregroundStyle(Color.sekundærTekst) } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Aktiv farge testes som tekst/grafikk mot bakgrunnen. «Rett opp» endrer bare lysheten, og beholder kulør og metning. «Vis med» simulerer et fargesynsavvik i forhåndsvisningen; WCAG-kravene gjelder alltid de faktiske fargene.")
                MetodeHenvisning(.wcag, .oklab, .machado)
            }
        }
    }
}

struct KontrastForhåndsvisning: View {
    let forgrunn: Farge
    let bakgrunn: Farge
    let test: Kontrasttest
    /// Vises i hjørnet når forhåndsvisningen er simulert (f.eks. «Deuteranopi»).
    var merknad: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stor tekst").font(.system(size: 24, weight: .regular))
                Text("Brødtekst i vanlig størrelse, slik den leses i appen.").font(.system(size: 15))
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                    Image(systemName: "star.fill")
                    RoundedRectangle(cornerRadius: 4).strokeBorder(lineWidth: 2).frame(width: 36, height: 20)
                }
                .font(.title3)
                .accessibilityHidden(true)
            }
            .foregroundStyle(forgrunn.swiftUI)
            Spacer(minLength: 0)
            VStack(spacing: 0) {
                Text(test.formatert).font(.title2.weight(.semibold).monospacedDigit())
                Text(test.sammendrag).font(.caption.weight(.medium))
            }
            .foregroundStyle(forgrunn.swiftUI)
        }
        .padding(14)
        .padding(.top, merknad == nil ? 0 : 14)
        .background(bakgrunn.swiftUI, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topLeading) {
            if let merknad {
                Label(merknad, systemImage: "eye")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(forgrunn.swiftUI)
                    .padding(8)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(merknad.map { String(localized: "\($0): kontrast \(test.formatert), \(test.sammendrag)") }
                            ?? String(localized: "Kontrast \(test.formatert), \(test.sammendrag)"))
    }
}

struct KravRad: View {
    let krav: WCAGKrav
    let test: Kontrasttest
    var rettOpp: () -> Void

    var body: some View {
        let bestått = test.består(krav)
        HStack {
            Image(systemName: bestått ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(bestått ? Color.suksess : Color.feil)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(krav.navn)
                Text("\(krav.suksesskriterium) · minst \(krav.minimum, format: .number.precision(.fractionLength(1))):1")
                    .font(.caption)
                    .foregroundStyle(Color.sekundærTekst)
            }
            Spacer()
            if !bestått {
                Button("Rett opp", action: rettOpp)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(bestått ? "Bestått" : "Ikke bestått")
    }
}

/// Alle fargepar i en palett: rader er forgrunn, kolonner er bakgrunn.
struct KontrastmatriseArk: View {
    let palett: Palett
    @State private var krav: WCAGKrav = .aaTekst
    @State private var valgt: Kontrasttest?
    @Environment(\.dismiss) private var lukk

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                let f = palett.farger
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow {
                        Text("Tekst ↓ / bakgrunn →").font(.caption2).foregroundStyle(Color.sekundærTekst).frame(width: 72)
                        ForEach(f) { bg in
                            FargeRute(farge: bg.farge, visTekst: false, hjørne: 6).frame(width: 64, height: 28)
                        }
                    }
                    ForEach(f) { fg in
                        GridRow {
                            FargeRute(farge: fg.farge, visTekst: false, hjørne: 6).frame(width: 72, height: 52)
                            ForEach(f) { bg in
                                let t = Kontrasttest(forgrunn: fg.farge, bakgrunn: bg.farge)
                                celle(t, sammeFarge: fg.id == bg.id)
                            }
                        }
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .top) {
                Picker("Krav", selection: $krav) {
                    ForEach(WCAGKrav.allCases) { Text($0.navn).tag($0) }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .navigationTitle("Kontrastmatrise")
            .toolbar { Button("Ferdig") { lukk() } }
            .sheet(item: $valgt) { t in
                NavigationStack {
                    Form {
                        KontrastForhåndsvisning(forgrunn: t.forgrunn, bakgrunn: t.bakgrunn, test: t)
                        ForEach(WCAGKrav.allCases) { k in KravRad(krav: k, test: t) { Utklippstavle.kopier(t.rettet(for: k)) } }
                    }
                    .formStyle(.grouped)
                    .navigationTitle("\(t.forgrunn.hex()) på \(t.bakgrunn.hex())")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    @ViewBuilder
    private func celle(_ t: Kontrasttest, sammeFarge: Bool) -> some View {
        if sammeFarge {
            Color.clear.frame(width: 64, height: 52)
        } else {
            let bestått = t.består(krav)
            Button { valgt = t } label: {
                VStack(spacing: 2) {
                    Text("Aa").font(.headline)
                    Text(t.formatert).font(.caption2.monospacedDigit())
                }
                .foregroundStyle(t.forgrunn.swiftUI)
                .frame(width: 64, height: 52)
                .background(t.bakgrunn.swiftUI, in: RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: bestått ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(bestått ? Color.suksess : Color.feil)
                        .background(Circle().fill(.background))
                        .offset(x: 4, y: -4)
                }
                .opacity(bestått ? 1 : 0.55)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(t.forgrunn.hex()) på \(t.bakgrunn.hex()), \(t.formatert), \(bestått ? "bestått" : "ikke bestått")")
        }
    }
}

extension Kontrasttest: @retroactive Identifiable {
    public var id: String { forgrunn.hex(medAlfa: true) + bakgrunn.hex(medAlfa: true) }
}
