import FargeKjerne
import SwiftUI

struct KameraVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var plukker = KameraFargeplukker()
    @State private var fanget: [Farge] = []
    @State private var lagre: [PalettFarge]?

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
                FargeRute(farge: plukker.gjeldende ?? Farge(hex: "#808080")!, hjørne: 10,
                          leggIPalett: { lagre = [PalettFarge(farge: $0, opphav: .kamera)] })
                    .frame(width: 88, height: 64)
                Button("Legg i palett", systemImage: "plus.square.on.square") {
                    if let f = fanget.last ?? plukker.gjeldende { lagre = [PalettFarge(farge: f, opphav: .kamera)] }
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .disabled(fanget.isEmpty && plukker.gjeldende == nil)
                .help("Legg sist fangede farge i en palett")
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(fanget.indices, id: \.self) { i in
                            FargeRute(farge: fanget[i], visTekst: false, hjørne: 6,
                                      leggIPalett: { lagre = [PalettFarge(farge: $0, opphav: .kamera)] },
                                      fjern: { fanget.remove(at: i) })
                                .frame(width: 40, height: 40)
                                .onTapGesture { arbeidsbenk.aktivFarge = fanget[i] }
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
            ToolbarItemGroup {
                LyskildeKnapper(plukker: plukker)
                Button("Legg alle i palett", systemImage: "square.and.arrow.down.on.square") {
                    lagre = fanget.map { PalettFarge(farge: $0, opphav: .kamera) }
                }
                .disabled(fanget.isEmpty)
            }
        }
        .sheet(isPresented: Binding(get: { lagre != nil }, set: { if !$0 { lagre = nil } })) {
            VelgPalettArk(farger: lagre ?? [], foreslåttNavn: "Kamera")
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

/// Lyskilder for utplukk: kameraets lykt der den finnes, og lysfelt på Mac-skjermen.
private struct LyskildeKnapper: View {
    let plukker: KameraFargeplukker
    #if os(macOS)
    @State private var lysfelt = Lysfelt.delt
    #endif

    var body: some View {
        if plukker.harLykt {
            Menu {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { nivå in
                    Button("\(Int(nivå * 100)) %") { plukker.settLykt(på: true, nivå: Float(nivå)) }
                }
                if plukker.lyktPå { Button("Slå av", systemImage: "flashlight.off.fill") { plukker.settLykt(på: false) } }
            } label: {
                Label("Lykt", systemImage: plukker.lyktPå ? "flashlight.on.fill" : "flashlight.off.fill")
            } primaryAction: {
                plukker.settLykt(på: !plukker.lyktPå)
            }
            .accessibilityValue(plukker.lyktPå ? "På, \(Int(plukker.lyktNivå * 100)) prosent" : "Av")
        }
        #if os(macOS)
        Button {
            lysfelt.veksle()
        } label: {
            Label(lysfelt.erSynlig ? "Skjul lysfelt" : "Vis lysfelt",
                  systemImage: lysfelt.erSynlig ? "lightbulb.fill" : "lightbulb")
        }
        .help("Hvitt, flyttbart lysfelt på skjermen som lyskilde for kameraet")
        #endif
    }
}
