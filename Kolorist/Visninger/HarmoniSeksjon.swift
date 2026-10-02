import FargeKjerne
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Fargeharmonier rundt aktiv farge, med en liten fargesirkel som viser vinklene.
struct HarmoniSeksjon: View {
    let grunnfarge: Farge
    var gamut: Gamut = .displayP3
    var begrens: (Farge) -> Farge = { $0 }
    var velg: (Farge) -> Void
    var lagre: ([PalettFarge], String) -> Void

    @Environment(\.modelContext) private var kontekst
    @AppStorage("harmoni") private var harmoni: Harmoni = .splittKomplementær
    @AppStorage("harmoniAntall") private var antall = 3
    @AppStorage("harmoniVinkel") private var vinkel = 30.0
    @AppStorage("harmoniSirkel") private var sirkel: Fargesirkel = .okLCH

    /// Felles metning og lyshet for hele harmonien (0…1), som i HSL. `nil` = følg hver farge.
    /// Med HSL- og RYB-sirkelen er det HSL-metning og -lyshet; ellers OKLCH-lyshet og metning som andel av
    /// høyeste kroma innenfor gamut (100 % = så mettet som fargen kan bli).
    @State private var metning: Double?
    @State private var lyshet: Double?
    /// Ark for å velge grunnfarge blant lagrede farger og paletter (trykk i midten av sirkelen).
    @State private var velgerGrunnfarge = false
    #if SIRKELEKSPORT
    /// Midlertidig: eksport av fargesirkelen som vektor (SVG/PDF) til arbeidet med app-ikonet.
    @State private var sirkeleksport: (data: Data, type: UTType, navn: String)?
    #endif

    private var råfarger: [Farge] {
        harmoni.farger(fra: grunnfarge, antall: antall, vinkel: harmoni.harVinkel ? vinkel : nil, sirkel: sirkel, gamut: gamut)
    }

    /// Harmoniens eksakte vinkler i sirkelen, i samme rekkefølge som fargene. Markørene tegnes her, ikke på
    /// fargenes målte kulør: gamut-kartlegging og metning/lyshet flytter kuløren noen grader, så markørene
    /// ellers ble ujevnt fordelt.
    private var vinkler: [Double] {
        let basis = sirkel.vinkel(for: grunnfarge)
        return harmoni.forskyvninger(antall: antall, vinkel: harmoni.harVinkel ? vinkel : nil).map { basis + $0 }
    }

    /// Plassen til grunnfargen blant fargene (i midten for analog).
    private var grunnIndeks: Int? {
        harmoni.forskyvninger(antall: antall, vinkel: harmoni.harVinkel ? vinkel : nil).firstIndex(of: 0)
    }

    private var farger: [Farge] {
        råfarger.map { begrens(juster($0).gamutKartlagt(til: gamut)) }
    }

    private func juster(_ f: Farge) -> Farge {
        guard metning != nil || lyshet != nil else { return f }
        if sirkel == .hsl || sirkel == .ryb {
            var h = f.hsl
            if let metning { h.s = metning }
            if let lyshet { h.l = lyshet }
            return Farge(hsl: h, alfa: f.alfa)
        }
        let lch = f.okLCH
        let l = lyshet ?? lch.l
        let andel = metning ?? relativMetning(f)
        return Farge(okLCH: OKLCH(l: l, c: andel * Farge.maksKroma(lyshet: l, kulør: lch.h, i: gamut), h: lch.h), alfa: f.alfa)
    }

    private func relativMetning(_ f: Farge) -> Double {
        let lch = f.okLCH
        let maks = Farge.maksKroma(lyshet: lch.l, kulør: lch.h, i: gamut)
        return maks > 0 ? min(lch.c / maks, 1) : 0
    }

    /// Fargen i ringen ved en vinkel, med gjeldende metning og lyshet (grunnfargens når gliderne ikke er rørt).
    private func ringfarge(vinkel: Double) -> Farge {
        let f = sirkel.farge(grunnfarge, vinkel: vinkel, gamut: gamut)
        let m = metning ?? grunnMetning, l = lyshet ?? grunnLyshet
        if sirkel == .hsl || sirkel == .ryb {
            var h = f.hsl
            h.s = m
            h.l = l
            return Farge(hsl: h)
        }
        let h = f.okLCH.h
        return Farge(okLCH: OKLCH(l: l, c: m * Farge.maksKroma(lyshet: l, kulør: h, i: gamut), h: h)).gamutKartlagt(til: gamut)
    }

