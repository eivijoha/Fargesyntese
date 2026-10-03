import FargeKjerne
import SwiftData
import SwiftUI

/// Farger plukket fra kamera, bilder og skjermen som ikke er lagret ennå. Vises øverst i Paletter og
/// palettkolonnen, tydelig merket som ulagret: de forsvinner når appen lukkes.
struct MidlertidigeFarger: View {
    /// Kompakt utgave til palettkolonnen (rutenett i stedet for rad).
    var kompakt = false
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @Environment(\.modelContext) private var kontekst

    private var farger: [PalettFarge] {
        arbeidsbenk.målinger.reversed().map { PalettFarge(farge: $0, opphav: .kamera) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Plukkede farger", systemImage: "eyedropper.halffull").font(kompakt ? .subheadline.weight(.semibold) : .headline)
                Text("Ikke lagret")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .foregroundStyle(Color.advarsel)
                    .background(Color.advarsel.opacity(0.12), in: Capsule())
                Spacer()
                Menu {
                    Button("Lagre alle som enkeltfarger", systemImage: "square.and.arrow.down") {
                        lagreEnkeltfarger(farger, i: kontekst, navngi: false)
                        arbeidsbenk.tømMålinger()
                    }
                    Button("Tøm", systemImage: "trash", role: .destructive) { arbeidsbenk.tømMålinger() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Valg for plukkede farger")
            }
            Group {
                if kompakt {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 34, maximum: 48), spacing: 4)], alignment: .leading, spacing: 4) { ruter }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 4) { ruter } }
                }
            }
            Text("Fra kamera, bilder og skjermpipetten. Forsvinner når appen lukkes – dra en farge til en palett, eller lagre dem.")
                .font(.caption)
                .foregroundStyle(Color.sekundærTekst)
        }
    }

    @ViewBuilder private var ruter: some View {
        ForEach(farger) { pf in
            FargeRute(farge: pf.farge, visTekst: false, hjørne: 6,
                      lagre: { lagreEnkeltfarger([PalettFarge(farge: $0, opphav: .kamera)], i: kontekst) },
                      palettFarge: pf)
                .frame(width: kompakt ? nil : 36, height: kompakt ? nil : 36)
                .aspectRatio(1, contentMode: .fit)
                // Stiplet kant viser at fargen ikke er lagret.
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.sekundærTekst.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                .onTapGesture { arbeidsbenk.aktivFarge = pf.farge }
                .help(String(localized: "\(pf.farge.hex()) – ikke lagret"))
                .accessibilityLabel(String(localized: "\(pf.farge.hex()), ikke lagret"))
                .accessibilityAction(named: "Gjør til aktiv farge") { arbeidsbenk.aktivFarge = pf.farge }
        }
    }
}
