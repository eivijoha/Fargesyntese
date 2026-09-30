import Foundation
import Testing
@testable import FargeKI
@testable import FargeKjerne

private func nær(_ a: Double, _ b: Double, _ tol: Double = 1e-3) -> Bool { abs(a - b) <= tol }

@Suite("Fargerom")
struct FargeromTests {
    let rød = Farge(hex: "#FF0000")!

    @Test func p3Hex() {
        #expect(Farge(hex: "#FFFFFF")!.p3Hex() == "#FFFFFF")
        #expect(Farge(displayP3: DisplayP3(r: 1, g: 0, b: 0)).p3Hex() == "#FF0000")
        #expect(Farge(hex: "#FF0000")!.p3Hex() == "#EA3323")  // sRGB-rød uttrykt i P3
    }

    @Test func hexRundtur() {
        #expect(rød.hex() == "#FF0000")
        #expect(Farge(hex: "0af")!.hex() == "#00AAFF")
        #expect(Farge(hex: "#11223380")!.hex(medAlfa: true) == "#11223380")
        #expect(Farge(hex: "xyz") == nil)
    }

    /// Referanseverdier fra CSS Color 4 / Ottosson.
    @Test func okLabReferanse() {
        let lab = rød.okLab
        #expect(nær(lab.l, 0.62796, 1e-4))
        #expect(nær(lab.a, 0.22486, 1e-4))
        #expect(nær(lab.b, 0.12585, 1e-4))
        let hvit = Farge(hex: "#FFFFFF")!.okLab
        #expect(nær(hvit.l, 1, 1e-4) && nær(hvit.a, 0, 1e-4) && nær(hvit.b, 0, 1e-4))
    }

    @Test func cieLabD50Referanse() {
        let lab = rød.cieLab
        #expect(nær(lab.l, 54.29, 0.05))
        #expect(nær(lab.a, 80.80, 0.1))
        #expect(nær(lab.b, 69.89, 0.1))
        let hvit = Farge(hex: "#FFFFFF")!.cieLab
        #expect(nær(hvit.l, 100, 1e-3) && nær(hvit.a, 0, 1e-3) && nær(hvit.b, 0, 1e-3))
    }

    @Test func displayP3() {
        let p3Rød = Farge(displayP3: DisplayP3(r: 1, g: 0, b: 0))
        #expect(!p3Rød.erISRGB)
        #expect(p3Rød.erIDisplayP3)
        let s = p3Rød.sRGB
        #expect(nær(s.r, 1.0931, 1e-3) && nær(s.g, -0.2267, 1e-3) && nær(s.b, -0.1501, 1e-3))
        let hvit = Farge(displayP3: DisplayP3(r: 1, g: 1, b: 1)).sRGB
        #expect(nær(hvit.r, 1, 1e-6) && nær(hvit.g, 1, 1e-6) && nær(hvit.b, 1, 1e-6))
    }

    @Test(arguments: Fargemodell.allCases)
    func rundturAlleModeller(_ modell: Fargemodell) {
        for hex in ["#3366CC", "#E8A33D", "#1B1B1B", "#F2F2F2", "#7A2E8F"] {
            let f = Farge(hex: hex)!
            let tilbake = modell.farge(fra: modell.verdier(for: f))
            #expect(tilbake.avstandOK(til: f) < 1e-6, "\(modell.navn) \(hex)")
        }
    }

    @Test func hsbOgHsl() {
        let hsb = rød.hsb
        #expect(nær(hsb.h, 0) && nær(hsb.s, 1) && nær(hsb.b, 1))
        let hsl = Farge(hex: "#3366CC")!.hsl
        #expect(nær(hsl.h, 220) && nær(hsl.s, 0.6) && nær(hsl.l, 0.5))
    }

    @Test func gamutKartlegging() {
        let utenfor = Farge(okLCH: OKLCH(l: 0.7, c: 0.35, h: 150))
        #expect(!utenfor.erISRGB)
        let kartlagt = utenfor.gamutKartlagt(til: .sRGB)
        #expect(kartlagt.klippet(til: .sRGB).avstandOK(til: kartlagt) < 1e-9)
        #expect(nær(kartlagt.okLCH.l, 0.7, 0.02))
    }

    @Test func kontrast() {
        let hvit = Farge(hex: "#FFFFFF")!, sort = Farge(hex: "#000000")!
        #expect(nær(hvit.wcagKontrast(mot: sort), 21, 1e-6))
        #expect(Farge(hex: "#FFFF00")!.lesbarTekstfarge == sort)
    }
}

@Suite("Paletter")
struct PalettTests {
    @Test func overgangLikeSteg() {
        let a = Farge(hex: "#0033AA")!, b = Farge(hex: "#FFCC00")!
        let toner = Overgang.toner(fra: a, til: b, antall: 7)
        #expect(toner.count == 7)
        #expect(toner.first!.avstandOK(til: a) < 1e-9 && toner.last!.avstandOK(til: b) < 1e-9)
        let avstander = zip(toner, toner.dropFirst()).map { $0.avstandOK(til: $1) }
        #expect(avstander.allSatisfy { nær($0, avstander[0], 1e-6) })
    }

    @Test func flerpunktsOvergang() {
        let nøkler = ["#FF0000", "#00FF00", "#0000FF"].compactMap { Farge(hex: $0) }
        #expect(Overgang.toner(gjennom: nøkler, stegMellom: 3).count == 9)
    }

    @Test func toneskalaErMonotonOgInnenforGamut() {
        let toner = Toneskala(gamut: .sRGB).toner(for: Farge(hex: "#2F7FD8")!)
        #expect(toner.count == 11)
        #expect(toner.allSatisfy { $0.erISRGB })
        let l = toner.map(\.okLCH.l)
        #expect(zip(l, l.dropFirst()).allSatisfy { $0 > $1 })
    }

    @Test func aseHarRiktigHode() {
        let p = Palett(navn: "Test", farger: [PalettFarge(navn: "Rød", farge: Farge(hex: "#FF0000")!)])
        let d = Eksportformat.ase.data(for: p)
        #expect(d.prefix(4) == Data("ASEF".utf8))
        #expect(d[11] == 3)  // gruppestart + farge + gruppeslutt
    }

    @Test func cssIdentifikatorer() {
        let p = Palett(navn: "Fjord", farger: [
            PalettFarge(navn: "Blå hav", farge: Farge(hex: "#113355")!),
            PalettFarge(navn: "Blå hav", farge: Farge(hex: "#224466")!),
            PalettFarge(navn: "Grønn Ø", farge: Farge(hex: "#224466")!),
        ])
        let css = String(decoding: Eksportformat.css.data(for: p), as: UTF8.self)
        #expect(css.contains("--bla-hav: #113355;"))
        #expect(css.contains("--bla-hav-2: #224466;"))
        #expect(css.contains("--gronn-o:"))
    }

    #if canImport(CoreGraphics)
    @Test func iccCMYK() throws {
        let cmyk = try #require(Farge(hex: "#FFFFFF")!.komponenter(i: .genericCMYK))
        #expect(cmyk.count == 4)
        #expect(cmyk.allSatisfy { $0 < 0.05 })
    }
    #endif
}

@Suite("Verdiord")
struct VerdiordTests {
    @Test func leksikonGirForslag() async throws {
        let f = try await LeksikonTolker().forslag(for: "trygg, varm og nordisk", antall: 5)
        #expect(f.farger.count == 5)
        #expect(f.farger.allSatisfy { $0.farge.erIDisplayP3 })
    }
}
