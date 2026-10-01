import FargeKjerne
import SwiftData
import SwiftUI

/// Rad for å velge en farge (f.eks. forgrunn, bakgrunn, A eller B). Trykk på prøven eller «Velg»
/// åpner lagrede farger; menyen har også lim inn og (på Mac) skjermpipette.
struct FargeValgRad: View {
    let tittel: String
    @Binding var farge: Farge
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var visVelger = false

    var body: some View {
        HStack(spacing: 12) {
            Button { visVelger = true } label: {
                FargeRute(farge: farge, visTekst: false, hjørne: 8).frame(width: 52, height: 36)
                    // Tynn kant, så hvitt/svært lyse farger synes mot lys bakgrunn (og mørke mot mørk).
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(tittel): \(farge.hex()). Velg fra lagrede farger")
            VStack(alignment: .leading, spacing: 1) {
                Text(tittel).font(.caption).foregroundStyle(Color.sekundærTekst)
                Text(farge.hex()).font(.callout.monospaced())
            }
            Spacer()
            Button("Velg") { visVelger = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .lineLimit(1)
            Menu("Mer", systemImage: "ellipsis.circle") {
                Button("Aktiv farge", systemImage: "slider.horizontal.3") { farge = arbeidsbenk.aktivFarge }
                Button("Lim inn", systemImage: "doc.on.clipboard") { if let f = Utklippstavle.limInn() { farge = f } }
                #if os(macOS)
                Button("Plukk fra skjermen", systemImage: "eyedropper") {
                    Task { if let f = await Pipette.plukkFraSkjerm() { farge = f; arbeidsbenk.registrerMåling(f) } }
                }
                #endif
            }
            .labelStyle(.iconOnly)
        }
        .sheet(isPresented: $visVelger) {
            LagretFargeArk(tittel: tittel) { farge = $0 }
        }
    }
}

/// Velg blant lagrede farger: aktiv farge, enkeltfarger, paletter og siste målinger.
struct LagretFargeArk: View {
    let tittel: String
    var valgt: (Farge) -> Void
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @Environment(\.dismiss) private var lukk
    @Query(sort: \LagretFarge.opprettet, order: .reverse) private var enkeltfarger: [LagretFarge]
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]

    private let rutenett = [GridItem(.adaptive(minimum: 52), spacing: 8)]
    /// Kjent verdi skrevet inn: hex (sRGB), eller annen CSS-farge.
    @State private var hexTekst = ""
    private var tolket: Farge? { Fargetolk.tolk(hexTekst.trimmingCharacters(in: .whitespaces)) }

    private func brukInnskrevet() {
        guard let f = tolket else { return }
        valgt(f)
        lukk()
    }

    private var innskriving: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tolket?.swiftUI ?? Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.secondary.opacity(0.4), lineWidth: 1))
                .frame(width: 44, height: 36)
            TextField("Hex, f.eks. #2F7FD8", text: $hexTekst)
                .font(.body.monospaced())
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.characters)
                #endif
                .submitLabel(.done)
                .onSubmit(brukInnskrevet)
                .textFieldStyle(.roundedBorder)
            Button("Bruk", action: brukInnskrevet)
                .buttonStyle(.borderedProminent)
                .disabled(tolket == nil)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Kjent verdi", systemImage: "number").font(.headline)
                        innskriving
                        Text("sRGB-hex som #2F7FD8 eller 2F7FD8; CSS-farger som oklch(…) og rgb(…) går også.")
                            .font(.caption)
                            .foregroundStyle(Color.sekundærTekst)
                    }
                    gruppe(String(localized: "Aktiv farge"), [PalettFarge(farge: arbeidsbenk.aktivFarge)])
                    if !enkeltfarger.isEmpty {
                        gruppe(String(localized: "Enkeltfarger"), enkeltfarger.map(\.palettFarge), symbol: "square.fill")
                    }
                    ForEach(paletter) { p in
                        if !p.farger.isEmpty {
                            gruppe(p.navn.isEmpty ? String(localized: "Uten navn") : p.navn, p.farger, symbol: "swatchpalette")
                        }
                    }
                    if !arbeidsbenk.målinger.isEmpty {
                        gruppe(String(localized: "Siste målinger"), arbeidsbenk.målinger.reversed().map { PalettFarge(farge: $0) },
                               symbol: "eyedropper")
                    }
                    if enkeltfarger.isEmpty && paletter.allSatisfy({ $0.farger.isEmpty }) {
                        Text("Ingen lagrede farger ennå. Lagre farger fra Studio eller Utplukk, eller lag en palett.")
                            .font(.callout)
                            .foregroundStyle(Color.sekundærTekst)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "Velg farge – \(tittel)"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { lukk() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func gruppe(_ navn: String, _ farger: [PalettFarge], symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let symbol { Label(navn, systemImage: symbol) } else { Text(navn) }
            }
            .font(.headline)
            LazyVGrid(columns: rutenett, alignment: .leading, spacing: 8) {
                ForEach(farger) { pf in
                    Button {
                        valgt(pf.farge)
                        lukk()
                    } label: {
                        VStack(spacing: 3) {
                            FargeRute(farge: pf.farge, visTekst: false, hjørne: 8)
                                .frame(height: 52)
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.secondary.opacity(0.3), lineWidth: 1))
                            if !pf.navn.isEmpty {
                                Text(pf.navn).font(.caption2).lineLimit(1).foregroundStyle(Color.sekundærTekst)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(pf.visningsnavn), \(pf.farge.hex())")
                }
            }
        }
    }
}
