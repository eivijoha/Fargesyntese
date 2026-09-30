import Foundation

/// Leser profilbeskrivelsen («desc»-taggen) direkte fra ICC-data, slik at importerte
/// profiler vises med riktig navn (f.eks. «Coated FOGRA39 (ISO 12647-2:2004)»).
/// Støtter både ICC v2 (`desc`, ASCII) og v4 (`mluc`, UTF-16BE).
enum ICCBeskrivelse {
    static func les(_ data: Data) -> String? {
        let b = [UInt8](data)
        guard b.count >= 132 else { return nil }
        func u32(_ i: Int) -> Int? {
            guard i >= 0, i + 4 <= b.count else { return nil }
            return Int(b[i]) << 24 | Int(b[i + 1]) << 16 | Int(b[i + 2]) << 8 | Int(b[i + 3])
        }
        func sig(_ i: Int) -> String? {
            guard i >= 0, i + 4 <= b.count else { return nil }
            return String(bytes: b[i..<i + 4], encoding: .ascii)
        }

        guard let antall = u32(128), antall < 1000 else { return nil }
        for n in 0..<antall {
            let post = 132 + n * 12
            guard sig(post) == "desc", let start = u32(post + 4), let størrelse = u32(post + 8),
                  start + størrelse <= b.count, let type = sig(start)
            else { continue }

            switch type {
            case "desc":
                guard let lengde = u32(start + 8), lengde > 0, start + 12 + lengde <= b.count else { return nil }
                let bytes = b[(start + 12)..<(start + 12 + lengde)].prefix { $0 != 0 }
                return String(bytes: bytes, encoding: .ascii).map(renset)
            case "mluc":
                guard let poster = u32(start + 8), poster > 0,
                      let lengde = u32(start + 20), let forskyvning = u32(start + 24),
                      start + forskyvning + lengde <= b.count
                else { return nil }
                let bytes = Array(b[(start + forskyvning)..<(start + forskyvning + lengde)])
                let enheter = stride(from: 0, to: bytes.count - 1, by: 2).map { UInt16(bytes[$0]) << 8 | UInt16(bytes[$0 + 1]) }
                return renset(String(decoding: enheter.prefix { $0 != 0 }, as: UTF16.self))
            default:
                return nil
            }
        }
        return nil
    }

    private static func renset(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
}
