import FargeKjerne
import Foundation
import Testing

/// Lagringsformatet for palettfarger må kunne leses av 1.0, som kan synkronisere de samme palettene.
@Suite("Lagringsformat")
struct LagringsformatTests {
    /// Formatet slik 1.0 leser det (syntetisert Codable med typene fra 1.0).
    struct PalettFarge10: Decodable {
        enum Opphav: String, Decodable { case manuell, kamera, pipette, ki, overgang, toneskala, bilde }
        enum Modell: String, Decodable { case okLCH, okLab, cieLCH, cieLab, hsb, hsl, rgb, displayP3, cmyk }
        enum Rom: Decodable { case modell(Modell); case icc(id: String, navn: String) }
        struct Representasjon: Decodable { var rom: Rom; var verdier: [Double]; var tekst: String }
        var id: UUID
        var navn: String
        var farge: Farge
        var opphav: Opphav
        var representasjon: Representasjon?
    }

    @Test func munsellOgBibliotekKanLesesAv10() throws {
        let farge = Farge(hex: "#2F7FD8")!
        let farger = [
            PalettFarge(navn: "Fra bibliotek", farge: farge, opphav: .bibliotek),
            PalettFarge(farge: farge, representasjon: Fargerepresentasjon(modell: .munsell, farge: farge)),
            PalettFarge(farge: farge, representasjon: Fargerepresentasjon(modell: .cmyk, farge: farge)),
        ]
        let data = try JSONEncoder().encode(farger)
        let gamle = try JSONDecoder().decode([PalettFarge10].self, from: data)
        #expect(gamle.count == 3)
        #expect(gamle[0].opphav == .manuell && gamle[0].navn == "Fra bibliotek")
        #expect(gamle[1].representasjon == nil)
        if case .modell(.cmyk)? = gamle[2].representasjon?.rom {} else { Issue.record("CMYK-representasjonen gikk tapt") }
    }

    @Test func munsellBeholdesI11() throws {
        let farge = Farge(hex: "#2F7FD8")!
        let pf = PalettFarge(farge: farge, representasjon: Fargerepresentasjon(modell: .munsell, farge: farge))
        let tilbake = try JSONDecoder().decode(PalettFarge.self, from: JSONEncoder().encode(pf))
        #expect(tilbake.representasjon == pf.representasjon)
        #expect(tilbake.id == pf.id && tilbake.farge == pf.farge)
    }

    @Test func ukjenteVerdierTømmerIkkePaletten() throws {
        let farge = Farge(hex: "#2F7FD8")!
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(PalettFarge(farge: farge))) as! [String: Any]
        json["opphav"] = "fremtidig"
        json["representasjon"] = ["rom": ["modell": ["_0": "fremtidigModell"]], "verdier": [1.0], "tekst": "x"]
        let data = try JSONSerialization.data(withJSONObject: [json])
        let lest = try JSONDecoder().decode([PalettFarge].self, from: data)
        #expect(lest.count == 1 && lest[0].opphav == .manuell && lest[0].representasjon == nil)
    }
}
