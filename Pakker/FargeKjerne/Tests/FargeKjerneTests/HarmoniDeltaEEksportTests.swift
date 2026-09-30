import Foundation
import Testing
@testable import FargeKjerne

@Suite("Harmonier")
struct HarmoniTests {
    let grunn = Farge(hex: "#2F7FD8")!

    @Test func vinkler() {
        #expect(Harmoni.komplementær.forskyvninger() == [0, 180])
        #expect(Harmoni.splittKomplementær.forskyvninger(vinkel: 30) == [0, 150, 210])
        #expect(Harmoni.jevn.forskyvninger(antall: 5) == [0, 72, 144, 216, 288])
        #expect(Harmoni.analog.forskyvninger(antall: 3, vinkel: 20) == [-20, 0, 20])
        #expect(Harmoni.dobbeltKomplementær.forskyvninger(vinkel: 60) == [0, 60, 180, 240])
    }

    @Test(arguments: [3, 4, 5, 7])
    func jevnFordelingIOKLCH(antall: Int) {
        let farger = Harmoni.jevn.farger(fra: grunn, antall: antall, gamut: .displayP3)
        #expect(farger.count == antall)
        #expect(farger[0] == grunn)
        // Lyshet bevares (innenfor gamut-kartleggingens toleranse).
        #expect(farger.allSatisfy { abs($0.okLCH.l - grunn.okLCH.l) < 0.03 })
    }

    @Test func rybKunstnersirkel() {
        // I RYB er blå komplementær til oransje, og rød til grønn.
        let blå = Farge(hex: "#0000FF")!
        let motBlå = Harmoni.komplementær.farger(fra: blå, sirkel: .ryb)[1]
        #expect((25...45).contains(motBlå.hsl.h))
        let rød = Farge(hex: "#FF0000")!
        let motRød = Harmoni.komplementær.farger(fra: rød, sirkel: .ryb)[1]
        #expect((110...130).contains(motRød.hsl.h))
        // Avbildningen går begge veier.
        for h in stride(from: 0.0, to: 360, by: 17) {
            #expect(abs(RYB.fraRGBKulør(RYB.tilRGBKulør(h)) - h) < 1e-9)
        }
    }

    @Test(arguments: Fargesirkel.allCases)
    func sirkelVinkelRundtur(_ sirkel: Fargesirkel) {
        let f = Farge(hex: "#7A2E8F")!
        let flyttet = sirkel.farge(f, vinkel: sirkel.vinkel(for: f) + 90)
        let tilbake = sirkel.farge(flyttet, vinkel: sirkel.vinkel(for: flyttet) - 90)
        #expect(tilbake.deltaE2000(til: f) < 3, "\(sirkel)")
    }

    @Test func komplementærIHSL() {
        let rød = Farge(hex: "#FF0000")!
        let k = Harmoni.komplementær.farger(fra: rød, sirkel: .hsl)
        #expect(k[1].hex() == "#00FFFF")
    }
}

@Suite("ΔE2000")
struct DeltaE2000Tests {
    /// Utvalgte par fra Sharma, Wu & Dalal (2005), tabell 1.
    static let sharma: [(CIELab, CIELab, Double)] = [
        (CIELab(l: 50, a: 2.6772, b: -79.7751), CIELab(l: 50, a: 0, b: -82.7485), 2.0425),
        (CIELab(l: 50, a: 3.1571, b: -77.2803), CIELab(l: 50, a: 0, b: -82.7485), 2.8615),
        (CIELab(l: 50, a: 0, b: 0), CIELab(l: 50, a: -1, b: 2), 2.3669),
        (CIELab(l: 50, a: 2.5, b: 0), CIELab(l: 50, a: 0, b: -2.5), 4.3065),
        (CIELab(l: 50, a: 2.5, b: 0), CIELab(l: 73, a: 25, b: -18), 27.1492),
        (CIELab(l: 50, a: 2.5, b: 0), CIELab(l: 50, a: 3.1736, b: 0.5854), 1.0000),
        (CIELab(l: 60.2574, a: -34.0099, b: 36.2677), CIELab(l: 60.4626, a: -34.1751, b: 39.4387), 1.2644),
        (CIELab(l: 22.7233, a: 20.0904, b: -46.6940), CIELab(l: 23.0331, a: 14.9730, b: -42.5619), 2.0373),
    ]

