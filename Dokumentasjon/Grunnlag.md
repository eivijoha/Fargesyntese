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
| KI **på enheten** (Foundation Models) med strukturert utdata i et kategorisk fargespråk (familie, lyshet, metning), forankret i en kunnskapsbase | Personvern, ingen nøkler, fungerer offline. Små modeller treffer dårlig på OKLCH-tall; kategorier + deterministisk utregning gir riktige kulører. Kunnskapsbasen alene når Apple Intelligence mangler. |
| SwiftData med fargene som JSON i ett felt | Robust mot modellendringer og klar for CloudKit-synk. |

## Plattformforskjeller

| Funksjon | iPhone/iPad | Mac |
|---|---|---|
| Skjermpipette | Systemets `ColorPicker`-pipette (kun i appens vindu). iOS tillater ikke utplukk utenfor appen – bruk skjermbilde + Utplukk › Bilde. | `NSColorSampler`, hele skjermen |
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

## Status (fase 1 – påbegynt)

- [x] Import av egne ICC-profiler (.icc/.icm), lagret i Application Support/Profiler, navn lest fra `desc`/`mluc`
- [x] Profilverdier i Studio med gjengivelseshensikt, glidere i profilens komponenter (CMYK/RGB/grå)
- [x] Varsel når fargen er utenfor profilens gamut (ΔE_OK etter rundtur > 0,02)
- [x] `Fargetolk`: hex, `rgb()`, `hsl()`, `hwb()`, `lab()`, `lch()`, `oklab()`, `oklch()`, `color()`, `cmyk()`, CSS-navn;
      Studio-feltet tar CSS-tekst, paletter kan lime inn lister (også `--navn: verdi;`)
- [x] Utplukk fra bilder (Bilder/Filer): fargestyrt via bildets profil, lupe, dominerende farger (k-means i OKLab)

## Status (fase 1b – KI, WCAG og steg)

- [x] KI med Foundation Models: strømmende forslag, samtale med fritekstjusteringer, navngiving,
      vurdering med verktøykall (`kontrast`) og eksakte WCAG-fakta, automatisk leksikon-reserve
- [x] Rolleregler etter generering: bakgrunn tydelig lys/mørk, tekst minst WCAG AA
- [x] Hurtigjusteringer i OKLCH (varmere, kaldere, lysere, mørkere, mettet, dempet, kontrast)
- [x] WCAG 2.2: kontrasttest i Studio (AA/AAA tekst, stor tekst, grafikk 1.4.11), «Rett opp», kontrastmatrise per palett,
      Siri/Snarveier-handling «Sjekk kontrast»
- [x] Lysere/mørkere: antall og stegstørrelse per retning, faste steg (%-poeng) eller relativt mot hvitt/sort
- [x] Kopieringsknapp per rad i «Verdier»; «Legg i palett» kan opprette ny palett med navn
- [x] Trykk/klikk i kamerabildet plukker fargen der (iOS, iPadOS, macOS); trykk i bilde fanger også
- [x] `swift run kiprove` – kommandolinjeverktøy for å prøve promptene mot modellen på Macen

Kjent: i iOS-simulatoren feiler Foundation Models med `promptTemplateNotFound` (simulator/modell-misforhold);
appen faller da tilbake til leksikonet. Samme kode fungerer mot modellen på macOS.

## Status (fase 1c – køen)

- [x] **Fargeharmonier** i Studio: komplementær, split-komplementær, analog, dobbelt komplementær og jevn fordeling
      (2–12 farger); vinkel og fargesirkel (OKLCH perseptuell eller HSL tradisjonell) kan velges; fargesirkel-visning
- [x] **ΔE2000** (CIEDE2000, verifisert mot Sharma-datasettet) med ΔE76 og ΔE_OK: A/B-sammenligning fra kamera, bilde,
      skjermpipette (macOS), aktiv farge, utklippstavle eller siste målinger; ΔE-merke mellom de to siste fangede fargene
