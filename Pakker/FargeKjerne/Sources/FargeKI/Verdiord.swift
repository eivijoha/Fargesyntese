import FargeKjerne
import Foundation

/// Et foreslått fargevalg med begrunnelse knyttet til verdiordene.
public struct Fargeforslag: Sendable, Hashable, Identifiable {
    public let id = UUID()
    public var navn: String
    public var rolle: String
    public var begrunnelse: String
    public var farge: Farge
}

public struct PalettForslag: Sendable, Hashable {
    public var tittel: String
    public var forklaring: String
    public var farger: [Fargeforslag]
    /// Hvilken motor som laget forslaget (vises for åpenhet overfor brukeren).
    public var kilde: Kilde

    public enum Kilde: String, Sendable { case appleIntelligence, leksikon }

    public var palett: Palett {
        Palett(navn: tittel, farger: farger.map { PalettFarge(navn: $0.navn, farge: $0.farge, opphav: .ki) })
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
        if AppleIntelligenceTolker.erTilgjengelig { return AppleIntelligenceTolker() }
        #endif
        return LeksikonTolker()
    }
}
