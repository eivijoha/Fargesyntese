import FargeKjerne
import Foundation
import PDFKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Utskrift og PDF av paletter (A4). Fargerommet ved siden av fargens egen modell er det som er valgt
/// under «Vis også» i Studio – en ICC-profil eller et fargebibliotek (nærmeste tone).
enum PalettUtskrift {
    static func pdf(for palett: Palett) -> Data {
        let innstillinger = UserDefaults.standard
        let id = innstillinger.string(forKey: "visOgsåProfil") ?? ICCProfil.sRGB.id
        let hensikt = innstillinger.string(forKey: "gjengivelseshensikt").flatMap(Gjengivelseshensikt.init(rawValue:))
            ?? .relativKolorimetrisk
        let profiler = ProfilBibliotek.delt
        let bibliotek = profiler.fargebibliotek(id: id)
        let profil = bibliotek == nil ? (profiler.profil(id: id) ?? .sRGB) : nil

        let felt = palett.farger.map { pf -> PalettPDF.Felt in
            var rader: [(String, String)] = []
            // Verdiene i fargemodellen (eller profilen) fargen ble definert i.
            if let rep = pf.representasjon {
                rader.append((rep.romnavn, rep.tekst))
            } else {
                rader.append(("Hex (sRGB)", pf.farge.hex()))
            }
            // Valgt fargerom eller fargebibliotek.
            if let bibliotek, let n = bibliotek.nærmeste(til: pf.farge) {
                let tone = n.avstand < 0.05 ? n.tone.visningsnavn
                    : String(localized: "\(n.tone.visningsnavn) · ΔE00 \(String(format: "%.1f", n.avstand))")
                rader.append((bibliotek.navn, tone))
            } else if let profil, !erDefinertI(pf, profil: profil) {
                rader.append((profiler.visningsnavn(profil), verdier(pf.farge, i: profil, hensikt: hensikt)))
            }
            let lab = pf.farge.cieLab
            rader.append(("CIELab (D50)", String(format: "L* %.2f   a* %.2f   b* %.2f", lab.l, lab.a, lab.b)))
            return PalettPDF.Felt(lab: lab, navn: pf.navn.isEmpty ? nil : pf.navn, rader: rader)
        }

        let rom = bibliotek.map { String(localized: "Fargebibliotek: \($0.navn)") }
            ?? String(localized: "Fargerom: \(profil.map(profiler.visningsnavn) ?? ICCProfil.sRGB.navn)")
        let dato = Date.now.formatted(date: .long, time: .omitted)
        let undertittel = String(localized: "Kolorist · \(dato) · Fargeflater i CIELab (D50) · \(rom)")
        let tittel = palett.navn.isEmpty ? String(localized: "Uten navn") : palett.navn
        return PalettPDF.lag(tittel: tittel, undertittel: undertittel, felt: felt) { side, av in
            String(localized: "Side \(side) av \(av)")
        }
    }

    /// Fargen er allerede lagret med verdier i denne profilen – da gjentas de ikke.
    private static func erDefinertI(_ pf: PalettFarge, profil: ICCProfil) -> Bool {
        if case .icc(let id, _)? = pf.representasjon?.rom { return id == profil.id }
        return false
    }

    private static func verdier(_ farge: Farge, i profil: ICCProfil, hensikt: Gjengivelseshensikt) -> String {
        if profil.id == ICCProfil.sRGB.id {
            let s = farge.gamutKartlagt(til: .sRGB)
            return farge.erInnenfor(profil, hensikt: hensikt) ? s.hex() : String(localized: "\(s.hex()) (utenfor gamut)")
        }
        guard let k = farge.komponenter(i: profil, hensikt: hensikt) else { return "–" }
        let tekst = profil.formatert(k)
        return farge.erInnenfor(profil, hensikt: hensikt) ? tekst : String(localized: "\(tekst) (utenfor gamut)")
    }

    /// Systemets utskriftsdialog for PDF-en (på Mac også med «Arkiver som PDF»).
    static func skrivUt(_ palett: Palett) {
        let data = pdf(for: palett)
        let jobb = palett.navn.isEmpty ? String(localized: "Palett") : palett.navn
        #if canImport(UIKit)
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = jobb
        info.outputType = .general
        let utskrift = UIPrintInteractionController.shared
        utskrift.printInfo = info
        utskrift.printingItem = data
        utskrift.present(animated: true)
        #else
        guard let dokument = PDFDocument(data: data) else { return }
        // Som i Studieblikk: A4 uten marger og uten skalering – PDF-en har allerede sine egne marger, så
        // flatene skrives ut i riktig størrelse. Sandkassen trenger com.apple.security.print.
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.paperSize = NSSize(width: PalettPDF.side.width, height: PalettPDF.side.height)
        info.orientation = .portrait
        info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
        info.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] = false
        guard let operasjon = dokument.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false) else { return }
        operasjon.jobTitle = jobb
        operasjon.showsPrintPanel = true
        operasjon.showsProgressPanel = true
        if let vindu = NSApp.keyWindow ?? NSApp.mainWindow {
            operasjon.runModal(for: vindu, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operasjon.run()
        }
        #endif
    }
}

// MARK: - ⌘P via fokusverdi (samme mønster som Studieblikk)

/// Paletten som skrives ut med ⌘P der brukeren står. Lik ved samme id, så menyen ikke bygges om ved
/// hver oppdatering av visningen (closures sammenlignes ikke).
struct Palettutskrift: Equatable {
    let id: UUID
    let navn: String
    let palett: () -> Palett

    static func == (a: Palettutskrift, b: Palettutskrift) -> Bool { a.id == b.id && a.navn == b.navn }
}

extension FocusedValues {
    @Entry var palettutskrift: Palettutskrift?
}
