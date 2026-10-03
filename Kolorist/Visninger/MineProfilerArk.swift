import CoreGraphics
import FargeKjerne
import SwiftUI

/// Oversikt over importerte ICC-profiler («Mine profiler»), med import og sletting.
/// Sletting fjerner filen fra iCloud Drive › Kolorist › Profiler, og dermed fra alle enhetene.
struct MineProfilerArk: View {
    /// Profilen som vises i Studio («Vis også»); settes tilbake til sRGB hvis den slettes.
    @Binding var valgtID: String
    @Environment(ProfilBibliotek.self) private var bibliotek
    @Environment(\.dismiss) private var lukk
    @State private var slettes: ICCProfil?
    @State private var importerer = false
    @State private var feil: String?

    var body: some View {
        NavigationStack {
            List {
                if bibliotek.importerte.isEmpty {
                    ContentUnavailableView("Ingen egne profiler", systemImage: "doc.badge.plus",
                                           description: Text("Importer .icc- eller .icm-filer, for eksempel trykkprofilen fra trykkeriet."))
                } else {
                    Section {
                        ForEach(bibliotek.importerte) { profil in
                            rad(profil)
                                #if os(iOS)
                                .swipeActions {
                                    Button("Slett", systemImage: "trash", role: .destructive) { slettes = profil }
                                }
                                #endif
                        }
                    } footer: {
                        Text(bibliotek.brukerICloud
                             ? "Profilene ligger i iCloud Drive › Kolorist › Profiler og synkroniseres mellom enhetene dine."
                             : "Profilene lagres på denne enheten (iCloud Drive er ikke tilgjengelig).")
                    }
                }
                Section {
                    Button("Importer profil …", systemImage: "square.and.arrow.down") { importerer = true }
                }
            }
            .navigationTitle("Mine profiler")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Ferdig") { lukk() } } }
            .confirmationDialog(slettes.map { String(localized: "Slette «\($0.navn)»?") } ?? "",
                                isPresented: Binding(get: { slettes != nil }, set: { if !$0 { slettes = nil } }),
                                titleVisibility: .visible, presenting: slettes) { profil in
                Button("Slett profilen", role: .destructive) { slett(profil) }
                Button("Avbryt", role: .cancel) {}
            } message: { _ in
                Text(bibliotek.brukerICloud
                     ? "Filen slettes fra iCloud Drive og forsvinner fra alle enhetene dine. Farger som er lagret i profilen, beholder verdiene sine."
                     : "Filen slettes fra denne enheten. Farger som er lagret i profilen, beholder verdiene sine.")
            }
            .fileImporter(isPresented: $importerer, allowedContentTypes: ICCSeksjon.profiltyper, allowsMultipleSelection: true) { resultat in
                do {
                    _ = try resultat.get().map { try bibliotek.importer(fra: $0) }
                } catch {
                    feil = error.localizedDescription
                }
            }
            .alert("Kunne ikke importere", isPresented: Binding(get: { feil != nil }, set: { if !$0 { feil = nil } })) {
                Button("OK") {}
            } message: {
                Text(feil ?? "")
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 360)
        #endif
    }

    private func rad(_ profil: ICCProfil) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(profil.navn).lineLimit(2)
                Text(profil.modellnavn + (profil.id == valgtID ? " · " + String(localized: "vises i Studio") : ""))
                    .font(.caption)
                    .foregroundStyle(Color.sekundærTekst)
            }
            Spacer()
            #if os(macOS)
            Button("Slett", systemImage: "trash") { slettes = profil }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Slett profilen")
            #endif
        }
    }

    private func slett(_ profil: ICCProfil) {
        if valgtID == profil.id { valgtID = ICCProfil.sRGB.id }
        bibliotek.fjern(profil)
        slettes = nil
    }
}

extension ICCProfil {
    /// Fargemodellen som kort tekst («CMYK», «RGB», «Gråtone», «Lab»).
    var modellnavn: String {
        switch modell {
        case .cmyk: "CMYK"
        case .rgb: "RGB"
        case .monochrome: String(localized: "Gråtone")
        case .lab: "Lab"
        default: String(localized: "\(antallKomponenter) kanaler")
        }
    }
}
