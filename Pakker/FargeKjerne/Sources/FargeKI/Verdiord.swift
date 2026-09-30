import FargeKjerne
import Foundation

/// Et foreslått fargevalg med begrunnelse knyttet til verdiordene.
public struct Fargeforslag: Sendable, Hashable, Identifiable {
    public var id = UUID()
    public var navn: String
    public var rolle: String
    public var begrunnelse: String
    public var farge: Farge
    /// Fargen i fargespråket (familie · lyshet · metning), når den ble valgt slik.
    public var spesifikasjon: Fargespesifikasjon?

    /// Rollen som visningsnavn på appens språk (rollene er norske internt).
    public var rollenavn: String {
        switch rolle.lowercased() {
        case "primær": String(localized: "Primær", bundle: .module)
        case "sekundær": String(localized: "Sekundær", bundle: .module)
        case "aksent": String(localized: "Aksent", bundle: .module)
        case "bakgrunn": String(localized: "Bakgrunn", bundle: .module)
        case "tekst": String(localized: "Tekst", bundle: .module)
        case "støtte": String(localized: "Støtte", bundle: .module)
        default: rolle.capitalized
        }
    }

    public init(navn: String, rolle: String, begrunnelse: String, farge: Farge, spesifikasjon: Fargespesifikasjon? = nil) {
        self.navn = navn
        self.rolle = rolle
        self.begrunnelse = begrunnelse
        self.farge = farge
        self.spesifikasjon = spesifikasjon
    }
}

public struct PalettForslag: Sendable, Hashable {
    public var tittel: String
    public var forklaring: String
    public var farger: [Fargeforslag]
    /// Hvilken motor som laget forslaget (vises for åpenhet overfor brukeren).
    public var kilde: Kilde
    /// Begrepene fra kunnskapsbasen forslaget bygger på (vises for åpenhet).
    public var grunnlag: [String]

    public enum Kilde: String, Sendable { case appleIntelligence, leksikon }

    public init(tittel: String, forklaring: String, farger: [Fargeforslag], kilde: Kilde, grunnlag: [String] = []) {
        self.tittel = tittel
        self.forklaring = forklaring
        self.farger = farger
        self.kilde = kilde
        self.grunnlag = grunnlag
    }

    public var palett: Palett {
        Palett(navn: tittel, farger: farger.map { PalettFarge(navn: $0.navn, farge: $0.farge, opphav: .ki) })
    }

    /// Alle fargene gamut-kartlagt til `gamut` (f.eks. sRGB når brukeren har begrenset til det).
    public func begrenset(til gamut: Gamut) -> PalettForslag {
        var kopi = self
        for i in kopi.farger.indices { kopi.farger[i].farge = kopi.farger[i].farge.gamutKartlagt(til: gamut) }
        return kopi
    }

    /// Håndhever rollene: bakgrunn blir tydelig lys eller mørk (samme kulør, lite kroma),
    /// og tekst oppfyller WCAG AA mot bakgrunnen. Små modeller bommer ofte her.
    public func medRolleregler() -> PalettForslag {
        var kopi = self
        for i in kopi.farger.indices where kopi.farger[i].rolle.lowercased().contains("bakgrunn") {
            var lch = kopi.farger[i].farge.okLCH
            if lch.l < 0.3 {
                lch.l = min(lch.l, 0.22)
            } else {
                lch.l = max(lch.l, 0.95)
            }
            lch.c = min(lch.c, 0.025)
            kopi.farger[i].farge = Farge(okLCH: lch).gamutKartlagt(til: .displayP3)
            kopi.farger[i].spesifikasjon = nil
        }
        return kopi.medSikretLesbarhet()
    }

    /// Sikrer at tekst-fargen oppfyller WCAG AA (4,5:1) mot bakgrunnsfargen.
    /// Modellen treffer ikke alltid på lyshet; dette retter det deterministisk.
    public func medSikretLesbarhet() -> PalettForslag {
        guard let bakgrunn = farger.first(where: { $0.rolle.lowercased().contains("bakgrunn") })?.farge else { return self }
        var kopi = self
        for i in kopi.farger.indices where kopi.farger[i].rolle.lowercased().contains("tekst") {
            let justert = kopi.farger[i].farge.medKontrast(mot: bakgrunn, minst: WCAGKrav.aaTekst.minimum)
            if justert != kopi.farger[i].farge { kopi.farger[i].spesifikasjon = nil }
            kopi.farger[i].farge = justert
        }
        return kopi
    }
}

/// Oversetter verdiord (f.eks. «trygg, varm, nordisk») til fargeforslag.
public protocol VerdiordTolker: Sendable {
    func forslag(for verdiord: String, antall: Int) async throws -> PalettForslag
}

public enum Verdiordtjeneste {
    /// Apple Intelligence (på enheten) når tilgjengelig, ellers det innebygde leksikonet.
    public static func beste() -> any VerdiordTolker {
        #if canImport(FoundationModels)
        if KIStatus.gjeldende.erKlar { return AppleIntelligenceTolker() }
        #endif
        return LeksikonTolker()
    }
}
