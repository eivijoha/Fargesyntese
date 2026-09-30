import FargeKjerne
import SwiftUI

struct KameraVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var plukker = KameraFargeplukker()
    @State private var fanget: [Farge] = []
    @State private var visLagre = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                KameraForhåndsvisning(økt: plukker.økt)
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .shadow(radius: 2)
                    .frame(width: 44, height: 44)
                if plukker.tilgangNektet {
                    ContentUnavailableView("Ingen kameratilgang", systemImage: "camera.fill",
                                           description: Text("Gi tilgang i Innstillinger for å plukke farger fra omgivelsene."))
                        .background(.regularMaterial)
                }
            }
            .clipped()

            HStack(spacing: 12) {
                FargeRute(farge: plukker.gjeldende ?? Farge(hex: "#808080")!, hjørne: 10)
                    .frame(width: 88, height: 64)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(fanget.indices, id: \.self) { i in
                            FargeRute(farge: fanget[i], visTekst: false, hjørne: 6).frame(width: 40, height: 40)
                        }
                    }
                }
                Button {
                    if let f = plukker.gjeldende {
                        fanget.append(f)
                        arbeidsbenk.aktivFarge = f
                    }
                } label: {
                    Image(systemName: "circle.inset.filled").font(.system(size: 44))
                }
                .accessibilityLabel("Fang farge")
                .sensoryFeedback(.impact, trigger: fanget.count)
            }
            .padding()
            .background(.bar)
        }
        .navigationTitle("Kamera")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            Button("Lagre", systemImage: "square.and.arrow.down") { visLagre = true }
                .disabled(fanget.isEmpty)
        }
        .sheet(isPresented: $visLagre) {
            VelgPalettArk(farger: fanget.map { PalettFarge(farge: $0, opphav: .kamera) })
        }
        .task { await plukker.start() }
        .onDisappear { plukker.stopp() }
    }
}
