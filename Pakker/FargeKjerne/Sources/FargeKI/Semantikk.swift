import FargeKjerne
import Foundation

/// Ett begrep i fargesemantikken: hvilke kulørfamilier, lysheter og metninger det tradisjonelt
/// forbindes med, og hvorfor. Grunnlaget er konvensjoner og kontekst (natur, materialer, stiler,
/// verdier) – ikke bransjeklisjeer. Paletten brukes i merkevarer, men det er formålet, ikke grunnlaget.
public struct Fargebegrep: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var kategori: String
    public var nb: [String]
    public var en: [String]
    public var familier: [String: Double]
    public var lyshet: [Lyshetsnivå]
    public var metning: [Metningsnivå]
    public var aksent: [Kulørfamilie]
    public var harmoni: String
    public var unngå: [Kulørfamilie]
    public var notat: String
    /// Om begrepet handler om noe brunt (jord, tre, lær …). Bare da får paletten brune toner.
    public var brunt: Bool?

    /// Navn på appens språk (norsk id, ellers første engelske synonym).
    public var visningsnavn: String { Språk.erNorsk ? id : (en.first ?? id) }

    /// Kulørfamiliene sortert etter vekt.
    public var sorterteFamilier: [(Kulørfamilie, Double)] {
        familier.compactMap { k, v in Kulørfamilie(rawValue: k).map { ($0, v) } }.sorted { $0.1 > $1.1 }
    }
}

/// Resultatet av et oppslag: begrepene som traff, og en samlet vekting.
public struct Begrepsgrunnlag: Sendable, Hashable {
    public struct Treff: Sendable, Hashable {
        public var begrep: Fargebegrep
        /// Ordet i brukerens tekst som traff.
        public var ord: String
    }

    public var treff: [Treff]

    public init(treff: [Treff] = []) { self.treff = treff }

    public var erTomt: Bool { treff.isEmpty }
    public var begreper: [Fargebegrep] { treff.map(\.begrep) }

    /// Summert vekt per kulørfamilie; første begrep teller mest.
    public var familievekter: [(Kulørfamilie, Double)] {
        var sum: [Kulørfamilie: Double] = [:]
        for (i, b) in begreper.enumerated() {
            let rangvekt = 1.0 / (1.0 + 0.25 * Double(i))
            for (f, v) in b.sorterteFamilier { sum[f, default: 0] += v * rangvekt }
        }
        return sum.sorted { $0.value > $1.value }
    }

    /// Om begrepene åpner for brune toner: bare begreper som uttrykkelig handler om noe brunt
    /// (jord, tre, lær, høst …). Ellers løftes varme, mørke farger ut av det brune.
    public var tillaterBrunt: Bool { begreper.contains { $0.brunt == true } }

    /// Brunvakt: løfter en varm, mørk farge til lysheten der den er klarest, når grunnlaget ikke ber om brunt.
    public func utenUønsketBrunt(_ spes: Fargespesifikasjon, rolle: String, gamut: Gamut) -> Fargespesifikasjon {
        guard spes.blirBrun, !tillaterBrunt, !["tekst", "bakgrunn"].contains(rolle.lowercased()) else { return spes }
        var ny = spes
        ny.lyshet = Fargespesifikasjon.klaresteLyshet(for: spes.familie, blant: [.middels, .lys, .sværtLys], i: gamut)
        return ny
    }

    /// Laveste metning som begrepene åpner for. Uten treff: «moderat» – fargene skal ha kulør.
    public var minsteMetning: Metningsnivå {
        begreper.flatMap(\.metning).min() ?? .moderat
    }

    /// Minste metning for en rolle. Aksent skal alltid ha tydelig farge; bakgrunn og tekst styres av rollereglene.
    public func minsteMetning(for rolle: String) -> Metningsnivå? {
        switch rolle.lowercased() {
        case "bakgrunn", "tekst": nil
        case "aksent": max(minsteMetning, .moderat)
        case "primær": max(minsteMetning, begreper.isEmpty ? .moderat : .svak)
        default: minsteMetning
        }
    }

    /// Fakta til språkmodellen, på norsk (instruksjonene er norske; svarspråket styres separat).
    public var fakta: String {
        guard !treff.isEmpty else {
            return """
            Ingen begreper i kunnskapsbasen passet ordene. Bruk skjønn, men gi fargene tydelig kulør \
            (metning moderat eller klar) med mindre ordene tilsier noe dempet.
            """
        }
        var linjer = ["Begrepsgrunnlag fra kunnskapsbasen:"]
        for t in treff {
            let b = t.begrep
            var del = ["kulørfamilier " + b.sorterteFamilier.map(\.0.rawValue).joined(separator: ", ")]
            del.append("lyshet " + b.lyshet.map(\.rawValue).joined(separator: "/"))
            del.append("metning " + b.metning.map(\.rawValue).joined(separator: "/"))
            if !b.aksent.isEmpty { del.append("aksent " + b.aksent.map(\.rawValue).joined(separator: "/")) }
            del.append("harmoni " + b.harmoni)
            if !b.unngå.isEmpty { del.append("unngå " + b.unngå.map(\.rawValue).joined(separator: "/")) }
            linjer.append("- \(b.id) (fra «\(t.ord)»): " + del.joined(separator: " · ") + (b.notat.isEmpty ? "" : ". \(b.notat)"))
        }
        let vekter = familievekter.prefix(5).map { "\($0.0.rawValue) \(String(format: "%.1f", $0.1))" }
        linjer.append("Samlet vekting av kulørfamilier: " + vekter.joined(separator: ", ") + ".")
        linjer.append("Primær- og sekundærfarge hentes fra de tyngste familiene. Metning minst «\(minsteMetning.rawValue)» for primær, sekundær og støtte, og minst «\(max(minsteMetning, .moderat).rawValue)» for aksent.")
        return linjer.joined(separator: "\n")
    }
}

