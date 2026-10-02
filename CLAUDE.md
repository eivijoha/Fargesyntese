# Kolorist

Fargepalett-verktøy for designere – iOS, iPadOS og macOS (én multiplattform-target, SwiftUI).
**iOS er den avgrensende plattformen**: design og test for iPhone først, utvid for iPad/Mac.

## Struktur

- `Pakker/FargeKjerne/` – Swift-pakke, ingen UI:
  - `FargeKjerne`: `Farge` (kanonisk lineær utvidet sRGB), fargerom, gamut-kartlegging,
    `Overgang` (OKLab), `Toneskala`, ICC via CoreGraphics, eksport (ASE, CSS, DTCG, GPL, SwiftUI).
  - `FargeKI`: verdiord → palett og beskrivelse → farge. Kunnskapsbasen `Fargesemantikk.json` (fargebegreper
    med kulørfamilier, lyshet og metning) gir grunnlaget; modellen tolker bare ordene (kulørfamilier og
    uttrykk, `GenerertTolkning`), og `Palettkomponist` (`Komposisjon.swift`) bygger paletten deterministisk etter en
    `Palettoppskrift`: harmoniprinsipp, lik valør/metning, aksent, lys/mørk bakgrunn og kontrastkrav. Brunt bare for
    begreper merket `brunt` i kunnskapsbasen. `LeksikonTolker` bygger på samme base uten KI.
    Mål endringer med `swift run kiprove eval` (treff på kulør, andel brune og grå toner, kontrast mot bakgrunn).
- `Kolorist/` – appen (filsystem-synkronisert gruppe; nye filer plukkes opp automatisk).
  `App/`, `Modell/` (SwiftData), `Visninger/`, `Plattform/` (kamera, pipette, utklippstavle), `Intents/`.
- `Konfigurasjon/Info.plist` – kun det som ikke kan settes med `INFOPLIST_KEY_*` (eksporterte UTType-er,
  iCloud Drive-mappen). `Konfigurasjon/Kolorist.entitlements` – iCloud Documents og CloudKit (`iCloud.no.engenett.Kolorist`).
- Bundle-ID `no.engenett.Kolorist`. Byttet fra Fargesyntese (og kort Gamut Changer) 2026-10-01; gamle data og datamodeller
  blir liggende og overføres ikke – det finnes ingen migrering. Pakkene `FargeKjerne`/`FargeKI` er
  fagnavn, ikke appnavn, og beholdes.
- Fysisk testenhet: «Burgund» (iPhone 18 Pro). Bygg med `-allowProvisioningUpdates`, installer med `xcrun devicectl`.
- `Dokumentasjon/Grunnlag.md` – arkitektur, beslutninger og veikart.

## Konvensjoner

- Domenetyper og -metoder på norsk (`Farge`, `Palett`, `toner(fra:til:antall:)`), Apple-API-er som de er.
  All UI-tekst på norsk bokmål.
- All interpolasjon i OKLab. Farger klippes aldri før visning/eksport – bruk `gamutKartlagt(til:)`, ikke `klippet(til:)`.
- Matriser følger CSS Color 4; inverser utledes med `Matrise3.invertert` i stedet for å hardkodes.
- App-target bruker `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`; bakgrunnskode merkes `nonisolated`.

## Lokalisering (nb = kildespråk, en)

- Strengkataloger: `Kolorist/Localizable.xcstrings`, `AppShortcuts.xcstrings` (Siri-fraser), `InfoPlist.xcstrings`,
  og `Localizable.xcstrings` i hvert pakkemål (`FargeKjerne`, `FargeKI`, deklarert som `resources`).
- `Text("…")`-literaler lokaliseres automatisk. Tekst som går via `String` må pakkes i `String(localized:)`
  (i pakken: `String(localized: "…", bundle: .module)`).
- Nye strenger: bygg, og kjør `xcrun xcstringstool sync <katalog> --stringsdata …` med `.stringsdata` fra byggets
  `Objects-normal` (Xcode-IDE-et gjør dette automatisk ved bygg). Legg så inn engelsk.
- KI svarer på appens språk (`Språk.svarinstruks` i FargeKI).
- Arbeidsmappen er `~/App-utvikling/Kolorist` (utenfor Jottacloud, fra 2026-10-01). Den gamle kopien i
  `~/Jottacloud/App-utvikling/Kolorist` er tatt ut av synk og brukes ikke. GitHub er fasiten.

## Bygg og test

```bash
cd Pakker/FargeKjerne && swift test
xcodebuild -project Kolorist.xcodeproj -scheme Kolorist -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Kolorist.xcodeproj -scheme Kolorist -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```
