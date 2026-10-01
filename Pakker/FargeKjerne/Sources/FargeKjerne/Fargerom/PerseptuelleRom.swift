import Foundation

/// OKLab (Björn Ottosson 2020). L 0…1, a/b ca. −0,4…0,4.
/// Perseptuelt jevnt rom – brukes til all interpolasjon i Kolorist.
public struct OKLab: Hashable, Codable, Sendable {
    public var l, a, b: Double
    public init(l: Double, a: Double, b: Double) { self.l = l; self.a = a; self.b = b }
}

/// Polar form av OKLab. L 0…1, C 0…~0,4, h i grader 0…360.
public struct OKLCH: Hashable, Codable, Sendable {
    public var l, c, h: Double
    public init(l: Double, c: Double, h: Double) { self.l = l; self.c = c; self.h = h }
}

/// CIE L*a*b* med D50-hvitpunkt (som ICC, Photoshop og CSS `lab()`). L 0…100.
public struct CIELab: Hashable, Codable, Sendable {
    public var l, a, b: Double
    public init(l: Double, a: Double, b: Double) { self.l = l; self.a = a; self.b = b }
}

/// Polar form av CIELab (CSS `lch()`). L 0…100, C 0…~150, h i grader.
public struct CIELCH: Hashable, Codable, Sendable {
    public var l, c, h: Double
    public init(l: Double, c: Double, h: Double) { self.l = l; self.c = c; self.h = h }
}

// MARK: - OKLab

public extension Farge {
    init(okLab lab: OKLab, alfa: Double = 1) {
        let l_ = lab.l + 0.3963377774 * lab.a + 0.2158037573 * lab.b
        let m_ = lab.l - 0.1055613458 * lab.a - 0.0638541728 * lab.b
        let s_ = lab.l - 0.0894841775 * lab.a - 1.2914855480 * lab.b
        let l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_
        self.init(
            lineærR: 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            g: -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            b: -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
            alfa: alfa
        )
    }

    var okLab: OKLab {
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return OKLab(
            l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    init(okLCH lch: OKLCH, alfa: Double = 1) {
        let (a, b) = Polar.tilKartesisk(c: lch.c, h: lch.h)
        self.init(okLab: OKLab(l: lch.l, a: a, b: b), alfa: alfa)
    }

    var okLCH: OKLCH {
        let lab = okLab
        let (c, h) = Polar.tilPolar(a: lab.a, b: lab.b)
        return OKLCH(l: lab.l, c: c, h: h)
    }
}

// MARK: - CIELab (D50)

private enum LabKonstanter {
    static let ε = 216.0 / 24389
    static let κ = 24389.0 / 27
}

public extension Farge {
    init(cieLab lab: CIELab, alfa: Double = 1) {
        let (ε, κ) = (LabKonstanter.ε, LabKonstanter.κ)
        let fy = (lab.l + 16) / 116
        let fx = lab.a / 500 + fy
        let fz = fy - lab.b / 200
        let x = fx * fx * fx > ε ? fx * fx * fx : (116 * fx - 16) / κ
        let y = lab.l > κ * ε ? fy * fy * fy : lab.l / κ
        let z = fz * fz * fz > ε ? fz * fz * fz : (116 * fz - 16) / κ
        let hvit = Matriser.hvitD50
        let xyzD50 = Vektor3(x * hvit.x, y * hvit.y, z * hvit.z)
        let xyzD65 = Matriser.d50TilD65 * xyzD50
        self.init(xyz: XYZ(x: xyzD65.x, y: xyzD65.y, z: xyzD65.z), alfa: alfa)
    }

    var cieLab: CIELab {
        let (ε, κ) = (LabKonstanter.ε, LabKonstanter.κ)
        let x = xyz
        let d50 = Matriser.d65TilD50 * Vektor3(x.x, x.y, x.z)
        let hvit = Matriser.hvitD50
        let f = { (t: Double) in t > ε ? cbrt(t) : (κ * t + 16) / 116 }
        let fx = f(d50.x / hvit.x), fy = f(d50.y / hvit.y), fz = f(d50.z / hvit.z)
        return CIELab(l: 116 * fy - 16, a: 500 * (fx - fy), b: 200 * (fy - fz))
    }

    init(cieLCH lch: CIELCH, alfa: Double = 1) {
        let (a, b) = Polar.tilKartesisk(c: lch.c, h: lch.h)
        self.init(cieLab: CIELab(l: lch.l, a: a, b: b), alfa: alfa)
    }

    var cieLCH: CIELCH {
        let lab = cieLab
        let (c, h) = Polar.tilPolar(a: lab.a, b: lab.b)
        return CIELCH(l: lab.l, c: c, h: h)
    }
}

enum Polar {
    static func tilKartesisk(c: Double, h: Double) -> (Double, Double) {
        let rad = h * .pi / 180
        return (c * cos(rad), c * sin(rad))
    }

    /// Kulør settes til 0 for (nesten) akromatiske farger, slik at grått ikke får en tilfeldig kulør.
    static func tilPolar(a: Double, b: Double) -> (c: Double, h: Double) {
        let c = (a * a + b * b).squareRoot()
        guard c > 1e-7 else { return (0, 0) }
        var h = atan2(b, a) * 180 / .pi
        if h < 0 { h += 360 }
        return (c, h)
    }
}
