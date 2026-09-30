import FargeKjerne
import Foundation

/// Innebygde og importerte ICC-profiler. Importerte profiler kopieres til
/// Application Support/Profiler, slik at de er tilgjengelige etter omstart.
@Observable
final class ProfilBibliotek {
    private(set) var importerte: [ICCProfil] = []

    var alle: [ICCProfil] { ICCProfil.innebygde + importerte }

    private let mappe: URL = {
        let url = URL.applicationSupportDirectory.appending(path: "Profiler", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    init() {
        let filer = (try? FileManager.default.contentsOfDirectory(at: mappe, includingPropertiesForKeys: nil)) ?? []
        importerte = filer
            .compactMap { url in (try? Data(contentsOf: url)).flatMap { ICCProfil(data: $0, navn: url.deletingPathExtension().lastPathComponent) } }
            .sorted { $0.navn.localizedStandardCompare($1.navn) == .orderedAscending }
    }

    func profil(id: String) -> ICCProfil? { alle.first { $0.id == id } }

    enum Feil: LocalizedError {
        case ugyldig(String)
        var errorDescription: String? {
            switch self { case .ugyldig(let navn): "«\(navn)» er ikke en gyldig ICC-profil." }
        }
    }

    /// Importerer en .icc/.icm-fil valgt av brukeren (sikkerhetsavgrenset URL).
    @discardableResult
    func importer(fra url: URL) throws -> ICCProfil {
        let tilgang = url.startAccessingSecurityScopedResource()
        defer { if tilgang { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard let profil = ICCProfil(data: data, navn: url.deletingPathExtension().lastPathComponent) else {
            throw Feil.ugyldig(url.lastPathComponent)
        }
        if let finnes = importerte.first(where: { $0.id == profil.id }) { return finnes }
        try data.write(to: mappe.appending(path: "\(profil.id).icc"))
        importerte.append(profil)
        importerte.sort { $0.navn.localizedStandardCompare($1.navn) == .orderedAscending }
        return profil
    }

    func fjern(_ profil: ICCProfil) {
        try? FileManager.default.removeItem(at: mappe.appending(path: "\(profil.id).icc"))
        importerte.removeAll { $0.id == profil.id }
    }
}
