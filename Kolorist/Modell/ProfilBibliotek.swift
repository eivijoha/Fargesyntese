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
    /// Ett bibliotek for hele appen, så dra-og-slipp kan slå opp profilen en farge er lagret i.
    static let delt = ProfilBibliotek()
    private(set) var importerte: [ICCProfil] = []
    /// Importerte fargebiblioteker (ASE/ACO/ACB) i samme mappe som profilene, så de følger med via iCloud Drive.
    private(set) var fargebiblioteker: [Fargebibliotek] = []
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
    func fargebibliotek(id: String) -> Fargebibliotek? { fargebiblioteker.first { $0.id == id } }

    static let bibliotekendelser = ["ase", "aco", "acb"]

    enum Feil: LocalizedError {
        case ugyldig(String)
        case ukjentFormat(String)
        var errorDescription: String? {
            switch self {
            case .ugyldig(let navn): String(localized: "«\(navn)» er ikke en gyldig ICC-profil.")
            case .ukjentFormat(let navn):
                String(localized: "«\(navn)» er verken en ICC-profil (.icc, .icm) eller et fargebibliotek (.ase, .aco, .acb).")
            }
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

    /// Det som ble importert av `importerFil(fra:)`.
    enum Importert { case profil(ICCProfil), bibliotek(Fargebibliotek) }

    /// Importerer en ICC-profil eller et fargebibliotek. Typen avgjøres av innholdet, ikke filendelsen.
    @discardableResult
    func importerFil(fra url: URL) throws -> Importert {
        let tilgang = url.startAccessingSecurityScopedResource()
        defer { if tilgang { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        if Bibliotekimport.endelse(for: data) != nil { return .bibliotek(try importerBibliotek(fra: url)) }
        guard Bibliotekimport.erICCProfil(data) else { throw Feil.ukjentFormat(url.lastPathComponent) }
        return .profil(try importer(fra: url))
    }

    /// Importerer et fargebibliotek (.ase/.aco/.acb) til profilmappen.
    @discardableResult
    func importerBibliotek(fra url: URL) throws -> Fargebibliotek {
        let tilgang = url.startAccessingSecurityScopedResource()
        defer { if tilgang { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let bibliotek = try Fargebibliotek(data: data, filnavn: url.lastPathComponent)
        if let finnes = fargebiblioteker.first(where: { $0.id == bibliotek.id }) { return finnes }
        // Endelsen etter innholdet, ikke filnavnet: lastInn() leser bare .ase/.aco/.acb, og en fil med
        // annen endelse ville ellers forsvunnet fra listen ved neste oppstart.
        let mål = ledigFilnavn(for: bibliotek.navn, endelse: Bibliotekimport.endelse(for: data) ?? "ase")
        try skriv(data, til: mål)
        filer[bibliotek.id] = mål
        fargebiblioteker.append(bibliotek)
        sorter()
        return bibliotek
    }

    func fjern(_ bibliotek: Fargebibliotek) {
        slettFil(for: bibliotek.id)
        fargebiblioteker.removeAll { $0.id == bibliotek.id }
    }

    func fjern(_ profil: ICCProfil) {
        slettFil(for: profil.id)
        importerte.removeAll { $0.id == profil.id }
    }

    private func slettFil(for id: String) {
        if let fil = filer[id] {
            var feil: NSError?
            NSFileCoordinator().coordinate(writingItemAt: fil, options: .forDeleting, error: &feil) { url in
                try? FileManager.default.removeItem(at: url)
            }
        }
        filer[id] = nil
    }

    // MARK: - Lesing

    private func lastInn() {
        let urler = (try? FileManager.default.contentsOfDirectory(at: mappe, includingPropertiesForKeys: nil)) ?? []
        var nye: [ICCProfil] = []
        var nyeBiblioteker: [Fargebibliotek] = []
        var nyeFiler: [String: URL] = [:]
        for url in urler {
            let endelse = url.pathExtension.lowercased()
            if ["icc", "icm"].contains(endelse) {
                guard let data = les(url), let p = ICCProfil(data: data, navn: url.deletingPathExtension().lastPathComponent),
                      nyeFiler[p.id] == nil
                else { continue }
                nye.append(p)
                nyeFiler[p.id] = url
            } else if Self.bibliotekendelser.contains(endelse) {
                guard let data = les(url), let b = try? Fargebibliotek(data: data, filnavn: url.lastPathComponent),
                      nyeFiler[b.id] == nil
                else { continue }
                nyeBiblioteker.append(b)
                nyeFiler[b.id] = url
            }
        }
        importerte = nye
        fargebiblioteker = nyeBiblioteker
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
    private func ledigFilnavn(for navn: String, endelse: String = "icc") -> URL {
        let rent = navn.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        let basis = rent.isEmpty ? (endelse == "icc" ? "Profil" : "Fargebibliotek") : rent
        var url = mappe.appending(path: "\(basis).\(endelse)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = mappe.appending(path: "\(basis) \(n).\(endelse)")
            n += 1
        }
        return url
    }

    private func sorter() {
        importerte.sort { $0.navn.localizedStandardCompare($1.navn) == .orderedAscending }
        fargebiblioteker.sort { $0.navn.localizedStandardCompare($1.navn) == .orderedAscending }
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
        for fil in lokale where (["icc", "icm"] + Self.bibliotekendelser).contains(fil.pathExtension.lowercased()) {
            let endelse = fil.pathExtension.lowercased()
            let navn = (endelse == "icc" || endelse == "icm" ? ICCBeskrivelseNavn.navn(for: fil) : nil) ?? fil.deletingPathExtension().lastPathComponent
            var mål = skyMappe.appending(path: "\(navn).\(endelse)")
            if FileManager.default.fileExists(atPath: mål.path) { mål = skyMappe.appending(path: "\(navn) \(UUID().uuidString.prefix(4)).\(endelse)") }
            try? FileManager.default.setUbiquitous(true, itemAt: fil, destinationURL: mål)
        }
    }

    /// Følger med på endringer fra andre enheter og Finder, og laster ned nye profiler.
    private func startSpørring() {
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        let endelser = ["icc", "icm"] + Self.bibliotekendelser
        q.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: endelser.map {
            NSPredicate(format: "%K LIKE[c] %@", NSMetadataItemFSNameKey, "*.\($0)")
        })
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