    @Test func sharmaDatasett() {
        for (a, b, fasit) in Self.sharma {
            let d = Fargeavstand.deltaE2000(a, b)
            #expect(abs(d - fasit) < 1e-4, "\(a) / \(b): \(d) ≠ \(fasit)")
            #expect(abs(Fargeavstand.deltaE2000(b, a) - d) < 1e-9)  // symmetrisk
        }
    }

    @Test func likeFargerGirNull() {
        let f = Farge(hex: "#6B8F71")!
        #expect(f.deltaE2000(til: f) < 1e-9)
        #expect(Fargeavstand.tolkning(0.5) == "Ikke merkbar")
    }
}

@Suite("Eksport til Adobe, Figma og CSS")
struct NyEksportTests {
    let palett = Palett(navn: "Fjord", farger: [
        PalettFarge(navn: "Fjordblå", farge: Farge(hex: "#1B3A6B")!),
        PalettFarge(navn: "P3-grønn", farge: Farge(displayP3: DisplayP3(r: 0, g: 1, b: 0))),
    ])

    @Test func aco() {
        let d = [UInt8](Eksportformat.aco.data(for: palett))
        #expect(d[0...3] == [0, 1, 0, 2])            // versjon 1, 2 farger
        #expect(d[4...5] == [0, 0])                  // første farge: RGB
        #expect(d[14...15] == [0, 7])                // andre farge: Lab (utenfor sRGB)
        let v2 = 4 + 2 * 10
        #expect(d[v2...(v2 + 3)] == [0, 2, 0, 2])    // versjon 2, 2 farger
        // Navnelengde (UInt32) = 8 tegn + null
        #expect(d[(v2 + 14)...(v2 + 17)] == [0, 0, 0, 9])
    }

    @Test func figmaVariabler() throws {
        let json = try JSONSerialization.jsonObject(with: Eksportformat.figmaVariabler.data(for: palett)) as? [String: Any]
        let samling = try #require(json?["fjord"] as? [String: Any])
        let blå = try #require(samling["fjordbla"] as? [String: Any])
        #expect(blå["$type"] as? String == "color")
        let verdi = try #require(blå["$value"] as? [String: Any])
        #expect(verdi["colorSpace"] as? String == "srgb")
        #expect(verdi["hex"] as? String == "#1B3A6B")
    }

    @Test func svg() {
        let svg = String(decoding: Eksportformat.svg.data(for: palett), as: UTF8.self)
        #expect(svg.hasPrefix("<svg"))
        #expect(svg.contains("id=\"fjordbla\"") && svg.contains("fill=\"#1B3A6B\""))
    }

    @Test func cssGradient() {
        let g = CSSGradient(farger: [Farge(hex: "#1B3A6B")!, Farge(hex: "#F2B84B")!])
        #expect(g.moderne.hasPrefix("linear-gradient(in oklab 90deg, oklch("))
        #expect(g.reserve.hasPrefix("linear-gradient(90deg, #1B3A6B 0%"))
        #expect(g.reserve.hasSuffix("#F2B84B 100%)"))
        #expect(g.reserve.components(separatedBy: "%").count - 1 == 9)
        let trinn = CSSGradient(farger: [Farge(hex: "#000000")!, Farge(hex: "#FFFFFF")!], form: .konisk, trinnvis: true)
        #expect(trinn.moderne == "conic-gradient(from 90deg, oklch(0.000 0.000 0.0) 0% 50%, oklch(1.000 0.000 0.0) 50% 100%)")
    }
}
