import FargeKjerne
import SwiftUI

/// Konverter farger fra én ICC-profil til en annen med valgt gjengivelseshensikt,
/// og se resultatet for alle fire hensiktene side om side.
struct ProfilkonverteringVisning: View {
    @Environment(ProfilBibliotek.self) private var bibliotek
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @AppStorage("konverterFra") private var fraID = ICCProfil.sRGB.id
    @AppStorage("konverterTil") private var tilID = ICCProfil.genericCMYK.id
    @AppStorage("konverterHensikt") private var hensikt: Gjengivelseshensikt = .relativKolorimetrisk
    @State private var verdier: [Double] = []

    private var fra: ICCProfil { bibliotek.profil(id: fraID) ?? .sRGB }
    private var til: ICCProfil { bibliotek.profil(id: tilID) ?? .genericCMYK }

    private var kildefarge: Farge? { Farge(komponenter: gyldigeVerdier, i: fra) }

    /// Verdiene tilpasset kildeprofilens antall komponenter.
    private var gyldigeVerdier: [Double] {
        verdier.count == fra.antallKomponenter ? verdier : (arbeidsbenk.aktivFarge.komponenter(i: fra) ?? Array(repeating: 0, count: fra.antallKomponenter))
    }

    var body: some View {
        Form {
            Section("Fra") {
                profilvelger("Kildeprofil", valgt: $fraID)
                if fra.kanRedigeres {
                    ForEach(Array(fra.komponentnavn.enumerated()), id: \.offset) { i, navn in
                        if i < gyldigeVerdier.count { komponentrad(navn: navn, indeks: i) }
                    }
                } else {
                    Text("Verdier for denne profiltypen hentes fra aktiv farge.").font(.callout).foregroundStyle(.secondary)
                }
                Button("Hent fra aktiv farge", systemImage: "arrow.down.circle") {
                    verdier = arbeidsbenk.aktivFarge.komponenter(i: fra) ?? []
                }
            }

            Section("Til") {
                profilvelger("Målprofil", valgt: $tilID)
                Picker("Gjengivelseshensikt", selection: $hensikt) {
                    ForEach(Gjengivelseshensikt.allCases, id: \.self) { Text($0.visningsnavn).tag($0) }
                }
                if let resultat = ICCProfil.konverter(gyldigeVerdier, fra: fra, til: til, hensikt: hensikt) {
                    let målfarge = Farge(komponenter: resultat, i: til)
                    HStack(spacing: 0) {
                        (kildefarge ?? .init(lineærR: 0, g: 0, b: 0)).swiftUI
                        (målfarge ?? .init(lineærR: 0, g: 0, b: 0)).swiftUI
                    }
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VerdiRad(navn: til.komponentnavn.joined(separator: " "), tekst: formatert(resultat, i: til)) {
                        Utklippstavle.kopierTekst(formatert(resultat, i: til))
                    }
                    if let målfarge {
                        Button("Bruk som aktiv farge", systemImage: "slider.horizontal.3") {
                            arbeidsbenk.aktivFarge = målfarge
                            arbeidsbenk.valgtFane = .studio
                        }
                    }
                }
            }

            Section {
                ForEach(Gjengivelseshensikt.allCases, id: \.self) { h in
                    hensiktsrad(h)
                }
            } header: {
                Text("Alle gjengivelseshensikter")
            } footer: {
                Text("ΔE00 måler avviket fra kildefargen. Hensiktene skiller seg bare når profilene har egne tabeller for dem, typisk CMYK-profiler fra trykkerier; rene matriseprofiler som sRGB og Display P3 gir samme svar for alle.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Konverter mellom profiler")
        .onChange(of: fraID) { verdier = [] }
    }

    private func profilvelger(_ tittel: String, valgt: Binding<String>) -> some View {
        Picker(tittel, selection: valgt) {
            Section("Innebygde") { ForEach(ICCProfil.innebygde) { Text($0.navn).tag($0.id) } }
            if !bibliotek.importerte.isEmpty {
                Section("Importerte") { ForEach(bibliotek.importerte) { Text($0.navn).tag($0.id) } }
            }
        }
    }

    private func komponentrad(navn: String, indeks i: Int) -> some View {
        HStack {
            Text(navn).frame(width: 36, alignment: .leading)
            Slider(value: Binding(
                get: { gyldigeVerdier.indices.contains(i) ? gyldigeVerdier[i] : 0 },
                set: { ny in
                    var v = gyldigeVerdier
                    guard v.indices.contains(i) else { return }
                    v[i] = ny
                    verdier = v
                }
            ), in: 0...1)
            TextField("", value: Binding(
                get: { gyldigeVerdier.indices.contains(i) ? (gyldigeVerdier[i] * fra.visningsskala).rounded() : 0 },
                set: { ny in
                    var v = gyldigeVerdier
                    guard v.indices.contains(i) else { return }
                    v[i] = min(max(ny / fra.visningsskala, 0), 1)
                    verdier = v
                }
            ), format: .number)
            .multilineTextAlignment(.trailing)
            .frame(width: 48)
            .monospacedDigit()
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            Text(fra.visningsenhet).foregroundStyle(.secondary).frame(minWidth: 12)
        }
    }

    private func hensiktsrad(_ h: Gjengivelseshensikt) -> some View {
        let resultat = ICCProfil.konverter(gyldigeVerdier, fra: fra, til: til, hensikt: h)
        let målfarge = resultat.flatMap { Farge(komponenter: $0, i: til) }
        var avvik: Double?
        if let kildefarge, let målfarge { avvik = kildefarge.deltaE2000(til: målfarge) }
        return HStack(spacing: 10) {
            (målfarge ?? .init(lineærR: 0, g: 0, b: 0)).swiftUI
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(h.visningsnavn).fontWeight(h == hensikt ? .semibold : .regular)
                if let resultat {
                    Text(formatert(resultat, i: til)).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let avvik {
                Text("ΔE00 \(avvik, format: .number.precision(.fractionLength(2)))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(avvik > 2 ? .orange : .secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { hensikt = h }
    }

    private func formatert(_ v: [Double], i profil: ICCProfil) -> String { profil.formatert(v) }
}
