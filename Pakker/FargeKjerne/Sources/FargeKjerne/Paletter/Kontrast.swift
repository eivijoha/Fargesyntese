import Foundation

public extension Farge {
    /// WCAG 2.x kontrastforhold (1…21), beregnet på sRGB-klippet luminans.
    func wcagKontrast(mot annen: Farge) -> Double {
        let a = klippet(til: .sRGB).luminans, b = annen.klippet(til: .sRGB).luminans
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Passende tekstfarge (sort/hvit) oppå denne fargen.
    var lesbarTekstfarge: Farge {
        let hvit = Farge(lineærR: 1, g: 1, b: 1), sort = Farge(lineærR: 0, g: 0, b: 0)
        return wcagKontrast(mot: hvit) >= wcagKontrast(mot: sort) ? hvit : sort
    }
}
