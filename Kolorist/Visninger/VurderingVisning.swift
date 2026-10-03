import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI

/// Vurdering: kontrast (WCAG), sammenligning (ΔE2000), vurdering av hele paletter og fargesyn (CVD).
struct VurderingVisning: View {
    enum Del: String, CaseIterable, Identifiable {
        case kontrast, sammenlign, palett, fargesyn
        var id: String { rawValue }
        var navn: String {
            switch self {
            case .kontrast: String(localized: "Kontrast")
            case .sammenlign: String(localized: "Sammenlign")
            case .palett: String(localized: "Palett")
            case .fargesyn: String(localized: "Fargesyn")
            }
        }
    }

    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @AppStorage("vurderingDel") private var del: Del = .kontrast

    var body: some View {
        Group {
            switch del {
            case .kontrast: KontrastVurdering()
            case .sammenlign:
                // Ny identitet ved hver visning, slik at A/B hentes fra aktiv farge og siste måling.
                SammenligningVisning(a: arbeidsbenk.aktivFarge,
                                     b: arbeidsbenk.målinger.last(where: { $0 != arbeidsbenk.aktivFarge }) ?? Farge(hex: "#FFFFFF")!,
                                     innebygd: true)
            case .palett: PalettVurderingDel()
            case .fargesyn: FargesynVurdering()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Vurdering", selection: $del) {
                    ForEach(Del.allCases) { Text($0.navn).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}

/// WCAG-kontrast for aktiv farge mot en valgt bakgrunn.
private struct KontrastVurdering: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk

    var body: some View {
        @Bindable var arbeidsbenk = arbeidsbenk
        Form {
            Section {
                FargeValgRad(tittel: String(localized: "Farge som testes"), farge: $arbeidsbenk.aktivFarge)
            }
            KontrastSeksjon(forgrunn: $arbeidsbenk.aktivFarge)
        }
        .formStyle(.grouped)
        .navigationTitle("Kontrast")
    }
}

/// Vurdering av en hel palett: KI-vurdering (med eksakte WCAG-fakta) og kontrastmatrise.
private struct PalettVurderingDel: View {
    @Query(sort: \PalettDokument.endret, order: .reverse) private var paletter: [PalettDokument]
    /// Delt med Vurdering › Fargesyn, så samme palett er valgt i begge.
    @AppStorage("vurderingPalett") private var valgtIDTekst = ""
    @State private var bruk = ""
    @State private var vurdering: PalettVurdering?
    @State private var arbeider = false
    @State private var feil: String?
    @State private var visMatrise = false

    private var valgt: PalettDokument? { paletter.first { $0.id.uuidString == valgtIDTekst } ?? paletter.first }

    var body: some View {
        Form {
            if paletter.isEmpty {
                ContentUnavailableView("Ingen paletter", systemImage: "swatchpalette",
                                       description: Text("Lag en palett først, så kan den vurderes her."))
            } else {
                Section {
                    Picker("Palett", selection: Binding(get: { valgt?.id }, set: { valgtIDTekst = $0?.uuidString ?? ""; vurdering = nil })) {
                        ForEach(paletter) { Text($0.navn.isEmpty ? "Uten navn" : $0.navn).tag(Optional($0.id)) }
                    }
                    if let valgt {
                        PalettStripe(farger: valgt.farger.map(\.farge)).frame(height: 40)
                    }
                    TextField("Bruk (valgfritt), f.eks. «nettside for en barnehage»", text: $bruk, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section {
                    Button {
                        Task { await vurder() }
                    } label: {
                        if arbeider { ProgressView() } else { Label("Vurder paletten", systemImage: "text.magnifyingglass") }
                    }
                    .disabled(valgt?.farger.isEmpty ?? true || arbeider)
                    Button("Kontrastmatrise", systemImage: "square.grid.3x3.fill") { visMatrise = true }
                        .disabled((valgt?.farger.count ?? 0) < 2)
                } footer: { Group {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vurderingen lages med Apple Intelligence på enheten når det er tilgjengelig, ellers med faste regler. Den tar med kontrast (WCAG) og fargesyn.")
                        MetodeHenvisning(.wcag, .machado, .ciede2000, .kunnskapsbase)
                    }
                }.foregroundStyle(Color.sekundærTekst) }
                if let feil {
                    Section { Label(feil, systemImage: "xmark.circle").foregroundStyle(Color.advarsel) }
                }
                if let vurdering { PalettVurderingInnhold(vurdering: vurdering) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Palett")
        .sheet(isPresented: $visMatrise) {
            if let valgt { KontrastmatriseArk(palett: valgt.palett) }
        }
    }

    private func vurder() async {
        guard let valgt else { return }
        arbeider = true
        defer { arbeider = false }
        feil = nil
        do {
            vurdering = try await Palettvurderer.vurder(valgt.palett, bruk: bruk.isEmpty ? nil : bruk)
        } catch {
            feil = error.localizedDescription
        }
    }
}

/// Resultatet av en palettvurdering som seksjoner i en liste/et skjema. Brukes både i
/// Vurdering › Palett og i vurderingsarket fra en palett, så de ser like ut.
struct PalettVurderingInnhold: View {
    let vurdering: PalettVurdering

    var body: some View {
        Seksjon("Oppsummering") { Text(vurdering.oppsummering) }
        punkter(String(localized: "Styrker"), vurdering.styrker, "plus.circle.fill", Color.suksess)
        punkter(String(localized: "Svakheter"), vurdering.svakheter, "minus.circle.fill", Color.advarsel)
        punkter(String(localized: "Forslag"), vurdering.forslag, "arrow.right.circle.fill", Color.accentColor)
        Section {
            DisclosureGroup("Fakta vurderingen bygger på") {
                ForEach(vurdering.fakta, id: \.self) { Text($0).font(.callout) }
            }
        } footer: { Group {
            Text(vurdering.kilde == .appleIntelligence
                 ? "Laget med Apple Intelligence på enheten. Kontrast og fargesyn er beregnet eksakt."
                 : "Regelbasert vurdering (Apple Intelligence er ikke tilgjengelig). Kontrast og fargesyn er beregnet eksakt.")
        }.foregroundStyle(Color.sekundærTekst) }
    }

    @ViewBuilder
    private func punkter(_ tittel: String, _ liste: [String], _ symbol: String, _ farge: Color) -> some View {
        if !liste.isEmpty {
            Seksjon(tittel) {
                ForEach(liste, id: \.self) { p in
                    Label { Text(p) } icon: { Image(systemName: symbol).foregroundStyle(farge) }
                }
            }
        }
    }
}
