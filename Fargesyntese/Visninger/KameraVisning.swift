import FargeKjerne
import SwiftData
import SwiftUI

struct KameraVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var plukker = KameraFargeplukker()
    @State private var fanget: [Farge] = []
    @State private var lagre: [PalettFarge]?
    @State private var lagret = false
    @Environment(\.modelContext) private var kontekst
    /// Slukk lykt/lysfelt når en farge er fanget (lyset trengs bare under målingen).
    @AppStorage("slukkLysEtterFangst") private var slukkEtterFangst = true

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
                // Egen visning: bare denne oppdateres ~10 ganger i sekundet, ikke hele Utplukk
                // (ellers avbrytes trykk i knapper og ark).
                LevendeKamerafarge(plukker: plukker) { lagre = [PalettFarge(farge: $0, opphav: .kamera)] }
                    .frame(width: 88, height: 64)
                VStack(spacing: 10) {
                    Button("Lagre som enkeltfarge", systemImage: lagret ? "bookmark.fill" : "bookmark") {
                        guard let f = fanget.last ?? plukker.gjeldende else { return }
                        lagreEnkeltfarger([PalettFarge(farge: arbeidsbenk.begrens(f), opphav: .kamera)], i: kontekst)
                        lagret = true
                        Task { try? await Task.sleep(for: .seconds(1.5)); lagret = false }
                    }
                    .sensoryFeedback(.success, trigger: lagret) { _, ny in ny }
                    .help("Lagre sist fangede farge som enkeltfarge")
                    Button("Legg i palett", systemImage: "plus.square.on.square") {
                        if let f = fanget.last ?? plukker.gjeldende { lagre = [PalettFarge(farge: arbeidsbenk.begrens(f), opphav: .kamera)] }
                    }
                    .help("Legg sist fangede farge i en palett")
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(fanget.enumerated()), id: \.offset) { i, farge in
                            FargeRute(farge: farge, visTekst: false, hjørne: 6,
                                      leggIPalett: { lagre = [PalettFarge(farge: $0, opphav: .kamera)] },
                                      fjern: { if fanget.indices.contains(i) { fanget.remove(at: i) } })
                                .frame(width: 40, height: 40)
                                .onTapGesture { arbeidsbenk.aktivFarge = farge }
                        }
                    }
                }
                Button {
                    plukker.fang()
                } label: {
                    Image(systemName: "circle.inset.filled").font(.system(size: 44))
                }
                .accessibilityLabel("Fang farge")
                .sensoryFeedback(.impact, trigger: fanget)
            }
            .padding()
            .background(.bar)
            .overlay(alignment: .top) { DeltaEMerke(fanget: fanget).offset(y: -44) }
        }
        .toolbar {
            ToolbarItemGroup {
                LyskildeKnapper(plukker: plukker, slukkEtterFangst: $slukkEtterFangst)
                Button("Legg alle i palett", systemImage: "square.and.arrow.down.on.square") {
                    lagre = fanget.map { PalettFarge(farge: $0, opphav: .kamera) }
                }
                .disabled(fanget.isEmpty)
            }
        }
        .sheet(isPresented: Binding(get: { lagre != nil }, set: { if !$0 { lagre = nil } })) {
            VelgPalettArk(farger: lagre ?? [], foreslåttNavn: "Kamera")
        }
        // Pause kameraet mens arket er åpent, så det ikke konkurrerer med trykk i arket.
        .onChange(of: lagre != nil) { _, åpent in
            if åpent { plukker.stopp() } else { Task { await plukker.start() } }
        }
        .task {
            plukker.vedFangst = { målt in
                let farge = arbeidsbenk.begrens(målt)
                fanget.fang(farge)
                arbeidsbenk.aktivFarge = farge
                arbeidsbenk.registrerMåling(farge)
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

extension Array where Element == Farge {
    /// Utplukk holder bare de siste fangede fargene (rullerende), nyeste sist.
    static let maksFanget = 3

    mutating func fang(_ farge: Farge) {
        append(farge)
        if count > Self.maksFanget { removeFirst(count - Self.maksFanget) }
    }
}
