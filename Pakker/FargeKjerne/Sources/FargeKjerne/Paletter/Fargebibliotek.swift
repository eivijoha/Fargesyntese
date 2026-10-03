import CryptoKit
import Foundation

/// Et importert fargebibliotek (ASE, ACO eller ACB), f.eks. et fargekart med navngitte toner.
/// Brukes som «fargerom» i Studio: nærmeste tone vises ved siden av fargen, og «Begrens nye farger»
/// låser fargen til nærmeste tone. Id-en er en hash av filen, så valget er stabilt mellom enheter.
public struct Fargebibliotek: Sendable, Hashable, Identifiable {
    public let id: String
    public let navn: String
    public let farger: [PalettFarge]

    public init(data: Data, filnavn: String) throws {
        let palett = try Bibliotekimport.les(data, filnavn: filnavn)
        self.navn = palett.navn
        self.farger = palett.farger
        self.id = "bib:" + SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    public static func erBibliotekID(_ id: String) -> Bool { id.hasPrefix("bib:") }

    /// Nærmeste tone etter ΔE2000, med avstanden.
    public func nærmeste(til farge: Farge) -> (tone: PalettFarge, avstand: Double)? {
        var beste: (PalettFarge, Double)?
        for t in farger {
            let d = farge.deltaE2000(til: t.farge)
            if beste == nil || d < beste!.1 { beste = (t, d) }
        }
        return beste.map { (tone: $0.0, avstand: $0.1) }
    }
}
