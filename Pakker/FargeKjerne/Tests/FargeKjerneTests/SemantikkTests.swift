import FargeKjerne
import Testing
@testable import FargeKI

@Suite("Fargesemantikk")
struct SemantikkTests {
    @Test func kunnskapsbasenLastes() {
        #expect(Fargesemantikk.begreper.count > 100)
        for b in Fargesemantikk.begreper {
            #expect(!b.sorterteFamilier.isEmpty, "\(b.id) mangler kulørfamilier")
            #expect(b.sorterteFamilier.count == b.familier.count, "\(b.id) har ukjent familie")
            #expect(!b.lyshet.isEmpty && !b.metning.isEmpty, "\(b.id)")
        }
    }

    @Test func oppslagMedBøyningOgSynonymer() {
        let g = Fargesemantikk.oppslag("Natur, friskhet og grønne flater")
        #expect(g.begreper.map(\.id) == ["natur", "frisk", "grønn"])
        #expect(g.familievekter.first?.0 == .grønn)
        #expect(Fargesemantikk.oppslag("trygghet").begreper.first?.id == "trygg")
        #expect(Fargesemantikk.oppslag("fresh nature").begreper.map(\.id).sorted() == ["frisk", "natur"])
        #expect(Fargesemantikk.oppslag("klar luft over fjellet").begreper.map(\.id).contains("himmel"))
        #expect(Fargesemantikk.oppslag("skogsgrønn").begreper.map(\.id) == ["skog", "grønn"])
        #expect(Fargesemantikk.oppslag("havblå").begreper.map(\.id) == ["hav", "blå"])
        // Preposisjoner og tallord skal ikke gi treff.
        #expect(Fargesemantikk.oppslag("mot tre farger").erTomt)
    }

    @Test func naturGirKlareFarger() {
        let g = Fargesemantikk.oppslag("natur")
        #expect(g.minsteMetning >= .moderat)
        #expect(g.minsteMetning(for: "aksent")! >= .moderat)
    }

    @Test func fargespråkTilFargeOgTilbake() {
        let spes = Fargespesifikasjon(familie: .grønn, lyshet: .middels, metning: .klar)
        let f = spes.farge(i: .sRGB)
        #expect(f.erISRGB)
        let lch = f.okLCH
        #expect(abs(lch.h - 145) < 3)
        #expect(lch.c > 0.12)
        #expect(Fargespesifikasjon.nærmeste(f, i: .sRGB) == spes)
        #expect(Kulørfamilie.nærmeste(kulør: Farge(hex: "#FFA500")!.okLCH.h) == .oransje)
    }

    @Test func reserveforslagFølgerGrunnlaget() {
        let p = LeksikonTolker().forslag(for: "natur, frisk", antall: 5, gamut: .sRGB)
        let primær = p.farger.first { $0.rolle == "primær" }!.farge.okLCH
        #expect((115...185).contains(primær.h))
        #expect(primær.c > 0.1)
        #expect(p.grunnlag == ["natur", "frisk"])
        let hav = LeksikonTolker().forslag(for: "hav", antall: 5, gamut: .sRGB)
        #expect((200...280).contains(hav.farger[0].farge.okLCH.h))
    }
}

@Suite("Fargebeskriver")
struct FargebeskriverTests {
    @Test func regelbasertTolkerModifikatorer() {
        let pastell = Fargebeskriver.regelbasert("pastell lilla", gamut: .sRGB)
        #expect(pastell.spesifikasjon.familie == .fiolett)
        #expect(pastell.spesifikasjon.lyshet == .sværtLys)
        #expect(pastell.spesifikasjon.metning <= .moderat)
        let dyp = Fargebeskriver.regelbasert("dyp havblå", gamut: .sRGB)
        #expect(dyp.spesifikasjon.familie == .blå)
        #expect(dyp.spesifikasjon.lyshet == .mørk)
        let støv = Fargebeskriver.regelbasert("støvete rosa", gamut: .sRGB)
        #expect(støv.spesifikasjon.metning == .dempet)
        #expect(Fargebeskriver.regelbasert("nesten sort skogsgrønn", gamut: .sRGB).spesifikasjon.lyshet == .nestenSort)
        #expect(Fargebeskriver.regelbasert("mustard", gamut: .sRGB).spesifikasjon.familie == .rav)
    }
}
