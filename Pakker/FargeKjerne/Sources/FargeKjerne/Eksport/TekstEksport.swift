import Foundation

enum TekstEksport {
    private static func navn(_ p: Palett) -> [String] {
        Identifikator.unike(p.farger.enumerated().map { i, f in Identifikator.kebab(f.navn, reserve: "farge-\(i + 1)") })
    }

    static func css(_ p: Palett) -> String {
        let n = navn(p)
        let sRGB = zip(n, p.farger).map { "  --\($0): \($1.farge.hex(medAlfa: $1.farge.alfa < 1));" }
        // Moderne verdi i lagret modell når CSS har syntaks for den, ellers OKLCH.
        let oklch = zip(n, p.farger).map { "    --\($0): \(($1.lagretCSSModell ?? .okLCH).tekst(for: $1.farge));" }
        return """
        /* \(p.navn) – eksportert fra Fargesyntese */
        :root {
        \(sRGB.joined(separator: "\n"))
        }

        @supports (color: oklch(0 0 0)) {
          :root {
        \(oklch.joined(separator: "\n"))
          }
        }

        """
    }

    /// W3C Design Tokens Community Group-format (2025.10), fargeverdier som objekter med fargerom.
    static func designTokens(_ p: Palett) -> Data {
        var gruppe: [String: Any] = ["$type": "color", "$description": p.navn]
        for (n, f) in zip(navn(p), p.farger) {
            let (rom, komp) = dtcgVerdi(f)
            var token: [String: Any] = [
                "$value": [
                    "colorSpace": rom,
                    "components": komp.map { ($0 * 10000).rounded() / 10000 },
                    "alpha": f.farge.alfa,
                    "hex": f.farge.hex(),
                ] as [String: Any],
            ]
            // CMYK og ICC-profiler har ikke DTCG-fargerom; de lagrede verdiene følger med som utvidelse.
            if let cmyk = f.lagretCMYK {
                var ext: [String: Any] = ["cmyk": cmyk.map { ($0 * 10000).rounded() / 10000 }]
                if let profil = f.lagretProfilnavn { ext["iccProfil"] = profil }
                token["$extensions"] = ["no.engenett.fargesyntese": ext]
            }
            gruppe[n] = token
        }
        let rot = [Identifikator.kebab(p.navn, reserve: "palett"): gruppe]
        return (try? JSONSerialization.data(withJSONObject: rot, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    /// DTCG-fargerom og komponenter etter lagret modell (OKLCH når modellen ikke finnes i DTCG).
    private static func dtcgVerdi(_ f: PalettFarge) -> (String, [Double]) {
        let farge = f.farge
        switch f.lagretCSSModell {
        case .okLab?: let v = farge.okLab; return ("oklab", [v.l, v.a, v.b])
        case .cieLab?: let v = farge.cieLab; return ("lab", [v.l, v.a, v.b])
        case .cieLCH?: let v = farge.cieLCH; return ("lch", [v.l, v.c, v.h])
        case .hsl?: let v = farge.hsl; return ("hsl", [v.h, v.s * 100, v.l * 100])
        case .rgb?: let v = farge.gamutKartlagt(til: .sRGB).sRGB; return ("srgb", [v.r, v.g, v.b])
        case .displayP3?: let v = farge.gamutKartlagt(til: .displayP3).displayP3; return ("display-p3", [v.r, v.g, v.b])
        default: let v = farge.okLCH; return ("oklch", [v.l, v.c, v.h])
        }
    }

    static func gpl(_ p: Palett) -> String {
        var linjer = ["GIMP Palette", "Name: \(p.navn)", "Columns: \(min(max(p.farger.count, 1), 16))", "#"]
        for f in p.farger {
            let s = f.farge.gamutKartlagt(til: .sRGB).sRGB
            let k = [s.r, s.g, s.b].map { Int(($0.klampet(0, 1) * 255).rounded()) }
            linjer.append(String(format: "%3d %3d %3d\t%@", k[0], k[1], k[2], f.visningsnavn))
        }
        return linjer.joined(separator: "\n") + "\n"
    }

    static func swiftUI(_ p: Palett) -> String {
        let typenavn = Identifikator.camel(p.navn, reserve: "palett").prefix(1).uppercased()
            + Identifikator.camel(p.navn, reserve: "palett").dropFirst()
        let egenskaper = zip(p.farger.indices, p.farger).map { i, f -> String in
            let id = Identifikator.camel(f.navn, reserve: "farge\(i + 1)")
            let d = f.farge.gamutKartlagt(til: .displayP3).displayP3
            let v = [d.r, d.g, d.b].map { String(format: "%.4f", $0.klampet(0, 1)) }
            return "    static let \(id) = Color(.displayP3, red: \(v[0]), green: \(v[1]), blue: \(v[2]), opacity: \(String(format: "%.3f", f.farge.alfa))) // \(f.farge.hex())"
        }
        return """
        // \(p.navn) – eksportert fra Fargesyntese
        import SwiftUI

        enum \(typenavn) {
        \(egenskaper.joined(separator: "\n"))
        }

        """
    }

    /// Figma «Import variables» (DTCG): én variabelsamling med en fargevariabel per farge.
    /// Figma forventer sRGB-komponenter 0…1; P3-farger gamut-kartlegges.
    static func figmaVariabler(_ p: Palett) -> Data {
        var samling: [String: Any] = [:]
        for (n, f) in zip(navn(p), p.farger) {
            let s = f.farge.gamutKartlagt(til: .sRGB).sRGB
            samling[n] = [
                "$type": "color",
                "$value": [
                    "colorSpace": "srgb",
                    "components": [s.r, s.g, s.b].map { ($0.klampet(0, 1) * 10000).rounded() / 10000 },
                    "alpha": f.farge.alfa,
                    "hex": f.farge.hex(),
                ] as [String: Any],
                "$description": Fargemodell.okLCH.tekst(for: f.farge),
            ] as [String: Any]
        }
        let rot = [Identifikator.kebab(p.navn, reserve: "palett"): samling]
        return (try? JSONSerialization.data(withJSONObject: rot, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    /// Tokens Studio-format: `{ gruppe: { navn: { value, type } } }`.
    static func tokensStudio(_ p: Palett) -> Data {
        var gruppe: [String: Any] = [:]
        for (n, f) in zip(navn(p), p.farger) {
            gruppe[n] = ["value": f.farge.hex(medAlfa: f.farge.alfa < 1), "type": "color",
                         "description": Fargemodell.okLCH.tekst(for: f.farge)]
        }
        let rot = [Identifikator.kebab(p.navn, reserve: "palett"): gruppe]
        return (try? JSONSerialization.data(withJSONObject: rot, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    /// Fargeprøver som SVG. Rutene får fargenavnet som id, så de heter riktig etter innliming.
    static func svg(_ p: Palett, rute: Int = 96, mellomrom: Int = 8) -> String {
        let bredde = max(p.farger.count, 1) * (rute + mellomrom) - mellomrom
        let ruter = zip(navn(p), p.farger).enumerated().map { i, par in
            let (n, f) = par
            let x = i * (rute + mellomrom)
            let opasitet = f.farge.alfa < 1 ? " fill-opacity=\"\(String(format: "%.3f", f.farge.alfa))\"" : ""
            return "  <rect id=\"\(n)\" x=\"\(x)\" y=\"0\" width=\"\(rute)\" height=\"\(rute)\" rx=\"8\" fill=\"\(f.farge.hex())\"\(opasitet)><title>\(xml(f.visningsnavn))</title></rect>"
        }
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(bredde)" height="\(rute)" viewBox="0 0 \(bredde) \(rute)">
          <title>\(xml(p.navn))</title>
        \(ruter.joined(separator: "\n"))
        </svg>

        """
    }

    private static func xml(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