    #if SIRKELEKSPORT
    private func eksporterSirkel(svg: Bool) {
        let tegning = Fargesirkeltegning(grunnfarge: grunnfarge, farger: farger, sirkel: sirkel, vinkler: vinkler, grunnIndeks: grunnIndeks,
                                         ringfarge: { ringfarge(vinkel: $0) },
                                         midtfarge: juster(grunnfarge).gamutKartlagt(til: gamut))
        sirkeleksport = svg ? (Data(tegning.svg.utf8), .svg, "Fargesirkel.svg") : (tegning.pdf, .pdf, "Fargesirkel.pdf")
    }
    #endif

    /// Grunnfargens egne verdier, som gliderne starter på.
    private var brukerHSL: Bool { sirkel == .hsl || sirkel == .ryb }
    private var grunnMetning: Double { brukerHSL ? grunnfarge.hsl.s : relativMetning(grunnfarge) }
    private var grunnLyshet: Double { brukerHSL ? grunnfarge.hsl.l : grunnfarge.okLCH.l }

    /// Grunnfargen med gitt metning og lyshet (samme regler som harmonien).
    private func grunnfarge(metning m: Double, lyshet l: Double) -> Farge {
        if brukerHSL {
            var h = grunnfarge.hsl
            h.s = m
            h.l = l
            return Farge(hsl: h)
        }
        let h = grunnfarge.okLCH.h
        return Farge(okLCH: OKLCH(l: l, c: m * Farge.maksKroma(lyshet: l, kulør: h, i: gamut), h: h))
    }

    /// Sporfarger: grunnfargen langs gliderens akse, med den andre verdien som den er.
    private func spor(metningsakse: Bool) -> [Color] {
        let m = metning ?? grunnMetning, l = lyshet ?? grunnLyshet
        return (0..<24).map { n in
            let t = Double(n) / 23
            return grunnfarge(metning: metningsakse ? t : m, lyshet: metningsakse ? l : t).swiftUI
        }
    }

    private func glider(_ tittel: LocalizedStringKey, verdi: Binding<Double?>, grunn: Double, metningsakse: Bool) -> some View {
        let gjeldende = verdi.wrappedValue ?? grunn
        return HStack(spacing: 10) {
            Text(tittel).lineLimit(1).minimumScaleFactor(0.8).frame(width: 96, alignment: .leading)
            FargeGlider(verdi: Binding(get: { gjeldende }, set: { ny in
                // Lås den andre verdien der den er: grunnfargen oppdateres underveis (og kan begrenses
                // av valgt profil), og en verdi som «følger grunnfargen» ville da krype.
                if metning == nil { metning = grunnMetning }
                if lyshet == nil { lyshet = grunnLyshet }
                verdi.wrappedValue = ny
            }), område: 0...1,
                        spor: spor(metningsakse: metningsakse),
                        gjeldende: grunnfarge(metning: metning ?? grunnMetning, lyshet: lyshet ?? grunnLyshet).swiftUI,
                        tittel: Text(tittel),
                        verdiTekst: gjeldende.formatted(.percent.precision(.fractionLength(0))),
                        stegForTilgjengelighet: 0.05)
            Text(verdi.wrappedValue ?? grunn, format: .percent.precision(.fractionLength(0)))
                .font(.callout.monospacedDigit())
                .foregroundStyle(Color.sekundærTekst)
                .frame(width: 48, alignment: .trailing)
        }
    }

