import FargeKjerne
import Testing

@Suite("Munsell")
struct MunsellTests {
    @Test func notasjonLesesOgSkrives() throws {
        let m = try #require(Munsell("5R 4/14"))
        #expect(m.kulør == 5 && m.valør == 4 && m.kroma == 14)
        #expect(m.notasjon == "5R 4/14")
        #expect(Munsell("2.5PB 6/8")?.kulør == 72.5)
        #expect(Munsell("10RP 5/6")?.kulørnavn == "10RP")
        #expect(Munsell("N 5/")?.notasjon == "N 5/")
        #expect(Munsell("tull") == nil)
    }

    @Test func valørFølgerASTM() {
        // ASTM D1535 (skalert til perfekt diffus hvit): V 5 ≈ Y 19,27 %, V 10 = 100 %.
        #expect(abs(Munsell.luminans(forValør: 5) - 0.1927) < 0.001)
        #expect(abs(Munsell.luminans(forValør: 10) - 1.0) < 0.001)
        #expect(abs(Munsell.valør(forLuminans: 0.1927) - 5) < 0.01)
    }

    @Test func rundturForSkjermfarger() throws {
        for hex in ["#C0392B", "#2F7FD8", "#27AE60", "#F1C40F", "#8E44AD", "#7F8C8D", "#FAD7A0", "#1B2631"] {
            let f = try #require(Farge(hex: hex))
            let m = f.munsell
            let tilbake = try #require(Farge(munsell: m))
            #expect(f.deltaE2000(til: tilbake) < 1.0, "\(hex) → \(m.notasjon) → \(tilbake.hex())")
        }
    }

    @Test func kjenteFarger() throws {
        // Munsell-renotasjon: 5R 4/14 er en mettet rød, 5PB 5/10 en klar blå, N 5/ er mellomgrå.
        let rød = try #require(Farge(munsell: Munsell("5R 4/14")!))
        let lch = rød.okLCH
        #expect(lch.h > 15 && lch.h < 40 && lch.c > 0.15)
        let grå = try #require(Farge(munsell: Munsell("N 5/")!))
        #expect(grå.okLCH.c < 0.01 && abs(grå.lrv - 19.3) < 0.5)
        let blå = try #require(Farge(munsell: Munsell("5PB 5/10")!))
        #expect(blå.okLCH.h > 240 && blå.okLCH.h < 275)
        // Nøytrale gråtoner blir N, og kulørnavnet på hvitt/sort er irrelevant.
        #expect(Farge(hex: "#808080")!.munsell.notasjon.hasPrefix("N "))
    }
}

@Suite("LRV")
struct LRVTests {
    @Test func lrvOgFlatekontrast() {
        #expect(abs(Farge(hex: "#FFFFFF")!.lrv - 100) < 0.01)
        #expect(Farge(hex: "#000000")!.lrv == 0)
        #expect(abs(Farge(hex: "#808080")!.lrv - 21.6) < 0.2)
        let k = Flatekontrast(Farge(hex: "#FFFFFF")!, Farge(hex: "#808080")!)
        #expect(k.består(.lrv30) && k.består(.luminans04))
        #expect(!k.består(.luminans08))
        let lik = Flatekontrast(Farge(hex: "#2F7FD8")!, Farge(hex: "#3A86DE")!)
        #expect(!lik.består(.lrv30))
        let rettet = lik.rettet(for: .lrv30, gamut: .sRGB)
        #expect(Flatekontrast(rettet, Farge(hex: "#3A86DE")!).består(.lrv30))
        // Kuløren bevares når lysheten endres.
        #expect(abs(rettet.okLCH.h - Farge(hex: "#2F7FD8")!.okLCH.h) < 8)  // gamut-kartlegging kan flytte kuløren litt
    }
}
