import Foundation

/// Import av fargebiblioteker: Adobe Swatch Exchange (.ase), Photoshop-fargeprøver (.aco) og
/// Adobe Color Book (.acb), som brukes for fargekart med navngitte toner. Lab-verdier tolkes med D50 som i Adobe, CMYK naivt (uten profil), og navn beholdes
/// så nærmeste tone kan finnes med ΔE2000 i Vurdering › Sammenlign.
public enum Bibliotekimport {
    public enum Feil: LocalizedError {
        case ukjentFormat, ødelagt
        public var errorDescription: String? {
            switch self {
            case .ukjentFormat: String(localized: "Filen er ikke et ASE-, ACO- eller ACB-fargebibliotek.", bundle: .module)
            case .ødelagt: String(localized: "Fargebiblioteket kunne ikke leses.", bundle: .module)
            }
        }
    }

    /// Leser filen og gir en palett med filnavnet (eller bokens navn) som palettnavn.
    public static func les(_ data: Data, filnavn: String) throws -> Palett {
        let navn = (filnavn as NSString).deletingPathExtension
        if data.starts(with: Data("ASEF".utf8)) { return try ase(data, navn: navn) }
        if data.starts(with: Data("8BCB".utf8)) { return try acb(data, navn: navn) }
        if data.count >= 4, data[0] == 0, data[1] == 1 || data[1] == 2 { return try aco(data, navn: navn) }
        throw Feil.ukjentFormat
    }

    // MARK: - ASE

    static func ase(_ d: Data, navn: String) throws -> Palett {
        var l = Leser(d); l.pos = 4
        _ = try l.u16(); _ = try l.u16()
        let antall = try l.u32()
        var farger: [PalettFarge] = []
        var gruppe: String?
        for _ in 0..<antall {
            let type = try l.u16(), lengde = Int(try l.u32())
            let slutt = l.pos + lengde
            switch type {
            case 0xC001: gruppe = try l.utf16Tekst()
            case 0x0001:
                let fargenavn = try l.utf16Tekst()
                let modell = try l.ascii(4)
                let f: Farge?
                switch modell {
                case "RGB ": f = Farge(sRGB: SRGB(r: Double(try l.f32()), g: Double(try l.f32()), b: Double(try l.f32())))
                case "CMYK":
                    let c = Double(try l.f32()), m = Double(try l.f32()), y = Double(try l.f32()), k = Double(try l.f32())
                    f = Farge(naivCMYK: CMYK(c: c, m: m, y: y, k: k))
                case "LAB ":
                    let L = Double(try l.f32()) * 100, a = Double(try l.f32()), b = Double(try l.f32())
                    f = Farge(cieLab: CIELab(l: L, a: a, b: b))
                case "Gray": let g = Double(try l.f32()); f = Farge(sRGB: SRGB(r: g, g: g, b: g))
                default: f = nil
                }
                if let f { farger.append(PalettFarge(navn: fargenavn.trimmingCharacters(in: .whitespaces), farge: f, opphav: .bibliotek)) }
            default: break
            }
            l.pos = slutt
        }
        return Palett(navn: farger.count > 0 && gruppe?.isEmpty == false && navn.isEmpty ? gruppe! : navn, farger: farger)
    }

    // MARK: - ACO

    static func aco(_ d: Data, navn: String) throws -> Palett {
        var l = Leser(d)
        let versjon = try l.u16()
        let antall = Int(try l.u16())
        var farger: [PalettFarge] = []
        func lesFarge() throws -> Farge? {
            let rom = try l.u16()
            let w = try (0..<4).map { _ in try l.u16() }
            switch rom {
            case 0: return Farge(sRGB: SRGB(r: Double(w[0]) / 65535, g: Double(w[1]) / 65535, b: Double(w[2]) / 65535))
            case 1: return Farge(hsb: HSB(h: Double(w[0]) / 65535 * 360, s: Double(w[1]) / 65535, b: Double(w[2]) / 65535))
            case 2: return Farge(naivCMYK: CMYK(c: 1 - Double(w[0]) / 65535, m: 1 - Double(w[1]) / 65535, y: 1 - Double(w[2]) / 65535, k: 1 - Double(w[3]) / 65535))
            case 7:
                let L = Double(w[0]) / 100, a = Double(Int16(bitPattern: w[1])) / 100, b = Double(Int16(bitPattern: w[2])) / 100
                return Farge(cieLab: CIELab(l: L, a: a, b: b))
            case 8: let g = 1 - Double(w[0]) / 10000; return Farge(sRGB: SRGB(r: g, g: g, b: g))
            default: return nil
            }
        }
        // Versjon 1-blokk (uten navn). Følger en versjon 2-blokk med navn, brukes den i stedet.
        var utenNavn: [PalettFarge] = []
        for i in 0..<antall { if let f = try lesFarge() { utenNavn.append(PalettFarge(navn: "\(i + 1)", farge: f, opphav: .bibliotek)) } }
        if versjon == 2 {
            // Filen begynte rett på versjon 2: les på nytt med navn.
            l.pos = 0
        }
        if l.pos + 4 <= d.count, try l.u16() == 2 {
            let antall2 = Int(try l.u16())
            for i in 0..<antall2 {
                let f = try lesFarge()
                let lengde = Int(try l.u32())  // antall UTF-16-enheter inkl. nullterminering
                let tekst = try l.utf16(enheter: lengde)
                if let f { farger.append(PalettFarge(navn: tekst.isEmpty ? "\(i + 1)" : tekst, farge: f, opphav: .bibliotek)) }
            }
        }
        return Palett(navn: navn, farger: farger.isEmpty ? utenNavn : farger)
    }