    var body: some View {
        Section {
            Picker("Harmoni", selection: $harmoni) {
                ForEach(Harmoni.allCases) { Text($0.navn).tag($0) }
            }
            .onChange(of: harmoni) { _, ny in if ny.harVinkel { vinkel = ny.standardVinkel } }

            if harmoni.harAntall {
                Stepper("Antall farger: \(antall)", value: $antall, in: harmoni == .jevn ? 2...12 : 2...9)
            }
            if harmoni.harVinkel {
                HStack {
                    Text("Vinkel")
                    Slider(value: $vinkel, in: 5...90, step: 1)
                    Text("\(Int(vinkel))°").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
            Picker("Fargesirkel", selection: $sirkel) {
                ForEach(Fargesirkel.allCases) { Text($0.navn).tag($0) }
            }

            // Fargeprøvene over fargesirkelen, så resultatet sees før detaljene.
            HStack(spacing: 4) {
                ForEach(Array(farger.enumerated()), id: \.offset) { i, farge in
                    FargeRute(farge: farge, visTekst: false, hjørne: 6,
                              lagre: { lagreEnkeltfarger([PalettFarge(farge: $0)], i: kontekst) },
                              leggIPalett: { lagre([PalettFarge(farge: $0)], "") },
                              valgBoble: true)
                        .frame(height: 44)
                        .overlay {
                            // Rammen markerer harmoniens grunnfarge, også når metning/lyshet er justert.
                            if råfarger.indices.contains(i), råfarger[i] == grunnfarge {
                                RoundedRectangle(cornerRadius: 6).strokeBorder(.primary, lineWidth: 2)
                            }
                        }
                        .onTapGesture { velg(farge) }
                }
            }

            // Ringen og midten tegnes med gjeldende metning og lyshet, så gliderne under virker direkte på sirkelen.
            Fargesirkelvisning(grunnfarge: grunnfarge, farger: farger, sirkel: sirkel, vinkler: vinkler, grunnIndeks: grunnIndeks,
                               velg: velg, ringfarge: { ringfarge(vinkel: $0) }, midtfarge: juster(grunnfarge).gamutKartlagt(til: gamut),
                               vedMidttrykk: { velgerGrunnfarge = true })
                .sheet(isPresented: $velgerGrunnfarge) {
                    LagretFargeArk(tittel: String(localized: "Grunnfarge")) { f in
                        // Start harmonien fra den valgte fargen som den er.
                        metning = nil
                        lyshet = nil
                        velg(f)
                    }
                }
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            #if SIRKELEKSPORT
            Menu("Eksporter sirkelen (midlertidig)", systemImage: "square.and.arrow.up") {
                Button("SVG") { eksporterSirkel(svg: true) }
                Button("PDF (Display P3)") { eksporterSirkel(svg: false) }
            }
            #endif
            glider("Metning", verdi: $metning, grunn: grunnMetning, metningsakse: true)
            glider("Lyshet", verdi: $lyshet, grunn: grunnLyshet, metningsakse: false)
            if metning != nil || lyshet != nil {
                Button("Tilbakestill til grunnfargen", systemImage: "arrow.uturn.backward") {
                    metning = nil
                    lyshet = nil
                }
            }
            Button("Legg harmonien i palett", systemImage: "plus.square.on.square") {
                lagre(farger.map { PalettFarge(farge: $0, opphav: .manuell) }, harmoni.navn)
            }
            KopierTilMeny(farger: farger.map { PalettFarge(farge: $0, opphav: .manuell) }, navn: harmoni.navn)
        } header: {
            Text("Fargeharmonier")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(sirkel.forklaring + " " + String(localized: "Dra i sirkelen for å endre grunnfargens kulør, eller trykk i midten for å starte fra en lagret farge. Metning og lyshet gjelder hele harmonien."))
                MetodeHenvisning(.harmonier, .oklab, .cieLab)
            }
        }
        #if SIRKELEKSPORT
        .fileExporter(isPresented: Binding(get: { sirkeleksport != nil }, set: { if !$0 { sirkeleksport = nil } }),
                      document: EksportDokument(data: sirkeleksport?.data ?? Data()),
                      contentType: sirkeleksport?.type ?? .data,
                      defaultFilename: sirkeleksport?.navn) { _ in }
        #endif
        // Gliderne betyr noe annet i HSL enn i OKLCH; start på nytt ved bytte av sirkel.
        .onChange(of: sirkel) { _, _ in metning = nil; lyshet = nil }
        // Primærfargen (grunnfargen med gjeldende metning/lyshet) blir aktiv farge, så den vises i
        // fargefeltet øverst. Justeringen er idempotent, så den nye grunnfargen gir samme harmoni.
        .onChange(of: metning) { _, _ in velg(juster(grunnfarge).gamutKartlagt(til: gamut)) }
        .onChange(of: lyshet) { _, _ in velg(juster(grunnfarge).gamutKartlagt(til: gamut)) }
    }
}

/// Fargesirkel med markører for harmoniens kulører. Dra for å flytte grunnfargen rundt sirkelen.
struct Fargesirkelvisning: View {
    let grunnfarge: Farge
    let farger: [Farge]
    let sirkel: Fargesirkel
    /// Markørenes vinkler, i samme rekkefølge som `farger`. Uten dem brukes fargenes målte kulør.
    var vinkler: [Double]? = nil
    /// Hvilken av fargene som er grunnfargen (større markør). Uten den sammenlignes med midtfargen.
    var grunnIndeks: Int? = nil
    var velg: ((Farge) -> Void)? = nil
    /// Ringens farge ved en vinkel; standard er sirkelens egen ringfarge.
    var ringfarge: ((Double) -> Farge)? = nil
    /// Fargen i midten; standard er grunnfargen.
    var midtfarge: Farge? = nil
    /// Trykk på midten (f.eks. velg grunnfarge blant lagrede farger).
    var vedMidttrykk: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let senter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            Canvas { ctx, _ in
                let r = side / 2
                let segmenter = 120
                for i in 0..<segmenter {
                    let a0 = Double(i) / Double(segmenter) * 360, a1 = Double(i + 1) / Double(segmenter) * 360
                    var sti = Path()
                    sti.addArc(center: senter, radius: r * 0.8, startAngle: .degrees(a0 - 90), endAngle: .degrees(a1 - 89.5), clockwise: false)
                    ctx.stroke(sti, with: .color((ringfarge?(a0) ?? sirkel.ringfarge(vinkel: a0, grunn: grunnfarge)).swiftUI), lineWidth: r * 0.3)
                }
                for i in farger.indices.reversed() {
                    let f = farger[i]
                    let vinkel = vinkler.flatMap { i < $0.count ? $0[i] : nil } ?? sirkel.vinkel(for: f)
                    let v = (vinkel - 90) * .pi / 180
                    let p = CGPoint(x: senter.x + cos(v) * r * 0.8, y: senter.y + sin(v) * r * 0.8)
                    var linje = Path()
                    linje.move(to: senter)
                    linje.addLine(to: p)
                    ctx.stroke(linje, with: .color(.primary.opacity(0.35)), lineWidth: 1)
                    let erGrunn = grunnIndeks.map { $0 == i } ?? (f == (midtfarge ?? grunnfarge))
                    let d = erGrunn ? r * 0.26 : r * 0.19
                    let rute = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
                    ctx.fill(Path(ellipseIn: rute), with: .color(f.swiftUI))
                    ctx.stroke(Path(ellipseIn: rute), with: .color(.white), lineWidth: erGrunn ? 3 : 2)
                }
                // Midten viser grunnfargen.
                let m = r * 0.34
                ctx.fill(Path(ellipseIn: CGRect(x: senter.x - m, y: senter.y - m, width: m * 2, height: m * 2)),
                         with: .color((midtfarge ?? grunnfarge).swiftUI))
            }
            .contentShape(Circle())
            .overlay {
                // Midten er en egen knapp: velg grunnfarge blant lagrede farger.
                if let vedMidttrykk {
                    Button(action: vedMidttrykk) {
                        Circle().fill(.clear).contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: side * 0.34, height: side * 0.34)
                    .position(senter)
                    .help("Velg grunnfarge fra lagrede farger")
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    guard let velg else { return }
                    // Dra som starter i midten, flytter ikke kuløren (midten er en knapp).
                    guard hypot(g.startLocation.x - senter.x, g.startLocation.y - senter.y) > side * 0.17 else { return }
                    let dx = g.location.x - senter.x, dy = g.location.y - senter.y
                    guard hypot(dx, dy) > side * 0.15 else { return }
                    let vinkel = atan2(dy, dx) * 180 / .pi + 90
                    velg(sirkel.farge(grunnfarge, vinkel: vinkel))
                }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("\(sirkel.navn) fargesirkel med \(farger.count) markerte kulører")
        .accessibilityValue("Grunnfarge \(Int(sirkel.vinkel(for: grunnfarge))) grader")
        .accessibilityAction(named: "Velg grunnfarge fra lagrede farger") { vedMidttrykk?() }
        .accessibilityAdjustableAction { retning in
            let steg: Double = retning == .increment ? 15 : -15
            velg?(sirkel.farge(grunnfarge, vinkel: sirkel.vinkel(for: grunnfarge) + steg))
        }
    }
}
