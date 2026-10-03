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
                IkkeLagretMerke()
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

/// Blå merkelapp «Ikke lagret» for plukkede farger.
struct IkkeLagretMerke: View {
    var body: some View {
        Text("Ikke lagret")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(Color.blue)
            .background(Color.blue.opacity(0.12), in: Capsule())
    }
}

/// De plukkede fargene som en vannrett rad under kamera og bilde – de samme som «Plukkede farger» i
/// Paletter (nyeste først). Trykk gjør fargen aktiv; menyen kan lagre, legge i palett eller fjerne den.
struct PlukkedeFargerRad: View {
    let opphav: PalettFarge.Opphav
    var størrelse: CGFloat = 36
    var leggIPalett: (Farge) -> Void
    @Environment(Arbeidsbenk.self) private var arbeidsbenk

    var body: some View {
        let målinger = arbeidsbenk.målinger
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(målinger.indices.reversed()), id: \.self) { i in
                    let farge = målinger[i]
                    FargeRute(farge: farge, visTekst: false, hjørne: 6,
                              leggIPalett: leggIPalett,
                              fjern: { arbeidsbenk.fjernMåling(i) },
                              palettFarge: PalettFarge(farge: farge, opphav: opphav))
                        .frame(width: størrelse, height: størrelse)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.sekundærTekst.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                        .onTapGesture { arbeidsbenk.aktivFarge = farge }
                        .help(String(localized: "\(farge.hex()) – ikke lagret"))
                }
            }
        }
    }
}
