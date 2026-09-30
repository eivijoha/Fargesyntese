# Fargesyntese – grunnlag og veikart

## Mål

Et fargeverktøy for designere som bygger paletter på tvers av fargemodeller (OKLab, OKLCH, CIELab,
LCH, HSB, HSL, RGB/Display P3, CMYK med ICC), med KI-støtte for verdiord, overgangstoner i OKLab,
lys/mørk-skalaer, kamera- og skjermutplukk, eksport, utklippstavle, App Intents, Snarveier og Siri.
iOS er den avgrensende plattformen; iPad og Mac får mer plass, ikke andre funksjoner (unntak: skjermpipette).

## Arkitektur

```
┌──────────────── Fargesyntese (SwiftUI, iOS/iPadOS/macOS) ────────────────┐
│ Visninger: Studio · Paletter · Overgang · Kamera · Verdiord              │
│ Plattform: KameraFargeplukker · Pipette · Utklippstavle · Transferable   │
│ Intents:   PalettEntity (IndexedEntity) · 3 intents · AppShortcuts       │
│ Modell:    PalettDokument (SwiftData, CloudKit-klar)                     │
└───────────────┬───────────────────────────────────────┬──────────────────┘
                │                                       │
      ┌─────────▼──────────┐                  ┌─────────▼──────────┐
      │ FargeKjerne        │◄─────────────────┤ FargeKI            │
      │ Farge, fargerom,   │                  │ Foundation Models  │
      │ gamut, overgang,   │                  │ + leksikon-reserve │
      │ toneskala, ICC,    │                  └────────────────────┘
      │ eksport            │
      └────────────────────┘
```

### Viktige beslutninger

| Beslutning | Begrunnelse |
|---|---|
| `Farge` lagres som **lineær, utvidet sRGB** (Double) | Én kanonisk form; P3-farger fra kamera/skjerm bevares (verdier utenfor 0…1). |
| **CIELab med D50** (Bradford) | Samme som ICC, Photoshop og CSS `lab()`; verdiene stemmer med designverktøyene. |
| **Gamut-kartlegging etter CSS Color 4** (kroma-reduksjon i OKLCH) | Bevarer lyshet og kulør. Hard klipping gir kulørforskyvning. |
| Overganger **lineært i OKLab** | Jevne perseptuelle steg, korteste vei. Merk: komplementærfarger går via grått (se veikart). |
| Toneskala med **kromademping** mot ytterpunktene | Lyse og mørke toner blir naturlige og havner mindre utenfor gamut. |
| Naiv CMYK *og* ICC-CMYK | Naiv for rask visning; ICC (ColorSync) for trykk, med valgbar gjengivelseshensikt. |
| KI **på enheten** (Foundation Models) med strukturert utdata i OKLCH | Personvern, ingen nøkler, fungerer offline. Leksikon når Apple Intelligence mangler. |
| SwiftData med fargene som JSON i ett felt | Robust mot modellendringer og klar for CloudKit-synk. |

## Plattformforskjeller

| Funksjon | iPhone/iPad | Mac |
|---|---|---|
| Skjermpipette | Systemets `ColorPicker`-pipette (kun i appens vindu). iOS tillater ikke utplukk utenfor appen. | `NSColorSampler`, hele skjermen |
| Kamera | Bakkamera | Innebygd kamera / Continuity Camera |
| Kopier | `UIPasteboard`: fargeobjekt + tekst i samme element | `NSPasteboard`: `NSColor` + streng; ⌥⌘C / ⌥⌘V |
| Dra og slipp | `Transferable` (hex til andre apper, full presisjon internt) | Samme |

## Status (fase 0 – skjelett)

- [x] Fargerom: sRGB, Display P3, XYZ, OKLab, OKLCH, CIELab (D50), LCH, HSB, HSL, naiv CMYK
- [x] ICC-profiler via CoreGraphics (innebygde + lasting fra data), gjengivelseshensikt
- [x] Gamut-kartlegging, ΔE_OK, WCAG-kontrast
- [x] Overgangstoner (to- og flerpunkts) i OKLab, lys/mørk-variasjoner, toneskala 50–950
- [x] Eksport: ASE, CSS (oklch + hex), W3C Design Tokens, GPL, SwiftUI, hex-liste
- [x] Verdiord → palett (Foundation Models + leksikon)
- [x] App: Studio, Paletter, Overgang, Kamera, Verdiord; kopier/lim inn; dra og slipp
- [x] App Intents: lag palett fra verdiord, lag overgang, konverter farge; AppShortcuts med norske fraser
- [x] 15 enhetstester (referanseverdier fra CSS Color 4)

## Veikart

**Fase 1 – kjernen i bruk**
- Import av egne ICC-profiler (`fileImporter`), profilbibliotek, visning av «utenfor trykkgamut»
- Tolking av CSS-fargetekst ved innliming (`oklch()`, `lab()`, `rgb()`, `hsl()`)
- Overgangsmodus: OKLab (standard) / OKLCH (kortere/lengre kulørvei) / easing-kurver
- Omorganisering, navngiving og låsing av farger i palett; angre/gjør om
- Fargeutplukk fra bilder og skjermbilder (PhotosPicker + lupe) – iOS-alternativet til skjermpipette
- Hvitbalanse-lås og referansekort for kamera

**Fase 2 – designerflyt**
- Kontrastmatrise (WCAG 2 + APCA) og fargeblindhetssimulering
- Flere eksportformater: Procreate `.swatches`, Apple `.clr` (Mac), Figma-variabler, Tailwind, Android XML
- iCloud-synk (CloudKit) og deling av paletter
- Widget og Kontrollsenter-kontroll (siste palett, rask pipette/kamera)

**Fase 3 – Siri og KI**
- Siri med skjermbevissthet: knytt `NSUserActivity`/`appEntityIdentifier` til åpen palett
- Interaktive snippets i Snarveier (vis paletten direkte i Siri-svaret)
- KI: forklar/kritiser palett, foreslå navn, generer varianter («varmere», «mer eksklusiv»)
- Spotlight-indeksering ved hver lagring (i dag bare ved intents)
