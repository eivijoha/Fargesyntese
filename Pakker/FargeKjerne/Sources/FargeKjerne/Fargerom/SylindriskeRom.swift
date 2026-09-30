import Foundation

/// HSB (også kalt HSV) over gammakodet sRGB. h i grader, s/b 0…1.
public struct HSB: Hashable, Codable, Sendable {
    public var h, s, b: Double
    public init(h: Double, s: Double, b: Double) { self.h = h; self.s = s; self.b = b }
}

/// HSL over gammakodet sRGB. h i grader, s/l 0…1.
public struct HSL: Hashable, Codable, Sendable {
    public var h, s, l: Double
    public init(h: Double, s: Double, l: Double) { self.h = h; self.s = s; self.l = l }
}

/// Enkel («naiv») CMYK uten fargestyring, 0…1 per kanal.
/// For trykk skal ``ICCProfil`` brukes – denne er kun for rask visning og CSS-lignende bruk.
public struct CMYK: Hashable, Codable, Sendable {
    public var c, m, y, k: Double
    public init(c: Double, m: Double, y: Double, k: Double) { self.c = c; self.m = m; self.y = y; self.k = k }
}

public extension Farge {
    /// HSB/HSL er definert på sRGB-kuben, så fargen klippes til sRGB først.
    private var klippetSRGB: SRGB {
        let s = sRGB
        return SRGB(r: s.r.klampet(0, 1), g: s.g.klampet(0, 1), b: s.b.klampet(0, 1))
    }

    private static func kulør(r: Double, g: Double, b: Double, maks: Double, delta: Double) -> Double {
        guard delta > 0 else { return 0 }
        var h: Double
        switch maks {
        case r: h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        case g: h = (b - r) / delta + 2
        default: h = (r - g) / delta + 4
        }
        h *= 60
        return h < 0 ? h + 360 : h
    }

    var hsb: HSB {
        let s = klippetSRGB
        let maks = max(s.r, s.g, s.b), min = Swift.min(s.r, s.g, s.b), delta = maks - min
        return HSB(h: Self.kulør(r: s.r, g: s.g, b: s.b, maks: maks, delta: delta),
                   s: maks == 0 ? 0 : delta / maks,
                   b: maks)
    }

    init(hsb: HSB, alfa: Double = 1) {
        let h = (hsb.h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let f = { (n: Double) -> Double in
            let k = (n + h).truncatingRemainder(dividingBy: 6)
            return hsb.b - hsb.b * hsb.s * max(0, min(k, 4 - k, 1))
        }
        self.init(sRGB: SRGB(r: f(5), g: f(3), b: f(1)), alfa: alfa)
    }

    var hsl: HSL {
        let s = klippetSRGB
        let maks = max(s.r, s.g, s.b), min = Swift.min(s.r, s.g, s.b), delta = maks - min
        let l = (maks + min) / 2
        let metning = (l == 0 || l == 1) ? 0 : delta / (1 - abs(2 * l - 1))
        return HSL(h: Self.kulør(r: s.r, g: s.g, b: s.b, maks: maks, delta: delta), s: metning, l: l)
    }

    init(hsl: HSL, alfa: Double = 1) {
        let v = hsl.l + hsl.s * min(hsl.l, 1 - hsl.l)
        let sv = v == 0 ? 0 : 2 * (1 - hsl.l / v)
        self.init(hsb: HSB(h: hsl.h, s: sv, b: v), alfa: alfa)
    }

    var naivCMYK: CMYK {
        let s = klippetSRGB
        let k = 1 - max(s.r, s.g, s.b)
        guard k < 1 else { return CMYK(c: 0, m: 0, y: 0, k: 1) }
        return CMYK(c: (1 - s.r - k) / (1 - k), m: (1 - s.g - k) / (1 - k), y: (1 - s.b - k) / (1 - k), k: k)
    }

    init(naivCMYK c: CMYK, alfa: Double = 1) {
        self.init(sRGB: SRGB(r: (1 - c.c) * (1 - c.k), g: (1 - c.m) * (1 - c.k), b: (1 - c.y) * (1 - c.k)), alfa: alfa)
    }
}
