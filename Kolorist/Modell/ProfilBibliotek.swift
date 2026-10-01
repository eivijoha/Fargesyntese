import FargeKjerne
import Foundation

/// Innebygde og importerte ICC-profiler.
///
/// Importerte profiler ligger i appens iCloud Drive-mappe («Kolorist › Profiler»), synlig i
/// Filer og Finder. Profiler som legges der fra en annen enhet eller fra Finder, dukker opp
/// automatisk. Uten iCloud brukes Application Support/Profiler lokalt, og lokale profiler flyttes
/// til iCloud når det blir tilgjengelig.
@Observable
final class ProfilBibliotek {
    private(set) var importerte: [ICCProfil] = []
    /// Om profilene synkroniseres via iCloud Drive.
    private(set) var brukerICloud = false

    /// Profiler installert på Macen (tom på iPhone/iPad, der apper ikke ser systemets profiler).
    private(set) var installerte: [ICCProfil] = []
    /// Mappegruppe og entydig visningsnavn for hver installerte profil (id → verdi).
    @ObservationIgnored private(set) var installertGruppe: [String: String] = [:]
    @ObservationIgnored private var installertNavn: [String: String] = [:]

    /// Navnet som vises i menyer: entydig for installerte profiler med like beskrivelser.
    func visningsnavn(_ p: ICCProfil) -> String { installertNavn[p.id] ?? p.navn }

    var alle: [ICCProfil] {
        ICCProfil.innebygde + importerte + installerte.filter { p in !importerte.contains { $0.id == p.id } }
    }

    nonisolated static let containerID = "iCloud.no.engenett.Kolorist"

    @ObservationIgnored private var mappe: URL = ProfilBibliotek.lokalMappe
    @ObservationIgnored private var filer: [String: URL] = [:]  // profil-id → fil
    @ObservationIgnored private var spørring: NSMetadataQuery?

    private static let lokalMappe: URL = {
        let url = URL.applicationSupportDirectory.appending(path: "Profiler", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    init() {
        lastInn()
        Task { await kobleTilICloud() }
        #if os(macOS)
        Task {
            let funnet = await Task.detached(priority: .utility) { InstallerteProfiler.finn() }.value
            installertGruppe = Dictionary(funnet.map { ($0.profil.id, $0.gruppe) }, uniquingKeysWith: { a, _ in a })
            installertNavn = Dictionary(funnet.map { ($0.profil.id, $0.visningsnavn) }, uniquingKeysWith: { a, _ in a })
            installerte = funnet.map(\.profil)
        }
        #endif
    }

    func profil(id: String) -> ICCProfil? { alle.first { $0.id == id } }

    enum Feil: LocalizedError {
        case ugyldig(String)
        var errorDescription: String? {
            switch self { case .ugyldig(let navn): String(localized: "«\(navn)» er ikke en gyldig ICC-profil.") }
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
        let mål = ledigFilnavn(for: profil.navn)
        try skriv(data, til: mål)
        filer[profil.id] = mål
        importerte.append(profil)
        sorter()
        return profil
    }

    /// Kopierer en profil installert på Macen inn i profilmappen (iCloud Drive), så den blir med til
    /// de andre enhetene. Id-en er en hash av profildataene, så valget i menyene peker fortsatt riktig.
    /// Gjør ingenting for innebygde, allerede kopierte eller ikke-installerte profiler.
    @discardableResult
    func taMedTilMineProfiler(_ profil: ICCProfil) -> Bool {
        guard installerte.contains(where: { $0.id == profil.id }),
              !importerte.contains(where: { $0.id == profil.id }),
              let data = profil.data
        else { return false }
        let mål = ledigFilnavn(for: visningsnavn(profil))
        do { try skriv(data, til: mål) } catch { return false }
        filer[profil.id] = mål
        importerte.append(profil)
        sorter()
        return true
    }

    func fjern(_ profil: ICCProfil) {
        if let fil = filer[profil.id] {
            var feil: NSError?
            NSFileCoordinator().coordinate(writingItemAt: fil, options: .forDeleting, error: &feil) { url in
                try? FileManager.default.removeItem(at: url)
            }
        }
        filer[profil.id] = nil
        importerte.removeAll { $0.id == profil.id }
    }

    // MARK: - Lesing

    private func lastInn() {
        let urler = (try? FileManager.default.contentsOfDirectory(at: mappe, includingPropertiesForKeys: nil)) ?? []
        var nye: [ICCProfil] = []
        var nyeFiler: [String: URL] = [:]
        for url in urler where ["icc", "icm"].contains(url.pathExtension.lowercased()) {
            guard let data = les(url), let p = ICCProfil(data: data, navn: url.deletingPathExtension().lastPathComponent),
                  nyeFiler[p.id] == nil
            else { continue }
            nye.append(p)
            nyeFiler[p.id] = url
        }
        importerte = nye
        filer = nyeFiler
        sorter()
    }

    private func les(_ url: URL) -> Data? {
        var data: Data?
        var feil: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &feil) { data = try? Data(contentsOf: $0) }
        return data
    }

    private func skriv(_ data: Data, til url: URL) throws {
        var feil: NSError?
        var skrivefeil: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &feil) { url in
            do { try data.write(to: url, options: .atomic) } catch { skrivefeil = error }
        }
        if let feil { throw feil }
        if let skrivefeil { throw skrivefeil }
    }

    /// Lesbare filnavn, siden brukeren ser mappen i Filer/Finder.
    private func ledigFilnavn(for navn: String) -> URL {
        let rent = navn.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        let basis = rent.isEmpty ? "Profil" : rent
        var url = mappe.appending(path: "\(basis).icc")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = mappe.appending(path: "\(basis) \(n).icc")
            n += 1
        }
        return url
    }

