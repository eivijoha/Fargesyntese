#if canImport(CoreGraphics)
import CoreGraphics
import CryptoKit
import Foundation

/// Fargestyrt konvertering via ICC-profiler (ColorSync under panseret).
///
/// Brukes til reell CMYK for trykk (f.eks. FOGRA39/ISO Coated v2, GRACoL, PSO Uncoated)
/// og til å tolke farger fra filer/kamera som er merket med en profil.
public struct ICCProfil: Sendable, Hashable, Identifiable {
    public let id: String
    public let navn: String
    public let antallKomponenter: Int
    public let modell: CGColorSpaceModel
    /// Rå ICC-data når profilen er lastet fra fil (nil for innebygde).
    public let data: Data?
    private let navngittRom: String?

    public var fargerom: CGColorSpace? {
        if let data { return CGColorSpace(iccData: data as CFData) }
        if let navngittRom { return CGColorSpace(name: navngittRom as CFString) }
        return nil
    }

    /// Laster en .icc/.icm-fil.
    public init?(data: Data, navn: String? = nil) {
        guard let rom = CGColorSpace(iccData: data as CFData) else { return nil }
        self.data = data
        self.navngittRom = nil
        self.modell = rom.model
        self.antallKomponenter = rom.numberOfComponents
        self.navn = ICCBeskrivelse.les(data) ?? navn ?? (rom.name as String?) ?? String(localized: "ICC-profil", bundle: .module)
        // Stabil id på tvers av oppstarter, slik at valgt profil kan huskes.
        self.id = "icc:" + SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
    }

    private init(navngitt: CFString, visningsnavn: String) {
        let rom = CGColorSpace(name: navngitt)!
        self.data = nil
        self.navngittRom = navngitt as String
        self.modell = rom.model
        self.antallKomponenter = rom.numberOfComponents
        self.navn = visningsnavn
        self.id = navngitt as String
    }

    public static let sRGB = ICCProfil(navngitt: CGColorSpace.sRGB, visningsnavn: "sRGB IEC61966-2.1")
    public static let displayP3 = ICCProfil(navngitt: CGColorSpace.displayP3, visningsnavn: "Display P3")
    public static let adobeRGB = ICCProfil(navngitt: CGColorSpace.adobeRGB1998, visningsnavn: "Adobe RGB (1998)")
    public static let genericCMYK = ICCProfil(navngitt: CGColorSpace.genericCMYK, visningsnavn: String(localized: "Generisk CMYK", bundle: .module))

    public static let innebygde: [ICCProfil] = [.sRGB, .displayP3, .adobeRGB, .genericCMYK]

    /// Kortnavn for komponentene, i profilens rekkefølge.
    public var komponentnavn: [String] {
        switch modell {
        case .cmyk: ["C", "M", "Y", "K"]
        case .rgb: ["R", "G", "B"]
        case .lab: ["L", "a", "b"]
        case .monochrome: [String(localized: "Grå", bundle: .module)]
        default: (1...antallKomponenter).map { "K\($0)" }
        }
    }

    /// Om komponentene er 0…1-verdier som kan redigeres direkte (CMYK, RGB, grå).
    public var kanRedigeres: Bool { [.cmyk, .rgb, .monochrome].contains(modell) }
}

public extension ICCProfil {
    /// Konverterer komponentverdier fra én profil til en annen med valgt gjengivelseshensikt,
    /// f.eks. CMYK i FOGRA39 → CMYK i GRACoL, eller Adobe RGB → sRGB.
    ///
    /// Merk: hensikten får bare effekt når profilene har tabeller for den (typisk LUT-baserte
    /// CMYK-profiler). Rene matriseprofiler (sRGB, Display P3) oppfører seg kolorimetrisk uansett.
    static func konverter(_ komponenter: [Double], fra kilde: ICCProfil, til mål: ICCProfil,
                          hensikt: Gjengivelseshensikt, alfa: Double = 1) -> [Double]? {
        guard komponenter.count == kilde.antallKomponenter,
              let fraRom = kilde.fargerom, let tilRom = mål.fargerom,
              let cg = CGColor(colorSpace: fraRom, components: komponenter.map { CGFloat($0) } + [alfa]),
              let ut = cg.converted(to: tilRom, intent: hensikt.cg, options: nil),
              let k = ut.components
        else { return nil }
        return Array(k.prefix(mål.antallKomponenter)).map { Double($0) }
    }
}

