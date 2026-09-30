import FargeKI
import FargeKjerne
import SwiftData
import SwiftUI

/// Vurdering: kontrast (WCAG), sammenligning (ΔE2000) og vurdering av hele paletter.
struct VurderingVisning: View {
    enum Del: String, CaseIterable, Identifiable {
        case kontrast, sammenlign, palett
        var id: String { rawValue }
        var navn: String {
            switch self {
            case .kontrast: "Kontrast"
            case .sammenlign: "Sammenlign"
            case .palett: "Palett"
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
                FargeValgRad(tittel: "Tekst og grafikk", farge: $arbeidsbenk.aktivFarge)
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
    @State private var valgtID: UUID?
    @State private var bruk = ""
    @State private var vurdering: PalettVurdering?
    @State private var arbeider = false
    @State private var feil: String?
    @State private var visMatrise = false

    private var valgt: PalettDokument? { paletter.first { $0.id == valgtID } ?? paletter.first }

    var body: some View {
        Form {
            if paletter.isEmpty {
                ContentUnavailableView("Ingen paletter", systemImage: "swatchpalette",
                                       description: Text("Lag en palett først, så kan den vurderes her."))
            } else {
                Section {
                    Picker("Palett", selection: Binding(get: { valgt?.id }, set: { valgtID = $0; vurdering = nil })) {
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
                } footer: {
                    Text("Vurderingen lages med Apple Intelligence på enheten når det er tilgjengelig, ellers med faste regler. Kontrasttallene er beregnet eksakt.")
                }
                if let feil {
                    Section { Label(feil, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                }
                if let vurdering {
                    Section("Oppsummering") { Text(vurdering.oppsummering) }
                    punkter("Styrker", vurdering.styrker, "plus.circle.fill", .green)
                    punkter("Svakheter", vurdering.svakheter, "exclamationmark.triangle.fill", .orange)
                    punkter("Forslag", vurdering.forslag, "arrow.right.circle.fill", .blue)
                    Section {
                        DisclosureGroup("Fakta vurderingen bygger på") {
                            ForEach(vurdering.fakta, id: \.self) { Text($0).font(.callout) }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Palett")
        .sheet(isPresented: $visMatrise) {
            if let valgt { KontrastmatriseArk(palett: valgt.palett) }
        }
    }

    @ViewBuilder
    private func punkter(_ tittel: String, _ liste: [String], _ symbol: String, _ farge: Color) -> some View {
        if !liste.isEmpty {
            Section(tittel) {
                ForEach(liste, id: \.self) { p in
                    Label { Text(p) } icon: { Image(systemName: symbol).foregroundStyle(farge) }
                }
            }
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
