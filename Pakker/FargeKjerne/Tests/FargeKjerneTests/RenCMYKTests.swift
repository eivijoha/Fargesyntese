import Testing
@testable import FargeKjerne

@Suite("Rene CMYK-verdier")
struct RenCMYKTests {
    @Test func gråBlirBareSort() throws {
        let grå = Farge(okLCH: OKLCH(l: 0.6, c: 0, h: 0))
        let r = try #require(RenCMYK.separer(grå, i: .genericCMYK))
        #expect(r.avvik <= RenCMYK.standardtoleranse)
        // Grått bygges nesten bare av sort (rester under 5 % i C, M og Y til sammen).
        #expect(r.verdier[0] + r.verdier[1] + r.verdier[2] <= 0.05, "\(r.verdier)")
        #expect(r.verdier[3] > 0.4)
    }

    @Test func færreFargerInnenforToleranse() throws {
        for hex in ["#2F7FD8", "#C75820", "#388E3C", "#7B5E3A", "#D32F2F"] {
            let f = Farge(hex: hex)!
            let profilens = try #require(f.komponenter(i: .genericCMYK)).filter { $0 > 0.005 }.count
            let r = try #require(RenCMYK.separer(f, i: .genericCMYK))
            let rene = r.verdier.filter { $0 > 0 }.count
            #expect(rene <= profilens)
            #expect(r.avvik <= RenCMYK.standardtoleranse)
        }
    }

    @Test func ikkeCMYKGirNil() {
        #expect(RenCMYK.separer(Farge(hex: "#2F7FD8")!, i: .sRGB) == nil)
    }
}
