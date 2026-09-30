import Foundation

/// Adobe Swatch Exchange (versjon 1.0), big-endian binærformat.
///
/// Fargene skrives som `LAB ` (D50) når de ligger utenfor sRGB, ellers som `RGB `,
/// slik at Adobe-programmer tolker dem mest mulig riktig.
enum ASEEksport {
    static func data(for palett: Palett) -> Data {
        var blokker: [Data] = []
        blokker.append(blokk(type: 0xC001, innhold: tekst(palett.navn)))  // gruppestart
        for f in palett.farger {
            var innhold = tekst(f.visningsnavn)
            if f.farge.erISRGB {
                let s = f.farge.sRGB
                innhold.append(Data("RGB ".utf8))
                for v in [s.r, s.g, s.b] { innhold.append(float32(v.klampet(0, 1))) }
            } else {
                let lab = f.farge.cieLab
                innhold.append(Data("LAB ".utf8))
                // ASE lagrer L som 0…1, a/b direkte.
                for v in [lab.l / 100, lab.a, lab.b] { innhold.append(float32(v)) }
            }
            innhold.append(uint16(2))  // 0 = global, 1 = spot, 2 = normal
            blokker.append(blokk(type: 0x0001, innhold: innhold))
        }
        blokker.append(blokk(type: 0xC002, innhold: Data()))  // gruppeslutt

        var data = Data("ASEF".utf8)
        data.append(uint16(1)); data.append(uint16(0))
        data.append(uint32(UInt32(blokker.count)))
        blokker.forEach { data.append($0) }
        return data
    }

    private static func blokk(type: UInt16, innhold: Data) -> Data {
        var d = uint16(type)
        d.append(uint32(UInt32(innhold.count)))
        d.append(innhold)
        return d
    }

    /// Navn: antall UTF-16-enheter inkl. nullterminering, så UTF-16BE, så 0x0000.
    private static func tekst(_ s: String) -> Data {
        let enheter = Array(s.utf16) + [0]
        var d = uint16(UInt16(enheter.count))
        enheter.forEach { d.append(uint16($0)) }
        return d
    }

    private static func uint16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }
    private static func uint32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }
    private static func float32(_ v: Double) -> Data { uint32(Float(v).bitPattern) }
}
