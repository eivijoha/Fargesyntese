import FargeKjerne
import Foundation
import Testing

@Suite("Bibliotekimport")
struct BibliotekimportTests {
    let palett = Palett(navn: "Test", farger: [
        PalettFarge(navn: "Fjordblå", farge: Farge(hex: "#2F7FD8")!),
        PalettFarge(navn: "Rav", farge: Farge(hex: "#F2B84B")!),
        PalettFarge(navn: "Dyp P3-grønn", farge: Farge(displayP3: DisplayP3(r: 0, g: 0.8, b: 0.2))),
    ])

    /// Én importknapp: formatet avgjøres av innholdet. En ICC-profil over 64 KB begynner med 00 01 og må
    /// ikke tas for en ACO-fil.
    @Test func formatGjenkjennesFraInnholdet() throws {
        #expect(Bibliotekimport.endelse(for: Eksportformat.ase.data(for: palett)) == "ase")
        #expect(Bibliotekimport.endelse(for: Eksportformat.aco.data(for: palett)) == "aco")
        let cmyk = try Data(contentsOf: URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/Generic CMYK Profile.icc"))
        #expect(Bibliotekimport.erICCProfil(cmyk))
        #expect(Bibliotekimport.endelse(for: cmyk) == nil)
        var stor = cmyk
        stor.replaceSubrange(0..<4, with: [0x00, 0x01, 0x20, 0x00])   // som en profil på 73 KB
        #expect(Bibliotekimport.endelse(for: stor) == nil)
        #expect(!Bibliotekimport.erICCProfil(Eksportformat.ase.data(for: palett)))
    }

    @Test func aseRundtur() throws {
        let data = Eksportformat.ase.data(for: palett)
        let lest = try Bibliotekimport.les(data, filnavn: "Test.ase")
        #expect(lest.farger.map(\.navn) == ["Fjordblå", "Rav", "Dyp P3-grønn"])
        for (a, b) in zip(palett.farger, lest.farger) { #expect(a.farge.deltaE2000(til: b.farge) < 0.5, "\(a.navn)") }
        #expect(lest.farger.allSatisfy { $0.opphav == .bibliotek })
    }

    @Test func acoRundtur() throws {
        let data = Eksportformat.aco.data(for: palett)
        let lest = try Bibliotekimport.les(data, filnavn: "Test.aco")
        #expect(lest.farger.map(\.navn) == ["Fjordblå", "Rav", "Dyp P3-grønn"])
        for (a, b) in zip(palett.farger, lest.farger) { #expect(a.farge.deltaE2000(til: b.farge) < 0.5, "\(a.navn)") }
    }

    @Test func acbLeses() throws {
        // Minimal Color Book i Lab med to farger og ett sideskift.
        var d = Data("8BCB".utf8)
        func u16(_ v: UInt16) { d.append(contentsOf: withUnsafeBytes(of: v.bigEndian) { Array($0) }) }
        func u32(_ v: UInt32) { d.append(contentsOf: withUnsafeBytes(of: v.bigEndian) { Array($0) }) }
        func tekst(_ s: String) { let u = Array(s.utf16); u32(UInt32(u.count)); u.forEach(u16) }
        u16(1); u16(3000); tekst("$$$/colorbook/Testbok/title=Testbok"); tekst(""); tekst(" C"); tekst("")
        u16(3); u16(2); u16(0); u16(7)
        tekst("Rød 1"); d.append(contentsOf: Array("RED001".utf8)); d.append(contentsOf: [138, 208, 190])  // L 54, a 80, b 62
        tekst(""); d.append(contentsOf: Array("      ".utf8)); d.append(contentsOf: [0, 128, 128])
        tekst("Blå 2"); d.append(contentsOf: Array("BLU002".utf8)); d.append(contentsOf: [128, 128, 60])
        let lest = try Bibliotekimport.les(d, filnavn: "x.acb")
        #expect(lest.navn == "Testbok")
        #expect(lest.farger.map(\.navn) == ["Rød 1 C", "Blå 2 C"])
        #expect(lest.farger[0].farge.okLCH.h < 40)
        #expect(lest.farger[1].farge.okLCH.h > 240)
    }

    @Test func ukjentFormatAvvises() {
        #expect(throws: Bibliotekimport.Feil.self) { try Bibliotekimport.les(Data("hei".utf8), filnavn: "x.txt") }
    }
}
