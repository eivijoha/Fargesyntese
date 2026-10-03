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

/// Lagringsformatet holdes lesbart for eldre versjoner av appen, som kan synkronisere de samme palettene
/// via iCloud. Kan ikke 1.0 lese én farge, blir hele paletten tom der – og lagres den derfra, er fargene borte.
/// - Opphav `bibliotek` (fra 1.1) lagres som `manuell`; opphavet er bare til informasjon.
/// - Representasjon i Munsell (fra 1.1) lagres i et eget felt som eldre versjoner hopper over.
/// - Ukjente verdier fra nyere versjoner gir en farge uten opphav/representasjon i stedet for en tom palett.
extension PalettFarge {
    private enum Nøkler: String, CodingKey {
        case id, navn, farge, opphav, representasjon
        /// Representasjon i en fargemodell som 1.0 ikke kjenner (Munsell).
        case representasjonUtvidet
    }

    /// Fargemodellene som fantes i 1.0.
    private static let modeller10: Set<Fargemodell> = [.okLCH, .okLab, .cieLCH, .cieLab, .hsb, .hsl, .rgb, .displayP3, .cmyk]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Nøkler.self)
        id = try c.decode(UUID.self, forKey: .id)
        navn = try c.decodeIfPresent(String.self, forKey: .navn) ?? ""
        farge = try c.decode(Farge.self, forKey: .farge)
        opphav = (try? c.decodeIfPresent(Opphav.self, forKey: .opphav)) ?? .manuell
        representasjon = (try? c.decodeIfPresent(Fargerepresentasjon.self, forKey: .representasjonUtvidet))
            ?? (try? c.decodeIfPresent(Fargerepresentasjon.self, forKey: .representasjon))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Nøkler.self)
        try c.encode(id, forKey: .id)
        try c.encode(navn, forKey: .navn)
        try c.encode(farge, forKey: .farge)
        try c.encode(opphav == .bibliotek ? .manuell : opphav, forKey: .opphav)
        if let representasjon {
            if case .modell(let m) = representasjon.rom, !Self.modeller10.contains(m) {
                try c.encode(representasjon, forKey: .representasjonUtvidet)
            } else {
                try c.encode(representasjon, forKey: .representasjon)
            }
        }
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
