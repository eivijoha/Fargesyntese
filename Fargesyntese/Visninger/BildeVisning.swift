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
    @State private var fanget: [Farge] = []
    @State private var antallKlynger = 6
    @State private var klynger: [Bildepalett.Klynge] = []
    @State private var lagre: [PalettFarge]?
    @State private var lagret = false
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
            ZStack(alignment: .topLeading) {
                Image(decorative: bilde, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: ramme.width, height: ramme.height)
                    .offset(x: ramme.minX, y: ramme.minY)

                if let farge = gjeldende {
                    Lupe(farge: farge)
                        .position(x: ramme.minX + punkt.x * ramme.width, y: ramme.minY + punkt.y * ramme.height - (drar ? 70 : 0))
                        .animation(.snappy(duration: 0.15), value: drar)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        drar = true
                        punkt = CGPoint(x: min(1, max(0, (g.location.x - ramme.minX) / ramme.width)),
                                        y: min(1, max(0, (g.location.y - ramme.minY) / ramme.height)))
                    }
                    .onEnded { _ in
                        // Trykk/klikk (eller slipp etter dra) fanger fargen – samme oppførsel som kameraet.
                        drar = false
                        if let målt = gjeldende {
                            let f = arbeidsbenk.begrens(målt)
                            arbeidsbenk.aktivFarge = f
                            arbeidsbenk.registrerMåling(f)
                            fanget.fang(f)
                        }
                    }
            )
        }
        .clipped()
        .background(.black.opacity(0.9))
        .accessibilityLabel("Bilde. Trykk eller dra for å plukke farge.")
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
                VStack(spacing: 10) {
                    Button("Lagre som enkeltfarge", systemImage: lagret ? "bookmark.fill" : "bookmark") {
                        guard let f = fanget.last ?? gjeldende else { return }
                        lagreEnkeltfarger([PalettFarge(farge: arbeidsbenk.begrens(f), opphav: .bilde)], i: kontekst)
                        lagret = true
                        Task { try? await Task.sleep(for: .seconds(1.5)); lagret = false }
                    }
                    .sensoryFeedback(.success, trigger: lagret) { _, ny in ny }
                    .help("Lagre sist fangede farge som enkeltfarge")
                    Button("Legg i palett", systemImage: "plus.square.on.square") {
                        if let f = fanget.last ?? gjeldende { lagre = [PalettFarge(farge: arbeidsbenk.begrens(f), opphav: .bilde)] }
                    }
                    .help("Legg sist fangede farge i en palett")
                }
                .labelStyle(.iconOnly)
                .font(.title3)
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
                Text("Dominerende").font(.caption).foregroundStyle(.secondary)
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
