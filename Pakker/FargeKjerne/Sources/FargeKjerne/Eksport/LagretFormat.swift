import Foundation

/// Hjelpere for eksport som tar hensyn til formatet en farge ble lagret i.
extension PalettFarge {
    /// CMYK-verdier (0…1) når fargen er lagret i CMYK-modellen eller i en CMYK-profil (4 komponenter).
    var lagretCMYK: [Double]? {
        guard let r = representasjon, r.verdier.count == 4 else { return nil }
        switch r.rom {
        case .modell(.cmyk), .icc: return r.verdier.map { $0.klampet(0, 1) }
        default: return nil
        }
    }

    /// Navnet på ICC-profilen fargen er lagret i, hvis noen.
    var lagretProfilnavn: String? {
        if case .icc(_, let navn) = representasjon?.rom { return navn }
        return nil
    }

    /// CIELab-verdier når fargen er lagret i CIELab eller LCH.
    var lagretLab: CIELab? {
        guard let r = representasjon else { return nil }
        switch r.rom {
        case .modell(.cieLab), .modell(.cieLCH): return farge.cieLab
        default: return nil
        }
    }

    /// Lagret modell når den har en CSS Color 4-syntaks.
    var lagretCSSModell: Fargemodell? {
        guard case .modell(let m) = representasjon?.rom else { return nil }
        return [.okLCH, .okLab, .cieLCH, .cieLab, .hsl, .rgb, .displayP3].contains(m) ? m : nil
    }
}