/// Kunnskapsbasen (`Fargesemantikk.json`) og oppslag i den.
public enum Fargesemantikk {
    struct Fil: Codable { var versjon: Int; var begreper: [Fargebegrep] }

    public static let begreper: [Fargebegrep] = {
        guard let url = Bundle.module.url(forResource: "Fargesemantikk", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let fil = try? JSONDecoder().decode(Fil.self, from: data)
        else { return [] }
        return fil.begreper
    }()

    /// Finner begrepene i en fritekst (norsk eller engelsk). Flerords-uttrykk («klar luft») går foran
    /// enkeltord; ord treffer også bøyde former og avledninger («trygghet» → «trygg»).
    /// Visningsnavn for begreper gitt ved id (f.eks. `PalettForslag.grunnlag`).
    public static func visningsnavn(_ ider: [String]) -> [String] {
        ider.map { id in begreper.first { $0.id == id }?.visningsnavn ?? id }
    }

    public static func oppslag(_ tekst: String) -> Begrepsgrunnlag {
        let normalisert = " " + tekst.lowercased()
            .map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ").joined(separator: " ") + " "

        var funn: [(posisjon: Int, Begrepsgrunnlag.Treff)] = []
        func legg(_ b: Fargebegrep, _ ord: String, _ posisjon: Int) {
            if let i = funn.firstIndex(where: { $0.1.begrep.id == b.id }) {
                if posisjon < funn[i].posisjon { funn[i] = (posisjon, .init(begrep: b, ord: ord)) }
            } else {
                funn.append((posisjon, .init(begrep: b, ord: ord)))
            }
        }

        // Flerords-uttrykk («klar luft», «art deco»).
        for (synonym, b) in ordliste where synonym.contains(" ") || synonym.contains("-") {
            if let r = normalisert.range(of: " \(synonym) ") {
                legg(b, synonym, normalisert.distance(from: normalisert.startIndex, to: r.lowerBound))
            }
        }
        // Enkeltord, med bøyning og sammensetninger («havblå» → hav + blå, «skogsgrønn» → skog + grønn).
        var posisjon = 0
        for del in normalisert.split(separator: " ", omittingEmptySubsequences: false) {
            let ord = String(del)
            defer { posisjon += ord.count + 1 }
            guard !ord.isEmpty else { continue }
            // Eksakt ord, så sammensetning, så bøyd form («skogsgrønn» er skog + grønn, ikke en bøyning av «skogs»).
            if let t = ordliste.first(where: { $0.0 == ord }) {
                legg(t.1, t.0, posisjon)
            } else if let (venstre, høyre) = sammensetning(ord) {
                legg(venstre.0, venstre.1, posisjon)
                legg(høyre.0, høyre.1, posisjon + 1)
            } else if let (b, synonym) = begrep(for: ord) {
                legg(b, synonym, posisjon)
            }
        }
        return Begrepsgrunnlag(treff: funn.sorted { $0.posisjon < $1.posisjon }.map(\.1))
    }

    /// Alle synonymer (små bokstaver) med begrepet de hører til, i kunnskapsbasens rekkefølge.
    static let ordliste: [(String, Fargebegrep)] = begreper.flatMap { b in (b.nb + b.en).map { ($0.lowercased(), b) } }

    static func begrep(for ord: String) -> (Fargebegrep, String)? {
        // Eksakt treff først, så bøyde former.
        if let t = ordliste.first(where: { $0.0 == ord }) { return (t.1, t.0) }
        return ordliste.first { !$0.0.contains(" ") && passer(ord, $0.0) }.map { ($0.1, $0.0) }
    }

    /// Deler et sammensatt ord i to kjente ord, med eventuell fuge-s/-e («skogs-grønn»).
    static func sammensetning(_ ord: String) -> ((Fargebegrep, String), (Fargebegrep, String))? {
        let tegn = Array(ord)
        guard tegn.count >= 6 else { return nil }
        for kutt in 3...(tegn.count - 3) {
            let venstre = String(tegn[..<kutt]), høyre = String(tegn[kutt...])
            guard let h = begrep(for: høyre) else { continue }
            for v in [venstre, String(venstre.dropLast())] where venstre.count - v.count == 0 || ["s", "e"].contains(venstre.last.map(String.init) ?? "") {
                if let t = ordliste.first(where: { $0.0 == v }) { return ((t.1, t.0), h) }
            }
        }
        return nil
    }

    /// Eksakt treff, eller bøyd form/avledning av et ord på minst fire bokstaver.
    static func passer(_ ord: String, _ synonym: String) -> Bool {
        if ord == synonym { return true }
        guard synonym.count >= 4, ord.hasPrefix(synonym) else { return false }
        return ord.count - synonym.count <= 4
    }
}
