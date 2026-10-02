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

@Suite("Palettkomponist")
struct PalettkomponistTests {
    private func kjerne(_ f: [Fargeforslag]) -> [Fargeforslag] { f.filter { !["bakgrunn", "tekst"].contains($0.rolle) } }

    @Test(arguments: Harmoniprinsipp.allCases, Samklang.allCases)
    func lesbarOgUtenBruntForAlleOppskrifter(_ harmoni: Harmoniprinsipp, _ samklang: Samklang) throws {
        for primær in Kulørfamilie.kromatiske {
            for bakgrunn in Bakgrunnstype.allCases {
                let o = Palettoppskrift(primær: primær, harmoni: harmoni, samklang: samklang, bakgrunn: bakgrunn)
                let farger = Palettkomponist.komponer(o, antall: 8, gamut: .sRGB)
                #expect(farger.prefix(5).map(\.rolle) == ["primær", "sekundær", "aksent", "bakgrunn", "tekst"])
                let bg = try #require(farger.first { $0.rolle == "bakgrunn" }).farge
                let tekst = try #require(farger.first { $0.rolle == "tekst" }).farge
                #expect(tekst.wcagKontrast(mot: bg) >= Palettkomponist.tekstkontrast - 0.01)
                #expect(bakgrunn == .mørk ? bg.okLCH.l < 0.25 : bg.okLCH.l > 0.94)
                for f in farger.prefix(3) {
                    let lch = f.farge.okLCH
                    // Ingen brune eller grå hovedfarger uten at oppskriften ber om det.
                    #expect(lch.c > 0.05, "\(primær) \(harmoni) \(samklang) \(f.rolle) \(f.farge.hex())")
                    #expect(!((30...90).contains(lch.h) && lch.l < 0.6 && lch.c < 0.11), "brun: \(primær) \(harmoni) \(f.rolle) \(f.farge.hex())")
                    // Hovedfargene synes mot bakgrunnen; gul og lime får være klare i stedet.
                    let spes = Fargespesifikasjon.nærmeste(f.farge, i: .sRGB)
                    // En tone av primærfargen (monokrom og komplementær sekundær) er en flatefarge og er unntatt.
                    let toneITone = f.rolle == "sekundær" && [.monokrom, .komplementær].contains(harmoni)
                    if ![.gul, .lime, .rav].contains(spes.familie), !toneITone {
                        #expect(f.farge.wcagKontrast(mot: bg) >= Palettkomponist.fargekontrast - 0.05, "\(primær) \(harmoni) \(samklang) \(bakgrunn) \(f.rolle) \(f.farge.hex())")
                    }
                }
            }
        }
    }

    @Test func harmoniFølgerVinkelenMellomOrdeneskulører() {
        let trygtOgVarmt = Palettoppskrift(grunnlag: Fargesemantikk.oppslag("trygg, varm"), gamut: .sRGB)
        #expect(trygtOgVarmt.primær == .blå)
        #expect(trygtOgVarmt.sekundær == .oransje)
        #expect(trygtOgVarmt.harmoni == .komplementær)
        // Komplementær: sekundær er tone i tone, og ordets andre kulør blir aksent.
        let f = Palettkomponist.komponer(trygtOgVarmt, antall: 5, grunnlag: Fargesemantikk.oppslag("trygg, varm"), gamut: .sRGB)
        #expect(vinkelavstand(f[1].farge.okLCH.h, f[0].farge.okLCH.h) < 12)
        #expect(Kulørfamilie.nærmeste(kulør: f[2].farge.okLCH.h) == .oransje)
        #expect(Palettoppskrift.harmoni(.grønn, .blågrønn) == .analog)
        #expect(Palettoppskrift.harmoni(.grønn, .blå) == .triade)
        #expect(Palettoppskrift.harmoni(.blå, .gul) == .splittkomplementær)
    }

    @Test func likValørGirSammeLyshet() {
        // Grønn + blågrønn med magenta aksent: ingen av kulørene trenger egen lyshet for å være klare.
        let o = Palettoppskrift(primær: .grønn, sekundær: .blågrønn, harmoni: .analog, samklang: .likValør, lyshet: .middelsMørk)
        let f = Palettkomponist.komponer(o, antall: 5, gamut: .sRGB)
        let l = f.prefix(3).map { $0.farge.okLCH.l }
        #expect(l.max()! - l.min()! < 0.08)
        // Lik metning: lysheten skiller primær og sekundær i stedet.
        let variert = Palettkomponist.komponer({ var v = o; v.samklang = .likMetning; return v }(), antall: 5, gamut: .sRGB)
        #expect(abs(variert[0].farge.okLCH.l - variert[1].farge.okLCH.l) > 0.06)
    }

    @Test func bruntBareNårBegrepetBerOmDet() {
        #expect(Fargesemantikk.oppslag("jord").tillaterBrunt)
        #expect(!Fargesemantikk.oppslag("moderne, lokal, luksus, tidløs").tillaterBrunt)
        #expect(Palettoppskrift(grunnlag: Fargesemantikk.oppslag("varm, nær, raus"), gamut: .sRGB).brunt == nil)
        #expect(Fargesemantikk.oppslag("raus, kompetent, ambisiøs, respekt, samarbeid, jordnær").begreper.count == 6)
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
