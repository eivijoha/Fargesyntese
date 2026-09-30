import FargeKjerne
import Foundation
import SwiftData

/// Persistert palett. Fargene lagres som JSON-kodet `[PalettFarge]` i ett felt:
/// det er robust mot modellendringer og kompatibelt med CloudKit-synk senere
/// (alle felt har standardverdier, ingen unike begrensninger).
@Model
final class PalettDokument {
    var id: UUID = UUID()
    var navn: String = ""
    var opprettet: Date = Date.now
    var endret: Date = Date.now
    private var fargeData: Data = Data()

    init(navn: String, farger: [PalettFarge] = []) {
        self.id = UUID()
        self.navn = navn
        self.farger = farger
    }

    convenience init(_ palett: Palett) {
        self.init(navn: palett.navn, farger: palett.farger)
    }

    var farger: [PalettFarge] {
        get { (try? JSONDecoder().decode([PalettFarge].self, from: fargeData)) ?? [] }
        set {
            fargeData = (try? JSONEncoder().encode(newValue)) ?? Data()
            endret = .now
        }
    }

    var palett: Palett { Palett(id: id, navn: navn, farger: farger) }
}

/// En enkeltfarge lagret uten palett («Enkeltfarger»).
@Model
final class LagretFarge {
    var id: UUID = UUID()
    var opprettet: Date = Date.now
    private var data: Data = Data()

    init(_ farge: PalettFarge) {
        self.id = farge.id
        self.palettFarge = farge
    }

    var palettFarge: PalettFarge {
        get { (try? JSONDecoder().decode(PalettFarge.self, from: data)) ?? PalettFarge(id: id, farge: Farge(lineærR: 0, g: 0, b: 0)) }
        set { data = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}

/// Felles lagring for app og App Intents (intents kjører i appens prosess).
///
/// Paletter og enkeltfarger synkroniseres via iCloud (CloudKit, privat database) når brukeren er
/// logget inn i iCloud. Ellers lagres de lokalt. Modellene oppfyller CloudKit-kravene: alle felt
/// har standardverdier, ingen unike begrensninger og ingen påkrevde relasjoner.
enum Lagring {
    static let containerID = "iCloud.no.engenett.Fargesyntese"
    private static let skjema = Schema([PalettDokument.self, LagretFarge.self])

    /// Om lageret synkroniseres via iCloud (for visning i appen).
    private(set) static var synkroniserer = false

    static let container: ModelContainer = {
        if kanBrukeICloud {
            do {
                let oppsett = ModelConfiguration(schema: skjema, cloudKitDatabase: .private(containerID))
                let c = try ModelContainer(for: skjema, configurations: oppsett)
                synkroniserer = true
                return c
            } catch {
                print("iCloud-synk utilgjengelig, bruker lokal lagring: \(error)")
            }
        }
        do {
            return try ModelContainer(for: skjema, configurations: ModelConfiguration(schema: skjema, cloudKitDatabase: .none))
        } catch {
            fatalError("Kunne ikke åpne palettlageret: \(error)")
        }
    }()

    private static var kanBrukeICloud: Bool {
        #if targetEnvironment(simulator)
        // Simulatorbygg er ikke signert med CloudKit-rettighet, og CloudKit stopper appen da.
        return false
        #else
        return FileManager.default.ubiquityIdentityToken != nil
        #endif
    }
}