- [x] **Adobe**: ASE (ingen fargegrense) og ACO (Photoshop, v1+v2 med navn, Lab for farger utenfor sRGB)
- [x] **Figma**: variabler (DTCG-JSON for «Import variables»), Tokens Studio, SVG-fargeprøver (fil og utklippstavle –
      limes inn som fylte former)
- [x] **CSS-gradient** fra Overgang: lineær/radiell/konisk, retning, trinnvis, `in oklab` + sRGB-reserve, forhåndsvisning

- [x] **Lyskilder**: lykt på iPhone/iPad (og Continuity-iPhone på Mac) med styrke; lysfelt på Mac-skjermen
- [x] **Fargesirkler**: OKLCH, CIE LCH, HSL og RYB (kunstnersirkel); interaktiv sirkel
- [x] **Paletter**: dra farger mellom paletter (også i listen på iPhone), «Kopier til» / «Flytt til»,
      hver utplukket farge kan legges i palett
- [x] **ICC via iCloud Drive**: importerte profiler i «Fargesyntese › Profiler» (synlig i Filer/Finder), med
      NSMetadataQuery for endringer fra andre enheter; lokal reserve uten iCloud
- [x] **Profil-til-profil-konvertering** med valgt gjengivelseshensikt, sammenligning av alle fire hensikter med ΔE00

Gjenstår i disse sporene: Adobe Color-tema direkte (krever Adobe-konto/API), Figma REST-API for variabler
(krever Enterprise-plan) eller egen Figma-plugin, RYB-«kunstnersirkel» for harmonier.

## Veikart

**Fase 1 – kjernen i bruk**
- Softproof: vis fargen slik den blir på trykk (rundtur gjennom profilen) side om side med skjermfargen
- Overgangsmodus: OKLab (standard) / OKLCH (kortere/lengre kulørvei) / easing-kurver
- Omorganisering, navngiving og låsing av farger i palett; angre/gjør om
- Bildeutplukk: zoom/panorering, dra-og-slipp av bilder, velge region for dominerende farger
- Hvitbalanse-lås og referansekort for kamera

**Fase 2 – designerflyt**
- Kontrastmatrise (WCAG 2 + APCA) og fargeblindhetssimulering
- Flere eksportformater: Procreate `.swatches`, Apple `.clr` (Mac), Figma-variabler, Tailwind, Android XML
- iCloud-synk (CloudKit) og deling av paletter
- Widget og Kontrollsenter-kontroll (siste palett, rask pipette/kamera)

### Semantisk grunnlag for KI (2026-09-30)

- `Fargesemantikk.json`: ~115 begreper (fargeord, natur, tid, materialer, verdier, stiler) med norske og engelske
  synonymer, kulørfamilier med vekt, lyshets- og metningsnivåer, aksent, harmoni og notat. Merkevarer er formålet,
  ikke grunnlaget – ingen bransjeklisjeer. Natur = levende, klare farger.
- Oppslag med bøyning og sammensetninger («skogsgrønn» → skog + grønn). Fakta sendes med i prompten.
- Modellen velger familie/lyshet/metning (relativ til gamut); minste metning per rolle og en «brunvakt» hindrer
  grå og brune toner når begrepene ikke ber om dem.
- `kiprove eval`: 15 faste verdiord × 2. Før: primær i forventet kulør 5/18, brune 15 %, lite kulør 26 %,
  snittkroma 0,084. Etter: 17/17, 7 %, 6 %, 0,134 (før brunvakt).
- «Beskriv en farge» (App Intent, Siri og Studio-feltet): beskrivelse → farge i OKLCH, vist i Studio.
  Eksplisitte ord (pastell, dyp, neon …) overstyrer modellen.

**Fase 3 – Siri og KI**
- Siri med skjermbevissthet: knytt `NSUserActivity`/`appEntityIdentifier` til åpen palett
- Interaktive snippets i Snarveier (vis paletten direkte i Siri-svaret)
- KI: forklar/kritiser palett, foreslå navn, generer varianter («varmere», «mer eksklusiv»)
- Spotlight-indeksering ved hver lagring (i dag bare ved intents)
