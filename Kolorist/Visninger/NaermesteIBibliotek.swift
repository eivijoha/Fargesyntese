import FargeKjerne
import SwiftData
import SwiftUI

/// Finner tonene i et importert fargebibliotek (eller en vanlig palett) som ligger nærmest en farge,
/// rangert etter ΔE2000. Brukes når en målt eller blandet farge skal oversettes til et fargekart
/// med navngitte toner, f.eks. Freetone.
struct NærmesteIBibliotekSeksjon: View {
    let farge: Farge
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]
    @AppStorage("bibliotekPalett") private var valgtIDTekst = ""
    @Environment(Arbeidsbenk.self) private var arbeidsbenk

    /// Store paletter (importerte biblioteker) først i lista, så vanlige paletter.
    private var valgt: PalettDokument? {
        paletter.first { $0.id.uuidString == valgtIDTekst }
            ?? paletter.first { p in p.farger.contains { $0.opphav == .bibliotek } }
            ?? paletter.first
    }

    var body: some View {
        if paletter.isEmpty {
            Section {
                Text("Importer et fargebibliotek (ASE, ACO eller ACB) i Paletter for å finne nærmeste navngitte tone.")
                    .foregroundStyle(Color.sekundærTekst)
            } header: { Group { Text("Nærmeste i bibliotek") }.foregroundStyle(Color.sekundærTekst) }
        } else if let valgt {
            let treff = nærmeste(i: valgt.farger, antall: 5)
            Section {
                Picker("Bibliotek", selection: Binding(get: { valgt.id.uuidString }, set: { valgtIDTekst = $0 })) {
                    ForEach(paletter) { p in
                        Text("\(p.navn.isEmpty ? String(localized: "Uten navn") : p.navn) (\(p.farger.count))").tag(p.id.uuidString)
                    }
                }
                ForEach(treff, id: \.farge.id) { t in
                    HStack(spacing: 12) {
                        HStack(spacing: 0) {
                            farge.swiftUI
                            t.farge.farge.swiftUI
                        }
                        .frame(width: 56, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.farge.visningsnavn).lineLimit(1)
                            Text("ΔE00 \(t.avstand, format: .number.precision(.fractionLength(1))) · \(Fargeavstand.tolkning(t.avstand))")
                                .font(.caption)
                                .foregroundStyle(t.avstand < 2 ? Color.suksess : t.avstand < 5 ? Color.sekundærTekst : Color.advarsel)
                        }
                        Spacer()
                        Button("Bruk") { arbeidsbenk.aktivFarge = t.farge.farge }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .contextMenu { KopierMeny(farge: t.farge.farge) }
                }
            } header: { Group {
                Text("Nærmeste i bibliotek")
            }.foregroundStyle(Color.sekundærTekst) } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("De fem tonene i biblioteket som ligger nærmest fargen, etter ΔE2000. Under 2 er knapt synlig forskjell; over 5 er en annen farge. «Bruk» gjør tonen til aktiv farge.")
                    MetodeHenvisning(.ciede2000, .cieLab)
                }
            }
        }
    }

    private func nærmeste(i farger: [PalettFarge], antall: Int) -> [(farge: PalettFarge, avstand: Double)] {
        farger.map { ($0, farge.deltaE2000(til: $0.farge)) }
            .sorted { $0.1 < $1.1 }
            .prefix(antall)
            .map { (farge: $0.0, avstand: $0.1) }
    }
}
