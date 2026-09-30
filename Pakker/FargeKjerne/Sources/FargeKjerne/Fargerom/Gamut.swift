import Foundation

public enum Gamut: String, CaseIterable, Codable, Sendable {
    case sRGB, displayP3
}

public extension Farge {
    /// Perseptuell avstand i OKLab (ΔE_OK). ~0,02 er omtrent én merkbar forskjell.
    func avstandOK(til annen: Farge) -> Double {
        let a = okLab, b = annen.okLab
        let dl = a.l - b.l, da = a.a - b.a, db = a.b - b.b
        return (dl * dl + da * da + db * db).squareRoot()
    }

    func erInnenfor(_ gamut: Gamut) -> Bool {
        switch gamut {
        case .sRGB: erISRGB
        case .displayP3: erIDisplayP3
        }
    }

    /// Klipper kanalene hardt til gamut (endrer kulør – bruk ``gamutKartlagt(til:)`` for visning).
    func klippet(til gamut: Gamut) -> Farge {
        switch gamut {
        case .sRGB:
            return Farge(lineærR: r.klampet(0, 1), g: g.klampet(0, 1), b: b.klampet(0, 1), alfa: alfa)
        case .displayP3:
            let p = displayP3
            return Farge(displayP3: DisplayP3(r: p.r.klampet(0, 1), g: p.g.klampet(0, 1), b: p.b.klampet(0, 1)), alfa: alfa)
        }
    }

    /// Gamut-kartlegging etter CSS Color 4: reduserer kroma i OKLCH (bevarer lyshet og kulør)
    /// til fargen ligger innenfor, med binærsøk og en «merkbar forskjell»-toleranse.
    func gamutKartlagt(til gamut: Gamut) -> Farge {
        if erInnenfor(gamut) { return self }
        let opphav = okLCH
        if opphav.l >= 1 { return Farge(lineærR: 1, g: 1, b: 1, alfa: alfa) }
        if opphav.l <= 0 { return Farge(lineærR: 0, g: 0, b: 0, alfa: alfa) }

        let jnd = 0.02, ε = 0.0001
        var lav = 0.0, høy = opphav.c, lavErInnenfor = true
        var gjeldende = self
        var klipp = gjeldende.klippet(til: gamut)
        if klipp.avstandOK(til: gjeldende) < jnd { return klipp }

        while høy - lav > ε {
            let kroma = (lav + høy) / 2
            gjeldende = Farge(okLCH: OKLCH(l: opphav.l, c: kroma, h: opphav.h), alfa: alfa)
            if lavErInnenfor && gjeldende.erInnenfor(gamut) {
                lav = kroma
                continue
            }
            klipp = gjeldende.klippet(til: gamut)
            let e = klipp.avstandOK(til: gjeldende)
            if e < jnd {
                if jnd - e < ε { return klipp }
                lavErInnenfor = false
                lav = kroma
            } else {
                høy = kroma
            }
        }
        return klipp
    }
}
