import Foundation

/// Hvordan en lagret farge ble uttrykt da den ble lagret: i en fargemodell (OKLCH, CMYK …)
/// eller i et ICC-fargerom, med verdiene der. Selve fargen (`Farge`) er fortsatt kanonisk;
/// representasjonen bevarer brukerens valg av modell/rom og de nøyaktige verdiene.
public struct Fargerepresentasjon: Hashable, Codable, Sendable {
    public enum Rom: Hashable, Codable, Sendable {
        case modell(Fargemodell)
        case icc(id: String, navn: String)
    }

    public var rom: Rom
    public var verdier: [Double]
    /// Verdiene formatert slik de ble vist da fargen ble lagret, f.eks. «oklch(0.593 0.156 253.9)»
    /// eller «78 / 41 / 0 / 15 %».
    public var tekst: String

    public init(rom: Rom, verdier: [Double], tekst: String) {
        self.rom = rom
        self.verdier = verdier
        self.tekst = tekst
    }

    /// Representasjon i en fargemodell.
    public init(modell: Fargemodell, farge: Farge) {
        self.init(rom: .modell(modell), verdier: modell.verdier(for: farge), tekst: modell.tekst(for: farge))
    }

    public var romnavn: String {
        switch rom {
        case .modell(let m): m.navn
        case .icc(_, let navn): navn
        }
    }
}

/// En navngitt farge i en palett.
public struct PalettFarge: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var navn: String
    public var farge: Farge
    /// Hvordan fargen ble til – nyttig for å kunne regenerere overganger og skalaer.
    public var opphav: Opphav
    /// Fargemodell/fargerom fargen ble lagret i (nil for eldre farger og farger uten valgt rom).
    public var representasjon: Fargerepresentasjon?

    public enum Opphav: String, Codable, Sendable {
        case manuell, kamera, pipette, ki, overgang, toneskala, bilde, bibliotek
    }

    public init(id: UUID = UUID(), navn: String = "", farge: Farge, opphav: Opphav = .manuell,
                representasjon: Fargerepresentasjon? = nil) {
        self.id = id
        self.navn = navn
        self.farge = farge
        self.opphav = opphav
        self.representasjon = representasjon
    }
}

/// Plattformnøytral palett. Appen persisterer denne (SwiftData), eksportørene leser den.
public struct Palett: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var navn: String
    public var farger: [PalettFarge]

    public init(id: UUID = UUID(), navn: String, farger: [PalettFarge] = []) {
        self.id = id
        self.navn = navn
        self.farger = farger
    }
}

public extension PalettFarge {
    /// Navn hvis satt, ellers hex.
    var visningsnavn: String { navn.isEmpty ? farge.hex() : navn }
}
