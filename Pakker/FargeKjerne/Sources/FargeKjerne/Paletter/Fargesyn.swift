import Foundation

/// Typer fargesynsavvik (CVD) som kan simuleres.
///
/// Rød-grønn-avvik (protan og deutan) rammer omtrent 8 % av menn og 0,5 % av kvinner med nordeuropeisk
/// bakgrunn; deutan er klart vanligst. Tritan (blå-gul) og akromatopsi (ingen fargesyn) er sjeldne.
public enum Fargesynstype: String, CaseIterable, Codable, Sendable, Identifiable {
    case protan, deutan, tritan, akromatopsi

    public var id: String { rawValue }

    /// Navn ved fullstendig avvik (dikromasi).
    public var navn: String {
        switch self {
        case .protan: String(localized: "Protanopi", bundle: .module)
        case .deutan: String(localized: "Deuteranopi", bundle: .module)
        case .tritan: String(localized: "Tritanopi", bundle: .module)
        case .akromatopsi: String(localized: "Akromatopsi", bundle: .module)
        }
    }

    /// Navn ved delvis avvik (anomal trikromasi).
    public var delvisNavn: String {
        switch self {
        case .protan: String(localized: "Protanomali", bundle: .module)
        case .deutan: String(localized: "Deuteranomali", bundle: .module)
        case .tritan: String(localized: "Tritanomali", bundle: .module)
        case .akromatopsi: String(localized: "Akromatopsi", bundle: .module)
        }
    }

    public var beskrivelse: String {
        switch self {
        case .protan: String(localized: "Rød-grønn, svak rødsans – rødt virker også mørkere", bundle: .module)
        case .deutan: String(localized: "Rød-grønn, svak grønnsans – den vanligste formen", bundle: .module)
        case .tritan: String(localized: "Blå-gul – sjelden", bundle: .module)
        case .akromatopsi: String(localized: "Ingen fargesyn, bare lyshet – svært sjelden", bundle: .module)
        }
    }

    /// Machado, Oliveira & Fernandes (2009), alvorlighetsgrad 1,0, i lineær sRGB.
    var matrise: Matrise3? {
        switch self {
        case .protan:
            Matrise3([[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]])
        case .deutan:
            Matrise3([[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]])
        case .tritan:
            Matrise3([[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.304900]])
        case .akromatopsi:
            nil
        }
    }
}

public extension Fargesynstype {
    /// Simuleringen som 3×3-matrise i lineær sRGB (rad for rad), blandet med identitet etter `grad`.
    /// For bildefiltre (f.eks. kamerabildet); gir samme resultat som ``Farge/simulert(_:grad:)``.
    func lineærMatrise(grad: Double = 1) -> [[Double]] {
        let g = min(max(grad, 0), 1)
        let m: [[Double]] = matrise?.rader ?? {
            // Akromatopsi: luminansen (Y-raden i sRGB → XYZ) i alle tre kanaler.
            let y = Matriser.lineærSRGBTilXYZ.rader[1]
            return [y, y, y]
        }()
        return (0..<3).map { i in (0..<3).map { j in (i == j ? 1 - g : 0) + m[i][j] * g } }
    }
}

public extension Farge {
    /// Fargen slik den oppfattes med fargesynsavviket. `grad` 1 er fullstendig avvik (dikromasi);
    /// lavere verdier tilnærmer delvis avvik ved lineær blanding med normalt syn.
    func simulert(_ type: Fargesynstype, grad: Double = 1) -> Farge {
        let g = min(max(grad, 0), 1)
        let ut: (Double, Double, Double)
        if let m = type.matrise {
            let v = m * Vektor3(r, self.g, b)
            ut = (v.x, v.y, v.z)
        } else {
            // Akromatopsi: bare relativ luminans (Y), den samme som WCAG-kontrasten bygger på.
            let y = luminans
            ut = (y, y, y)
        }
        return Farge(lineærR: r + (ut.0 - r) * g, g: self.g + (ut.1 - self.g) * g, b: b + (ut.2 - b) * g, alfa: alfa)
    }
}

/// Et fargepar som blir vanskelig å skille med et fargesynsavvik.
public struct Forveksling: Hashable, Sendable {
    public var i: Int
    public var j: Int
    public var type: Fargesynstype
    /// ΔE2000 med normalt syn og med avviket.
    public var normalt: Double
    public var simulert: Double

    public var alvorlig: Bool { simulert < Fargesynsanalyse.alvorligGrense }
}

public enum Fargesynsanalyse {
    /// Under denne ΔE2000-verdien er fargene vanskelige å skille i små flater og grafikk.
    public static let forvekslingsgrense = 10.0
    /// Under denne er fargene nesten like.
    public static let alvorligGrense = 5.0

    /// Fargepar som er tydelig ulike med normalt syn, men blir vanskelige å skille med avviket.
    public static func forvekslinger(i farger: [Farge], type: Fargesynstype, grad: Double = 1) -> [Forveksling] {
        let sim = farger.map { $0.simulert(type, grad: grad) }
        var ut: [Forveksling] = []
        for i in farger.indices {
            for j in farger.indices where j > i {
                let normalt = farger[i].deltaE2000(til: farger[j])
                let simulert = sim[i].deltaE2000(til: sim[j])
                if normalt >= forvekslingsgrense, simulert < forvekslingsgrense {
                    ut.append(Forveksling(i: i, j: j, type: type, normalt: normalt, simulert: simulert))
                }
            }
        }
        return ut.sorted { $0.simulert < $1.simulert }
    }
}
