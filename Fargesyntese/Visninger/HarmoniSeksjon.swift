import FargeKjerne
import SwiftUI

/// Fargeharmonier rundt aktiv farge, med en liten fargesirkel som viser vinklene.
struct HarmoniSeksjon: View {
    let grunnfarge: Farge
    var velg: (Farge) -> Void
    var lagre: ([PalettFarge], String) -> Void

    @AppStorage("harmoni") private var harmoni: Harmoni = .splittKomplementær
    @AppStorage("harmoniAntall") private var antall = 3
    @AppStorage("harmoniVinkel") private var vinkel = 30.0
    @AppStorage("harmoniSirkel") private var sirkel: Fargesirkel = .okLCH

    private var farger: [Farge] {
        harmoni.farger(fra: grunnfarge, antall: antall, vinkel: harmoni.harVinkel ? vinkel : nil, sirkel: sirkel)
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

            HStack(alignment: .center, spacing: 16) {
                Fargesirkelvisning(grunnfarge: grunnfarge, farger: farger, sirkel: sirkel)
                    .frame(width: 120, height: 120)
                VStack(spacing: 4) {
                    ForEach(farger.indices, id: \.self) { i in
                        FargeRute(farge: farger[i], visTekst: true, hjørne: 6)
                            .frame(height: 30)
                            .overlay {
                                if farger[i] == grunnfarge { RoundedRectangle(cornerRadius: 6).strokeBorder(.primary, lineWidth: 2) }
                            }
                            .onTapGesture { velg(farger[i]) }
                    }
                }
            }
            .padding(.vertical, 4)

            Button("Legg harmonien i palett", systemImage: "plus.square.on.square") {
                lagre(farger.map { PalettFarge(farge: $0, opphav: .manuell) }, harmoni.navn)
            }
        } header: {
            Text("Fargeharmonier")
        } footer: {
            Text(sirkel == .okLCH
                 ? "OKLCH gir perseptuelt like vinkler og holder lyshet og metning fast, så fargene veier likt."
                 : "HSL er den tradisjonelle RGB-sirkelen, som i de fleste designverktøy.")
        }
    }
}

/// Fargesirkel med markører for harmoniens kulører.
struct Fargesirkelvisning: View {
    let grunnfarge: Farge
    let farger: [Farge]
    let sirkel: Fargesirkel

    private func kulør(_ f: Farge) -> Double { sirkel == .okLCH ? f.okLCH.h : f.hsl.h }

    var body: some View {
        Canvas { ctx, størrelse in
            let r = min(størrelse.width, størrelse.height) / 2
            let senter = CGPoint(x: størrelse.width / 2, y: størrelse.height / 2)
            // Ringen tegnes med grunnfargens lyshet/metning, slik at den viser hva harmonien faktisk gir.
            let g = grunnfarge.okLCH
            let segmenter = 72
            for i in 0..<segmenter {
                let a0 = Double(i) / Double(segmenter) * 360, a1 = Double(i + 1) / Double(segmenter) * 360
                let farge: Farge = sirkel == .okLCH
                    ? Farge(okLCH: OKLCH(l: g.l, c: max(g.c, 0.08), h: a0)).gamutKartlagt(til: .displayP3)
                    : Farge(hsl: HSL(h: a0, s: 0.85, l: 0.55))
                var sti = Path()
                sti.addArc(center: senter, radius: r * 0.78, startAngle: .degrees(a0 - 90), endAngle: .degrees(a1 - 89.5), clockwise: false)
                ctx.stroke(sti, with: .color(farge.swiftUI), lineWidth: r * 0.36)
            }
            for (i, f) in farger.enumerated() {
                let v = (kulør(f) - 90) * .pi / 180
                let p = CGPoint(x: senter.x + cos(v) * r * 0.78, y: senter.y + sin(v) * r * 0.78)
                var linje = Path()
                linje.move(to: senter)
                linje.addLine(to: p)
                ctx.stroke(linje, with: .color(.primary.opacity(0.35)), lineWidth: 1)
                let d = i == 0 ? r * 0.3 : r * 0.22
                let rute = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
                ctx.fill(Path(ellipseIn: rute), with: .color(f.swiftUI))
                ctx.stroke(Path(ellipseIn: rute), with: .color(.white), lineWidth: 2)
            }
        }
        .accessibilityLabel("Fargesirkel med \(farger.count) markerte kulører")
    }
}
