import FargeKjerne
import Foundation

/// Deterministisk reserve når Apple Intelligence ikke er tilgjengelig (eldre enheter,
/// slått av, eller språket ikke støttet). Bruker samme kunnskapsbase som språkmodellen
/// (``Fargesemantikk``): de tyngste kulørfamiliene blir primær og sekundær, og paletten
/// komponeres av ``Palettkomponist`` etter samme regler som med språkmodellen.
public struct LeksikonTolker: VerdiordTolker {
    public init() {}

    public func forslag(for verdiord: String, antall: Int) async throws -> PalettForslag {
        forslag(for: verdiord, antall: antall, gamut: .displayP3)
    }

    public func forslag(for verdiord: String, antall: Int, gamut: Gamut) -> PalettForslag {
        let grunnlag = Fargesemantikk.oppslag(verdiord)
        return Palettolkning(grunnlag: grunnlag, gamut: gamut).forslag(antall: antall, grunnlag: grunnlag, gamut: gamut)
    }
}
