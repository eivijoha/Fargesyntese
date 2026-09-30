import FargeKjerne
import SwiftUI

/// Overgangstoner i like OKLab-steg mellom to farger, med lysere/mørkere rader.
struct OvergangVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var start = Farge(hex: "#1B3A6B")!
    @State private var slutt = Farge(hex: "#F2B84B")!
    @State private var antall = 7
    @State private var visLagre = false

    private var toner: [Farge] { Overgang.toner(fra: start, til: slutt, antall: antall) }

    /// Rader fra lysest til mørkest; midtraden er selve overgangen.
    private var rader: [[Farge]] {
        let trinn = arbeidsbenk.lyshetstrinn
        let variasjoner = toner.map { trinn.toner(for: $0) }
        return (0..<(trinn.antallLysere + trinn.antallMørkere + 1)).map { rad in variasjoner.map { $0[rad] } }
    }

    var body: some View {
        Form {
            Section("Endepunkter") {
                FargeVelgerRad(tittel: "Fra", farge: $start)
                FargeVelgerRad(tittel: "Til", farge: $slutt)
                Button("Bytt om", systemImage: "arrow.left.arrow.right") { swap(&start, &slutt) }
            }
            Section("Overgang") {
                Stepper("Toner: \(antall)", value: $antall, in: 2...24)
            }
            Section("Lysere og mørkere rader") {
                @Bindable var arbeidsbenk = arbeidsbenk
                LyshetstrinnKontroller(trinn: $arbeidsbenk.lyshetstrinn)
            }
            Section {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    ForEach(rader.indices, id: \.self) { r in
                        GridRow {
                            ForEach(rader[r].indices, id: \.self) { k in
                                FargeRute(farge: rader[r][k], visTekst: false, hjørne: 4)
                                    .frame(minHeight: r == arbeidsbenk.lyshetstrinn.antallLysere ? 56 : 36)
                                    .onTapGesture { arbeidsbenk.aktivFarge = rader[r][k] }
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            } header: {
                Text("Interpolert i OKLab")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Overgang")
        .toolbar {
            Button("Lagre som palett", systemImage: "square.and.arrow.down") { visLagre = true }
        }
        .sheet(isPresented: $visLagre) {
            VelgPalettArk(farger: rader.flatMap { $0 }.map { PalettFarge(farge: $0, opphav: .overgang) },
                          foreslåttNavn: "Overgang \(start.hex()) → \(slutt.hex())")
        }
    }
}

struct FargeVelgerRad: View {
    let tittel: String
    @Binding var farge: Farge
    @Environment(Arbeidsbenk.self) private var arbeidsbenk

    var body: some View {
        HStack {
            ColorPicker(tittel, selection: Binding(get: { farge.swiftUI }, set: { farge = Farge($0) }))
            Text(farge.hex()).font(.callout.monospaced()).foregroundStyle(.secondary)
            Menu("Mer", systemImage: "ellipsis.circle") {
                Button("Bruk aktiv farge") { farge = arbeidsbenk.aktivFarge }
                Button("Lim inn") { if let f = Utklippstavle.limInn() { farge = f } }
            }
            .labelStyle(.iconOnly)
        }
    }
}
