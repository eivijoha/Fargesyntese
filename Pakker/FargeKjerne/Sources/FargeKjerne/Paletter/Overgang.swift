import Foundation

/// Overgangstoner og lys/mørk-skalaer, alltid beregnet i OKLab.
public enum Overgang {
    /// `antall` farger i like perseptuelle steg fra `start` til `slutt` (begge inkludert).
    ///
    /// Interpolasjonen skjer lineært i OKLab (ikke OKLCH), slik at overgangen går
    /// den korteste veien gjennom fargerommet uten kulør-«omveier». Alfa interpoleres lineært.
    public static func toner(fra start: Farge, til slutt: Farge, antall: Int) -> [Farge] {
        guard antall > 1 else { return antall == 1 ? [start] : [] }
        let a = start.okLab, b = slutt.okLab
        return (0..<antall).map { i in
            // Endepunktene returneres eksakt, slik at brukerens valgte farger ikke drifter.
            if i == 0 { return start }
            if i == antall - 1 { return slutt }
            let t = Double(i) / Double(antall - 1)
            return Farge(
                okLab: OKLab(l: a.l + (b.l - a.l) * t, a: a.a + (b.a - a.a) * t, b: a.b + (b.b - a.b) * t),
                alfa: start.alfa + (slutt.alfa - start.alfa) * t
            )
        }
    }

    /// Flerpunkts-overgang: like steg mellom hvert par av nøkkelfarger.
    /// `stegMellom` er antall mellomtoner mellom to nabofarger.
    public static func toner(gjennom nøkler: [Farge], stegMellom: Int) -> [Farge] {
        guard let første = nøkler.first else { return [] }
        var resultat = [første]
        for (a, b) in zip(nøkler, nøkler.dropFirst()) {
            resultat += toner(fra: a, til: b, antall: stegMellom + 2).dropFirst()
        }
        return resultat
    }
}

/// En lys-til-mørk-skala rundt en grunnfarge (à la «50…950» i designsystemer).
public struct Toneskala: Sendable {
    /// Lysestegenes OKLab-lyshet. Standard er en jevn trapp fra nesten hvit til nesten sort.
    public var lysheter: [Double]
    /// Hvor mye kroma dempes mot ytterpunktene (0 = ingen demping, 1 = full).
    /// Hindrer at lyse/mørke toner blir utmettet eller havner langt utenfor gamut.
    public var kromaDemping: Double
    public var gamut: Gamut

    public init(lysheter: [Double] = Toneskala.standardLysheter, kromaDemping: Double = 0.6, gamut: Gamut = .displayP3) {
        self.lysheter = lysheter
        self.kromaDemping = kromaDemping
        self.gamut = gamut
    }

    /// 11 trinn som tilsvarer 50, 100, 200 … 900, 950.
    public static let standardLysheter: [Double] = [0.97, 0.93, 0.87, 0.78, 0.69, 0.60, 0.51, 0.43, 0.35, 0.27, 0.20]

    /// `antall` jevne trinn mellom `lysest` og `mørkest`.
    public static func jevn(antall: Int, lysest: Double = 0.97, mørkest: Double = 0.2) -> [Double] {
        guard antall > 1 else { return [lysest] }
        return (0..<antall).map { lysest + (mørkest - lysest) * Double($0) / Double(antall - 1) }
    }

    /// Lager skalaen. Kulør holdes fast; kroma skaleres ned mot ytterpunktene
    /// med en jevn kurve, og hvert trinn gamut-kartlegges.
    public func toner(for grunnfarge: Farge) -> [Farge] {
        let g = grunnfarge.okLCH
        return lysheter.map { l in
            let avstand = abs(l - g.l) / max(g.l, 1 - g.l, 0.001)
            let faktor = 1 - kromaDemping * avstand * avstand
            return Farge(okLCH: OKLCH(l: l, c: g.c * max(faktor, 0), h: g.h), alfa: grunnfarge.alfa)
                .gamutKartlagt(til: gamut)
        }
    }

    /// Lysere og mørkere varianter av en farge i like OKLab-lyshetssteg.
    public static func variasjoner(av farge: Farge, lysere: Int, mørkere: Int, steg: Double = 0.08, gamut: Gamut = .displayP3) -> [Farge] {
        let g = farge.okLCH
        let trinn = (-lysere...mørkere).map { g.l - Double($0) * steg }
        return trinn.map { l in
            Farge(okLCH: OKLCH(l: l.klampet(0, 1), c: g.c, h: g.h), alfa: farge.alfa).gamutKartlagt(til: gamut)
        }
    }
}
