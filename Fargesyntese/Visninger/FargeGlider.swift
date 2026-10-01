import SwiftUI

/// Glider med fargespor: sporet viser fargene man får ved å flytte nettopp denne komponenten,
/// med de andre komponentene som de er (f.eks. kulør ved gjeldende lyshet og kroma).
struct FargeGlider: View {
    @Binding var verdi: Double
    let område: ClosedRange<Double>
    /// Farger jevnt fordelt langs sporet, fra laveste til høyeste verdi.
    let spor: [Color]
    /// Fargen ved gjeldende verdi (fyller tommelen).
    let gjeldende: Color
    var tittel: Text = Text("")
    var verdiTekst: String = ""
    var stegForTilgjengelighet: Double? = nil

    private let høyde: CGFloat = 10
    private let tommel: CGFloat = 26

    private var andel: Double {
        let spenn = område.upperBound - område.lowerBound
        return spenn > 0 ? min(max((verdi - område.lowerBound) / spenn, 0), 1) : 0
    }

    var body: some View {
        GeometryReader { geo in
            let bredde = geo.size.width
            let løp = max(bredde - tommel, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: spor.isEmpty ? [.gray] : spor, startPoint: .leading, endPoint: .trailing))
                    .frame(height: høyde)
                    .overlay(Capsule().strokeBorder(Color.sekundærTekst.opacity(0.35), lineWidth: 0.5))
                    .padding(.horizontal, tommel / 2 - høyde / 2)
                Circle()
                    .fill(gjeldende)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .frame(width: tommel, height: tommel)
                    .offset(x: andel * løp)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let t = min(max((g.location.x - tommel / 2) / løp, 0), 1)
                    verdi = område.lowerBound + t * (område.upperBound - område.lowerBound)
                }
            )
        }
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel(tittel)
        .accessibilityValue(verdiTekst)
        .accessibilityAdjustableAction { retning in
            let steg = stegForTilgjengelighet ?? (område.upperBound - område.lowerBound) / 50
            let ny = verdi + (retning == .increment ? steg : -steg)
            verdi = min(max(ny, område.lowerBound), område.upperBound)
        }
    }
}
