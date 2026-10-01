import FargeKjerne
import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Utplukk-fanen: kamera eller bilde. Bilde er iOS-alternativet til skjermpipette –
/// ta et skjermbilde, åpne det her og plukk fargene.
struct UtplukkVisning: View {
    enum Kilde: Hashable { case kamera, bilde }
    @State private var kilde: Kilde = .kamera

    var body: some View {
        Group {
            switch kilde {
            case .kamera: KameraVisning()
            case .bilde: BildeVisning()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Kilde", selection: $kilde) {
                    Label("Kamera", systemImage: "camera").tag(Kilde.kamera)
                    Label("Bilde", systemImage: "photo").tag(Kilde.bilde)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }
}

struct BildeVisning: View {
    @Environment(Arbeidsbenk.self) private var arbeidsbenk
    @State private var bildevalg: PhotosPickerItem?
    @State private var velgerFil = false
    @State private var bilde: CGImage?
    @State private var prøve: Bildeprøve?
    @State private var laster = false
    /// Utplukkspunkt, normalisert 0…1 i bildet.
    @State private var punkt = CGPoint(x: 0.5, y: 0.5)
    @State private var drar = false
    /// Zoom (1 = hele bildet) og forskyvning av det zoomede bildet.
    @State private var skala: CGFloat = 1
    @State private var forskyvning: CGSize = .zero
    @State private var knipStart: (skala: CGFloat, forskyvning: CGSize, senter: CGPoint)?
    @State private var knipIDenneBerøringen = false
    @State private var fanget: [Farge] = []
    @State private var antallKlynger = 6
    @State private var klynger: [Bildepalett.Klynge] = []
    @State private var lagre: [PalettFarge]?
    @Environment(\.modelContext) private var kontekst

    private var gjeldende: Farge? {
        guard let prøve else { return nil }
        let x = min(prøve.bredde - 1, max(0, Int(punkt.x * Double(prøve.bredde))))
        let y = min(prøve.høyde - 1, max(0, Int(punkt.y * Double(prøve.høyde))))
        return prøve.farge(x: x, y: y, radius: 2)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let bilde {
                bildeflate(bilde)
                verktøylinje
            } else {
                ContentUnavailableView {
                    Label(laster ? "Laster bilde …" : "Plukk farger fra et bilde", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Velg et foto eller skjermbilde. Fargene leses med bildets egen fargeprofil.")
                } actions: {
                    velgKnapper
                }
            }
        }
        .toolbar {
            if bilde != nil {
                ToolbarItem { Menu("Nytt bilde", systemImage: "photo.badge.plus") { velgKnapper } }
            }
        }
        .onChange(of: bildevalg) { _, valg in
            guard let valg else { return }
            Task { await last { try await valg.loadTransferable(type: Data.self) } }
        }
        .fileImporter(isPresented: $velgerFil, allowedContentTypes: [.image]) { resultat in
            guard let url = try? resultat.get() else { return }
            Task {
                await last {
                    let tilgang = url.startAccessingSecurityScopedResource()
                    defer { if tilgang { url.stopAccessingSecurityScopedResource() } }
                    return try Data(contentsOf: url)
                }
            }
        }
        .onChange(of: antallKlynger) { beregnKlynger() }
        .onChange(of: arbeidsbenk.gamut) { beregnKlynger() }
        .sheet(isPresented: Binding(get: { lagre != nil }, set: { if !$0 { lagre = nil } })) {
            VelgPalettArk(farger: lagre ?? [])
        }
    }

    @ViewBuilder private var velgKnapper: some View {
        PhotosPicker(selection: $bildevalg, matching: .images) {
            Label("Velg fra Bilder", systemImage: "photo")
        }
        Button("Velg fil …", systemImage: "folder") { velgerFil = true }
    }

    // MARK: - Bilde med lupe

    private func bildeflate(_ bilde: CGImage) -> some View {
        GeometryReader { geo in
            let ramme = tilpasset(bilde: bilde, i: geo.size)
            let vist = vistRamme(ramme)
            ZStack(alignment: .topLeading) {
                Image(decorative: bilde, scale: 1)
                    .resizable()
                    .interpolation(skala > 2 ? .none : .high)
                    .frame(width: vist.width, height: vist.height)
                    .offset(x: vist.minX, y: vist.minY)

                if let farge = gjeldende {
                    Lupe(farge: farge)
                        .position(x: vist.minX + punkt.x * vist.width, y: vist.minY + punkt.y * vist.height - (drar ? 70 : 0))
                        .animation(.snappy(duration: 0.15), value: drar)
                        .allowsHitTesting(false)
                }

                #if os(iOS)
                BildeGester(
                    vedBerøring: { p, fase in berøring(p, fase: fase, ramme: ramme) },
                    vedKnip: { skalaEndring, senter, fase in knip(skalaEndring, senter: senter, fase: fase, ramme: ramme) }
                )
                #endif
            }
            // Flaten har alltid visningens størrelse, selv når det zoomede bildet er større.
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            #if os(macOS)
            // Klikk plukker fargen der man klikker; dra flytter lupen og plukker ved slipp.
            .onTapGesture(coordinateSpace: .local) { p in
                berøring(p, fase: .start, ramme: ramme)
                berøring(p, fase: .slutt, ramme: ramme)
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { g in berøring(g.location, fase: drar ? .endret : .start, ramme: ramme) }
                    .onEnded { g in berøring(g.location, fase: .slutt, ramme: ramme) }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in knip(v.magnification, senter: v.startLocation, fase: knipStart == nil ? .start : .endret, ramme: ramme) }
                    .onEnded { v in
                        knip(v.magnification, senter: v.startLocation, fase: .slutt, ramme: ramme)
                        knipIDenneBerøringen = false  // styreflate-knip er adskilt fra klikk på Mac
                    }
            )
            #endif
            .overlay(alignment: .topTrailing) {
                if skala > 1.01 {
                    Button {
                        withAnimation(.snappy) { skala = 1; forskyvning = .zero }
                    } label: {
                        Text("\(skala, format: .number.precision(.fractionLength(1)))× · 1×")
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .accessibilityLabel("Tilbakestill zoom")
                }
            }
        }
        .clipped()
        .background(.black.opacity(0.9))
        .accessibilityLabel("Bilde. Trykk eller dra for å plukke farge, knip for å zoome.")
    }

    enum Fase { case start, endret, slutt, avbrutt }

    /// Bildets ramme på skjermen etter zoom og forskyvning.
    private func vistRamme(_ ramme: CGRect) -> CGRect {
        CGRect(x: ramme.minX + forskyvning.width, y: ramme.minY + forskyvning.height,
               width: ramme.width * skala, height: ramme.height * skala)
    }

    /// Én finger: flytt utplukkspunktet; slipp fanger fargen (ikke hvis berøringen ble et knip).
    private func berøring(_ p: CGPoint, fase: Fase, ramme: CGRect) {
        if fase == .start { knipIDenneBerøringen = false }
        guard !knipIDenneBerøringen else {
            if fase == .slutt || fase == .avbrutt { drar = false }
            return
        }
        let vist = vistRamme(ramme)
        switch fase {
        case .start, .endret:
            drar = true
            punkt = CGPoint(x: min(1, max(0, (p.x - vist.minX) / vist.width)),
                            y: min(1, max(0, (p.y - vist.minY) / vist.height)))
        case .slutt:
            // Trykk/klikk (eller slipp etter dra) fanger fargen – samme oppførsel som kameraet.
            drar = false
            if let målt = gjeldende {
                let f = arbeidsbenk.begrens(målt)
                arbeidsbenk.aktivFarge = f
                arbeidsbenk.registrerMåling(f)
                fanget.fang(f)
            }
        case .avbrutt:
            drar = false
        }
    }

    /// To fingre: zoom (1–12×) rundt knipets senter, og flytt bildet når senteret beveger seg.
    private func knip(_ skalaEndring: CGFloat, senter: CGPoint, fase: Fase, ramme: CGRect) {
        switch fase {
        case .start:
            knipIDenneBerøringen = true
            drar = false
            knipStart = (skala, forskyvning, senter)
        case .endret:
            guard let start = knipStart else { knipStart = (skala, forskyvning, senter); return }
            let ny = min(max(start.skala * skalaEndring, 1), 12)
            // Punktet i bildet som lå under knipets startsenter, skal ligge under nåværende senter.
            let qx = (start.senter.x - ramme.minX - start.forskyvning.width) / (ramme.width * start.skala)
            let qy = (start.senter.y - ramme.minY - start.forskyvning.height) / (ramme.height * start.skala)
            var ox = senter.x - ramme.minX - qx * ramme.width * ny
            var oy = senter.y - ramme.minY - qy * ramme.height * ny
            // Hold bildet innenfor rammen, så det ikke kan skyves ut av syne.
            ox = min(0, max(ramme.width - ramme.width * ny, ox))
            oy = min(0, max(ramme.height - ramme.height * ny, oy))
            skala = ny
            forskyvning = ny <= 1.001 ? .zero : CGSize(width: ox, height: oy)
        case .slutt, .avbrutt:
            knipStart = nil
        }
    }

    private func tilpasset(bilde: CGImage, i størrelse: CGSize) -> CGRect {
        let skala = min(størrelse.width / CGFloat(bilde.width), størrelse.height / CGFloat(bilde.height))
        let w = CGFloat(bilde.width) * skala, h = CGFloat(bilde.height) * skala
        return CGRect(x: (størrelse.width - w) / 2, y: (størrelse.height - h) / 2, width: w, height: h)
    }

    // MARK: - Nederste felt

    private var verktøylinje: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                FargeRute(farge: gjeldende ?? Farge(hex: "#808080")!, hjørne: 10,
                          leggIPalett: { lagre = [PalettFarge(farge: $0, opphav: .bilde)] })
                    .frame(width: 88, height: 56)
                LagreMeny(lagre: {
                    guard let f = fanget.last ?? gjeldende else { return }
                    lagreEnkeltfarger([PalettFarge(farge: arbeidsbenk.begrens(f), opphav: .bilde)], i: kontekst)
                }, leggIPalett: {
                    if let f = fanget.last ?? gjeldende { lagre = [PalettFarge(farge: arbeidsbenk.begrens(f), opphav: .bilde)] }
                })
                .font(.title2)
                .foregroundStyle(.tint)
                .help("Lagre sist fangede farge")
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(fanget.enumerated()), id: \.offset) { i, farge in
                            FargeRute(farge: farge, visTekst: false, hjørne: 6,
                                      leggIPalett: { lagre = [PalettFarge(farge: $0, opphav: .bilde)] },
                                      fjern: { if fanget.indices.contains(i) { fanget.remove(at: i) } })
                                .frame(width: 36, height: 36)
                                .onTapGesture { arbeidsbenk.aktivFarge = farge }
                        }
                    }
                }
                Button("Fang", systemImage: "plus.circle.fill") {
                    if let målt = gjeldende {
                        let f = arbeidsbenk.begrens(målt)
                        fanget.fang(f)
                        arbeidsbenk.registrerMåling(f)
                    }
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 36))
                .sensoryFeedback(.impact, trigger: fanget)
                Button("Legg alle i palett", systemImage: "square.and.arrow.down.on.square") {
                    lagre = fanget.map { PalettFarge(farge: $0, opphav: .bilde) }
                }
                .labelStyle(.iconOnly)
                .disabled(fanget.isEmpty)
            }

            HStack(spacing: 8) {
                Text("Dominerende").font(.caption).foregroundStyle(Color.sekundærTekst)
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        ForEach(klynger, id: \.self) { k in
                            Rectangle().fill(k.farge.swiftUI)
                                .frame(width: geo.size.width * k.andel)
                                .onTapGesture { arbeidsbenk.aktivFarge = k.farge }
                        }
                    }
                }
                .frame(height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Stepper("Antall: \(antallKlynger)", value: $antallKlynger, in: 2...12).labelsHidden()
                Button("Bruk som palett", systemImage: "swatchpalette") {
                    lagre = klynger.map { PalettFarge(farge: $0.farge, opphav: .bilde) }
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding()
        .background(.bar)
        .overlay(alignment: .top) { DeltaEMerke(fanget: fanget).offset(y: -44) }
    }

    // MARK: - Lasting

    private func last(_ hent: @escaping () async throws -> Data?) async {
        laster = true
        defer { laster = false }
        guard let data = try? await hent(), let resultat = await Self.dekod(data) else { return }
        bilde = resultat.bilde
        prøve = resultat.prøve
        punkt = CGPoint(x: 0.5, y: 0.5)
        skala = 1
        forskyvning = .zero
        beregnKlynger()
    }

    /// Dekoder utenfor hovedtråden, retter opp orientering og skalerer ned til maks 2048 px.
    nonisolated private static func dekod(_ data: Data) async -> (bilde: CGImage, prøve: Bildeprøve)? {
        guard let kilde = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let valg: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
        ]
        guard let bilde = CGImageSourceCreateThumbnailAtIndex(kilde, 0, valg as CFDictionary),
              let prøve = Bildeprøve(bilde: bilde)
        else { return nil }
        return (bilde, prøve)
    }

    private func beregnKlynger() {
        guard let prøve else { klynger = []; return }
        klynger = Bildepalett.dominerende(prøve.utvalg(maks: 4000), antall: antallKlynger)
            .map { Bildepalett.Klynge(farge: arbeidsbenk.begrens($0.farge), andel: $0.andel) }
    }
}

