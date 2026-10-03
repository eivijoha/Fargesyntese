import Foundation

// Matriser og overføringsfunksjoner følger CSS Color Module Level 4
// (https://www.w3.org/TR/css-color-4/#color-conversion-code), slik at verdiene
// stemmer med nettlesere og designverktøy som følger samme spesifikasjon.

/// Gammakodet sRGB, 0…1 per kanal (kan gå utenfor for farger utenfor gamut).
public struct SRGB: Hashable, Codable, Sendable {
    public var r, g, b: Double
    public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
}

/// Gammakodet Display P3, 0…1 per kanal.
public struct DisplayP3: Hashable, Codable, Sendable {
    public var r, g, b: Double
    public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
}

/// CIE XYZ med D65-hvitpunkt (Y = 1 for referansehvitt).
public struct XYZ: Hashable, Codable, Sendable {
    public var x, y, z: Double
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
}

enum Overføring {
    /// sRGB/Display P3-kurven (samme kurve), speilet for negative verdier.
    static func tilLineær(_ c: Double) -> Double {
        let a = abs(c)
        let v = a <= 0.04045 ? a / 12.92 : pow((a + 0.055) / 1.055, 2.4)
        return c < 0 ? -v : v
    }

    static func tilGamma(_ c: Double) -> Double {
        let a = abs(c)
        let v = a <= 0.0031308 ? a * 12.92 : 1.055 * pow(a, 1 / 2.4) - 0.055
        return c < 0 ? -v : v
    }
}

enum Matriser {
    static let lineærSRGBTilXYZ = Matrise3([
        [506752.0 / 1228815, 87881.0 / 245763, 12673.0 / 70218],
        [87098.0 / 409605, 175762.0 / 245763, 12673.0 / 175545],
        [7918.0 / 409605, 87881.0 / 737289, 1001167.0 / 1053270],
    ])
    static let xyzTilLineærSRGB = lineærSRGBTilXYZ.invertert
    static let lineærP3TilXYZ = Matrise3([
        [608311.0 / 1250200, 189793.0 / 714400, 198249.0 / 1000160],
        [35783.0 / 156275, 247089.0 / 357200, 198249.0 / 2500400],
        [0, 32229.0 / 714400, 5220557.0 / 5000800],
    ])
    static let xyzTilLineærP3 = lineærP3TilXYZ.invertert

    static let hvitD65 = Vektor3(0.3127 / 0.3290, 1, (1 - 0.3127 - 0.3290) / 0.3290)
    static let hvitD50 = Vektor3(0.3457 / 0.3585, 1, (1 - 0.3457 - 0.3585) / 0.3585)

    /// Bradford kromatisk tilpasning D65 → D50 (for CIELab og ICC-profiler).
    static let d65TilD50 = bradford(fra: hvitD65, til: hvitD50)
    static let d50TilD65 = d65TilD50.invertert

    static func bradford(fra kilde: Vektor3, til mål: Vektor3) -> Matrise3 {
        let mA = Matrise3([[0.8951, 0.2664, -0.1614], [-0.7502, 1.7135, 0.0367], [0.0389, -0.0685, 1.0296]])
        let k = mA * kilde, m = mA * mål
        let skalering = Matrise3([[m.x / k.x, 0, 0], [0, m.y / k.y, 0], [0, 0, m.z / k.z]])
        return mA.invertert * (skalering * mA)
    }
}

public extension Farge {
    init(sRGB s: SRGB, alfa: Double = 1) {
        self.init(lineærR: Overføring.tilLineær(s.r), g: Overføring.tilLineær(s.g), b: Overføring.tilLineær(s.b), alfa: alfa)
    }

    var sRGB: SRGB {
        SRGB(r: Overføring.tilGamma(r), g: Overføring.tilGamma(g), b: Overføring.tilGamma(b))
    }

    init(xyz: XYZ, alfa: Double = 1) {
        self.init(lineær: Matriser.xyzTilLineærSRGB * Vektor3(xyz.x, xyz.y, xyz.z), alfa: alfa)
    }

    var xyz: XYZ {
        let v = Matriser.lineærSRGBTilXYZ * lineær
        return XYZ(x: v.x, y: v.y, z: v.z)
    }

    init(displayP3 p: DisplayP3, alfa: Double = 1) {
        let lin = Vektor3(Overføring.tilLineær(p.r), Overføring.tilLineær(p.g), Overføring.tilLineær(p.b))
        let xyz = Matriser.lineærP3TilXYZ * lin
        self.init(lineær: Matriser.xyzTilLineærSRGB * xyz, alfa: alfa)
    }

    internal var displayP3Lineær: Vektor3 {
        Matriser.xyzTilLineærP3 * (Matriser.lineærSRGBTilXYZ * lineær)
    }

    var displayP3: DisplayP3 {
        let p = displayP3Lineær
        return DisplayP3(r: Overføring.tilGamma(p.x), g: Overføring.tilGamma(p.y), b: Overføring.tilGamma(p.z))
    }

    /// Relativ luminans (Y i XYZ), brukt til kontrastberegning.
    var luminans: Double { xyz.y }
}
