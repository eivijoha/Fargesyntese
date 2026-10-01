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
                    Text("Utenfor profilens gamut (ΔE\u{2009}OK \(avvik, format: .number.precision(.fractionLength(3))))")
                        .foregroundStyle(Color.advarsel)
                        .font(.callout)
                }
                if profil.kanRedigeres {
                    DisclosureGroup("Juster i profilen") {
                        ProfilGlidere(profil: profil, farge: $farge)
                    }
                }
            }
            NavigationLink {
                ProfilkonverteringVisning()
            } label: {
                Label("Konverter mellom profiler …", systemImage: "arrow.triangle.swap")
            }
        } header: {
            Text("Fargestyring (ICC)")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
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
                Text(bibliotek.brukerICloud
                     ? "Importerte profiler ligger i iCloud Drive › Fargesyntese › Profiler og synkroniseres mellom enhetene. Du kan også legge .icc-filer der fra Filer eller Finder."
                     : "Importerte profiler lagres på denne enheten (iCloud Drive er ikke tilgjengelig).")
                    .font(.caption)
            }
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

    private func formatert(_ v: [Double]) -> String { profil.formatert(v) }
}

extension ICCProfil {
    /// Visningsskala etter bransjekonvensjon: RGB 0–255, CMYK og grå i prosent.
    var visningsskala: Double { modell == .rgb ? 255 : 100 }
    /// Enhet som vises etter tallene («%» for CMYK/grå, ingen for RGB).
    var visningsenhet: String { modell == .rgb ? "" : "%" }

    func formatert(_ v: [Double]) -> String {
        switch modell {
        case .lab: return v.map { String(format: "%.1f", $0) }.joined(separator: " / ")
        default:
            let tall = v.map { String(format: "%.0f", $0 * visningsskala) }.joined(separator: " / ")
            return visningsenhet.isEmpty ? tall : "\(tall) \(visningsenhet)"
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

    /// Fargene langs sporet: komponent `i` fra 0 til 1 i profilen, de andre som de er.
    private func spor(for i: Int, prøver: Int = 16) -> [Color] {
        let basis = gjeldende
        guard basis.indices.contains(i) else { return [] }
        return (0..<prøver).compactMap { n in
            var v = basis
            v[i] = Double(n) / Double(prøver - 1)
            return Farge(komponenter: v, i: profil, alfa: 1)?.swiftUI
        }
    }

    var body: some View {
        ForEach(Array(profil.komponentnavn.enumerated()), id: \.offset) { i, navn in
            if i < gjeldende.count {
                HStack {
                    Text(navn).frame(width: 36, alignment: .leading)
                    FargeGlider(verdi: Binding(
                        get: { gjeldende.indices.contains(i) ? gjeldende[i] : 0 },
                        set: { ny in
                            var v = gjeldende
                            guard v.indices.contains(i) else { return }
                            v[i] = ny
                            verdier = v
                            if let f = Farge(komponenter: v, i: profil, alfa: farge.alfa) { farge = f }
                        }
                    ), område: 0...1, spor: spor(for: i), gjeldende: farge.swiftUI,
                       tittel: Text(navn),
                       verdiTekst: (gjeldende[i] * profil.visningsskala).formatted(.number.precision(.fractionLength(0))),
                       stegForTilgjengelighet: 0.01)
                    Text(gjeldende[i] * profil.visningsskala, format: .number.precision(.fractionLength(0)))
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
        case .perseptuell: String(localized: "Perseptuell")
        case .relativKolorimetrisk: String(localized: "Relativ kolorimetrisk")
        case .metning: String(localized: "Metning")
        case .absoluttKolorimetrisk: String(localized: "Absolutt kolorimetrisk")
        }
    }
}
