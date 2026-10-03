import AppIntents
import FargeKI
import FargeKjerne
import Foundation
import SwiftData

enum FargemodellAppEnum: String, AppEnum {
    case okLCH, okLab, cieLCH, cieLab, munsell, hsb, hsl, rgb, displayP3, cmyk

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Fargemodell")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .okLCH: "OKLCH", .okLab: "OKLab", .cieLCH: "LCH", .cieLab: "CIELab", .munsell: "Munsell",
        .hsb: "HSB", .hsl: "HSL", .rgb: "RGB", .displayP3: "Display P3", .cmyk: "CMYK",
    ]

    var modell: Fargemodell { Fargemodell(rawValue: rawValue)! }
}

struct UgyldigFarge: Error, CustomLocalizedStringResourceConvertible {
    let tekst: String
    var localizedStringResource: LocalizedStringResource { "«\(tekst)» er ikke en gyldig farge. Bruk hex eller CSS, f.eks. #2F7FD8 eller oklch(0.6 0.15 250)." }
}

// MARK: - Verdiord → palett

struct LagPalettFraVerdiordIntent: AppIntent {
    static let title: LocalizedStringResource = "Lag palett fra verdiord"
    static let description = IntentDescription("Foreslår en fargepalett ut fra verdiord eller en stemning, og lagrer den.")

    @Parameter(title: "Verdiord", requestValueDialog: "Hvilke verdiord skal paletten uttrykke?")
    var verdiord: String

    @Parameter(title: "Antall farger", default: 5, inclusiveRange: (3, 10))
    var antall: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Lag palett med \(\.$antall) farger fra \(\.$verdiord)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PalettEntity> & ProvidesDialog {
        let forslag = try await Verdiordtjeneste.beste().forslag(for: verdiord, antall: antall)
        let dokument = PalettDokument(forslag.palett)
        Lagring.container.mainContext.insert(dokument)
        try Lagring.container.mainContext.save()
        await Spotlight.indekser([dokument])
        return .result(value: PalettEntity(dokument), dialog: "Laget «\(forslag.tittel)» med \(forslag.farger.count) farger.")
    }
}

// MARK: - Beskriv en farge

struct BeskrivFargeIntent: AppIntent {
    static let title: LocalizedStringResource = "Beskriv en farge"
    static let description = IntentDescription("Lager en farge fra en beskrivelse, f.eks. «dyp havblå» eller «støvete rosa». Fargen regnes ut i OKLCH og vises i Studio.")
    static let openAppWhenRun = true

    @Parameter(title: "Beskrivelse", requestValueDialog: "Hvordan ser fargen ut?")
    var beskrivelse: String

    static var parameterSummary: some ParameterSummary {
        Summary("Vis fargen \(\.$beskrivelse)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let farge = await Fargebeskriver.farge(fra: beskrivelse)
        Arbeidsbenk.delt.vis(farge)
        return .result(dialog: "\(farge.navn): \(farge.farge.hex()), \(Fargemodell.okLCH.tekst(for: farge.farge))")
    }
}

// MARK: - Overgang

struct LagOvergangIntent: AppIntent {
    static let title: LocalizedStringResource = "Lag overgangstoner"
    static let description = IntentDescription("Lager toner i like perseptuelle steg (OKLab) mellom to farger.")

    @Parameter(title: "Fra farge", description: "Hex, f.eks. #1B3A6B")
    var fra: String

    @Parameter(title: "Til farge", description: "Hex, f.eks. #F2B84B")
    var til: String

    @Parameter(title: "Antall toner", default: 7, inclusiveRange: (2, 24))
    var antall: Int

