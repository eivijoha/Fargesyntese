import FargeKjerne
import SwiftData
import SwiftUI

/// Palettene som kompakt kolonne til høyre på store iPader i liggende format (Mac bruker hele palettvisningen),
/// tilgjengelig fra alle faner. Trykk på en farge gjør den aktiv; farger kan dras inn i en palett
/// (fra Studio, Overgang, Utplukk eller en annen palett) og ut igjen.
struct PalettKolonne: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @Environment(\.modelContext) private var kontekst
    @Query(sort: \PalettDokument.opprettet, order: .reverse) private var paletter: [PalettDokument]
    @Query(sort: \LagretFarge.opprettet, order: .reverse) private var enkeltfarger: [LagretFarge]
    /// Paletter som er foldet ut (id-er), husket mellom oppstarter.
    @AppStorage("palettkolonneÅpne") private var åpneTekst = ""
    @State private var nyPalett = false
    @State private var nyttNavn = ""

    private var åpne: Set<String> { Set(åpneTekst.split(separator: ",").map(String.init)) }

    private func veksle(_ id: String) {
        var s = åpne
        if s.contains(id) { s.remove(id) } else { s.insert(id) }
        åpneTekst = s.sorted().joined(separator: ",")
    }

    private let rutenett = [GridItem(.adaptive(minimum: 34, maximum: 48), spacing: 4)]

    var body: some View {
        List {
            aktivFargeSeksjon

            if !arbeidsbenk.målinger.isEmpty {
                Section { MidlertidigeFarger(kompakt: true) }
            }

            if !enkeltfarger.isEmpty {
                Section {
                    fargerutenett(enkeltfarger.map(\.palettFarge), fra: nil)
                } header: {
                    Text("Enkeltfarger")
                }
            }

            Section {
                if paletter.isEmpty {
                    Text("Ingen paletter ennå. Lag en nedenfor, eller dra farger hit.")
                        .font(.callout)
                        .foregroundStyle(Color.sekundærTekst)
                }
                ForEach(paletter) { p in palettRad(p) }
                Button("Ny palett …", systemImage: "plus") { nyttNavn = ""; nyPalett = true }
            } header: {
                Text("Paletter")
            }
        }
        .listStyle(.sidebar)
        // Ingen egen verktøylinje: på Mac blir knapper fra en lukket inspektør hengende igjen.
        .alert("Ny palett", isPresented: $nyPalett) {
            TextField("Navn", text: $nyttNavn)
            Button("Avbryt", role: .cancel) {}
            Button("Opprett") {
                let navn = nyttNavn.trimmingCharacters(in: .whitespacesAndNewlines)
                let p = PalettDokument(navn: navn.isEmpty ? String(localized: "Ny palett") : navn)
                kontekst.insert(p)
                veksle(p.id.uuidString)
            }
        }
    }

    /// Aktiv farge øverst, med «Legg i palett».
    private var aktivFargeSeksjon: some View {
        let farge = arbeidsbenk.aktivFarge
        return Section {
            HStack(spacing: 10) {
                FargeRute(farge: farge, visTekst: false, hjørne: 8,
                          palettFarge: PalettFarge(farge: farge, opphav: .manuell))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(farge.hex()).font(.callout.monospaced())
                    Text(Fargebeskrivelse.beskriv(farge)).font(.caption).foregroundStyle(Color.sekundærTekst).lineLimit(1)
                }
                Spacer(minLength: 4)
                Menu {
                    ForEach(paletter) { p in
                        Button(p.navn.isEmpty ? String(localized: "Uten navn") : p.navn) {
                            leggTil([PalettFarge(farge: farge, opphav: .manuell)], i: p)
                        }
                    }
                    Divider()
                    Button("Som enkeltfarge", systemImage: "square") {
                        lagreEnkeltfarger([PalettFarge(farge: farge, opphav: .manuell)], i: kontekst)
                    }
                } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .menuIndicator(.hidden)
                .help("Legg aktiv farge i en palett")
                .accessibilityLabel("Legg aktiv farge i palett")
            }
        } header: {
            Text("Aktiv farge")
        }
    }

    private func palettRad(_ p: PalettDokument) -> some View {
        let id = p.id.uuidString
        let åpen = åpne.contains(id)
        return VStack(alignment: .leading, spacing: 6) {
            Button { withAnimation(.snappy) { veksle(id) } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(åpen ? 90 : 0))
                        .foregroundStyle(Color.sekundærTekst)
                    Text(p.navn.isEmpty ? String(localized: "Uten navn") : p.navn).lineLimit(1)
                    Spacer()
                    Text("\(p.farger.count)").font(.caption.monospacedDigit()).foregroundStyle(Color.sekundærTekst)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if åpen {
                if p.farger.isEmpty {
                    Text("Slipp farger her").font(.caption).foregroundStyle(Color.sekundærTekst)
                } else {
                    fargerutenett(p.farger, fra: p)
                }
            } else if !p.farger.isEmpty {
                // Store biblioteker vises som en stripe til de foldes ut.
                PalettStripe(farger: p.farger.prefix(40).map(\.farge)).frame(height: 14)
            }
        }
        .padding(.vertical, 2)
        .tarImotFarger { farger in flytt(farger, til: p, i: kontekst) }
        .accessibilityElement(children: .contain)
    }

    private func fargerutenett(_ farger: [PalettFarge], fra palett: PalettDokument?) -> some View {
        LazyVGrid(columns: rutenett, alignment: .leading, spacing: 4) {
            ForEach(farger) { pf in
                FargeRute(farge: pf.farge, navn: pf.navn, visTekst: false, hjørne: 6,
                          fjern: {
                              if let palett { palett.farger.removeAll { $0.id == pf.id } } else { slettEnkeltfarge(pf.id, i: kontekst) }
                          },
                          palettFarge: pf,
                          ekstraMeny: palett.map { AnyView(FlyttMeny(farge: pf, fra: $0)) })
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture { arbeidsbenk.aktivFarge = pf.farge }
                    .help(pf.navn.isEmpty ? pf.farge.hex() : "\(pf.navn) · \(pf.farge.hex())")
                    .accessibilityAction(named: "Gjør til aktiv farge") { arbeidsbenk.aktivFarge = pf.farge }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Knapp i verktøylinjen som viser eller skjuler palettkolonnen (bare når vinduet er bredt nok).
struct PalettkolonneKnapp: ToolbarContent {
    private var erMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @AppStorage("visPalettkolonne") private var vis = true

    var body: some ToolbarContent {
        // Bare iPad: på Mac ligger Paletter fast til høyre når vinduet er bredt nok.
        if arbeidsbenk.palettkolonneMulig && !erMac {
            ToolbarItem(placement: .primaryAction) {
                Button(vis ? "Skjul paletter" : "Vis paletter", systemImage: "sidebar.trailing") { vis.toggle() }
                    .help(vis ? "Skjul palettkolonnen" : "Vis palettkolonnen")
            }
        }
    }
}

extension View {
    /// Legger til knappen for palettkolonnen i verktøylinjen.
    func palettkolonneKnapp() -> some View { toolbar { PalettkolonneKnapp() } }
}