    private func sorter() {
        importerte.sort { $0.navn.localizedStandardCompare($1.navn) == .orderedAscending }
    }

    // MARK: - iCloud

    private func kobleTilICloud() async {
        // Oppslaget kan blokkere; gjør det utenfor hovedtråden.
        let container = await Task.detached {
            FileManager.default.url(forUbiquityContainerIdentifier: ProfilBibliotek.containerID)
        }.value
        guard let container else { return }
        let skyMappe = container.appending(path: "Documents/Profiler", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: skyMappe, withIntermediateDirectories: true)
        } catch { return }

        flyttLokaleProfiler(til: skyMappe)
        mappe = skyMappe
        brukerICloud = true
        lastInn()
        startSpørring()
    }

    /// Profiler importert før iCloud var tilgjengelig, flyttes inn i iCloud-mappen.
    private func flyttLokaleProfiler(til skyMappe: URL) {
        let lokale = (try? FileManager.default.contentsOfDirectory(at: Self.lokalMappe, includingPropertiesForKeys: nil)) ?? []
        for fil in lokale where ["icc", "icm"].contains(fil.pathExtension.lowercased()) {
            let navn = ICCBeskrivelseNavn.navn(for: fil) ?? fil.deletingPathExtension().lastPathComponent
            var mål = skyMappe.appending(path: "\(navn).icc")
            if FileManager.default.fileExists(atPath: mål.path) { mål = skyMappe.appending(path: "\(navn) \(UUID().uuidString.prefix(4)).icc") }
            try? FileManager.default.setUbiquitous(true, itemAt: fil, destinationURL: mål)
        }
    }

    /// Følger med på endringer fra andre enheter og Finder, og laster ned nye profiler.
    private func startSpørring() {
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K LIKE[c] '*.icc' OR %K LIKE[c] '*.icm'",
                                  NSMetadataItemFSNameKey, NSMetadataItemFSNameKey)
        let oppdater: @Sendable (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.håndterSpørring() }
        }
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main, using: oppdater)
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: q, queue: .main, using: oppdater)
        q.start()
        spørring = q
    }

    private func håndterSpørring() {
        guard let q = spørring else { return }
        q.disableUpdates()
        defer { q.enableUpdates() }
        for case let item as NSMetadataItem in q.results {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            if status != NSMetadataUbiquitousItemDownloadingStatusCurrent {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            }
        }
        lastInn()
    }
}

/// Liten hjelper for å gi flyttede lokale filer (lagret med id-navn) et lesbart navn.
private enum ICCBeskrivelseNavn {
    static func navn(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return ICCProfil(data: data)?.navn
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
    }
}
