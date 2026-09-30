import Foundation

/// En navngitt farge i en palett.
public struct PalettFarge: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var navn: String
    public var farge: Farge
    /// Hvordan fargen ble til – nyttig for å kunne regenerere overganger og skalaer.
    public var opphav: Opphav

    public enum Opphav: String, Codable, Sendable {
        case manuell, kamera, pipette, ki, overgang, toneskala, bilde
    }

    public init(id: UUID = UUID(), navn: String = "", farge: Farge, opphav: Opphav = .manuell) {
        self.id = id
        self.navn = navn
        self.farge = farge
        self.opphav = opphav
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
