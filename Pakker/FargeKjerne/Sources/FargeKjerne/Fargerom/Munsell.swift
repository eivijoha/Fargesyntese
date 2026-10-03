import Foundation

// Munsell-systemet: kulør (hue), valør (value) og kroma, slik det brukes av arkitekter,
// landskapsarkitekter og i jord- og steinbeskrivelser. Omregningen bygger på Munsell-
// renotasjonsdataene (Newhall, Nickerson & Judd 1943; OSA), som gir CIE xyY under lyskilde C
// for hvert prøvepunkt, og på ASTM D1535 for sammenhengen mellom valør og luminans.
// Datasettet er det offentlige «all»-settet med ekstrapolerte kromaer, så interpolasjonen
// holder ut til kanten av skjermens fargeområde.

/// En Munsell-notasjon, f.eks. 5R 4/14 eller N 5/.
public struct Munsell: Hashable, Codable, Sendable {
    /// Kulør som vinkel 0…100 på Munsell-sirkelen (0 = 10RP/0R, 5 = 5R, 15 = 5YR …).
    public var kulør: Double
    /// Valør 0…10 (0 = sort, 10 = hvitt).
    public var valør: Double
    /// Kroma ≥ 0 (0 = nøytral grå).
    public var kroma: Double

    public init(kulør: Double, valør: Double, kroma: Double) {
        self.kulør = kulør
        self.valør = valør
        self.kroma = kroma
    }

    public static let familier = ["R", "YR", "Y", "GY", "G", "BG", "B", "PB", "P", "RP"]

    /// Notasjon slik den skrives: «5R 4/14», «2.5PB 6/8» eller «N 5/» for nøytrale.
    public var notasjon: String {
        let v = Self.tall(valør, maks: 1)
        guard kroma >= 0.25 else { return "N \(v)/" }
        return "\(kulørnavn) \(v)/\(Self.tall(kroma, maks: 1))"
    }

    /// Kulørdelen, f.eks. «5R» eller «2.5PB».
    public var kulørnavn: String {
        var h = kulør.truncatingRemainder(dividingBy: 100)
        if h < 0 { h += 100 }
        var indeks = Int(h / 10)
        var tall = h - Double(indeks) * 10
        // 0 i en familie skrives som 10 i den forrige («10RP», ikke «0R»).
        if tall < 0.05 { tall = 10; indeks = (indeks + 9) % 10 }
        return "\(Self.tall(tall, maks: 1))\(Self.familier[indeks])"
    }

    private static func tall(_ v: Double, maks: Int) -> String {
        let avrundet = (v * 10).rounded() / 10
        return avrundet == avrundet.rounded() ? String(Int(avrundet)) : String(format: "%.1f", avrundet)
    }

    /// Tolker «5R 4/14», «5 R 4/14», «2.5PB 6/8», «N 5/» og «N5».
    public init?(_ tekst: String) {
        let t = tekst.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: ",", with: ".")
        let nøytral = /^N\s*([\d.]+)\s*\/?\s*$/
        if let m = t.firstMatch(of: nøytral), let v = Double(m.1) {
            self.init(kulør: 0, valør: v, kroma: 0)
            return
        }
        let mønster = /^([\d.]+)\s*([A-Z]{1,2})\s+([\d.]+)\s*\/\s*([\d.]+)$/
        guard let m = t.firstMatch(of: mønster), let tall = Double(m.1), let v = Double(m.3), let c = Double(m.4),
              let indeks = Self.familier.firstIndex(of: String(m.2)), (0...10).contains(tall), (0...10).contains(v), c >= 0
        else { return nil }
        self.init(kulør: (tall + Double(indeks) * 10).truncatingRemainder(dividingBy: 100), valør: v, kroma: c)
    }

    // MARK: - Valør ↔ luminans (ASTM D1535)

    /// Luminans Y (0…1, relativt til perfekt diffus hvit) for en valør.
    public static func luminans(forValør v: Double) -> Double {
        // ASTM D1535-08: Y = 1,1914 V − 0,22533 V² + 0,23352 V³ − 0,020484 V⁴ + 0,00081939 V⁵ (Y i prosent).
        let y = 1.1914 * v - 0.22533 * pow(v, 2) + 0.23352 * pow(v, 3) - 0.020484 * pow(v, 4) + 0.00081939 * pow(v, 5)
        return max(0, y / 100)
    }

    /// Valør for en luminans Y (0…1), ved invertering av ASTM-polynomet.
    public static func valør(forLuminans y: Double) -> Double {
        let mål = max(0, min(1, y))
        var lav = 0.0, høy = 10.0
        for _ in 0..<40 {
            let midt = (lav + høy) / 2
            if luminans(forValør: midt) < mål { lav = midt } else { høy = midt }
        }
        return (lav + høy) / 2
    }
}

