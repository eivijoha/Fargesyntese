import FargeKjerne
import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// Tar imot farger som slippes her: fra paletter og fargeruter i Kolorist, fra andre programmer
    /// (som tekst: hex eller CSS) og – på iOS – via Transferable. `handling` får fargene i rekkefølge.
    ///
    /// På Mac leses dataene direkte fra dra-utklippstavla: SwiftUIs `dropDestination` klarer ikke å laste
    /// fargene fra Kolorists egne dra-kilder (som er laget med `onDrag` for å virke i fargebrønner i andre
    /// programmer), og slippet ble stille avvist.
    func tarImotFarger(_ handling: @escaping ([PalettFarge]) -> Bool, isTargeted: ((Bool) -> Void)? = nil) -> some View {
        modifier(FargeSlipp(målrettet: isTargeted, handling: handling))
    }
}

private struct FargeSlipp: ViewModifier {
    let målrettet: ((Bool) -> Void)?
    let handling: ([PalettFarge]) -> Bool
    @State private var over = false

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .onDrop(of: Self.typer, delegate: Delegat(over: $over, handling: handling))
            .onChange(of: over) { _, ny in målrettet?(ny) }
        #else
        content
            .dropDestination(for: PalettFarge.self) { farger, _ in handling(farger) } isTargeted: { målrettet?($0) }
        #endif
    }

    #if os(macOS)
    static let typer: [UTType] = [.koloristPalettfarge, .koloristFarge, .macFarge, .utf8PlainText, .plainText]

    /// Egen delegat: foreslår «kopier» (eller «flytt» når kilden bare tillater det), så slippet ikke
    /// avvises fordi kilden og målet foreslår ulike operasjoner.
    struct Delegat: DropDelegate {
        @Binding var over: Bool
        let handling: ([PalettFarge]) -> Bool

        func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: FargeSlipp.typer) }
        func dropEntered(info: DropInfo) { over = true }
        func dropExited(info: DropInfo) { over = false }
        func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .copy) }

        func performDrop(info: DropInfo) -> Bool {
            over = false
            // Leverandørene SwiftUI gir her er tomme for dra-kilder laget med `onDrag`, så fargene leses
            // rett fra dra-utklippstavla, som har alle typene kilden registrerte.
            let farger = (NSPasteboard(name: .drag).pasteboardItems ?? []).compactMap(FargeSlipp.les)
            return !farger.isEmpty && handling(farger)
        }
    }

    /// Leser ett element i prioritert rekkefølge: Kolorist-palettfarge (med navn og id, så den kan flyttes
    /// mellom paletter), ren Kolorist-farge, systemets NSColor (fargepanelet, fargebrønner og andre
    /// programmer, i sitt eget fargerom), og til slutt tekst (hex, CSS m.m.).
    static func les(_ element: NSPasteboardItem) -> PalettFarge? {
        func data(_ type: UTType) -> Data? { element.data(forType: NSPasteboard.PasteboardType(type.identifier)) }
        if let d = data(.koloristPalettfarge), let pf = try? JSONDecoder().decode(PalettFarge.self, from: d) { return pf }
        if let d = data(.koloristFarge), let f = try? JSONDecoder().decode(Farge.self, from: d) { return PalettFarge(farge: f) }
        if let d = element.data(forType: .color), let ns = NSColor(pasteboardPropertyList: d, ofType: .color),
           let f = Farge(cgFarge: ns.cgColor) {
            return PalettFarge(farge: f)
        }
        if let tekst = element.string(forType: .string), let f = Fargetolk.tolk(tekst) { return PalettFarge(farge: f) }
        return nil
    }
    #endif
}
