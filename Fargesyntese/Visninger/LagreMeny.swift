import SwiftUI

/// «+»-meny for å lagre en farge: som enkeltfarge eller i en palett.
/// Viser en kort hake etter lagring som enkeltfarge.
struct LagreMeny: View {
    var lagre: () -> Void
    var leggIPalett: () -> Void
    var størrelse: CGFloat = 44
    @State private var lagret = false

    var body: some View {
        Menu {
            Button("Lagre som enkeltfarge", systemImage: "plus.square") {
                lagre()
                lagret = true
                Task { try? await Task.sleep(for: .seconds(1.5)); lagret = false }
            }
            Button("Legg i palett …", systemImage: "plus.square.on.square") { leggIPalett() }
        } label: {
            Image(systemName: lagret ? "checkmark.square.fill" : "plus.square")
                .frame(width: størrelse, height: størrelse)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .sensoryFeedback(.success, trigger: lagret) { _, ny in ny }
        .accessibilityLabel(lagret ? String(localized: "Lagret") : String(localized: "Lagre farge"))
    }
}
