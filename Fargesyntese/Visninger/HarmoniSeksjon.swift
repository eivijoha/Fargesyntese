import FargeKjerne
import SwiftData
import SwiftUI

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
    /// Med HSL-sirkelen er det HSL-metning og -lyshet; ellers OKLCH-lyshet og metning som andel av
    /// høyeste kroma innenfor gamut (100 % = så mettet som fargen kan bli).
    @State private var metning: Double?
    @State private var lyshet: Double?

    private var råfarger: [Farge] {
        harmoni.farger(fra: grunnfarge, antall: antall, vinkel: harmoni.harVinkel ? vinkel : nil, sirkel: sirkel, gamut: gamut)
    }

    private var farger: [Farge] {
        råfarger.map { begrens(juster($0).gamutKartlagt(til: gamut)) }
    }

    private func juster(_ f: Farge) -> Farge {
        guard metning != nil || lyshet != nil else { return f }
        if sirkel == .hsl {
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

    /// Grunnfargens egne verdier, som gliderne starter på.
    private var grunnMetning: Double { sirkel == .hsl ? grunnfarge.hsl.s : relativMetning(grunnfarge) }
    private var grunnLyshet: Double { sirkel == .hsl ? grunnfarge.hsl.l : grunnfarge.okLCH.l }

    private func glider(_ tittel: LocalizedStringKey, verdi: Binding<Double?>, grunn: Double) -> some View {
        HStack(spacing: 10) {
            Text(tittel).lineLimit(1).minimumScaleFactor(0.8).frame(width: 96, alignment: .leading)
            Slider(value: Binding(get: { verdi.wrappedValue ?? grunn }, set: { verdi.wrappedValue = $0 }), in: 0...1)
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

            glider("Metning", verdi: $metning, grunn: grunnMetning)
            glider("Lyshet", verdi: $lyshet, grunn: grunnLyshet)
            if metning != nil || lyshet != nil {
                Button("Tilbakestill til grunnfargen", systemImage: "arrow.uturn.backward") {
                    metning = nil
                    lyshet = nil
                }
            }

            Fargesirkelvisning(grunnfarge: grunnfarge, farger: farger, sirkel: sirkel, velg: velg)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
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

            Button("Legg harmonien i palett", systemImage: "plus.square.on.square") {
                lagre(farger.map { PalettFarge(farge: $0, opphav: .manuell) }, harmoni.navn)
            }
        } header: {
            Text("Fargeharmonier")
        } footer: {
            Text(sirkel.forklaring + " " + String(localized: "Dra i sirkelen for å endre grunnfargens kulør. Metning og lyshet gjelder hele harmonien."))
        }
        // Gliderne betyr noe annet i HSL enn i OKLCH; start på nytt ved bytte av sirkel.
        .onChange(of: sirkel) { _, _ in metning = nil; lyshet = nil }
    }
}

/// Fargesirkel med markører for harmoniens kulører. Dra for å flytte grunnfargen rundt sirkelen.
struct Fargesirkelvisning: View {
    let grunnfarge: Farge
    let farger: [Farge]
    let sirkel: Fargesirkel
    var velg: ((Farge) -> Void)? = nil

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
                    ctx.stroke(sti, with: .color(sirkel.ringfarge(vinkel: a0, grunn: grunnfarge).swiftUI), lineWidth: r * 0.3)
                }
                for f in farger.reversed() {
                    let v = (sirkel.vinkel(for: f) - 90) * .pi / 180
                    let p = CGPoint(x: senter.x + cos(v) * r * 0.8, y: senter.y + sin(v) * r * 0.8)
                    var linje = Path()
                    linje.move(to: senter)
                    linje.addLine(to: p)
                    ctx.stroke(linje, with: .color(.primary.opacity(0.35)), lineWidth: 1)
                    let erGrunn = f == grunnfarge
                    let d = erGrunn ? r * 0.26 : r * 0.19
                    let rute = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
                    ctx.fill(Path(ellipseIn: rute), with: .color(f.swiftUI))
                    ctx.stroke(Path(ellipseIn: rute), with: .color(.white), lineWidth: erGrunn ? 3 : 2)
                }
                // Midten viser grunnfargen.
                let m = r * 0.34
                ctx.fill(Path(ellipseIn: CGRect(x: senter.x - m, y: senter.y - m, width: m * 2, height: m * 2)),
                         with: .color(grunnfarge.swiftUI))
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    guard let velg else { return }
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
        .accessibilityAdjustableAction { retning in
            let steg: Double = retning == .increment ? 15 : -15
            velg?(sirkel.farge(grunnfarge, vinkel: sirkel.vinkel(for: grunnfarge) + steg))
        }
    }
}