    // MARK: - ACB (Adobe Color Book)

    static func acb(_ d: Data, navn: String) throws -> Palett {
        var l = Leser(d); l.pos = 4
        _ = try l.u16()  // versjon
        _ = try l.u16()  // bok-id
        let tittel = try l.u32Tekst()
        let prefiks = try l.u32Tekst()
        let suffiks = try l.u32Tekst()
        _ = try l.u32Tekst()  // beskrivelse
        let antall = Int(try l.u16())
        _ = try l.u16()  // farger per side
        _ = try l.u16()  // nøkkelfarge-indeks
        let rom = try l.u16()  // 0 RGB, 2 CMYK, 7 Lab
        var farger: [PalettFarge] = []
        for _ in 0..<antall {
            let fargenavn = try l.u32Tekst()
            _ = try l.ascii(6)  // kode
            let f: Farge?
            switch rom {
            case 0: f = Farge(sRGB: SRGB(r: Double(try l.u8()) / 255, g: Double(try l.u8()) / 255, b: Double(try l.u8()) / 255))
            case 2:
                let c = 1 - Double(try l.u8()) / 255, m = 1 - Double(try l.u8()) / 255, y = 1 - Double(try l.u8()) / 255, k = 1 - Double(try l.u8()) / 255
                f = Farge(naivCMYK: CMYK(c: c, m: m, y: y, k: k))
            case 7:
                let L = Double(try l.u8()) / 255 * 100, a = Double(try l.u8()) - 128, b = Double(try l.u8()) - 128
                f = Farge(cieLab: CIELab(l: L, a: a, b: b))
            default: throw Feil.ukjentFormat
            }
            // Tomme navn er sideskift i boka.
            if let f, !fargenavn.isEmpty {
                let fullt = (rydd(prefiks) + fargenavn + rydd(suffiks)).trimmingCharacters(in: .whitespaces)
                farger.append(PalettFarge(navn: fullt, farge: f, opphav: .bibliotek))
            }
        }
        return Palett(navn: tittel.isEmpty ? navn : rydd(tittel), farger: farger)
    }

    /// Adobe skriver «$$$/colorbook/…=Navn»; vi vil bare ha Navn.
    private static func rydd(_ s: String) -> String {
        if let i = s.lastIndex(of: "="), s.hasPrefix("$$$") { return String(s[s.index(after: i)...]) }
        return s
    }

    // MARK: - Leser

    struct Leser {
        let d: Data
        var pos = 0
        init(_ d: Data) { self.d = d }

        mutating func u8() throws -> UInt8 { guard pos < d.count else { throw Feil.ødelagt }; defer { pos += 1 }; return d[d.startIndex + pos] }
        mutating func u16() throws -> UInt16 { UInt16(try u8()) << 8 | UInt16(try u8()) }
        mutating func u32() throws -> UInt32 { UInt32(try u16()) << 16 | UInt32(try u16()) }
        mutating func f32() throws -> Float { Float(bitPattern: try u32()) }
        mutating func ascii(_ n: Int) throws -> String {
            guard pos + n <= d.count else { throw Feil.ødelagt }
            defer { pos += n }
            return String(decoding: d[d.startIndex + pos ..< d.startIndex + pos + n], as: UTF8.self)
        }
        mutating func utf16(enheter n: Int) throws -> String {
            guard n >= 0, pos + 2 * n <= d.count else { throw Feil.ødelagt }
            var u: [UInt16] = []
            for _ in 0..<n { u.append(try u16()) }
            if u.last == 0 { u.removeLast() }
            return String(decoding: u, as: UTF16.self)
        }
        /// ASE: lengde i UTF-16-enheter (u16) inkl. nullterminering.
        mutating func utf16Tekst() throws -> String { try utf16(enheter: Int(try u16())) }
        /// ACB: lengde i UTF-16-enheter (u32), uten nullterminering.
        mutating func u32Tekst() throws -> String { try utf16(enheter: Int(try u32())) }
    }
}
