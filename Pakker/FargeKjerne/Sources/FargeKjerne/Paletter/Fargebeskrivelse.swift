import Foundation

/// Deterministisk norsk beskrivelse av en farge, f.eks. «lys dempet blågrønn».
///
/// Brukes som faktagrunnlag for språkmodellen (små modeller gjetter dårlig ut fra tall),
/// og som VoiceOver-tekst.
public enum Fargebeskrivelse {
    /// Kulørnavn etter OKLCH-kulør (grader). Hver post gjelder fra og med gradtallet.
    static let kulører: [(Double, String)] = [
        (0, "rosa"), (15, "rød"), (42, "oransje"), (80, "gul"), (112, "gulgrønn"), (130, "grønn"),
        (165, "blågrønn"), (195, "turkis"), (225, "blå"), (268, "indigo"), (285, "fiolett"),
        (318, "magenta"), (345, "rosa"),
    ]

    public static func kulørnavn(_ h: Double) -> String {
        let g = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        return kulører.last { $0.0 <= g }!.1
    }

    public static func beskriv(_ farge: Farge) -> String {
        let f = farge.okLCH
        let (l, c, h) = (f.l, f.c, f.h)

        if c < 0.02 {
            if l > 0.96 { return "hvit" }
            if l < 0.18 { return "sort" }
            let tone = c < 0.008 ? "grå" : (40...110).contains(h) ? "varmgrå" : (200...290).contains(h) ? "kaldgrå" : "grå"
            return (l > 0.7 ? "lys " : l < 0.4 ? "mørk " : "") + tone
        }

        let navn = kulørnavn(h)
        // Egne navn der kulør alene villeder.
        if (30...100).contains(h), l < 0.55, c < 0.14 { return (l < 0.35 ? "mørk " : "") + "brun" }
        if (40...110).contains(h), l > 0.82, c < 0.07 { return "beige" }
        if (345...360).contains(h) || h < 15, l < 0.45 { return "vinrød" }

        let lyshet = l < 0.35 ? "mørk" : l < 0.55 ? "dyp" : l < 0.78 ? "" : l < 0.9 ? "lys" : "blek"
        let metning = c < 0.06 ? "dempet" : c < 0.15 ? "" : c < 0.22 ? "klar" : "sterk"
        return [lyshet, metning, navn].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
