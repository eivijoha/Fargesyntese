import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI

/// Verdiord → palett med Apple Intelligence på enheten.
/// Fargene strømmes inn mens modellen skriver; deretter kan paletten justeres
/// presist (hurtigknapper i OKLCH) eller med fritekst (språkmodellen).
struct VerdiordVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var samtale = PalettSamtale()
    @State private var verdiord = ""
    @State private var antall = 5
    @State private var instruks = ""
    @State private var lagre = false
    @FocusState private var fokus: Felt?

    enum Felt { case verdiord, instruks }

    var body: some View {
        Form {
            if !samtale.status.erKlar {
                Section {
                    Label(samtale.status.forklaring, systemImage: "info.circle")
                        .font(.callout)
                }
            }

            Section {
                TextField("F.eks. trygg, varm, nordisk, nyskapende", text: $verdiord, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($fokus, equals: .verdiord)
                    .submitLabel(.go)
                    .onSubmit(foreslå)
                Stepper("Antall farger: \(antall)", value: $antall, in: 3...10)
                Button(action: foreslå) {
                    Label(samtale.forslag == nil ? "Foreslå palett" : "Nytt forslag", systemImage: "sparkles")
                }
                .disabled(verdiord.trimmingCharacters(in: .whitespaces).isEmpty || samtale.arbeider)
            } header: {
                Text("Verdiord")
            }

            if let feil = samtale.feil {
                Section { Label(feil.localizedDescription, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            }

            if let forslag = samtale.forslag {
                forslagsseksjon(forslag)
                justeringsseksjon
            } else if samtale.arbeider {
                Section { ProgressView("Tenker på farger …") }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Verdiord")
        .animation(.snappy, value: samtale.forslag?.farger.count)
        .toolbar {
            if samtale.arbeider {
                Button("Stopp", systemImage: "stop.circle") { samtale.avbryt() }
            } else if samtale.forslag != nil {
                Button("Lagre som palett", systemImage: "square.and.arrow.down") { lagre = true }
            }
        }
        .sheet(isPresented: $lagre) {
            if let f = samtale.forslag {
                VelgPalettArk(farger: f.palett.farger, foreslåttNavn: f.tittel)
            }
        }
        .onAppear {
            samtale.gamut = arbeidsbenk.gamut
            samtale.forvarm()
        }
        .onChange(of: arbeidsbenk.gamut) { _, ny in samtale.gamut = ny }
    }

    private func foreslå() {
        guard !verdiord.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        fokus = nil
        samtale.foreslå(verdiord: verdiord, antall: antall)
    }

    private func forslagsseksjon(_ forslag: PalettForslag) -> some View {
        Section {
            PalettStripe(farger: forslag.farger.map(\.farge)).frame(height: 56)
            if !forslag.forklaring.isEmpty { Text(forslag.forklaring).font(.callout) }
            ForEach(forslag.farger) { f in
                HStack(alignment: .top, spacing: 12) {
                    FargeRute(farge: f.farge, visTekst: false, hjørne: 8).frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.navn.isEmpty ? "…" : f.navn).font(.headline)
                        Text("\(f.rolle.capitalized) · \(f.farge.hex())")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        if !f.begrunnelse.isEmpty { Text(f.begrunnelse).font(.caption) }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { arbeidsbenk.aktivFarge = f.farge }
                .contextMenu { KopierMeny(farge: f.farge) }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        } header: {
            HStack {
                Text(forslag.tittel.isEmpty ? "Forslag" : forslag.tittel)
                if samtale.arbeider { ProgressView().controlSize(.small) }
            }
        } footer: {
            Text(forslag.kilde == .appleIntelligence
                 ? "Laget med Apple Intelligence på enheten. Tekstfargen er justert til minst WCAG AA mot bakgrunnen."
                 : "Laget med innebygd leksikon.")
        }
    }

    private var justeringsseksjon: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Justering.allCases) { j in
                        Button(j.navn, systemImage: j.symbol) { samtale.bruk(j) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
            }
            .disabled(samtale.arbeider)

            if samtale.status.erKlar {
                HStack {
                    TextField("Juster med KI, f.eks. «mer som en skandinavisk kafé»", text: $instruks, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($fokus, equals: .instruks)
                        .onSubmit(juster)
                    Button("Send", systemImage: "arrow.up.circle.fill", action: juster)
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .disabled(instruks.trimmingCharacters(in: .whitespaces).isEmpty || samtale.arbeider)
                }
            }
            if samtale.logg.count > 1 {
                Text(samtale.logg.joined(separator: " → "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Juster")
        } footer: {
            Text("Hurtigknappene endrer fargene presist i OKLCH. Fritekst tolkes av språkmodellen, som husker samtalen.")
        }
    }

    private func juster() {
        let tekst = instruks.trimmingCharacters(in: .whitespaces)
        guard !tekst.isEmpty else { return }
        instruks = ""
        samtale.juster(tekst)
    }
}
