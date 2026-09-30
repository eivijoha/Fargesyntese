import Foundation

/// Deterministisk norsk beskrivelse av en farge, f.eks. «lys dempet blågrønn».
///
/// Brukes som faktagrunnlag for språkmodellen (små modeller gjetter dårlig ut fra tall),
/// og som VoiceOver-tekst.
public enum Fargebeskrivelse {
    /// Kulørnavn etter OKLCH-kulør (grader). Hver post gjelder fra og med gradtallet.
    static let kulører: [(Double, String)] = [
        (0, String(localized: "rosa", bundle: .module)), (15, String(localized: "rød", bundle: .module)), (42, String(localized: "oransje", bundle: .module)), (80, String(localized: "gul", bundle: .module)), (112, String(localized: "gulgrønn", bundle: .module)), (130, String(localized: "grønn", bundle: .module)),
        (165, String(localized: "blågrønn", bundle: .module)), (195, String(localized: "turkis", bundle: .module)), (225, String(localized: "blå", bundle: .module)), (268, String(localized: "indigo", bundle: .module)), (285, String(localized: "fiolett", bundle: .module)),
        (318, String(localized: "magenta", bundle: .module)), (345, String(localized: "rosa", bundle: .module)),
    ]

    public static func kulørnavn(_ h: Double) -> String {
        let g = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return kulører.last { $0.0 <= g }!.1
    }

    public static func beskriv(_ farge: Farge) -> String {
        let f = farge.okLCH
        let (l, c, h) = (f.l, f.c, f.h)

        if c < 0.02 {
            if l > 0.96 { return String(localized: "hvit", bundle: .module) }
            if l < 0.18 { return String(localized: "sort", bundle: .module) }
            let tone = c < 0.008 ? String(localized: "grå", bundle: .module) : (40...110).contains(h) ? String(localized: "varmgrå", bundle: .module) : (200...290).contains(h) ? String(localized: "kaldgrå", bundle: .module) : String(localized: "grå", bundle: .module)
            return (l > 0.7 ? String(localized: "lys", bundle: .module) + " " : l < 0.4 ? String(localized: "mørk", bundle: .module) + " " : "") + tone
        }

        let navn = kulørnavn(h)
        // Egne navn der kulør alene villeder.
        if (30...100).contains(h), l < 0.55, c < 0.14 { return (l < 0.35 ? String(localized: "mørk", bundle: .module) + " " : "") + String(localized: "brun", bundle: .module) }
        if (40...110).contains(h), l > 0.82, c < 0.07 { return String(localized: "beige", bundle: .module) }
        if (345...360).contains(h) || h < 15, l < 0.45 { return String(localized: "vinrød", bundle: .module) }

        let lyshet = l < 0.35 ? String(localized: "mørk", bundle: .module) : l < 0.55 ? String(localized: "dyp", bundle: .module) : l < 0.78 ? "" : l < 0.9 ? String(localized: "lys", bundle: .module) : String(localized: "blek", bundle: .module)
        let metning = c < 0.06 ? String(localized: "dempet", bundle: .module) : c < 0.15 ? "" : c < 0.22 ? String(localized: "klar", bundle: .module) : String(localized: "sterk", bundle: .module)
        return [lyshet, metning, navn].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