/// Forstørret fargeprøve som følger fingeren (hevet over fingeren mens man drar).
private struct Lupe: View {
    let farge: Farge

    var body: some View {
        ZStack {
            Circle().fill(farge.swiftUI)
            Circle().strokeBorder(.white, lineWidth: 3)
            Circle().strokeBorder(.black.opacity(0.25), lineWidth: 1)
            Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(farge.lesbarTekstfarge.swiftUI)
        }
        .frame(width: 56, height: 56)
        .shadow(radius: 4)
    }
}

#if os(iOS)
/// Berøringsflate for bildet: én finger (umiddelbart, uten forsinkelse) plukker farge, to fingre
/// zoomer og flytter samtidig – knipets senter følger fingrene.
private struct BildeGester: UIViewRepresentable {
    var vedBerøring: (CGPoint, BildeVisning.Fase) -> Void
    var vedKnip: (CGFloat, CGPoint, BildeVisning.Fase) -> Void

    final class Flate: UIView, UIGestureRecognizerDelegate {
        var vedBerøring: (CGPoint, BildeVisning.Fase) -> Void = { _, _ in }
        var vedKnip: (CGFloat, CGPoint, BildeVisning.Fase) -> Void = { _, _, _ in }

        @objc func berørt(_ g: UILongPressGestureRecognizer) {
            let p = g.location(in: self)
            switch g.state {
            case .began: vedBerøring(p, .start)
            case .changed: vedBerøring(p, .endret)
            case .ended: vedBerøring(p, .slutt)
            case .cancelled, .failed: vedBerøring(p, .avbrutt)
            default: break
            }
        }

        @objc func knepet(_ g: UIPinchGestureRecognizer) {
            let senter = g.location(in: self)
            switch g.state {
            case .began: vedKnip(g.scale, senter, .start)
            case .changed: vedKnip(g.scale, senter, .endret)
            case .ended: vedKnip(g.scale, senter, .slutt)
            case .cancelled, .failed: vedKnip(g.scale, senter, .avbrutt)
            default: break
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith annen: UIGestureRecognizer) -> Bool { true }
    }

    func makeUIView(context: Context) -> Flate {
        let v = Flate()
        v.backgroundColor = .clear
        let berøring = UILongPressGestureRecognizer(target: v, action: #selector(Flate.berørt(_:)))
        berøring.minimumPressDuration = 0
        berøring.allowableMovement = .greatestFiniteMagnitude
        berøring.delegate = v
        let knip = UIPinchGestureRecognizer(target: v, action: #selector(Flate.knepet(_:)))
        knip.delegate = v
        v.addGestureRecognizer(berøring)
        v.addGestureRecognizer(knip)
        return v
    }

    func updateUIView(_ v: Flate, context: Context) {
        v.vedBerøring = vedBerøring
        v.vedKnip = vedKnip
    }
}
#endif
