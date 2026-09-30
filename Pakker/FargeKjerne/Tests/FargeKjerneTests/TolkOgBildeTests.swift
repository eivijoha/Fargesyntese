import Foundation
import Testing
@testable import FargeKjerne

#if canImport(CoreGraphics)
import CoreGraphics
#endif

@Suite("Fargetolk")
struct FargetolkTests {
    private func lik(_ tekst: String, _ hex: String, tol: Double = 0.004) -> Bool {
        guard let f = Fargetolk.tolk(tekst), let fasit = Farge(hex: hex) else { return false }
        return f.avstandOK(til: fasit) < tol
    }

    @Test func cssSyntakser() {
        #expect(lik("#2f7fd8", "#2F7FD8"))
        #expect(lik("  2F7FD8 ", "#2F7FD8"))
        #expect(lik("rgb(255 0 0)", "#FF0000"))
        #expect(lik("rgb(255, 0, 0)", "#FF0000"))
        #expect(lik("rgba(255, 0, 0, 0.5)", "#FF0000"))
        #expect(Fargetolk.tolk("rgba(255, 0, 0, 0.5)")?.alfa == 0.5)
        #expect(lik("rgb(100% 0% 0% / 50%)", "#FF0000"))
        #expect(lik("hsl(120deg 100% 25%)", "#008000"))
        #expect(lik("hsl(0.5turn 100% 50%)", "#00FFFF"))
        #expect(lik("hwb(0 0% 0%)", "#FF0000"))
        #expect(lik("lab(54.29 80.8 69.89)", "#FF0000"))
        #expect(lik("lch(54.29% 106.8 40.85)", "#FF0000"))
        #expect(lik("oklab(0.628 0.2249 0.1258)", "#FF0000"))
        #expect(lik("oklch(62.8% 0.2577 29.23)", "#FF0000"))
        #expect(lik("color(srgb 1 0 0)", "#FF0000"))
        #expect(lik("color(display-p3 0.9176 0.2003 0.1386)", "#FF0000"))
        #expect(lik("rebeccapurple", "#663399"))
        #expect(lik("--merkevare: oklch(0.593 0.156 253.9);", "#2F7FD8"))
        #expect(Fargetolk.tolk("oklch(banan)") == nil)
        #expect(Fargetolk.tolk("tull") == nil)
    }

    @Test(arguments: Fargemodell.allCases)
    func eksportertTekstKanLesesTilbake(_ modell: Fargemodell) throws {
        for hex in ["#3366CC", "#E8A33D", "#1B1B1B", "#7A2E8F"] {
            let f = Farge(hex: hex)!
            let tekst = modell.tekst(for: f)
            let tilbake = try #require(Fargetolk.tolk(tekst), "\(tekst)")
            #expect(tilbake.avstandOK(til: f) < 0.005, "\(tekst)")
        }
    }

    @Test func liste() {
        let tekst = """
        Fjordblå\t#1B3A6B
        --sand: #F2B84B;
        oklch(0.7 0.1 150)

        ingen farge her
        """
        let farger = Fargetolk.tolkListe(tekst)
        #expect(farger.map(\.navn) == ["Fjordblå", "sand", ""])
        #expect(farger[0].farge.hex() == "#1B3A6B")
    }
}

#if canImport(CoreGraphics)
@Suite("ICC og bilder")
struct ICCOgBildeTests {
    @Test func profilbeskrivelse() throws {
        let data = try #require(CGColorSpace(name: CGColorSpace.sRGB)?.copyICCData() as Data?)
        let profil = try #require(ICCProfil(data: data))
        #expect(profil.navn.localizedCaseInsensitiveContains("sRGB"))
        #expect(profil.id == ICCProfil(data: data)?.id)  // stabil id
        #expect(profil.komponentnavn == ["R", "G", "B"])
    }

    @Test func trykkgamut() throws {
        let p3Grønn = Farge(displayP3: DisplayP3(r: 0, g: 1, b: 0))
        let grå = Farge(hex: "#808080")!
        #expect(try #require(p3Grønn.avvik(i: .genericCMYK)) > 0.02)
        #expect(try #require(grå.avvik(i: .genericCMYK)) < 0.02)
    }

    @Test func bildeprøveLeserRiktigRadOgFarge() throws {
        let rom = CGColorSpace(name: CGColorSpace.sRGB)!
        let k = try #require(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
                                       space: rom, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        k.setFillColor(CGColor(colorSpace: rom, components: [0, 0, 1, 1])!)
        k.fill(CGRect(x: 0, y: 0, width: 4, height: 2))  // nederst i CG = nederst i bildet
        k.setFillColor(CGColor(colorSpace: rom, components: [1, 0, 0, 1])!)
        k.fill(CGRect(x: 0, y: 2, width: 4, height: 2))
        let bilde = try #require(k.makeImage())
        let prøve = try #require(Bildeprøve(bilde: bilde))

        #expect(prøve.farge(x: 1, y: 0).avstandOK(til: Farge(hex: "#FF0000")!) < 1e-3)
        #expect(prøve.farge(x: 1, y: 3, radius: 1).avstandOK(til: Farge(hex: "#0000FF")!) < 1e-3)

        let klynger = Bildepalett.dominerende(prøve.utvalg(), antall: 2)
        #expect(klynger.count == 2)
        #expect(abs(klynger[0].andel - 0.5) < 0.01)
    }

    @Test func kMeansErDeterministisk() {
        let farger = (0..<300).map { i in Farge(okLCH: OKLCH(l: 0.3 + Double(i % 3) * 0.25, c: 0.1, h: Double(i % 3) * 120)) }
        let a = Bildepalett.dominerende(farger, antall: 3)
        let b = Bildepalett.dominerende(farger, antall: 3)
        #expect(a == b)
        #expect(a.allSatisfy { abs($0.andel - 1.0 / 3) < 1e-9 })
    }
}
#endif
