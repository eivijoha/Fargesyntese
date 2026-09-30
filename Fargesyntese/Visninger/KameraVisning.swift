import FargeKjerne
import SwiftUI

struct KameraVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var plukker = KameraFargeplukker()
    @State private var fanget: [Farge] = []
    @State private var visLagre = false

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    KameraForhåndsvisning(økt: plukker.økt) { enhet, visning in
                        plukker.plukk(enhetspunkt: enhet, visningspunkt: visning)
                    }
                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .shadow(radius: 2)
                        .frame(width: 44, height: 44)
                        .position(plukker.markør ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                        .animation(.snappy(duration: 0.2), value: plukker.markør)
                        .allowsHitTesting(false)
                    if plukker.tilgangNektet {
                        ContentUnavailableView("Ingen kameratilgang", systemImage: "camera.fill",
                                               description: Text("Gi tilgang i Innstillinger for å plukke farger fra omgivelsene."))
                            .background(.regularMaterial)
                    }
                }
                .onChange(of: geo.size) { plukker.tilbakestillMarkør() }
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
                    plukker.fang()
                } label: {
                    Image(systemName: "circle.inset.filled").font(.system(size: 44))
                }
                .accessibilityLabel("Fang farge")
                .sensoryFeedback(.impact, trigger: fanget.count)
            }
            .padding()
            .background(.bar)
            .overlay(alignment: .top) { DeltaEMerke(fanget: fanget).offset(y: -44) }
        }
        .toolbar {
            Button("Lagre", systemImage: "square.and.arrow.down") { visLagre = true }
                .disabled(fanget.isEmpty)
        }
        .sheet(isPresented: $visLagre) {
            VelgPalettArk(farger: fanget.map { PalettFarge(farge: $0, opphav: .kamera) })
        }
        .task {
            plukker.vedFangst = { farge in
                fanget.append(farge)
                arbeidsbenk.aktivFarge = farge
                arbeidsbenk.registrerMåling(farge)
            }
            await plukker.start()
        }
        .onDisappear { plukker.stopp() }
    }
}
