import Foundation

/// Photoshop Color Swatches (.aco): versjon 1 (uten navn) etterfulgt av versjon 2 (med navn),
/// slik Photoshop selv skriver filen. Farger utenfor sRGB lagres som Lab (fargerom 7),
/// ellers som RGB (fargerom 0).
enum ACOEksport {
    static func data(for palett: Palett) -> Data {
        var data = Data()
        for versjon in [UInt16(1), 2] {
            data.append(u16(versjon))
            data.append(u16(UInt16(palett.farger.count)))
            for f in palett.farger {
                data.append(fargeverdier(f.farge))
                if versjon == 2 {
                    let enheter = Array(f.visningsnavn.utf16)
                    data.append(u32(UInt32(enheter.count + 1)))
                    enheter.forEach { data.append(u16($0)) }
                    data.append(u16(0))
                }
            }
        }
        return data
    }

    /// Fargerom (2 byte) + fire 16-bits verdier.
    private static func fargeverdier(_ f: Farge) -> Data {
        var d = Data()
        if f.erISRGB {
            let s = f.sRGB
            d.append(u16(0))
            for v in [s.r, s.g, s.b] { d.append(u16(UInt16((v.klampet(0, 1) * 65535).rounded()))) }
            d.append(u16(0))
        } else {
            let lab = f.cieLab
            d.append(u16(7))
            d.append(u16(UInt16((lab.l.klampet(0, 100) * 100).rounded())))
            d.append(i16(Int16((lab.a.klampet(-128, 127) * 100).rounded())))
            d.append(i16(Int16((lab.b.klampet(-128, 127) * 100).rounded())))
            d.append(u16(0))
        }
        return d
    }

    private static func u16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }
    private static func i16(_ v: Int16) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }
    private static func u32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }
}