/// Renotasjonsdataene og interpolasjon i dem.
enum MunsellTabell {
    struct Punkt { let kulør: Double; let valør: Double; let kroma: Double; let x: Double; let y: Double }

    /// Lyskilde C (kromatisitet 0,3101, 0,3162), som renotasjonsdataene gjelder for.
    static let hvitC = Vektor3(0.3101 / 0.3162, 1, (1 - 0.3101 - 0.3162) / 0.3162)
    static let cTilD65 = Matriser.bradford(fra: hvitC, til: Matriser.hvitD65)
    static let d65TilC = cTilD65.invertert

    static let valører: [Double] = [0.2, 0.4, 0.6, 0.8, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    /// Kulørene i tabellen: 0, 2,5, 5, 7,5 … 97,5.
    static let kulører: [Double] = (0..<40).map { Double($0) * 2.5 }

    /// (kulørindeks, valør) → punkter sortert etter kroma, med nøytralpunktet (kroma 0) først.
    static let kart: [Int: [Double: [Punkt]]] = {
        guard let url = Bundle.module.url(forResource: "Munsell", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rader = try? JSONDecoder().decode([[Double]].self, from: data)
        else { return [:] }
        var k: [Int: [Double: [Punkt]]] = [:]
        for r in rader where r.count == 5 {
            let i = Int((r[0] / 2.5).rounded()) % 40
            k[i, default: [:]][r[1], default: []].append(Punkt(kulør: r[0], valør: r[1], kroma: r[2], x: r[3], y: r[4]))
        }
        for i in k.keys {
            for v in k[i]!.keys {
                var p = k[i]![v]!.sorted { $0.kroma < $1.kroma }
                // Nøytralpunktet er lyskilde C for alle kulører.
                p.insert(Punkt(kulør: Double(i) * 2.5, valør: v, kroma: 0, x: 0.3101, y: 0.3162), at: 0)
                k[i]![v] = p
            }
        }
        return k
    }()

    /// xy for gitt kulørindeks (0…39), valør i tabellen og kroma; lineært i kroma, ekstrapolert utover siste punkt.
    static func xy(kulørindeks i: Int, valør v: Double, kroma c: Double) -> (x: Double, y: Double)? {
        guard let p = kart[i]?[v], p.count >= 2 else { return nil }
        if c <= 0 { return (p[0].x, p[0].y) }
        var j = 1
        while j < p.count - 1 && p[j].kroma < c { j += 1 }
        let a = p[j - 1], b = p[j]
        let t = (c - a.kroma) / (b.kroma - a.kroma)
        return (a.x + t * (b.x - a.x), a.y + t * (b.y - a.y))
    }

    /// xy for vilkårlig kulør, valør og kroma: interpolasjon i kulør mellom tabellens kulører
    /// (i polare koordinater rundt nøytralpunktet) og i valør mellom tabellens valører.
    static func xy(kulør h: Double, valør v: Double, kroma c: Double) -> (x: Double, y: Double)? {
        let v1 = max(valører.first!, min(valører.last!, v))
        // Valør-naboer.
        var vLav = valører[0], vHøy = valører[0]
        for (a, b) in zip(valører, valører.dropFirst()) where v1 >= a && v1 <= b { vLav = a; vHøy = b; break }
        if v1 >= valører.last! { vLav = valører.last!; vHøy = vLav }
        func vedValør(_ vv: Double) -> (Double, Double)? {
            let hn = (h.truncatingRemainder(dividingBy: 100) + 100).truncatingRemainder(dividingBy: 100)
            let i0 = Int(hn / 2.5) % 40, i1 = (i0 + 1) % 40
            let t = (hn - Double(i0) * 2.5) / 2.5
            guard let p0 = xy(kulørindeks: i0, valør: vv, kroma: c), let p1 = xy(kulørindeks: i1, valør: vv, kroma: c) else { return nil }
            if t <= 0 { return p0 }
            // Polar interpolasjon rundt nøytralpunktet, så kulørsirkelen blir rund og ikke kuttet av korder.
            let nx = 0.3101, ny = 0.3162
            let r0 = hypot(p0.x - nx, p0.y - ny), r1 = hypot(p1.x - nx, p1.y - ny)
            var a0 = atan2(p0.y - ny, p0.x - nx), a1 = atan2(p1.y - ny, p1.x - nx)
            if a1 - a0 > .pi { a1 -= 2 * .pi }
            if a0 - a1 > .pi { a1 += 2 * .pi }
            let r = r0 + t * (r1 - r0), a = a0 + t * (a1 - a0)
            return (nx + r * cos(a), ny + r * sin(a))
        }
        guard let lav = vedValør(vLav) else { return nil }
        if vHøy == vLav { return lav }
        guard let høy = vedValør(vHøy) else { return lav }
        let t = (v1 - vLav) / (vHøy - vLav)
        return (lav.0 + t * (høy.0 - lav.0), lav.1 + t * (høy.1 - lav.1))
    }
}

public extension Farge {
    /// Fargen for en Munsell-notasjon (lyskilde C omregnet til D65 med Bradford). `nil` utenfor tabellen.
    init?(munsell m: Munsell, alfa: Double = 1) {
        let y = Munsell.luminans(forValør: m.valør)
        guard let xy = MunsellTabell.xy(kulør: m.kulør, valør: m.valør, kroma: m.kroma), xy.y > 0 else { return nil }
        let xyzC = Vektor3(xy.x * y / xy.y, y, (1 - xy.x - xy.y) * y / xy.y)
        let xyz = MunsellTabell.cTilD65 * xyzC
        self.init(xyz: XYZ(x: xyz.x, y: xyz.y, z: xyz.z), alfa: alfa)
    }

    /// Nærmeste Munsell-notasjon: valør fra luminansen, kulør og kroma ved iterasjon mot renotasjonsdataene.
    var munsell: Munsell {
        let xyzD65 = xyz
        let c = MunsellTabell.d65TilC * Vektor3(xyzD65.x, xyzD65.y, xyzD65.z)
        let valør = Munsell.valør(forLuminans: c.y)
        let sum = c.x + c.y + c.z
        guard sum > 0 else { return Munsell(kulør: 0, valør: 0, kroma: 0) }
        let mx = c.x / sum, my = c.y / sum
        let nx = 0.3101, ny = 0.3162
        let avstand = hypot(mx - nx, my - ny)
        if avstand < 0.0015 { return Munsell(kulør: 0, valør: valør, kroma: 0) }
        // Start: vinkelen i xy gir en grov kulør; kroma fra forholdet til tabellens kroma 2 ved samme vinkel.
        var h = Self.startkulør(vinkel: atan2(my - ny, mx - nx), valør: valør)
        var k = 2.0
        if let p = MunsellTabell.xy(kulør: h, valør: valør, kroma: 2) {
            let r2 = hypot(p.x - nx, p.y - ny)
            if r2 > 0 { k = 2 * avstand / r2 }
        }
        // Newton-lignende iterasjon i (h, k) mot målets xy.
        for _ in 0..<40 {
            guard let p = MunsellTabell.xy(kulør: h, valør: valør, kroma: k) else { break }
            let fx = p.x - mx, fy = p.y - my
            if hypot(fx, fy) < 1e-5 { break }
            let dh = 0.5, dk = 0.1
            guard let ph = MunsellTabell.xy(kulør: h + dh, valør: valør, kroma: k),
                  let pk = MunsellTabell.xy(kulør: h, valør: valør, kroma: k + dk) else { break }
            let j11 = (ph.x - p.x) / dh, j12 = (pk.x - p.x) / dk
            let j21 = (ph.y - p.y) / dh, j22 = (pk.y - p.y) / dk
            let det = j11 * j22 - j12 * j21
            guard abs(det) > 1e-12 else { break }
            let sh = (j22 * fx - j12 * fy) / det, sk = (-j21 * fx + j11 * fy) / det
            h -= max(-10, min(10, sh))
            k = max(0, k - max(-4, min(4, sk)))
            h = (h.truncatingRemainder(dividingBy: 100) + 100).truncatingRemainder(dividingBy: 100)
        }
        return Munsell(kulør: h, valør: valør, kroma: k)
    }

    /// Kuløren i tabellen hvis xy-vinkel ligger nærmest målets vinkel (ved kroma 4 og gitt valør).
    private static func startkulør(vinkel: Double, valør: Double) -> Double {
        var beste = 0.0, minst = Double.infinity
        for h in MunsellTabell.kulører {
            guard let p = MunsellTabell.xy(kulør: h, valør: valør, kroma: 4) else { continue }
            var d = abs(atan2(p.y - 0.3162, p.x - 0.3101) - vinkel)
            if d > .pi { d = 2 * .pi - d }
            if d < minst { minst = d; beste = h }
        }
        return beste
    }
}
