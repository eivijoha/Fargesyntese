import Testing
@testable import FargeKjerne

@Suite("Fargesyn (CVD)")
struct FargesynTests {
    @Test func nøytraleFargerEndresIkke() {
        // Machado-matrisene har radsum 1, så hvitt, sort og grått er uendret.
        for type in Fargesynstype.allCases {
            for f in [Farge(lineærR: 1, g: 1, b: 1), Farge(lineærR: 0, g: 0, b: 0), Farge(lineærR: 0.2, g: 0.2, b: 0.2)] {
                #expect(f.simulert(type).avstandOK(til: f) < 1e-3, "\(type) endret \(f.hex())")
            }
        }
    }

    @Test func kjenteVerdierFraMachado() {
        // Ren lineær rød med protanopi gir første kolonne i matrisen.
        let r = Farge(lineærR: 1, g: 0, b: 0).simulert(.protan)
        #expect(abs(r.r - 0.152286) < 1e-6 && abs(r.g - 0.114503) < 1e-6 && abs(r.b + 0.003882) < 1e-6)
        let g = Farge(lineærR: 0, g: 1, b: 0).simulert(.deutan)
        #expect(abs(g.r - 0.860646) < 1e-6 && abs(g.g - 0.672501) < 1e-6 && abs(g.b - 0.042940) < 1e-6)
    }

    @Test func gradBlanderMedNormaltSyn() {
        let f = Farge(hex: "#E53935")!
        #expect(f.simulert(.deutan, grad: 0) == f)
        let halv = f.simulert(.deutan, grad: 0.5), hel = f.simulert(.deutan)
        #expect(abs(halv.r - (f.r + hel.r) / 2) < 1e-9)
    }

    @Test func akromatopsiGirGråMedSammeLuminans() {
        let f = Farge(hex: "#2F7FD8")!
        let s = f.simulert(.akromatopsi)
        #expect(abs(s.r - s.g) < 1e-12 && abs(s.g - s.b) < 1e-12)
        #expect(abs(s.luminans - f.luminans) < 1e-9)
    }

    @Test func rødGrønnForveksles() {
        let rød = Farge(hex: "#D32F2F")!, grønn = Farge(hex: "#388E3C")!, blå = Farge(hex: "#1565C0")!
        let deutan = Fargesynsanalyse.forvekslinger(i: [rød, grønn, blå], type: .deutan)
        #expect(deutan.contains { $0.i == 0 && $0.j == 1 })
        #expect(!deutan.contains { $0.j == 2 })
        // Blå-gul er det tritan som forveksler, ikke deutan.
        let gul = Farge(hex: "#FBC02D")!, lyseblå = Farge(hex: "#90CAF9")!
        #expect(Fargesynsanalyse.forvekslinger(i: [gul, lyseblå], type: .deutan).isEmpty)
    }
}
