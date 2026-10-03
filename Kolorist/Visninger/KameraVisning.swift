import FargeKjerne
import SwiftData
import SwiftUI

struct KameraVisning: View {
    private var erMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var plukker = KameraFargeplukker()
    @State private var lagre: [PalettFarge]?
    @Environment(\.modelContext) private var kontekst
    /// Slukk lykt/lysfelt når en farge er fanget (lyset trengs bare under målingen).
    @AppStorage("slukkLysEtterFangst") private var slukkEtterFangst = true

    @ViewBuilder private var kameraflate: some View {
        #if os(iOS)
        KameraForhåndsvisning(
            økt: plukker.økt,
            vedTrykk: { enhet, visning in plukker.plukk(enhetspunkt: enhet, visningspunkt: visning) },
            vedKnip: { skala, begynner in plukker.knip(skala, begynner: begynner) },
            vedDobbelttrykk: { plukker.settZoom(1) },
        )
        #else
        // Mac: målpunktet følger pekeren, og et klikk fanger fargen der.
        KameraForhåndsvisning(
            økt: plukker.økt,
            vedTrykk: { enhet, visning in plukker.plukk(enhetspunkt: enhet, visningspunkt: visning) },
            vedSveve: { enhet, visning in plukker.sikt(enhetspunkt: enhet, visningspunkt: visning) }
        )
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    kameraflate
                    // På Mac vises markøren først når pekeren er over bildet (ingen fast midtmarkør).
                    if !erMac || plukker.markør != nil {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2)
                            .shadow(radius: 2)
                            .frame(width: 44, height: 44)
                            .position(plukker.markør ?? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2))
                            .animation(erMac ? nil : .snappy(duration: 0.2), value: plukker.markør)
                            .allowsHitTesting(false)
                    }
                    if plukker.tilgangNektet {
                        ContentUnavailableView("Ingen kameratilgang", systemImage: "camera.fill",
                                               description: Text("Gi tilgang i Innstillinger for å plukke farger fra omgivelsene."))
                            .background(.regularMaterial)
                    }
                }
                .overlay(alignment: .topTrailing) { ZoomMerke(plukker: plukker) }
                .onChange(of: geo.size) { plukker.tilbakestillMarkør() }
            }
            .clipped()

            HStack(spacing: 12) {
                // Egen visning: bare denne oppdateres ~10 ganger i sekundet, ikke hele Utplukk
                // (ellers avbrytes trykk i knapper og ark).
                LevendeKamerafarge(plukker: plukker) { lagre = [PalettFarge(farge: $0, opphav: .kamera)] }
                    .frame(width: 88, height: 64)
                LagreMeny(lagre: {
                    guard let f = arbeidsbenk.målinger.last ?? plukker.gjeldende else { return }
                    lagreEnkeltfarger([PalettFarge(farge: arbeidsbenk.begrens(f), opphav: .kamera)], i: kontekst)
                }, leggIPalett: {
                    if let f = arbeidsbenk.målinger.last ?? plukker.gjeldende { lagre = [PalettFarge(farge: arbeidsbenk.begrens(f), opphav: .kamera)] }
                })
                .font(.title2)
                .foregroundStyle(.tint)
                .help("Lagre sist fangede farge")
                PlukkedeFargerRad(opphav: .kamera, størrelse: 40) { lagre = [PalettFarge(farge: $0, opphav: .kamera)] }
                Button {
                    plukker.fang()
                } label: {
                    Image(systemName: "circle.inset.filled").font(.system(size: 44))
                }
                .accessibilityLabel("Fang farge")
                .sensoryFeedback(.impact, trigger: arbeidsbenk.målinger)
            }
            .padding()
            .background(.bar)
            .overlay(alignment: .top) { DeltaEMerke(fanget: arbeidsbenk.målinger).offset(y: -44) }
        }
        .toolbar {
            ToolbarItemGroup {
                LyskildeKnapper(plukker: plukker, slukkEtterFangst: $slukkEtterFangst)
                Button("Legg alle i palett", systemImage: "square.and.arrow.down.on.square") {
                    lagre = arbeidsbenk.målinger.map { PalettFarge(farge: $0, opphav: .kamera) }
                }
                .disabled(arbeidsbenk.målinger.isEmpty)
            }
        }
        .sheet(isPresented: Binding(get: { lagre != nil }, set: { if !$0 { lagre = nil } })) {
            VelgPalettArk(farger: lagre ?? [], foreslåttNavn: String(localized: "Kamera"))
        }
        // Pause kameraet mens arket er åpent, så det ikke konkurrerer med trykk i arket.
        .onChange(of: lagre != nil) { _, åpent in
            if åpent { plukker.stopp() } else { Task { await plukker.start() } }
        }
        .task {
            plukker.vedFangst = { målt in
                let farge = arbeidsbenk.begrens(målt)
                arbeidsbenk.aktivFarge = farge
                arbeidsbenk.registrerMåling(farge)
                // Klar for neste farge: punktet tilbake i midten (på Mac følger det pekeren).
                if !erMac { plukker.tilbakestillMarkør() }
                if slukkEtterFangst {
                    if plukker.lyktPå { plukker.settLykt(på: false) }
                    #if os(macOS)
                    if Lysfelt.delt.erSynlig { Lysfelt.delt.skjul() }
                    #endif
                }
            }
            await plukker.start()
        }
        .onDisappear { plukker.stopp() }
    }
}

/// Lyskilder for utplukk: kameraets lykt der den finnes, og lysfelt på Mac-skjermen.
private struct LyskildeKnapper: View {
    let plukker: KameraFargeplukker
    @Binding var slukkEtterFangst: Bool
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
                Divider()
                Toggle("Slukk etter fangst", isOn: $slukkEtterFangst)
            } label: {
                Label("Lykt", systemImage: plukker.lyktPå ? "flashlight.on.fill" : "flashlight.off.fill")
            } primaryAction: {
                plukker.settLykt(på: !plukker.lyktPå)
            }
            .accessibilityValue(plukker.lyktPå ? "På, \(Int(plukker.lyktNivå * 100)) prosent" : "Av")
        }
        #if os(macOS)
        Menu {
            Toggle("Slukk etter fangst", isOn: $slukkEtterFangst)
        } label: {
            Label(lysfelt.erSynlig ? "Skjul lysfelt" : "Vis lysfelt",
                  systemImage: lysfelt.erSynlig ? "lightbulb.fill" : "lightbulb")
        } primaryAction: {
            lysfelt.veksle()
        }
        .help("Hvitt, flyttbart lysfelt på skjermen som lyskilde for kameraet")
        #endif
    }
}

/// Levende fargeprøve fra kameraet – isolert, så hyppige oppdateringer ikke tegner hele visningen på nytt.
private struct LevendeKamerafarge: View {
    let plukker: KameraFargeplukker
    var leggIPalett: (Farge) -> Void

    var body: some View {
        FargeRute(farge: plukker.gjeldende ?? Farge(hex: "#808080")!, hjørne: 10, leggIPalett: leggIPalett)
    }
}

/// Viser zoomnivået når det avviker fra 1×. Egen visning, så zoomendringer ikke tegner alt på nytt.
private struct ZoomMerke: View {
    let plukker: KameraFargeplukker

    var body: some View {
        if abs(plukker.zoom - 1) > 0.01 {
            Text("\(plukker.zoom, format: .number.precision(.fractionLength(1)))×")
                .font(.callout.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule())
                .padding(10)
                .allowsHitTesting(false)
        }
    }
}