public enum Gjengivelseshensikt: String, CaseIterable, Codable, Sendable {
    case perseptuell, relativKolorimetrisk, metning, absoluttKolorimetrisk

    var cg: CGColorRenderingIntent {
        switch self {
        case .perseptuell: .perceptual
        case .relativKolorimetrisk: .relativeColorimetric
        case .metning: .saturation
        case .absoluttKolorimetrisk: .absoluteColorimetric
        }
    }
}

public extension Farge {
    /// Fargen som `CGColor` i utvidet lineær sRGB – ingen klipping.
    var cgFarge: CGColor {
        let rom = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        return CGColor(colorSpace: rom, components: [r, g, b, alfa])!
    }

    init?(cgFarge: CGColor) {
        guard let rom = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
              let c = cgFarge.converted(to: rom, intent: .relativeColorimetric, options: nil),
              let k = c.components, k.count >= 3
        else { return nil }
        self.init(lineærR: k[0], g: k[1], b: k[2], alfa: k.count > 3 ? k[3] : 1)
    }

    /// Komponentverdier (0…1) i profilens rom, f.eks. [C, M, Y, K] for en CMYK-profil.
    func komponenter(i profil: ICCProfil, hensikt: Gjengivelseshensikt = .relativKolorimetrisk) -> [Double]? {
        guard let rom = profil.fargerom,
              let c = cgFarge.converted(to: rom, intent: hensikt.cg, options: nil),
              let k = c.components
        else { return nil }
        return Array(k.prefix(profil.antallKomponenter)).map { Double($0) }
    }

    /// Perseptuelt avvik (ΔE_OK) etter en rundtur gjennom profilen. Over ~0,02 er fargen
    /// merkbart utenfor profilens gamut – f.eks. en mettet skjermfarge som ikke kan trykkes.
    func avvik(i profil: ICCProfil, hensikt: Gjengivelseshensikt = .relativKolorimetrisk) -> Double? {
        guard let k = komponenter(i: profil, hensikt: hensikt),
              let tilbake = Farge(komponenter: k, i: profil, alfa: alfa)
        else { return nil }
        return avstandOK(til: tilbake)
    }

    /// Om fargen kan gjengis i profilens rom. sRGB og Display P3 avgjøres eksakt; andre profiler
    /// via rundtur gjennom profilen (avvik under én merkbar forskjell, ΔE_OK < 0,02).
    func erInnenfor(_ profil: ICCProfil, hensikt: Gjengivelseshensikt = .relativKolorimetrisk) -> Bool {
        if profil.id == ICCProfil.sRGB.id { return erISRGB }
        if profil.id == ICCProfil.displayP3.id { return erIDisplayP3 }
        guard let avvik = avvik(i: profil, hensikt: hensikt) else { return true }
        return avvik < 0.02
    }

    /// Nærmeste farge som kan gjengis i profilens rom (for begrensning av nye farger).
    /// sRGB/P3 bruker perseptuell gamut-kartlegging; andre profiler går via profilen.
    func begrenset(til profil: ICCProfil, hensikt: Gjengivelseshensikt = .relativKolorimetrisk) -> Farge {
        if profil.id == ICCProfil.sRGB.id { return gamutKartlagt(til: .sRGB) }
        if profil.id == ICCProfil.displayP3.id { return gamutKartlagt(til: .displayP3) }
        if erInnenfor(profil, hensikt: hensikt) { return self }
        guard let k = komponenter(i: profil, hensikt: hensikt),
              let f = Farge(komponenter: k, i: profil, alfa: alfa)
        else { return self }
        return f
    }

    /// Lager en farge fra komponenter i en profil (f.eks. CMYK-verdier fra et trykkeri).
    init?(komponenter: [Double], i profil: ICCProfil, alfa: Double = 1) {
        guard komponenter.count == profil.antallKomponenter,
              let rom = profil.fargerom,
              let cg = CGColor(colorSpace: rom, components: komponenter.map { CGFloat($0) } + [alfa])
        else { return nil }
        self.init(cgFarge: cg)
    }
}
#endif
