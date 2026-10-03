import FargeKjerne
import SwiftUI

/// Tonene i et importert fargebibliotek som ligger nærmest en farge, rangert etter ΔE2000.
/// Brukes når en målt eller blandet farge skal oversettes til et fargekart med navngitte toner
/// (RAL, NCS …). Bibliotekene importeres under «Mine fargerom».
struct NærmesteIBibliotekSeksjon: View {
    let farge: Farge
    @Environment(ProfilBibliotek.self) private var bibliotek
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @AppStorage("bibliotekSammenlign") private var valgtID = ""

    private var valgt: Fargebibliotek? { bibliotek.fargebibliotek(id: valgtID) ?? bibliotek.fargebiblioteker.first }

    var body: some View {
        if bibliotek.fargebiblioteker.isEmpty {
            Section {
                Text("Importer et fargebibliotek (ASE, ACO eller ACB) under «Mine fargerom» i Studio for å finne nærmeste navngitte tone.")
                    .foregroundStyle(Color.sekundærTekst)
            } header: { Group { Text("Nærmeste i bibliotek") }.foregroundStyle(Color.sekundærTekst) }
        } else if let valgt {
            Section {
                Picker("Bibliotek", selection: Binding(get: { valgt.id }, set: { valgtID = $0 })) {
                    ForEach(bibliotek.fargebiblioteker) { b in Text("\(b.navn) (\(b.farger.count))").tag(b.id) }
                }
                ForEach(valgt.nærmeste(til: farge, antall: 5), id: \.tone.id) { t in
                    HStack(spacing: 12) {
                        HStack(spacing: 0) {
                            farge.swiftUI
                            t.tone.farge.swiftUI
                        }
                        .frame(width: 56, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.tone.visningsnavn).lineLimit(1)
                            Text("ΔE00 \(t.avstand, format: .number.precision(.fractionLength(1))) · \(Fargeavstand.tolkning(t.avstand))")
                                .font(.caption)
                                .foregroundStyle(t.avstand < 2 ? Color.suksess : t.avstand < 5 ? Color.sekundærTekst : Color.advarsel)
                        }
                        Spacer()
                        Button("Bruk") { arbeidsbenk.aktivFarge = t.tone.farge }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .contextMenu { KopierMeny(farge: t.tone.farge) }
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
}