    @Parameter(title: "Lagre som palett", default: false)
    var lagre: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Lag \(\.$antall) toner fra \(\.$fra) til \(\.$til)") { \.$lagre }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        guard let a = Fargetolk.tolk(fra) else { throw UgyldigFarge(tekst: fra) }
        guard let b = Fargetolk.tolk(til) else { throw UgyldigFarge(tekst: til) }
        let toner = Overgang.toner(fra: a, til: b, antall: antall)
        if lagre {
            let dokument = PalettDokument(navn: "Overgang \(a.hex()) → \(b.hex())",
                                          farger: toner.map { PalettFarge(farge: $0, opphav: .overgang) })
            Lagring.container.mainContext.insert(dokument)
            try Lagring.container.mainContext.save()
            await Spotlight.indekser([dokument])
        }
        return .result(value: toner.map { $0.hex() })
    }
}

// MARK: - Konvertering

struct KonverterFargeIntent: AppIntent {
    static let title: LocalizedStringResource = "Konverter farge"
    static let description = IntentDescription("Regner om en farge til en annen fargemodell, f.eks. fra hex til OKLCH eller CMYK.")

    @Parameter(title: "Farge", description: "Hex, f.eks. #2F7FD8")
    var farge: String

    @Parameter(title: "Til modell", default: .okLCH)
    var modell: FargemodellAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Konverter \(\.$farge) til \(\.$modell)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let f = Fargetolk.tolk(farge) else { throw UgyldigFarge(tekst: farge) }
        let tekst = modell.modell.tekst(for: f)
        return .result(value: tekst, dialog: "\(tekst)")
    }
}

// MARK: - Kontrast

struct SjekkKontrastIntent: AppIntent {
    static let title: LocalizedStringResource = "Sjekk kontrast"
    static let description = IntentDescription("Tester to farger mot WCAG 2.2-kravene til kontrast for tekst og grafikk.")

    @Parameter(title: "Tekstfarge", description: "Hex eller CSS-farge, f.eks. #767676")
    var forgrunn: String

    @Parameter(title: "Bakgrunn", default: "#FFFFFF")
    var bakgrunn: String

    static var parameterSummary: some ParameterSummary {
        Summary("Sjekk kontrasten til \(\.$forgrunn) på \(\.$bakgrunn)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        guard let fg = Fargetolk.tolk(forgrunn) else { throw UgyldigFarge(tekst: forgrunn) }
        guard let bg = Fargetolk.tolk(bakgrunn) else { throw UgyldigFarge(tekst: bakgrunn) }
        let test = Kontrasttest(forgrunn: fg, bakgrunn: bg)
        let krav = WCAGKrav.allCases.map { "\($0.navn): \(test.består($0) ? "bestått" : "ikke bestått")" }.joined(separator: ", ")
        return .result(value: test.forhold, dialog: "Kontrasten er \(test.formatert) (\(test.sammendrag)). \(krav).")
    }
}

// MARK: - Snarveier og Siri

struct KoloristSnarveier: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LagPalettFraVerdiordIntent(),
            phrases: [
                "Lag en palett i \(.applicationName)",
                "Foreslå farger med \(.applicationName)",
                "Lag fargepalett fra verdiord i \(.applicationName)",
            ],
            shortTitle: "Palett fra verdiord",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: BeskrivFargeIntent(),
            phrases: ["Beskriv en farge i \(.applicationName)", "Vis en farge i \(.applicationName)"],
            shortTitle: "Beskriv en farge",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: LagOvergangIntent(),
            phrases: ["Lag overgangstoner i \(.applicationName)", "Lag en fargeovergang med \(.applicationName)"],
            shortTitle: "Overgangstoner",
            systemImageName: "square.stack.3d.forward.dottedline"
        )
        AppShortcut(
            intent: SjekkKontrastIntent(),
            phrases: ["Sjekk kontrast i \(.applicationName)", "Test fargekontrast med \(.applicationName)"],
            shortTitle: "Sjekk kontrast",
            systemImageName: "circle.lefthalf.filled"
        )
        AppShortcut(
            intent: KonverterFargeIntent(),
            phrases: ["Konverter en farge med \(.applicationName)", "Regn om farge i \(.applicationName)"],
            shortTitle: "Konverter farge",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
