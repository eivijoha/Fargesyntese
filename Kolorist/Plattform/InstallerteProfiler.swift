#if os(macOS)
import ColorSync  // ColorSyncIterateInstalledProfiles; nøkkelen er «com.apple.ColorSync.ProfileURL» (kColorSyncProfileURL)
import FargeKjerne
import Foundation

/// ICC-profiler som er installert på Macen: systemets, maskinens (/Library) og brukerens egne
/// (~/Library), inkludert undermapper som «Displays» og egne mapper. ColorSync lister bare toppnivået,
/// så mappene leses i tillegg rekursivt. Profiler som ikke kan brukes som fargerom (navngitte farger,
/// device link, abstrakte, XYZ) og de innebygde standardrommene tas ikke med.
enum InstallerteProfiler {
    /// En installert profil med gruppe (mappen den ligger i) og et navn som skiller like beskrivelser.
    struct Funn: Sendable {
        var profil: ICCProfil
        var gruppe: String
        var visningsnavn: String
    }

    /// Gruppe ut fra plassering: «Systemet», «Maskinen», «Brukeren», eller første undermappe
    /// (f.eks. «Displays», «Plotter»).
    nonisolated static func gruppe(for url: URL, hjem: URL) -> String {
        let røtter: [(String, String)] = [
            ("/System/Library/ColorSync/Profiles", String(localized: "Systemet")),
            ("/Library/ColorSync/Profiles", String(localized: "Maskinen")),
            (hjem.appending(path: "Library/ColorSync/Profiles").path, String(localized: "Brukeren")),
        ]
        let sti = url.standardizedFileURL.path
        for (rot, navn) in røtter where sti.hasPrefix(rot + "/") {
            let deler = sti.dropFirst(rot.count + 1).split(separator: "/")
            return deler.count > 1 ? String(deler[0]) : navn
        }
        return url.deletingLastPathComponent().lastPathComponent
    }

    nonisolated static func finn() -> [Funn] {
        var urler = Set<URL>()

        // ColorSync: profilene systemet selv kjenner (fungerer også i sandkassen).
        final class Samler: @unchecked Sendable { var urler: [URL] = [] }
        let samler = Samler()
        var seed: UInt32 = 0
        ColorSyncIterateInstalledProfiles({ info, bruker in
            guard let info = info as? [String: Any], let bruker,
                  let url = info["com.apple.ColorSync.ProfileURL"] as? URL
            else { return true }
            Unmanaged<Samler>.fromOpaque(bruker).takeUnretainedValue().urler.append(url)
            return true
        }, &seed, Unmanaged.passUnretained(samler).toOpaque(), nil)
        urler.formUnion(samler.urler)

        // Mappene rekursivt. I sandkassen hoppes det stille over mapper appen ikke får lese.
        let hjem = URL(fileURLWithPath: NSHomeDirectoryForUser(NSUserName()) ?? NSHomeDirectory())
        let mapper = [
            URL(fileURLWithPath: "/System/Library/ColorSync/Profiles"),
            URL(fileURLWithPath: "/Library/ColorSync/Profiles"),
            hjem.appending(path: "Library/ColorSync/Profiles"),
        ]
        for mappe in mapper {
            guard let gjennom = FileManager.default.enumerator(at: mappe, includingPropertiesForKeys: nil,
                                                                options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in gjennom where ["icc", "icm"].contains(url.pathExtension.lowercased()) {
                urler.insert(url.standardizedFileURL)
            }
        }

        let innebygdeNavn = Set(ICCProfil.innebygde.map(\.navn))
        var sett = Set<String>()
        var profiler: [(ICCProfil, URL)] = []
        for url in urler {
            guard let data = try? Data(contentsOf: url), data.count >= 20 else { continue }
            // Profilklasse (byte 12–15) og fargerom (16–19) fra ICC-hodet.
            let klasse = String(decoding: data[12..<16], as: UTF8.self)
            let rom = String(decoding: data[16..<20], as: UTF8.self)
            guard ["mntr", "prtr", "scnr", "spac"].contains(klasse), ["RGB ", "CMYK", "GRAY"].contains(rom),
                  let profil = ICCProfil(data: data, navn: url.deletingPathExtension().lastPathComponent),
                  !innebygdeNavn.contains(profil.navn), sett.insert(profil.id).inserted
            else { continue }
            profiler.append((profil, url))
        }
        // Like beskrivelser (f.eks. flere «Display») får filnavnet i parentes.
        var antall: [String: Int] = [:]
        for (p, _) in profiler { antall[p.navn, default: 0] += 1 }
        return profiler.map { p, url in
            let filnavn = url.deletingPathExtension().lastPathComponent
            let navn = antall[p.navn, default: 0] > 1 && filnavn != p.navn ? "\(p.navn) (\(filnavn))" : p.navn
            return Funn(profil: p, gruppe: gruppe(for: url, hjem: hjem), visningsnavn: navn)
        }
        .sorted { $0.visningsnavn.localizedStandardCompare($1.visningsnavn) == .orderedAscending }
    }
}
#endif
