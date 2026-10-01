#if canImport(CoreGraphics)
import Foundation

/// «Rene» CMYK-verdier: så få trykkfarger som mulig, med det grå innslaget (felles C, M og Y)
/// flyttet til sort (GCR/UCR), så lenge fargen holder seg innenfor en synlig toleranse.
///
/// ICC-profilens egen separasjon gir ofte spor av en tredje eller fjerde farge (f.eks. 69/42/2/1),
/// som gir urene, ustabile toner i trykk. Her søkes det etter separasjonen med færrest farger der
/// fargen gjennom profilen (CMYK → farge) avviker under `toleranse` (ΔE00) fra profilens egen
/// gjengivelse. Finnes ingen slik, beholdes profilens verdier.
public enum RenCMYK {
    public struct Resultat: Sendable, Hashable {
        /// C, M, Y, K i 0…1, avrundet til hele prosent.
        public var verdier: [Double]
        /// ΔE00 mellom den rene separasjonen og profilens egen.
        public var avvik: Double
        /// Om verdiene er endret fra profilens egen separasjon.
        public var endret: Bool
    }

    /// Standard toleranse: under 1 ΔE00 regnes som ikke synlig forskjell.
    public static let standardtoleranse = 1.0

    public static func separer(_ farge: Farge, i profil: ICCProfil,
                               hensikt: Gjengivelseshensikt = .relativKolorimetrisk,
                               toleranse: Double = standardtoleranse) -> Resultat? {
        guard profil.modell == .cmyk, profil.antallKomponenter == 4,
              let start = farge.komponenter(i: profil, hensikt: hensikt),
              let mål = Farge(komponenter: start, i: profil, alfa: 1)
        else { return nil }
        let opprinnelig = start.map { min(max($0, 0), 1) }

        func gjengitt(_ v: [Double]) -> Farge? { Farge(komponenter: v, i: profil, alfa: 1) }
        func avvik(_ v: [Double]) -> Double { gjengitt(v)?.deltaE2000(til: mål) ?? .infinity }

        // Utgangspunkt med maksimal GCR: det felles grå i C, M og Y flyttes over i K.
        let grå = opprinnelig.prefix(3).min() ?? 0
        let gcr = [opprinnelig[0] - grå, opprinnelig[1] - grå, opprinnelig[2] - grå, min(1, opprinnelig[3] + grå)]

        var beste: (verdier: [Double], avvik: Double, antall: Int, blekk: Double)?
        // Alle kombinasjoner av aktive farger, færrest først.
        let delsett = (1..<16).map { maske in (0..<4).filter { maske & (1 << $0) != 0 } }
            .sorted { $0.count < $1.count }
        for aktive in delsett {
            if let b = beste, aktive.count > b.antall { break }
            for startpunkt in [gcr, opprinnelig] {
                var v = (0..<4).map { aktive.contains($0) ? startpunkt[$0] : 0 }
                var a = avvik(v)
                // Koordinatsøk med halverende steg.
                var steg = 0.08
                while steg > 0.002 {
                    var forbedret = false
                    for i in aktive {
                        for retning in [-1.0, 1.0] {
                            var prøve = v
                            prøve[i] = min(max(prøve[i] + retning * steg, 0), 1)
                            let pa = avvik(prøve)
                            if pa + 1e-6 < a { v = prøve; a = pa; forbedret = true }
                        }
                    }
                    if !forbedret { steg /= 2 }
                }
                // Hele prosent, og fjern spor under 0,5 %.
                let rundet = v.map { ($0 * 100).rounded() / 100 }
                let ra = avvik(rundet)
                guard ra <= toleranse else { continue }
                let antall = rundet.filter { $0 > 0 }.count
                let blekk = rundet.reduce(0, +)
                if beste == nil || antall < beste!.antall || (antall == beste!.antall && (ra < beste!.avvik - 0.05 || (abs(ra - beste!.avvik) <= 0.05 && blekk < beste!.blekk))) {
                    beste = (rundet, ra, antall, blekk)
                }
            }
        }
        let opprinneligRundet = opprinnelig.map { ($0 * 100).rounded() / 100 }
        guard let beste else { return Resultat(verdier: opprinneligRundet, avvik: avvik(opprinneligRundet), endret: false) }
        return Resultat(verdier: beste.verdier, avvik: beste.avvik, endret: beste.verdier != opprinneligRundet)
    }
}
#endif
