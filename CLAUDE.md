# Fargesyntese

Fargepalett-verktøy for designere – iOS, iPadOS og macOS (én multiplattform-target, SwiftUI).
**iOS er den avgrensende plattformen**: design og test for iPhone først, utvid for iPad/Mac.

## Struktur

- `Pakker/FargeKjerne/` – Swift-pakke, ingen UI:
  - `FargeKjerne`: `Farge` (kanonisk lineær utvidet sRGB), fargerom, gamut-kartlegging,
    `Overgang` (OKLab), `Toneskala`, ICC via CoreGraphics, eksport (ASE, CSS, DTCG, GPL, SwiftUI).
  - `FargeKI`: verdiord → palett. Foundation Models på enheten, `LeksikonTolker` som reserve.
- `Fargesyntese/` – appen (filsystem-synkronisert gruppe; nye filer plukkes opp automatisk).
  `App/`, `Modell/` (SwiftData), `Visninger/`, `Plattform/` (kamera, pipette, utklippstavle), `Intents/`.
- `Konfigurasjon/Info.plist` – kun det som ikke kan settes med `INFOPLIST_KEY_*` (eksportert UTType).
- `Dokumentasjon/Grunnlag.md` – arkitektur, beslutninger og veikart.

## Konvensjoner

- Domenetyper og -metoder på norsk (`Farge`, `Palett`, `toner(fra:til:antall:)`), Apple-API-er som de er.
  All UI-tekst på norsk bokmål.
- All interpolasjon i OKLab. Farger klippes aldri før visning/eksport – bruk `gamutKartlagt(til:)`, ikke `klippet(til:)`.
- Matriser følger CSS Color 4; inverser utledes med `Matrise3.invertert` i stedet for å hardkodes.
- App-target bruker `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; bakgrunnskode merkes `nonisolated`.

## Bygg og test

```bash
cd Pakker/FargeKjerne && swift test
xcodebuild -project Fargesyntese.xcodeproj -scheme Fargesyntese -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Fargesyntese.xcodeproj -scheme Fargesyntese -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
