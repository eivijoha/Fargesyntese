import Foundation

/// Fargeavstand (ΔE) mellom to farger.
public enum Fargeavstand {
    /// CIEDE2000 (ΔE00) etter Sharma, Wu & Dalal (2005), med kL = kC = kH = 1.
    /// Bransjestandard for fargemåling og toleranser (trykk, tekstil, maling).
    public static func deltaE2000(_ x: CIELab, _ y: CIELab) -> Double {
        let (l1, a1, b1) = (x.l, x.a, x.b)
        let (l2, a2, b2) = (y.l, y.a, y.b)
        let grad = Double.pi / 180
        let p25: Double = 6_103_515_625  // 25^7

        let c1 = (a1 * a1 + b1 * b1).squareRoot(), c2 = (a2 * a2 + b2 * b2).squareRoot()
        let cSnitt7 = pow((c1 + c2) / 2, 7)
        let g = 0.5 * (1 - (cSnitt7 / (cSnitt7 + p25)).squareRoot())
        let a1m = (1 + g) * a1, a2m = (1 + g) * a2
        let c1m = (a1m * a1m + b1 * b1).squareRoot(), c2m = (a2m * a2m + b2 * b2).squareRoot()

        func vinkel(_ b: Double, _ a: Double) -> Double {
            if a == 0 && b == 0 { return 0 }
            let h = atan2(b, a) / grad
            return h < 0 ? h + 360 : h
        }
        let h1m = vinkel(b1, a1m), h2m = vinkel(b2, a2m)

        let dL = l2 - l1
        let dC = c2m - c1m
        var dh = 0.0
        if c1m * c2m != 0 {
            dh = h2m - h1m
            if dh > 180 { dh -= 360 } else if dh < -180 { dh += 360 }
        }
        let dH = 2 * (c1m * c2m).squareRoot() * sin(dh / 2 * grad)

        let lSnitt = (l1 + l2) / 2
        let cSnittM = (c1m + c2m) / 2
        var hSnitt = h1m + h2m
        if c1m * c2m != 0 {
            if abs(h1m - h2m) <= 180 { hSnitt = (h1m + h2m) / 2 }
            else if h1m + h2m < 360 { hSnitt = (h1m + h2m + 360) / 2 }
            else { hSnitt = (h1m + h2m - 360) / 2 }
        }

        let t = 1 - 0.17 * cos((hSnitt - 30) * grad) + 0.24 * cos(2 * hSnitt * grad)
            + 0.32 * cos((3 * hSnitt + 6) * grad) - 0.20 * cos((4 * hSnitt - 63) * grad)
        let dTheta = 30 * exp(-pow((hSnitt - 275) / 25, 2))
        let cSnittM7 = pow(cSnittM, 7)
        let rC = 2 * (cSnittM7 / (cSnittM7 + p25)).squareRoot()
        let lAvvik2 = (lSnitt - 50) * (lSnitt - 50)
        let sL = 1 + 0.015 * lAvvik2 / (20 + lAvvik2).squareRoot()
        let sC = 1 + 0.045 * cSnittM
        let sH = 1 + 0.015 * cSnittM * t
        let rT = -sin(2 * dTheta * grad) * rC

        let lLedd = dL / sL, cLedd = dC / sC, hLedd = dH / sH
        return (lLedd * lLedd + cLedd * cLedd + hLedd * hLedd + rT * cLedd * hLedd).squareRoot()
    }

    /// CIE76 (ΔE*ab): enkel euklidsk avstand i CIELab. Tas med for sammenligning med eldre verktøy.
    public static func deltaE76(_ x: CIELab, _ y: CIELab) -> Double {
        let (dl, da, db) = (x.l - y.l, x.a - y.a, x.b - y.b)
        return (dl * dl + da * da + db * db).squareRoot()
    }

    /// Vanlig tolkning av ΔE00 for et menneskelig øye under gode forhold.
    public static func tolkning(_ deltaE: Double) -> String {
        switch deltaE {
        case ..<1: String(localized: "Ikke merkbar", bundle: .module)
        case ..<2: String(localized: "Merkbar ved nøye sammenligning", bundle: .module)
        case ..<3.5: String(localized: "Merkbar", bundle: .module)
        case ..<5: String(localized: "Tydelig forskjell", bundle: .module)
        default: String(localized: "Ulike farger", bundle: .module)
        }
    }
}

public extension Farge {
    /// ΔE00 (CIEDE2000) mot en annen farge, beregnet i CIELab D50.
    func deltaE2000(til annen: Farge) -> Double { Fargeavstand.deltaE2000(cieLab, annen.cieLab) }
}
