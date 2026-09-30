import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI

struct VerdiordVisning: View {
    @Environment(\.modelContext) private var kontekst
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var verdiord = ""
    @State private var antall = 5
    @State private var forslag: PalettForslag?
    @State private var arbeider = false
    @State private var feil: String?

    var body: some View {
        Form {
            Section {
                TextField("F.eks. trygg, varm, nordisk, nyskapende", text: $verdiord, axis: .vertical)
                    .lineLimit(2...4)
                Stepper("Antall farger: \(antall)", value: $antall, in: 3...10)
                Button {
                    Task { await generer() }
                } label: {
                    if arbeider { ProgressView() } else { Label("Foreslå palett", systemImage: "sparkles") }
                }
                .disabled(verdiord.trimmingCharacters(in: .whitespaces).isEmpty || arbeider)
            } footer: {
                Text("Forslagene lages på enheten med Apple Intelligence når det er tilgjengelig.")
            }

            if let feil {
                Section { Text(feil).foregroundStyle(.red) }
            }

            if let forslag {
                Section {
                    PalettStripe(farger: forslag.farger.map(\.farge)).frame(height: 56)
                    Text(forslag.forklaring).font(.callout)
                    ForEach(forslag.farger) { f in
                        HStack(alignment: .top, spacing: 12) {
                            FargeRute(farge: f.farge, visTekst: false, hjørne: 8).frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.navn).font(.headline)
                                Text("\(f.rolle.capitalized) · \(f.farge.hex())").font(.caption.monospaced()).foregroundStyle(.secondary)
                                if !f.begrunnelse.isEmpty { Text(f.begrunnelse).font(.caption) }
                            }
                        }
                        .onTapGesture { arbeidsbenk.aktivFarge = f.farge }
                    }
                    Button("Lagre som palett", systemImage: "square.and.arrow.down") {
                        kontekst.insert(PalettDokument(forslag.palett))
                        arbeidsbenk.valgtFane = .paletter
                    }
                } header: {
                    Text(forslag.tittel)
                } footer: {
                    Text(forslag.kilde == .appleIntelligence ? "Laget med Apple Intelligence" : "Laget med innebygd leksikon")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Verdiord")
    }

    private func generer() async {
        arbeider = true
        defer { arbeider = false }
        do {
            feil = nil
            forslag = try await Verdiordtjeneste.beste().forslag(for: verdiord, antall: antall)
        } catch {
            feil = "Kunne ikke lage forslag: \(error.localizedDescription)"
        }
    }
}
