import FargeKjerne
import SwiftData
import SwiftUI

/// Vurdering › Fargesyn: hvordan en palett ser ut med fargesynsavvik (CVD), og hvilke fargepar
/// som blir vanskelige å skille.
struct FargesynVurdering: View {
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]
    /// Delt med Vurdering › Palett, så samme palett er valgt i begge.
    @AppStorage("vurderingPalett") private var valgtIDTekst = ""
    @AppStorage("fargesynGrad") private var grad = 1.0
    /// Åpent kamera med fargesynsfilter.
    @State private var kameratype: Fargesynstype?

    private var valgt: PalettDokument? {
        paletter.first { $0.id.uuidString == valgtIDTekst } ?? paletter.first
    }

    var body: some View {
        Form {
            Section {
                Button("Se omgivelsene med kamera", systemImage: "camera.viewfinder") { kameratype = .deutan }
            } footer: { Group {
                Text("Kamerabildet vist med valgt fargesynsavvik. Velg type og grad i kameravisningen.")
            }.foregroundStyle(Color.sekundærTekst) }
            if paletter.isEmpty {
                ContentUnavailableView("Ingen paletter", systemImage: "swatchpalette",
                                       description: Text("Lag en palett først, så kan den vurderes her."))
            } else if let valgt {
                let farger = valgt.farger
                Section {
                    Picker("Palett", selection: Binding(get: { valgt.id.uuidString }, set: { valgtIDTekst = $0 })) {
                        ForEach(paletter) { Text($0.navn.isEmpty ? "Uten navn" : $0.navn).tag($0.id.uuidString) }
                    }
                    HStack(spacing: 10) {
                        Text("Grad")
                        Slider(value: $grad, in: 0.1...1, step: 0.1)
                        Text(grad, format: .percent.precision(.fractionLength(0)))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(Color.sekundærTekst)
                            .frame(width: 48, alignment: .trailing)
                    }
                } footer: { Group {
                    Text(grad >= 1 ? "100 % er fullstendig avvik (dikromasi). Lavere verdier tilsvarer delvis avvik (anomal trikromasi), som er vanligere."
                                   : "Delvis avvik (anomal trikromasi). 100 % er fullstendig avvik.")
                }.foregroundStyle(Color.sekundærTekst) }

                Seksjon("Slik ser paletten ut") {
                    stripe(String(localized: "Normalt syn"), undertekst: nil, farger: farger.map(\.farge), antall: nil, kamera: nil)
                    ForEach(Fargesynstype.allCases) { type in
                        let forvekslinger = Fargesynsanalyse.forvekslinger(i: farger.map(\.farge), type: type, grad: grad)
                        stripe(grad >= 1 ? type.navn : type.delvisNavn, undertekst: type.beskrivelse,
                               farger: farger.map { $0.farge.simulert(type, grad: grad) }, antall: forvekslinger.count,
                               kamera: { kameratype = type })
                    }
                }

                forvekslingsseksjon(farger)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Fargesyn")
        #if os(iOS)
        .fullScreenCover(item: $kameratype) { FargesynKamera(type: $0) }
        #else
        .sheet(item: $kameratype) { FargesynKamera(type: $0) }
        #endif
    }

    private func stripe(_ tittel: String, undertekst: String?, farger: [Farge], antall: Int?, kamera: (() -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(tittel).font(.subheadline.weight(.semibold))
                Spacer()
                if let antall {
                    if antall == 0 {
                        Label("Ingen forvekslinger", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.suksess)
                    } else {
                        Text(antall == 1 ? "1 vanskelig par" : "\(antall) vanskelige par")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.advarsel)
                    }
                }
            }
            PalettStripe(farger: farger).frame(height: 36)
            HStack(alignment: .firstTextBaseline) {
                if let undertekst {
                    Text(undertekst).font(.caption).foregroundStyle(Color.sekundærTekst)
                }
                Spacer(minLength: 8)
                if let kamera {
                    Button("Se med kamera", systemImage: "camera.viewfinder", action: kamera)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func forvekslingsseksjon(_ farger: [PalettFarge]) -> some View {
        let alle = Fargesynstype.allCases.flatMap {
            Fargesynsanalyse.forvekslinger(i: farger.map(\.farge), type: $0, grad: grad)
        }
        Section {
            if farger.count < 2 {
                Text("Paletten trenger minst to farger.").foregroundStyle(Color.sekundærTekst)
            } else if alle.isEmpty {
                Label("Alle fargeparene kan skilles med alle typene fargesynsavvik.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.suksess)
            } else {
                ForEach(Array(alle.enumerated()), id: \.offset) { _, f in
                    parRad(f, farger: farger)
                }
            }
        } header: {
            Text("Vanskelige fargepar").foregroundStyle(Color.sekundærTekst)
        } footer: { Group {
            Text("Par som er tydelig ulike med normalt syn (ΔE00 ≥ 10), men kommer under 10 med avviket. Under 5 er de nesten like. Skill dem med lyshet, ikke bare kulør, eller bruk mønster, ikon eller tekst i tillegg. Simulering etter Machado mfl. (2009).")
        }.foregroundStyle(Color.sekundærTekst) }
    }

    private func parRad(_ f: Forveksling, farger: [PalettFarge]) -> some View {
        let a = farger[f.i], b = farger[f.j]
        return HStack(spacing: 12) {
            VStack(spacing: 3) {
                HStack(spacing: 0) { a.farge.swiftUI; b.farge.swiftUI }
                    .frame(width: 56, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                HStack(spacing: 0) { a.farge.simulert(f.type, grad: grad).swiftUI; b.farge.simulert(f.type, grad: grad).swiftUI }
                    .frame(width: 56, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(a.visningsnavn) og \(b.visningsnavn)").font(.subheadline).lineLimit(1)
                Text(grad >= 1 ? f.type.navn : f.type.delvisNavn).font(.caption).foregroundStyle(Color.sekundærTekst)
                Text("ΔE00 \(f.normalt, format: .number.precision(.fractionLength(1))) → \(f.simulert, format: .number.precision(.fractionLength(1)))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(f.alvorlig ? Color.feil : Color.advarsel)
            }
            Spacer(minLength: 0)
            if f.alvorlig {
                Text("Nesten like").font(.caption2.weight(.semibold)).foregroundStyle(Color.feil)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
