import FargeKjerne
import SwiftUI
import UniformTypeIdentifiers

/// Fargestyring i Studio: vis og juster fargen i en valgt ICC-profil, varsle om
/// farger utenfor profilens gamut, og importer egne profiler (FOGRA39, GRACoL …).
struct ICCSeksjon: View {
    @Binding var farge: Farge
    @Environment(ProfilBibliotek.self) private var bibliotek
    @AppStorage("valgtProfil") private var valgtProfilID = ICCProfil.genericCMYK.id
    @AppStorage("gjengivelseshensikt") private var hensikt: Gjengivelseshensikt = .relativKolorimetrisk
    @State private var importerer = false
    @State private var feil: String?

    private var profil: ICCProfil { bibliotek.profil(id: valgtProfilID) ?? .genericCMYK }

    var body: some View {
        Section {
            Picker("Profil", selection: $valgtProfilID) {
                Section("Innebygde") {
                    ForEach(ICCProfil.innebygde) { Text($0.navn).tag($0.id) }
                }
                if !bibliotek.importerte.isEmpty {
                    Section("Importerte") {
                        ForEach(bibliotek.importerte) { Text($0.navn).tag($0.id) }
                    }
                }
            }
            Picker("Gjengivelse", selection: $hensikt) {
                ForEach(Gjengivelseshensikt.allCases, id: \.self) { Text($0.visningsnavn).tag($0) }
            }

            if let verdier = farge.komponenter(i: profil, hensikt: hensikt) {
                LabeledContent(profil.komponentnavn.joined(separator: " ")) {
                    Text(formatert(verdier))
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                }
                .contextMenu {
                    Button("Kopier verdier") { Utklippstavle.kopierTekst(formatert(verdier)) }
                }
                if let avvik = farge.avvik(i: profil, hensikt: hensikt), avvik > 0.02 {
                    Label("Utenfor profilens gamut (ΔE\u{2009}OK \(avvik, format: .number.precision(.fractionLength(3))))",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
                if profil.kanRedigeres {
                    DisclosureGroup("Juster i profilen") {
                        ProfilGlidere(profil: profil, farge: $farge)
                    }
                }
            }
        } header: {
            Text("Fargestyring (ICC)")
        } footer: {
            HStack {
                Button("Importer profil …", systemImage: "square.and.arrow.down") { importerer = true }
                if bibliotek.importerte.contains(where: { $0.id == profil.id }) {
                    Button("Fjern", systemImage: "trash", role: .destructive) {
                        bibliotek.fjern(profil)
                        valgtProfilID = ICCProfil.genericCMYK.id
                    }
                }
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .fileImporter(isPresented: $importerer, allowedContentTypes: ICCSeksjon.profiltyper, allowsMultipleSelection: true) { resultat in
            do {
                let profiler = try resultat.get().map { try bibliotek.importer(fra: $0) }
                if let siste = profiler.last { valgtProfilID = siste.id }
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

    static let profiltyper: [UTType] = [
        UTType("com.apple.colorsync-profile"), UTType(filenameExtension: "icc"), UTType(filenameExtension: "icm"),
    ].compactMap { $0 }

    private func formatert(_ v: [Double]) -> String {
        switch profil.modell {
        case .lab: v.map { String(format: "%.1f", $0) }.joined(separator: " / ")
        default: v.map { String(format: "%.0f", $0 * 100) }.joined(separator: " / ") + " %"
        }
    }
}

/// Glidere i profilens egne komponenter (f.eks. CMYK-prosenter fra trykkeriet).
private struct ProfilGlidere: View {
    let profil: ICCProfil
    @Binding var farge: Farge
    @State private var verdier: [Double] = []

    private var gjeldende: [Double] {
        verdier.count == profil.antallKomponenter ? verdier : (farge.komponenter(i: profil) ?? [])
    }

    var body: some View {
        ForEach(Array(profil.komponentnavn.enumerated()), id: \.offset) { i, navn in
            if i < gjeldende.count {
                HStack {
                    Text(navn).frame(width: 36, alignment: .leading)
                    Slider(value: Binding(
                        get: { gjeldende[i] },
                        set: { ny in
                            var v = gjeldende
                            v[i] = ny
                            verdier = v
                            if let f = Farge(komponenter: v, i: profil, alfa: farge.alfa) { farge = f }
                        }
                    ), in: 0...1)
                    Text(gjeldende[i] * 100, format: .number.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .onChange(of: profil.id) { verdier = [] }
        .onChange(of: farge) { _, ny in
            // Nullstill når fargen er endret utenfra (ikke av disse gliderne).
            if let egen = Farge(komponenter: verdier, i: profil, alfa: ny.alfa), egen.avstandOK(til: ny) > 1e-3 { verdier = [] }
        }
    }
}

extension Gjengivelseshensikt {
    var visningsnavn: String {
        switch self {
        case .perseptuell: "Perseptuell"
        case .relativKolorimetrisk: "Relativ kolorimetrisk"
        case .metning: "Metning"
        case .absoluttKolorimetrisk: "Absolutt kolorimetrisk"
        }
    }
}
