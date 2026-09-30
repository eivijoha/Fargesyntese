import Foundation
import Testing
@testable import FargeKI
@testable import FargeKjerne

/// Oppslag i pakkens strengkatalog, så testene virker uansett språk på maskinen.
private func lok(_ nøkkel: String.LocalizationValue) -> String { String(localized: nøkkel, bundle: Ressurser.pakke) }

private func nær(_ a: Double, _ b: Double, _ tol: Double = 1e-6) -> Bool { abs(a - b) <= tol }

@Suite("Lyshetstrinn")
struct LyshetstrinnTests {
    @Test func fasteStegHverRetningForSeg() {
        let t = Lyshetstrinn(antallLysere: 2, antallMørkere: 3, lysereSteg: 0.1, mørkereSteg: 0.05, modus: .fast)
        let l = t.lysheter(fra: 0.5)
        #expect(l.count == 6)
        #expect(zip(l, [0.7, 0.6, 0.5, 0.45, 0.4, 0.35]).allSatisfy { nær($0, $1) })
    }

    @Test func relativeStegNærmerSegHvittOgSort() {
        let t = Lyshetstrinn(antallLysere: 2, antallMørkere: 2, lysereSteg: 0.5, mørkereSteg: 0.5, modus: .relativ)
        let l = t.lysheter(fra: 0.6)
        #expect(zip(l, [0.9, 0.8, 0.6, 0.3, 0.15]).allSatisfy { nær($0, $1) })
    }

    @Test func grunnfargenBevaresOgKulørHoldes() {
        let f = Farge(hex: "#2F7FD8")!
        let toner = Lyshetstrinn(antallLysere: 2, antallMørkere: 2).toner(for: f)
        #expect(toner[2] == f)
        // Gamut-kartlegging (CSS Color 4) tillater et lite kulørskift innenfor én merkbar forskjell.
        #expect(toner.allSatisfy { abs($0.okLCH.h - f.okLCH.h) < 3 })
        #expect(Lyshetstrinn(lysereSteg: 0.08).stegtekst(lysere: true).hasPrefix("+8 %"))
        #expect(Lyshetstrinn(mørkereSteg: 0.2, modus: .relativ).stegtekst(lysere: false) == String(localized: "\(20) % mot sort", bundle: Ressurser.pakke))
    }

    @Test func nullSteg() {
        #expect(Lyshetstrinn(antallLysere: 0, antallMørkere: 0).lysheter(fra: 0.4) == [0.4])
    }
}

@Suite("WCAG")
struct WCAGTests {
    @Test func krav() {
        let grå = Kontrasttest(forgrunn: Farge(hex: "#767676")!, bakgrunn: Farge(hex: "#FFFFFF")!)
        #expect(grå.formatert(locale: Locale(identifier: "nb_NO")) == "4,54:1")
        #expect(grå.består(.aaTekst) && !grå.består(.aaaTekst) && grå.består(.aaGrafikk))
        #expect(grå.sammendrag == "AA")
        // #777777 er det klassiske eksempelet som akkurat ikke består (4,48:1).
        #expect(!Kontrasttest(forgrunn: Farge(hex: "#777777")!, bakgrunn: Farge(hex: "#FFFFFF")!).består(.aaTekst))
    }

    @Test func rettOpp() {
        let t = Kontrasttest(forgrunn: Farge(hex: "#6B8F71")!, bakgrunn: Farge(hex: "#FFFFFF")!)
        let rettet = t.rettet(for: .aaaTekst)
        #expect(Kontrasttest(forgrunn: rettet, bakgrunn: t.bakgrunn).består(.aaaTekst))
        #expect(abs(rettet.okLCH.h - t.forgrunn.okLCH.h) < 3)
    }

    @Test func gjennomsiktigForgrunn() {
        let halv = Farge(lineærR: 0, g: 0, b: 0, alfa: 0.5)
        let t = Kontrasttest(forgrunn: halv, bakgrunn: Farge(hex: "#FFFFFF")!)
        #expect(t.forhold < 21 && t.forhold > 1)
    }
}

@Suite("Beskrivelse og justering")
struct BeskrivelseTests {
    @Test func beskrivelser() {
        #expect(Fargebeskrivelse.beskriv(Farge(hex: "#FFFFFF")!) == lok("hvit"))
        #expect(Fargebeskrivelse.beskriv(Farge(hex: "#000000")!) == lok("sort"))
        #expect(Fargebeskrivelse.beskriv(Farge(hex: "#1B3A6B")!).hasSuffix(lok("blå")))
        #expect(Fargebeskrivelse.beskriv(Farge(hex: "#6B4226")!).contains(lok("brun")))
    }

    @Test func varmereDreierMotOransje() {
        let blå = Farge(hex: "#2F7FD8")!
        let varmere = Justering.varmere.bruk(på: [blå])[0]
        // Korteste vei mot oransje (60°) fra blått (254°) går via fiolett.
        let avstand = { (h: Double) in min(abs(h - 60), 360 - abs(h - 60)) }
        #expect(avstand(varmere.okLCH.h) < avstand(blå.okLCH.h))
        let grå = Farge(hex: "#808080")!
        #expect(Justering.varmere.bruk(på: [grå])[0].avstandOK(til: grå) < 1e-6)
    }

    @Test func begrensTilSRGB() {
        let p3Grønn = Farge(displayP3: DisplayP3(r: 0, g: 1, b: 0))
        let forslag = PalettForslag(tittel: "T", forklaring: "", farger: [
            Fargeforslag(navn: "G", rolle: "aksent", begrunnelse: "", farge: p3Grønn),
        ], kilde: .leksikon).begrenset(til: .sRGB)
        #expect(forslag.farger[0].farge.erISRGB)
        #expect(abs(forslag.farger[0].farge.okLCH.l - p3Grønn.okLCH.l) < 0.03)
        // Lyshetstrinn respekterer gamut.
        #expect(Lyshetstrinn().toner(for: Farge(hex: "#2F7FD8")!, gamut: .sRGB).dropFirst(0).allSatisfy { $0.erISRGB })
    }

    @Test func rolleregler() {
        let forslag = PalettForslag(tittel: "T", forklaring: "", farger: [
            Fargeforslag(navn: "B", rolle: "bakgrunn", begrunnelse: "", farge: Farge(okLCH: OKLCH(l: 0.6, c: 0.1, h: 60))),
            Fargeforslag(navn: "T", rolle: "tekst", begrunnelse: "", farge: Farge(okLCH: OKLCH(l: 0.7, c: 0.05, h: 60))),
        ], kilde: .leksikon).medRolleregler()
        let bg = forslag.farger[0].farge, tekst = forslag.farger[1].farge
        #expect(bg.okLCH.l >= 0.95 - 1e-6 && bg.okLCH.c <= 0.0251)
        #expect(Kontrasttest(forgrunn: tekst, bakgrunn: bg).består(.aaTekst))
    }
}
